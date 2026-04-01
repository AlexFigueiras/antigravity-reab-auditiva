#include "fir_filter.h"
#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

PartitionedFIR::PartitionedFIR(int taps, int block) : filterLength(taps), blockSize(block) {
    impulseResponse.resize(taps, 0.0f);
    overlapBuffer.resize(blockSize, 0.0f); // M
    
    // Calcula potencia de 2 para FFT: >= L + M - 1
    int target = taps + block - 1;
    fftSize = 1;
    while(fftSize < target) fftSize *= 2;
    
    fftSetup = pffft_new_setup(fftSize, PFFFT_REAL);
    
    freqDomainIR = (float*)pffft_aligned_malloc(fftSize * 2 * sizeof(float));
    timeDomainBuffer = (float*)pffft_aligned_malloc(fftSize * 2 * sizeof(float));
    freqDomainBuffer = (float*)pffft_aligned_malloc(fftSize * 2 * sizeof(float));
    
    for(int i=0; i<fftSize*2; i++) {
        freqDomainIR[i] = 0.0f;
        timeDomainBuffer[i] = 0.0f;
        freqDomainBuffer[i] = 0.0f;
    }
}

PartitionedFIR::~PartitionedFIR() {
    pffft_aligned_free(freqDomainIR);
    pffft_aligned_free(timeDomainBuffer);
    pffft_aligned_free(freqDomainBuffer);
    if(fftSetup) pffft_destroy_setup(fftSetup);
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

    // Pré-computa FFT(IR)
    for(int i=0; i<fftSize; i++) {
        timeDomainBuffer[i] = (i < filterLength) ? impulseResponse[i] : 0.0f;
    }
    alignas(16) float workSpace[fftSize * 2];
    pffft_transform_ordered(fftSetup, timeDomainBuffer, freqDomainIR, workSpace, PFFFT_REAL);
}

// Simulador Estrutural de Convolução OLS (Overlap-Save)
// Esta função estrutura o pipeline de salvamento de amostras, 
// perfeitamente configurada para ser encapsulada em um Transformador FFT no futuro.
void PartitionedFIR::processBlockOverlapSave(float* inputData, float* outputData, int numFrames) {
    
    int processed = 0;
    while (processed < numFrames) {
        int chunk = std::min(blockSize, numFrames - processed);
        
        // 1. x_ext = [overlap | input]
        for(int i=0; i<fftSize; i++) {
            if (i < filterLength - 1) {
                timeDomainBuffer[i] = overlapBuffer[i]; // Parte velha
            } else if (i < (filterLength - 1) + chunk) {
                timeDomainBuffer[i] = inputData[processed + (i - (filterLength - 1))]; // Parte nova
            } else {
                timeDomainBuffer[i] = 0.0f; // Zero padding extra se houver
            }
        }
        
        // 2. FFT
        alignas(16) float workSpace[fftSize * 2];
        pffft_transform_ordered(fftSetup, timeDomainBuffer, freqDomainBuffer, workSpace, PFFFT_REAL);
        
        // 3. Multiplicação complexa: Y = X * H
        for(int i=0; i<fftSize; i++) {
            float Xr = freqDomainBuffer[i*2];
            float Xi = freqDomainBuffer[i*2+1];
            float Hr = freqDomainIR[i*2];
            float Hi = freqDomainIR[i*2+1];
            timeDomainBuffer[i*2]   = Xr * Hr - Xi * Hi;
            timeDomainBuffer[i*2+1] = Xr * Hi + Xi * Hr;
        }
        
        // 4. IFFT
        pffft_transform_ordered(fftSetup, timeDomainBuffer, timeDomainBuffer, workSpace, PFFFT_COMPLEX);
        
        // 5. Extração do output válido
        for(int i=0; i<chunk; i++) {
            outputData[processed + i] = timeDomainBuffer[filterLength - 1 + i];
        }
        
        // 6. Guarda o final da entrada para o próximo overlap
        int keepStart = chunk;
        if (keepStart > filterLength - 1) keepStart = filterLength - 1;
        int shift = (filterLength - 1) - keepStart;
        
        // Desloca o buffer antigo
        for(int i=0; i<shift; i++) {
            overlapBuffer[i] = overlapBuffer[i + keepStart];
        }
        // Anexa os novos
        for(int i=0; i<keepStart; i++) {
            overlapBuffer[shift + i] = inputData[processed + chunk - keepStart + i];
        }

        processed += chunk;
    }
}
