#include "oboe_engine.h"
#include <iostream>

OboeEngine::OboeEngine() : dspEngine(48000.0f) {
}

OboeEngine::~OboeEngine() {
    stop();
}

bool OboeEngine::start() {
    if (outputStream) return true; // Já está rodando [IDEMPOTENTE]

    oboe::AudioStreamBuilder builder;
    
    // 1. OBRIGAÇÃO DA ENGENHARIA: 48kHz (Acesso Direto ao Mixer nativo do Android OS)
    builder.setSampleRate(48000);
    
    // 2. OBRIGAÇÃO DE LATÊNCIA: < 20ms
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    
    // Configurações Físicas
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setChannelCount(oboe::ChannelCount::Stereo);
    builder.setDirection(oboe::Direction::Output);
    
    // 3. Thread Nativa para impedir bloqueio à UI
    builder.setCallback(this);

    oboe::Result result = builder.openStream(outputStream);
    
    if (result == oboe::Result::OK) {
        // Double buffering rule
        outputStream->setBufferSizeInFrames(outputStream->getFramesPerBurst() * 2);
        
        result = outputStream->requestStart();
        if (result == oboe::Result::OK) return true;
    }
    return false;
}

void OboeEngine::stop() {
    if (outputStream) {
        outputStream->requestStop();
        outputStream->close();
        outputStream.reset();
    }
    if (inputStream) {
        inputStream->requestStop();
        inputStream->close();
        inputStream.reset();
    }
}

// O Hardware pede novos dados síncronos
oboe::DataCallbackResult OboeEngine::onAudioReady(
    oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {
    
    float *floatData = static_cast<float *>(audioData);
    
    // MIXER NATIVO (Zero Latency Synthesis)
    float panningValue = targetPanning.load();
    float leftGain = (panningValue <= 0.0f) ? 1.0f : (1.0f - panningValue);
    float rightGain = (panningValue >= 0.0f) ? 1.0f : (1.0f + panningValue);

    for(int i = 0; i < numFrames; i++) {
        float monoTarget = targetPlayer.getNextSample();
        float monoNoise = noisePlayer.getNextSample();
        float monoWhite = whiteNoiseGenerator.getNextSample();

        for(int ch = 0; ch < 2; ch++) {
            float mixedSample = 0.0f;
            float gain = (ch == 0) ? leftGain : rightGain;
            
            // 1. Testa tom puro (Lateralizado via Oscillador)
            mixedSample += testOscillator.getNextSample(ch);
            
            // 2. Canal de Estimulação Espacializada (Binaural Panning)
            mixedSample += monoTarget * gain;
            
            // 3. Canais de Ruído (Centrados para Mascaramento)
            mixedSample += monoNoise;
            mixedSample += monoWhite;

            floatData[i * 2 + ch] = mixedSample;
        }
        testOscillator.updatePhase();
    }

    // Processamento do Pipeline DSP (IIR/FIR Híbrido)
    // Roteamento para a matemática Híbrida do Crossover e EQ paramétrico
    dspEngine.processAudioBlock(floatData, numFrames, oboeStream->getChannelCount());
    
    return oboe::DataCallbackResult::Continue;
}
