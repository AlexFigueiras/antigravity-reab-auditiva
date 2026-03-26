#pragma once
#include <oboe/Oboe.h>
#include "sine_oscillator.h"
#include "sample_player.h"
#include "noise_generator.h"
#include <memory>
#include "dsp_engine.h"

class OboeEngine : public oboe::AudioStreamCallback {
private:
    std::shared_ptr<oboe::AudioStream> outputStream;
    std::shared_ptr<oboe::AudioStream> inputStream;
    
    DspEngine dspEngine;
    
    // Motor de Geração Clínica
    SineOscillator testOscillator;
    SamplePlayer targetPlayer;
    SamplePlayer noisePlayer;
    NoiseGenerator whiteNoiseGenerator;

    float sampleRate = 48000.0f; 
    std::atomic<float> targetPanning{0.0f}; // -1.0L, 0.0C, 1.0R

public:
    OboeEngine();
    ~OboeEngine();

    bool start();
    void stop();

    // Controle Clínico
    void setTestTone(float freq, float amp, bool left, bool right) {
        testOscillator.setFrequency(freq);
        testOscillator.setAmplitude(amp);
        testOscillator.setChannels(left, right);
    }

    void setTargetSample(const float* data, int len, float vol, bool loop) {
        targetPlayer.setData(data, len);
        targetPlayer.setVolume(vol);
        targetPlayer.setLoop(loop);
    }

    void setTargetPanning(float panning) {
        targetPanning.store(panning);
    }

    void setNoiseSample(const float* data, int len, float vol, bool loop) {
        noisePlayer.setData(data, len);
        noisePlayer.setVolume(vol);
        noisePlayer.setLoop(loop);
    }

    void setNoiseIntensity(float intensity) {
        whiteNoiseGenerator.setAmplitude(intensity);
    }

    // Loop Nativo assíncrono do Hardware (Callback)
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream *oboeStream,
        void *audioData,
        int32_t numFrames) override;
};
