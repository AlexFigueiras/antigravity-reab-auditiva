#pragma once
#include <cmath>

// Implementação Direct Form II Transposed (Mitiga erros de quantização de ponto flutuante em IIR)
class BiquadFilter {
private:
    float a0, a1, a2, b0, b1, b2;
    float z1, z2;

public:
    BiquadFilter() : a0(1), a1(0), a2(0), b0(1), b1(0), b2(0), z1(0), z2(0) {}

    // Equalizador Paramétrico (Peaking EQ) para transientes e sibilantes (/f/, /s/)
    void configurePeakingEQ(float sampleRate, float f0, float Q, float dbGain) {
        float A = std::pow(10.0f, dbGain / 40.0f);
        float w0 = 2.0f * M_PI * f0 / sampleRate;
        float alpha = std::sin(w0) / (2.0f * Q);

        b0 = 1.0f + alpha * A;
        b1 = -2.0f * std::cos(w0);
        b2 = 1.0f - alpha * A;
        a0 = 1.0f + alpha / A;
        a1 = -2.0f * std::cos(w0);
        a2 = 1.0f - alpha / A;
        
        // Normalização baseada em Transformada Bilinear (BLT)
        b0 /= a0; b1 /= a0; b2 /= a0;
        a1 /= a0; a2 /= a0;
    }

    // Filtro Passa-Baixa (Usado no Crossover IIR)
    void configureLowPass(float sampleRate, float f0, float Q) {
        float w0 = 2.0f * M_PI * f0 / sampleRate;
        float alpha = std::sin(w0) / (2.0f * Q);

        b0 = (1.0f - std::cos(w0)) / 2.0f;
        b1 = 1.0f - std::cos(w0);
        b2 = (1.0f - std::cos(w0)) / 2.0f;
        a0 = 1.0f + alpha;
        a1 = -2.0f * std::cos(w0);
        a2 = 1.0f - alpha;

        b0 /= a0; b1 /= a0; b2 /= a0;
        a1 /= a0; a2 /= a0;
    }

    // Processamento inline para latência zero no loop do Oboe
    inline float process(float input) {
        float output = b0 * input + z1;
        z1 = b1 * input - a1 * output + z2;
        z2 = b2 * input - a2 * output;
        return output;
    }
};
