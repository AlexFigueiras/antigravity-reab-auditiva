#include "dsp_engine.h"
#include <cmath>
#include <algorithm>
#include <chrono>

// Centros das bandas do EQ clínico (Hz), casados com as frequências do Dart.
// Local (não membro) para evitar ODR-use de array static constexpr. O tamanho é
// validado contra DspEngine::kNumEqBands por static_assert em initializeParameters.
static constexpr float kEqCenters[5] = {1000.f, 2000.f, 4000.f, 6000.f, 8000.f};

inline float processSoftKneeLimiter(float sample, DspEngine* engine) {
    const float threshold = 0.707f; // -3 dBFS (Volume máximo linear de fala)
    const float maxLimit = 0.98f;   // -0.17 dBFS (Trava Absoluta)
    const float headroom = maxLimit - threshold;

    float absSample = std::abs(sample);
    if (absSample <= threshold) {
        return sample; 
    } 
    
    // Modo Engenheiro: Captura o pico de saturação para a UI
    engine->setSoftKneeFlag();

    // Região Saturada Asintótica
    float overShoot = absSample - threshold;
    float outSample = threshold + (overShoot / (1.0f + (overShoot / headroom)));
    
    return (sample > 0.0f) ? outSample : -outSample;
}

DspEngine::DspEngine(float sr) : sampleRate(sr) {
    for (int i = 0; i < 2; i++) {
        for(int j=0; j<kMaxFramesPerCallback; j++) {
            channelDataBuffer[i][j] = 0.0f;
            highFreqBuffer[i][j] = 0.0f;
        }
        delayWritePtr[i] = 0;
        for(int j=0; j<kDelayBufferSize; j++) lowFreqDelayBuffer[i][j] = 0.0f;
    }
    initializeParameters();
}

DspEngine::~DspEngine() {}

// Configura matematicamente o Motor de Acordo com as Regras Clínicas
void DspEngine::initializeParameters() {
    static_assert(kNumEqBands == 5, "kEqCenters precisa ter kNumEqBands elementos");

    for (int i = 0; i < 2; i++) {
        // 1. Crossover de 1000 Hz: Filtro Passa-Baixa (IIR) para os graves (Q = 0.707 - Butterworth)
        lowPass1000Hz[i].configureLowPass(sampleRate, 1000.0f, 0.707f);

        // 2. Filtro FIR Janelado (Fase Estritamente Linear) - 512 taps, Beta 5.0 (Kaiser)
        highPassFir[i].designHighPassKaiser(sampleRate, 1000.0f, 5.0f);

        // 3. TEE: Temporal Envelope Expansion
        teeProcessor[i].initialize(sampleRate, 5.0f, 45.0f, 0.7f);

        // 4. EQ multibanda clínico: começa PLANO (0 dB = passa-tudo). Os ganhos
        //    reais vêm do audiograma via setEqBandGains (modo "sem aparelho");
        //    no modo "com aparelho" ficam em 0 (o aparelho já compensa).
        for (int b = 0; b < kNumEqBands; b++) {
            eqBands[i][b].configurePeakingEQ(sampleRate, kEqCenters[b], kEqQ, 0.0f);
        }
    }
    for (int b = 0; b < kNumEqBands; b++) {
        eqBandGainDb[b].store(0.0f, std::memory_order_relaxed);
    }
    eqDirty.store(false, std::memory_order_release);
}

// Recebe os ganhos por banda (dB) do Dart. Apenas guarda nos atomics e marca
// `eqDirty`; o recálculo dos coeficientes (sin/cos/pow) acontece no audio thread,
// no início do próximo bloco — evitando leituras parciais dos coeficientes.
void DspEngine::setEqBandGains(const float* gainsDb, int n) {
    if (!gainsDb) return;
    const int m = (n < kNumEqBands) ? n : kNumEqBands;
    for (int b = 0; b < m; b++) {
        eqBandGainDb[b].store(gainsDb[b], std::memory_order_relaxed);
    }
    // Bandas não informadas ficam em 0 dB (passa-tudo).
    for (int b = m; b < kNumEqBands; b++) {
        eqBandGainDb[b].store(0.0f, std::memory_order_relaxed);
    }
    eqDirty.store(true, std::memory_order_release);
}

// Núcleo de Latência Ultrabaixa (Obrigação: Executar em < 20ms de latência overall)
void DspEngine::processAudioBlock(float* audioData, int numFrames, int numChannels) {
    if (numChannels > 2) numChannels = 2; // Suporta apenas mono/stereo

    if (numFrames > kMaxFramesPerCallback) numFrames = kMaxFramesPerCallback;

    // Recalcula os coeficientes do EQ clínico SÓ quando o Dart mudou os ganhos
    // (troca de audiograma / de modo de escuta). Fora isso, custo zero no hot path.
    if (eqDirty.exchange(false, std::memory_order_acquire)) {
        for (int b = 0; b < kNumEqBands; b++) {
            const float g = eqBandGainDb[b].load(std::memory_order_relaxed);
            for (int ch = 0; ch < 2; ch++) {
                eqBands[ch][b].configurePeakingEQ(sampleRate, kEqCenters[b], kEqQ, g);
            }
        }
    }

    // 1. Extrai canais para processamento FIR (usando buffer pré-alocado)
    for (int ch = 0; ch < numChannels; ch++) {
        for (int i = 0; i < numFrames; i++) {
            channelDataBuffer[ch][i] = audioData[i * numChannels + ch];
        }
        
        // 2. Processa FIR High-Pass
        highPassFir[ch].processBlockOverlapSave(channelDataBuffer[ch], highFreqBuffer[ch], numFrames);
    }

    // 3. Loop de Processamento Final (Interleaved)
    for (int i = 0; i < numFrames; i++) {
        for (int ch = 0; ch < numChannels; ch++) {
            float sample = channelDataBuffer[ch][i];

            // A. Grave via IIR + Retardo para alinhar com o Agudo
            float lowFreqRaw = lowPass1000Hz[ch].process(sample);
            
            // Pega amostra antiga (atrasada)
            int readPtr = (delayWritePtr[ch] - kFirGroupDelay + kDelayBufferSize) % kDelayBufferSize;
            float lowFreq = lowFreqDelayBuffer[ch][readPtr];
            
            // Salva amostra atual no buffer circular
            lowFreqDelayBuffer[ch][delayWritePtr[ch]] = lowFreqRaw;
            delayWritePtr[ch] = (delayWritePtr[ch] + 1) % 512;

            // B. Agudo via FIR (já calculado com atraso natural de 256)
            float highFreq = highFreqBuffer[ch][i]; 
            
            // C. Modulação TEE
            highFreq = teeProcessor[ch].process(highFreq);

            // D. EQ multibanda clínico (ganho por banda vindo do audiograma).
            //    No modo "com aparelho" todas as bandas estão em 0 dB (passa-tudo).
            for (int b = 0; b < kNumEqBands; b++) {
                highFreq = eqBands[ch][b].process(highFreq);
            }

            // E. Mix e Conditional Soft-Knee Limiter (Saturação Transparente)
            float outSample = lowFreq + highFreq;
            outSample = processSoftKneeLimiter(outSample, this);

            audioData[i * numChannels + ch] = outSample;
        }
    }
}
