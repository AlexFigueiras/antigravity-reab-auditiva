#pragma once
#include <oboe/Oboe.h>
#include "dsp_engine.h"
#include <memory>

class OboeEngine : public oboe::AudioStreamCallback {
private:
    std::shared_ptr<oboe::AudioStream> outputStream;
    std::shared_ptr<oboe::AudioStream> inputStream;
    
    DspEngine dspEngine;
    float sampleRate = 48000.0f; // Sincronização direta com SoC (Evita Resampler)

public:
    OboeEngine();
    ~OboeEngine();

    bool start();
    void stop();

    // Loop Nativo assíncrono do Hardware (Callback)
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream *oboeStream,
        void *audioData,
        int32_t numFrames) override;
};
