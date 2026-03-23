#pragma once
#include <random>

class NoiseGenerator {
private:
    std::mt19937 engine;
    std::uniform_real_distribution<float> dist;
    float amplitude = 0.0f;

public:
    NoiseGenerator() : engine(std::random_device{}()), dist(-1.0f, 1.0f) {}

    void setAmplitude(float amp) {
        amplitude = amp;
    }

    float getNextSample() {
        if (amplitude <= 0.0f) return 0.0f;
        return dist(engine) * amplitude;
    }
};
