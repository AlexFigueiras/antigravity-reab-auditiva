#pragma once
#include "biquad_filter.h"
#include "fir_filter.h"
#include "tee_processor.h"
#include <vector>

// Motor de Processamento Digital de Sinais do Inova Simples Hearing
class DspEngine {
private:
    float sampleRate;

    // Componentes Acústicos (Stereo ready - Dual path)
    BiquadFilter lowPass1000Hz[2];  // Crossover para graves (L/R)
    BiquadFilter peakingEQ[2];      // Reforço paramétrico para fonemas /s/ (L/R)
    
    // Novo Pipeline Clínico de Compressão e Transientes (> 1.000 Hz)
    PartitionedFIR highPassFir[2];
    TemporalEnvelopeExpander teeProcessor[2];

    // Novo: Delay de compensação para alinhar IIR (Grave) com o FIR (Agudo)
    // FIR de 512 taps = Atraso de 256 amostras.
    float lowFreqDelayBuffer[2][512]; 
    int delayWritePtr[2];

    // Buffer da rota de Convolução
    std::vector<float> highFreqBuffer[2];


public:
    DspEngine(float sr = 48000.0f);
    ~DspEngine();

    void initializeParameters();
    
    // Bloco Principal de Processamento do Callback de Áudio (C++ Core)
    void processAudioBlock(float* audioData, int numFrames, int numChannels);
};
