#include "oboe_engine.h"
#include <iostream>

#if defined(__x86_64__) || defined(__i386__)
#include <xmmintrin.h>
#include <pmmintrin.h>
#endif

namespace {
    inline void setDenormalsAreZero() {
#if defined(__aarch64__)
        uint64_t fpcr;
        __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
        fpcr |= (1 << 24); // FZ (Flush-To-Zero)
        __asm__ __volatile__("msr fpcr, %0" : : "r"(fpcr));
#elif defined(__arm__)
        uint32_t fpscr;
        __asm__ __volatile__("vmrs %0, fpscr" : "=r"(fpscr));
        fpscr |= (1 << 24); // FZ
        __asm__ __volatile__("vmsr fpscr, %0" : : "r"(fpscr));
#elif defined(__x86_64__) || defined(__i386__)
        _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
        _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);
#endif
    }
}

OboeEngine::OboeEngine() : dspEngine(48000.0f) {
}

OboeEngine::~OboeEngine() {
    stop();
}

bool OboeEngine::start() {
    if (outputStream) return true; // Já está rodando [IDEMPOTENTE]

    oboe::AudioStreamBuilder builder;
    builder.setSampleRate(48000);
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setChannelCount(oboe::ChannelCount::Stereo);
    builder.setUsage(oboe::Usage::Media);
    builder.setContentType(oboe::ContentType::Music);
    builder.setDirection(oboe::Direction::Output);
    builder.setCallback(this);

    oboe::Result result = builder.openStream(outputStream);
    if (result != oboe::Result::OK) return false;

    // Double buffering rule
    outputStream->setBufferSizeInFrames(outputStream->getFramesPerBurst() * 2);

    result = outputStream->requestStart();
    return result == oboe::Result::OK;
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
    
    // Modo Engenheiro: Início da cronometria do CPU Load
    auto startTime = std::chrono::high_resolution_clock::now();
    
    // Configura FPU para Flush-to-Zero evitando picos de CPU com N°s Denormais (Silêncio Assintótico)
    setDenormalsAreZero();

    // PROVA DE HARDWARE: Teste de Denormais.
    // NUNCA logar (std::cerr/printf) dentro do callback de audio em tempo real:
    // I/O pega lock e pode alocar, causando XRuns. Apenas registramos o
    // resultado num atomic para inspecao fora da thread de audio.
    static bool denormalTested = false;
    if (!denormalTested) {
        volatile float tiny1 = 1e-20f;
        volatile float tiny2 = 1e-20f;
        volatile float result = tiny1 * tiny2; // 1e-40 é denormal no IEEE 754 float
        ftzActive.store(result == 0.0f, std::memory_order_relaxed);
        denormalTested = true;
    }

    float *floatData = static_cast<float *>(audioData);

    // Usa o número REAL de canais concedidos pelo stream (não assume estéreo).
    // Evita overflow de buffer em streams mono e mantém o roteamento L/R correto.
    const int channelCount = oboeStream->getChannelCount();

    // MIXER NATIVO (Zero Latency Synthesis)
    float panningValue = targetPanning.load();
    float leftGain = (panningValue <= 0.0f) ? 1.0f : (1.0f - panningValue);
    float rightGain = (panningValue >= 0.0f) ? 1.0f : (1.0f + panningValue);

    for(int i = 0; i < numFrames; i++) {
        float monoTarget = targetPlayer.getNextSample();

        // Detecção de Início do Estímulo na exata amostra do hardware [PASSO 2]
        if (monoTarget != 0.0f && !wasStimulusActive) {
            markStimulusOnset();
            wasStimulusActive = true;
        } else if (monoTarget == 0.0f) {
            wasStimulusActive = false;
        }

        float monoNoise = noisePlayer.getNextSample();
        float monoWhite = whiteNoiseGenerator.getNextSample();

        for(int ch = 0; ch < channelCount; ch++) {
            float mixedSample = 0.0f;
            // ch 0 = esquerdo, 1 = direito. Em mono (1 canal) o gain é 1.0.
            float gain = (channelCount < 2) ? 1.0f : ((ch == 0) ? leftGain : rightGain);

            // 1. Testa tom puro (Lateralizado via Oscillador)
            mixedSample += testOscillator.getNextSample(ch);

            // 2. Canal de Estimulação Espacializada (Binaural Panning)
            mixedSample += monoTarget * gain;

            // 3. Canais de Ruído (Centrados para Mascaramento)
            mixedSample += monoNoise;
            mixedSample += monoWhite;

            floatData[i * channelCount + ch] = mixedSample;
        }
        testOscillator.updatePhase();
    }

    // Processamento do Pipeline DSP (IIR/FIR Híbrido)
    // Roteamento para a matemática Híbrida do Crossover e EQ paramétrico
    dspEngine.processAudioBlock(floatData, numFrames, oboeStream->getChannelCount());

    // FIM DA MEDIÇÃO: Cálculo de Carga de CPU dedicada (DSP Load)
    auto endTime = std::chrono::high_resolution_clock::now();
    auto processTimeNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    
    // Tempo total disponível para este bloco: (frames / sampleRate) em nano
    double availableTimeNs = (double)numFrames / 48000.0 * 1e9;
    dspUsage.store((float)(processTimeNs / availableTimeNs), std::memory_order_relaxed);

    return oboe::DataCallbackResult::Continue;
}

void OboeEngine::onErrorBeforeClose(oboe::AudioStream *oboeStream, oboe::Result error) {
    // Log do evento de desconexão e sinaliza para UI [PASSO 4]
    std::cerr << "Oboe onErrorBeforeClose: " << oboe::convertToText(error) << std::endl;
    deviceDisconnected.store(true, std::memory_order_release);
}

void OboeEngine::onErrorAfterClose(oboe::AudioStream *oboeStream, oboe::Result error) {
    std::cerr << "Oboe onErrorAfterClose. Auto-restarting engine." << std::endl;
    // Tenta reativar o motor após a desconexão (ex: fim de chamada telefônica)
    start();
}
