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
        
        // Só incrementamos a fase no último canal para manter sincronia
        // Mas como somos Mono no Oboe por enquanto (OboeEngine.cpp:25: count: Mono), não faz diferença.
        // No entanto, se o OboeEngine mudar para Stereo, isso é importante.
        return sample;
    }

    void updatePhase() {
        if (!active) return;
        phase += phaseIncrement;
        if (phase >= 2.0 * M_PI) phase -= 2.0 * M_PI;
    }
};
