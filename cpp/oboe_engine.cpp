#include "oboe_engine.h"
#include <iostream>
#include <cmath>
#include <algorithm>

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
    bool ok = (result == oboe::Result::OK);
    // Stream (re)aberto com sucesso: limpa a flag de desconexão. Sem isto, após
    // uma troca de rota de áudio (fone, Bluetooth, fim de chamada) a flag ficava
    // presa em true e o Dart entraria em loop de restart. Ver SYSTEM.md §8.
    if (ok) deviceDisconnected.store(false, std::memory_order_release);
    return ok;
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

    float panningValue = targetPanning.load();
    float panLeftGain = (panningValue <= 0.0f) ? 1.0f : (1.0f - panningValue);
    float panRightGain = (panningValue >= 0.0f) ? 1.0f : (1.0f + panningValue);

    // MIXER NATIVO (Zero Latency Synthesis)
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
        float monoAmbience = ambiencePlayer.getNextSample();

        // Armazena no buffer de delay de target
        targetDelayBufferL[targetDelayWriteIdxL] = monoTarget;
        targetDelayBufferR[targetDelayWriteIdxR] = monoTarget;

        float targetL = monoTarget;
        float targetR = monoTarget;

        float targetAngle = targetAzimuth.load();
        int targetDelay = static_cast<int>(std::round(31.0f * std::abs(targetAngle) / 90.0f));
        if (targetDelay < 0) targetDelay = 0;
        if (targetDelay > 31) targetDelay = 31;

        if (targetAngle > 0.0f) {
            // Som na direita -> atrasa orelha esquerda
            int readIdxL = (targetDelayWriteIdxL - targetDelay + 64) % 64;
            targetL = targetDelayBufferL[readIdxL];
        } else if (targetAngle < 0.0f) {
            // Som na esquerda -> atrasa orelha direita
            int readIdxR = (targetDelayWriteIdxR - targetDelay + 64) % 64;
            targetR = targetDelayBufferR[readIdxR];
        }

        float targetLeftGain = 1.0f;
        float targetRightGain = 1.0f;
        if (targetAngle >= 0.0f) {
            targetLeftGain = 1.0f - 0.6f * (targetAngle / 90.0f);
        } else {
            targetRightGain = 1.0f - 0.6f * (std::abs(targetAngle) / 90.0f);
        }
        targetLeftGain = std::max(0.0f, std::min(1.0f, targetLeftGain));
        targetRightGain = std::max(0.0f, std::min(1.0f, targetRightGain));

        // Armazena no buffer de delay de noise
        float combinedNoise = monoNoise + monoWhite + monoAmbience;
        noiseDelayBufferL[noiseDelayWriteIdxL] = combinedNoise;
        noiseDelayBufferR[noiseDelayWriteIdxR] = combinedNoise;

        float noiseL = combinedNoise;
        float noiseR = combinedNoise;

        float noiseAngle = noiseAzimuth.load();
        int noiseDelay = static_cast<int>(std::round(31.0f * std::abs(noiseAngle) / 90.0f));
        if (noiseDelay < 0) noiseDelay = 0;
        if (noiseDelay > 31) noiseDelay = 31;

        if (noiseAngle > 0.0f) {
            // Som na direita -> atrasa orelha esquerda
            int readIdxL = (noiseDelayWriteIdxL - noiseDelay + 64) % 64;
            noiseL = noiseDelayBufferL[readIdxL];
        } else if (noiseAngle < 0.0f) {
            // Som na esquerda -> atrasa orelha direita
            int readIdxR = (noiseDelayWriteIdxR - noiseDelay + 64) % 64;
            noiseR = noiseDelayBufferR[readIdxR];
        }

        float noiseLeftGain = 1.0f;
        float noiseRightGain = 1.0f;
        if (noiseAngle >= 0.0f) {
            noiseLeftGain = 1.0f - 0.6f * (noiseAngle / 90.0f);
        } else {
            noiseRightGain = 1.0f - 0.6f * (std::abs(noiseAngle) / 90.0f);
        }
        noiseLeftGain = std::max(0.0f, std::min(1.0f, noiseLeftGain));
        noiseRightGain = std::max(0.0f, std::min(1.0f, noiseRightGain));

        for(int ch = 0; ch < channelCount; ch++) {
            float mixedSample = 0.0f;

            // 1. Testa tom puro (Lateralizado via Oscillador)
            mixedSample += testOscillator.getNextSample(ch);

            // 2. Target e Noise com ITD/ILD
            if (channelCount < 2) {
                mixedSample += monoTarget;
                mixedSample += combinedNoise;
            } else {
                if (ch == 0) {
                    mixedSample += targetL * targetLeftGain * panLeftGain;
                    mixedSample += noiseL * noiseLeftGain;
                } else {
                    mixedSample += targetR * targetRightGain * panRightGain;
                    mixedSample += noiseR * noiseRightGain;
                }
            }

            floatData[i * channelCount + ch] = mixedSample;
        }

        targetDelayWriteIdxL = (targetDelayWriteIdxL + 1) % 64;
        targetDelayWriteIdxR = (targetDelayWriteIdxR + 1) % 64;
        noiseDelayWriteIdxL = (noiseDelayWriteIdxL + 1) % 64;
        noiseDelayWriteIdxR = (noiseDelayWriteIdxR + 1) % 64;

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
