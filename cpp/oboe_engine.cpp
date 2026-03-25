#include "oboe_engine.h"
#include <iostream>

OboeEngine::OboeEngine() : dspEngine(48000.0f) {
}

OboeEngine::~OboeEngine() {
    stop();
}

bool OboeEngine::start() {
    // Para simplificar a Integração, estamos configurando a perna de Output (Speaker/Headphone)
    // Para um pass-through real de microfone, instanciaríamos o InputStream sincronizado aqui.
    oboe::AudioStreamBuilder builder;
    
    // 1. OBRIGAÇÃO DA ENGENHARIA: 48kHz (Acesso Direto ao Mixer nativo do Android OS)
    builder.setSampleRate(48000);
    
    // 2. OBRIGAÇÃO DE LATÊNCIA: < 20ms
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    
    // Configurações Físicas
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setChannelCount(oboe::ChannelCount::Mono);
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
    
    // [PREPARAÇÃO: Pass-Through do Microfone virá para preencher floatData aqui]
    // Por enquanto, preenchemos com silêncio para não dar lixo de memória na placa de som
    for(int i = 0; i < numFrames * oboeStream->getChannelCount(); i++) {
        floatData[i] = 0.0f; // Silence / Mic Placeholder
    }

    // Processamento do Pipeline DSP
    // Roteamento para a matemática Híbrida do Crossover e EQ paramétrico
    dspEngine.processAudioBlock(floatData, numFrames, oboeStream->getChannelCount());
    
    return oboe::DataCallbackResult::Continue;
}
