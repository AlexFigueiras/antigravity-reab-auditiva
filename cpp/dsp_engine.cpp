#include "dsp_engine.h"

DspEngine::DspEngine(float sr) : sampleRate(sr) {
    for (int i = 0; i < 2; i++) {
        highFreqBuffer[i].resize(2048, 0.0f);
        delayWritePtr[i] = 0;
        for(int j=0; j<512; j++) lowFreqDelayBuffer[i][j] = 0.0f;
    }
    initializeParameters();
}

DspEngine::~DspEngine() {}

// Configura matematicamente o Motor de Acordo com as Regras Clínicas
void DspEngine::initializeParameters() {
    for (int i = 0; i < 2; i++) {
        // 1. Crossover de 1000 Hz: Filtro Passa-Baixa (IIR) para os graves (Q = 0.707 - Butterworth)
        lowPass1000Hz[i].configureLowPass(sampleRate, 1000.0f, 0.707f);

        // 2. Filtro FIR Janelado (Fase Estritamente Linear) - 512 taps, Beta 5.0 (Kaiser)
        highPassFir[i].designHighPassKaiser(sampleRate, 1000.0f, 5.0f);

        // 3. TEE: Temporal Envelope Expansion
        teeProcessor[i].initialize(sampleRate, 2.0f, 30.0f, 0.7f);

        // 4. Equalizador de Pico (Peaking EQ): Realça Transientes
        peakingEQ[i].configurePeakingEQ(sampleRate, 5500.0f, 4.32f, 4.0f);
    }
}

// Núcleo de Latência Ultrabaixa (Obrigação: Executar em < 20ms de latência overall)
void DspEngine::processAudioBlock(float* audioData, int numFrames, int numChannels) {
    if (numChannels > 2) numChannels = 2; // Suporta apenas mono/stereo

    // 1. Extrai canais para processamento FIR (que exige buffer contíguo)
    std::vector<float> channelData[2];
    for (int ch = 0; ch < numChannels; ch++) {
        channelData[ch].resize(numFrames);
        if (highFreqBuffer[ch].size() < numFrames) highFreqBuffer[ch].resize(numFrames);
        
        for (int i = 0; i < numFrames; i++) {
            channelData[ch][i] = audioData[i * numChannels + ch];
        }
        
        // 2. Processa FIR High-Pass
        highPassFir[ch].processBlockOverlapSave(channelData[ch].data(), highFreqBuffer[ch].data(), numFrames);
    }

    // 3. Loop de Processamento Final (Interleaved)
    for (int i = 0; i < numFrames; i++) {
        for (int ch = 0; ch < numChannels; ch++) {
            float sample = channelData[ch][i];

            // A. Grave via IIR + Retardo para alinhar com o Agudo (Atraso FIR = 256)
            float lowFreqRaw = lowPass1000Hz[ch].process(sample);
            
            // Pega amostra antiga (atrasada)
            int readPtr = (delayWritePtr[ch] - 256 + 512) % 512;
            float lowFreq = lowFreqDelayBuffer[ch][readPtr];
            
            // Salva amostra atual no buffer circular
            lowFreqDelayBuffer[ch][delayWritePtr[ch]] = lowFreqRaw;
            delayWritePtr[ch] = (delayWritePtr[ch] + 1) % 512;

            // B. Agudo via FIR (já calculado com atraso natural de 256)
            float highFreq = highFreqBuffer[ch][i]; 
            
            // C. Modulação TEE
            highFreq = teeProcessor[ch].process(highFreq);

            // D. Peaking EQ
            highFreq = peakingEQ[ch].process(highFreq);

            // E. Mix e Clipping Limiter Clínico
            float outSample = lowFreq + highFreq;
            if (outSample > 1.0f) outSample = 1.0f;
            else if (outSample < -1.0f) outSample = -1.0f;

            audioData[i * numChannels + ch] = outSample;
        }
    }
}
