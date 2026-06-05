#pragma once
#include "biquad_filter.h"
#include "fir_filter.h"
#include "tee_processor.h"
#include <vector>
#include <atomic>

// Motor de Processamento Digital de Sinais do Inova Simples Hearing
class DspEngine {
private:
    float sampleRate;

    // Componentes Acústicos (Stereo ready - Dual path)
    BiquadFilter lowPass1000Hz[2];  // Crossover para graves (L/R)

    // EQ multibanda CLÍNICO, individualizado pelo audiograma (regra de meia-perda).
    // Antes era um peaking fixo de +4 dB @ 5500 Hz igual para todos; agora cada
    // banda recebe o ganho enviado pelo Dart (0 dB = passa-tudo). No modo "com
    // aparelho" o Dart manda tudo 0 (o aparelho já compensa). Ver plano 1.1 / 0.4.
    // Centros (Hz) definidos como constexpr local em dsp_engine.cpp (kEqCenters),
    // casados com as frequências audiométricas usadas no Dart: 1k/2k/4k/6k/8k.
    static constexpr int kNumEqBands = 5;
    static constexpr float kEqQ = 1.0f; // ~1 oitava: bandas se sobrepõem e formam shelf suave
    BiquadFilter eqBands[2][kNumEqBands]; // banco de peaking por canal (L/R)
    std::atomic<float> eqBandGainDb[kNumEqBands]; // ganho-alvo por banda (setado pelo Dart)
    std::atomic<bool> eqDirty{true};              // recalcula coeficientes no audio thread


    // Novo Pipeline Clínico de Compressão e Transientes (> 1.000 Hz)
    PartitionedFIR highPassFir[2];
    TemporalEnvelopeExpander teeProcessor[2];

    static constexpr int kMaxFramesPerCallback = 1024;
    static constexpr int kDelayBufferSize = 512;
    static constexpr int kFirGroupDelay = kDelayBufferSize / 2; // 256 amostras de atraso para FIR de 512 taps

    // Novo: Delay de compensação para alinhar IIR (Grave) com o FIR (Agudo)
    float lowFreqDelayBuffer[2][kDelayBufferSize]; 
    int delayWritePtr[2];

    // Buffers estáticos para alocação zero no hot path
    float channelDataBuffer[2][kMaxFramesPerCallback];
    float highFreqBuffer[2][kMaxFramesPerCallback];

    // Modo Engenheiro: Diagnóstico de Saturação
    std::atomic<bool> isSoftKneeHit{false};

public:
    DspEngine(float sr = 48000.0f);
    ~DspEngine();

    void initializeParameters();

    // Define o ganho (dB) de cada banda do EQ clínico a partir do audiograma.
    // Thread-safe: guarda nos atomics e marca `eqDirty`; os coeficientes são
    // recalculados no audio thread (sem leituras parciais / sem trig no hot path).
    void setEqBandGains(const float* gainsDb, int n);

    // Bloco Principal de Processamento do Callback de Áudio (C++ Core)
    void processAudioBlock(float* audioData, int numFrames, int numChannels);

    bool consumeSoftKneeFlag() {
        return isSoftKneeHit.exchange(false, std::memory_order_relaxed);
    }
    
    void setSoftKneeFlag() {
        isSoftKneeHit.store(true, std::memory_order_relaxed);
    }
};
