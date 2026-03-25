#pragma once
#include <vector>

// Estrutura Base para Convolução Particionada (Filtro FIR Janelado)
class PartitionedFIR {
private:
    std::vector<float> impulseResponse;
    std::vector<float> overlapBuffer;
    int filterLength;
    int blockSize; // Tamanho base N para o Bloco do Overlap-Save

    float besselI0(float x);

public:
    // Atraso Fixo em relação aos Taps. 512 é perfeito para 48kHz (Acesso em ~10ms).
    PartitionedFIR(int taps = 512, int block = 256);
    ~PartitionedFIR() = default;

    // Constrói a Resposta ao Impulso com Janela de Kaiser (Bessel Modificada)
    // Garante atenuação monstruosa (>50dB) na banda de rejeição, 
    // com fase irretocavelmente linear no domínio da frequência.
    void designHighPassKaiser(float sampleRate, float cutoffFreq, float beta);

    // Prepara as estruturas matemáticas da Técnica "Overlap-Save".
    // Isso mitiga O(N^2) no longo prazo transformando a banda para o Fast Fourier (FFT ready).
    void processBlockOverlapSave(float* inputData, float* outputData, int numFrames);
};
