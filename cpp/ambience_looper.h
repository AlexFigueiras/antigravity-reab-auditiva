#pragma once
#include <vector>
#include <atomic>
#include <algorithm>

// Player de AMBIÊNCIA em loop contínuo.
//
// Diferente do SamplePlayer (ring buffer SPSC consumido UMA vez), este guarda um
// buffer fixo, setado uma vez pelo Dart, e o lê em loop com wrap-around na thread
// de áudio. É para o som de fundo do treino de frases (restaurante, academia,
// praça, mercado), que precisa repetir indefinidamente por baixo da fala.
//
// Thread-safety: o Dart/FFI escreve via setData/stop; a thread de áudio lê via
// getNextSample. Durante a cópia, `length` é zerado primeiro (silêncio) e
// publicado por último — o pior caso é um breve silêncio ao trocar de ambiência,
// nunca leitura fora dos limites.
class AmbienceLooper {
private:
    std::vector<float> buffer;       // capacidade máxima pré-alocada
    std::atomic<int> length{0};      // amostras válidas (0 = silencioso)
    std::atomic<int> readIndex{0};
    std::atomic<float> volume{0.0f};

public:
    // ~20 s a 48 kHz mono é folga suficiente para um loop de ambiência.
    AmbienceLooper() : buffer(48000 * 20, 0.0f) {}

    // Chamado da thread Dart/FFI.
    void setData(const float* data, int len, float vol) {
        length.store(0, std::memory_order_release); // silencia enquanto copia
        int n = std::min(len, (int)buffer.size());
        std::copy(data, data + n, buffer.begin());
        readIndex.store(0, std::memory_order_relaxed);
        volume.store(vol, std::memory_order_relaxed);
        length.store(n, std::memory_order_release);  // publica
    }

    void setVolume(float v) { volume.store(v, std::memory_order_relaxed); }

    void stop() {
        volume.store(0.0f, std::memory_order_relaxed);
        length.store(0, std::memory_order_release);
    }

    // Chamado da thread de callback de áudio.
    float getNextSample() {
        int len = length.load(std::memory_order_acquire);
        if (len <= 0) return 0.0f;
        float v = volume.load(std::memory_order_relaxed);
        if (v <= 0.0f) return 0.0f;
        int idx = readIndex.load(std::memory_order_relaxed);
        if (idx >= len) idx = 0;
        float s = buffer[idx] * v;
        readIndex.store((idx + 1) % len, std::memory_order_relaxed);
        return s;
    }
};
