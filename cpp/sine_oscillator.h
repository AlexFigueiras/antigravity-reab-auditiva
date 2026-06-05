#pragma once
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

class SineOscillator {
private:
    double phase = 0.0;
    double phaseIncrement = 0.0;
    float amplitude = 0.0f;
    float sampleRate = 48000.0f;
    bool active = false;
    bool leftChannel = true;
    bool rightChannel = true;

public:
    void setSampleRate(float sr) {
        sampleRate = sr;
    }

    void setFrequency(float freq) {
        phaseIncrement = 2.0 * M_PI * freq / sampleRate;
        active = (freq > 0);
    }

    void setAmplitude(float amp) {
        amplitude = amp;
    }

    void setChannels(bool left, bool right) {
        leftChannel = left;
        rightChannel = right;
    }

    void setStop() {
        active = false;
        amplitude = 0.0f;
    }

    float getNextSample(int channel) {
        if (!active) return 0.0f;
        
        bool shouldPlay = (channel == 0 && leftChannel) || (channel == 1 && rightChannel);
        if (!shouldPlay) return 0.0f;

        float sample = (float)(std::sin(phase) * amplitude);

        // O stream é estéreo (oboe_engine.cpp: ChannelCount::Stereo). A fase é
        // avançada uma vez por frame em updatePhase() (chamado após os 2 canais),
        // então os canais L/R ficam em fase. O isolamento por orelha vem do
        // shouldPlay acima — essencial para o teste audiométrico.
        return sample;
    }

    void updatePhase() {
        if (!active) return;
        phase += phaseIncrement;
        if (phase >= 2.0 * M_PI) phase -= 2.0 * M_PI;
    }
};
