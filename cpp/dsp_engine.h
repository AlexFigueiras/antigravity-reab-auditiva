#pragma once
#include "biquad_filter.h"
#include "fir_filter.h"
#include "tee_processor.h"
#include <vector>

// Motor de Processamento Digital de Sinais do Inova Simples Hearing
class DspEngine {
private:
    float sampleRate;

    // Componentes Acústicos
    BiquadFilter lowPass1000Hz;  // Crossover para graves
    BiquadFilter peakingEQ;      // Reforço paramétrico para fonemas /s/
    
    // Novo Pipeline Clínico de Compressão e Transientes (> 1.000 Hz)
    PartitionedFIR highPassFir;
    TemporalEnvelopeExpander teeProcessor;

    // Buffer da rota de Convolução
    std::vector<float> highFreqBuffer;


public:
    DspEngine(float sr = 48000.0f);
    ~DspEngine();

    void initializeParameters();
    
    // Bloco Principal de Processamento do Callback de Áudio (C++ Core)
    void processAudioBlock(float* audioData, int numFrames, int numChannels);
};
