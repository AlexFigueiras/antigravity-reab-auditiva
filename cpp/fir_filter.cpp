#include "fir_filter.h"
#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

PartitionedFIR::PartitionedFIR(int taps, int block) : filterLength(taps), blockSize(block) {
    impulseResponse.resize(taps, 0.0f);
    overlapBuffer.resize(taps - 1, 0.0f);
}

// Expansão da Função de Bessel Modificada de Série de Primeira Espécie (Ordem zero)
float PartitionedFIR::besselI0(float x) {
    float sum = 1.0f;
    float term = 1.0f;
    for (int k = 1; k < 20; ++k) {
        term *= (x * x) / (4.0f * k * k);
        sum += term;
        if (term < 1e-6f) break; // Convergência matemática rápida
    }
    return sum;
}

void PartitionedFIR::designHighPassKaiser(float sampleRate, float cutoffFreq, float beta) {
    int M = filterLength - 1;
    float fc = cutoffFreq / sampleRate;
    float I0_beta = besselI0(beta);

    for (int n = 0; n < filterLength; n++) {
        float alpha = M / 2.0f;
        float x = n - alpha;
        
        // Coeficiente da Função Janela de Kaiser
        float arg = std::sqrt(1.0f - std::pow((2.0f * n) / M - 1.0f, 2.0f));
        float window = besselI0(beta * arg) / I0_beta;

        // Ideal High-Pass Sinc math
        float sinc;
        if (std::abs(x) < 1e-6f) { // x == 0
            sinc = 1.0f - 2.0f * fc;
        } else {
            sinc = -std::sin(2.0f * M_PI * fc * x) / (M_PI * x);
        }

        impulseResponse[n] = sinc * window;
    }
}

// Simulador Estrutural de Convolução OLS (Overlap-Save)
// Esta função estrutura o pipeline de salvamento de amostras, 
// perfeitamente configurada para ser encapsulada em um Transformador FFT no futuro.
void PartitionedFIR::processBlockOverlapSave(float* inputData, float* outputData, int numFrames) {
    
    // Convolução no domínio do tempo com preenchimento Overlap History
    for (int i = 0; i < numFrames; i++) {
        float out = 0.0f;
        
        out += inputData[i] * impulseResponse[0];
        
        for (int j = 1; j < filterLength; j++) {
            if (i - j >= 0) {
                out += inputData[i - j] * impulseResponse[j];
            } else {
                int overlapIdx = (overlapBuffer.size() - 1) + (i - j + 1);
                out += overlapBuffer[overlapIdx] * impulseResponse[j];
            }
        }
        outputData[i] = out;
    }

    // Gerenciador Circular de Saldo/Lixo de "Save" para o próximo Bloco Oboe
    if (numFrames == filterLength - 1) {
        for (int i = 0; i < numFrames; i++) {
            overlapBuffer[i] = inputData[i];
        }
    } else {
        int shift = numFrames;
        int keep = overlapBuffer.size() - shift;
        if (keep > 0) {
            std::copy(overlapBuffer.begin() + shift, overlapBuffer.end(), overlapBuffer.begin());
        }
        for (int i = 0; i < shift; i++) {
            int targetIdx = overlapBuffer.size() - shift + i;
            if (targetIdx >= 0) {
                overlapBuffer[targetIdx] = inputData[i];
            }
        }
    }
}
