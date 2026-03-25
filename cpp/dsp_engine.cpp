#include "dsp_engine.h"

DspEngine::DspEngine(float sr) : sampleRate(sr), highPassFir(512, 128) {
    initializeParameters();
    highFreqBuffer.resize(2048, 0.0f); // Prevenção de Segurança de Memória
}

DspEngine::~DspEngine() {}

// Configura matematicamente o Motor de Acordo com as Regras Clínicas
void DspEngine::initializeParameters() {
    // 1. Crossover de 1000 Hz: Filtro Passa-Baixa (IIR) para os graves (Q = 0.707 - Butterworth)
    lowPass1000Hz.configureLowPass(sampleRate, 1000.0f, 0.707f);

    // 2. Filtro FIR Janelado (Fase Estritamente Linear) - 512 taps, Beta 5.0 (Kaiser Janela Ouro)
    highPassFir.designHighPassKaiser(sampleRate, 1000.0f, 5.0f);

    // 3. TEE: Temporal Envelope Expansion
    // Attack=2.0ms, Release=30.0ms, Gamma=0.7 (Punch Clássico de Sibilante)
    teeProcessor.initialize(sampleRate, 2.0f, 30.0f, 0.7f);

    // 4. Equalizador de Pico (Peaking EQ): Realça Transientes
    // Frequência Central: 5500 Hz (fator Q: 4.32 = 1/3 de Oitava), Ganho: +4.0 dB
    peakingEQ.configurePeakingEQ(sampleRate, 5500.0f, 4.32f, 4.0f);
}

// Núcleo de Latência Ultrabaixa (Obrigação: Executar em < 20ms de latência overall)
void DspEngine::processAudioBlock(float* audioData, int numFrames, int numChannels) {
    // Garantia matemática de bloco contíguo Mono Seguro (Evita re-scaling do loop em Estéreo avançado)
    if (highFreqBuffer.size() < numFrames) highFreqBuffer.resize(numFrames);

    // Pré-Processamento por Blocos: Overlap-Save FIR Convolução Simulativa
    highPassFir.processBlockOverlapSave(audioData, highFreqBuffer.data(), numFrames);

    for (int i = 0; i < numFrames; i++) {
        for (int ch = 0; ch < numChannels; ch++) {
            int index = i * numChannels + ch;
            float sample = audioData[index];

            // 1. Grave via IIR de Alta Eficiência
            float lowFreq = lowPass1000Hz.process(sample);
            
            // 2. Agudo via Array de FIR de Fase Linear Calculado Anteriormente
            // A leitura é sincronizada por índice em HighFreqBuffer
            float highFreq = highFreqBuffer[i]; 
            
            // 3. Modulação Não-Linear (TEE - Expansão de Transientes com Gamma=0.7)
            highFreq = teeProcessor.process(highFreq);

            // 4. Aplicação do Filtro Sibilante / Sharpening Paramétrico de Banda Estreita (Q=4.32)
            highFreq = peakingEQ.process(highFreq);

            // 5. Soma de Sinal e Restauro Estrutural
            float outSample = lowFreq + highFreq;

            // 6. Hard/Soft Limiter Preventivo de Ataque Zero <1ms
            if (outSample > 0.99f) outSample = 0.99f;
            else if (outSample < -0.99f) outSample = -0.99f;

            audioData[index] = outSample;
        }
    }
}
