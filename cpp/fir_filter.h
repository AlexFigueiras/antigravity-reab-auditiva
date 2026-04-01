#pragma once
#include <vector>
#include "pffft.h"

// Estrutura Base para Convolução Particionada (Filtro FIR Janelado com Overlap-Save FFT)
class PartitionedFIR {
private:
    std::vector<float> impulseResponse;
    std::vector<float> overlapBuffer;
    int filterLength;
    int blockSize; // Tamanho base M para o Bloco do Overlap-Save
    int fftSize;
    
    PFFFT_Setup* fftSetup;
    float* freqDomainIR; // H[k]
    float* timeDomainBuffer;
    float* freqDomainBuffer;

    float besselI0(float x);

public:
    // Atraso Fixo em relação aos Taps. 512 é perfeito para 48kHz (Acesso em ~10ms).
    PartitionedFIR(int taps = 512, int block = 256);
    ~PartitionedFIR();

    // Constrói a Resposta ao Impulso com Janela de Kaiser (Bessel Modificada)
    // Garante atenuação monstruosa (>50dB) na banda de rejeição, 
    // com fase irretocavelmente linear no domínio da frequência.
    void designHighPassKaiser(float sampleRate, float cutoffFreq, float beta);

    // Prepara as estruturas matemáticas da Técnica "Overlap-Save".
    // Isso mitiga O(N^2) no longo prazo transformando a banda para o Fast Fourier (FFT ready).
    void processBlockOverlapSave(float* inputData, float* outputData, int numFrames);
};
