#pragma once
#include <cmath>

// TEE: Temporal Envelope Expansion (Fast-Acting Modulator)
class TemporalEnvelopeExpander {
private:
    float attackCoef;
    float releaseCoef;
    float envelope;
    float gamma;

public:
    TemporalEnvelopeExpander() : envelope(0.0f), gamma(0.7f) {}

    void initialize(float sampleRate, float attackMs, float releaseMs, float g) {
        // Cálculo da Constante de Tempo RC Digital para Exponenciais
        attackCoef = std::exp(-1.0f / (sampleRate * (attackMs / 1000.0f)));
        releaseCoef = std::exp(-1.0f / (sampleRate * (releaseMs / 1000.0f)));
        gamma = g;
    }

    // Processamento de transientes
    // Dá "Punch" (Expansão não linear) apenas nas frações /f/ e /s/ sem saturar a média.
    inline float process(float input) {
        float absInput = std::abs(input);
        
        // Seguidor de Envelope Assimétrico (Attack super rápido / Release lento clínico)
        if (absInput > envelope) {
            envelope = attackCoef * (envelope - absInput) + absInput;
        } else {
            envelope = releaseCoef * (envelope - absInput) + absInput;
        }

        // Modulação Não-linear $m_k(t) = a_k(t)^\gamma$
        // Se gamma estiver entre 0.5 e 1.0, garantimos a reconstrução correta dos sibilantes mudos transientes.
        float gain = 1.0f;
        if (envelope > 1e-6f) {
            gain = std::pow(envelope, gamma - 1.0f);
        }

        // Reconstrói amostra na fase original
        return input * gain;
    }
};
