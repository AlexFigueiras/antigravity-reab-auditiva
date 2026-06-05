#pragma once
#include <vector>
#include <atomic>
#include <algorithm>

// Single Producer Single Consumer (SPSC) Lock-free Ring Buffer
class SpscRingBuffer {
private:
    std::vector<float> buffer;
    std::atomic<int> head{0}; // Read ptr (consumer)
    std::atomic<int> tail{0}; // Write ptr (producer)
    int capacity;
    std::atomic<int> highWatermark{0};

public:
    SpscRingBuffer(int cap) : capacity(cap + 1) { // +1 to distinguish full/empty
        buffer.resize(capacity, 0.0f);
    }

    // Producer (called from FFI/Dart thread)
    // Writes block of data into the ring buffer
    void write(const float* data, int length) {
        int w = tail.load(std::memory_order_relaxed);
        int r = head.load(std::memory_order_acquire);
        
        int available = capacity - 1 - ((w - r + capacity) % capacity);
        int copies = std::min(length, available);
        if (copies <= 0) return;

        int currentUsed = ((w - r + capacity) % capacity) + copies;
        int max_val = highWatermark.load(std::memory_order_relaxed);
        while (currentUsed > max_val && 
               !highWatermark.compare_exchange_weak(max_val, currentUsed, std::memory_order_relaxed));

        int firstPart = std::min(copies, capacity - w);
        std::copy(data, data + firstPart, buffer.begin() + w);
        if (firstPart < copies) {
            std::copy(data + firstPart, data + copies, buffer.begin());
        }

        tail.store((w + copies) % capacity, std::memory_order_release);
    }

    // Consumer (called from audio callback thread)
    float read() {
        int r = head.load(std::memory_order_relaxed);
        int w = tail.load(std::memory_order_acquire);

        if (r == w) return 0.0f; // Empty buffer

        float sample = buffer[r];
        head.store((r + 1) % capacity, std::memory_order_release);
        return sample;
    }

    void clear() {
        head.store(0, std::memory_order_relaxed);
        tail.store(0, std::memory_order_relaxed);
    }

    int getHighWatermark() const {
        return highWatermark.load(std::memory_order_relaxed);
    }
    
    void resetWatermark() {
        highWatermark.store(0, std::memory_order_relaxed);
    }
};

class SamplePlayer {
private:
    std::vector<float> buffer;
    std::atomic<int> length{0};
    std::atomic<int> readIndex{0};
    std::atomic<float> volume{1.0f};
    std::atomic<bool> loop{false};

public:
    // Alocamos um buffer generoso de 5MB (suficiente p/ frases de até ~25 segundos em 48kHz mono float)
    SamplePlayer() : buffer(48000 * 25, 0.0f) {}

    void setData(const float* source, int len) {
        // Silencia/zera o comprimento ativo antes de copiar para evitar race conditions
        length.store(0, std::memory_order_release);
        
        int n = std::min(len, (int)buffer.size());
        if (n > 0 && source != nullptr) {
            std::copy(source, source + n, buffer.begin());
        }
        
        readIndex.store(0, std::memory_order_relaxed);
        length.store(n, std::memory_order_release);
    }

    void setVolume(float v) {
        volume.store(v, std::memory_order_relaxed);
    }

    void setLoop(bool l) {
        loop.store(l, std::memory_order_relaxed);
    }

    void stop() {
        length.store(0, std::memory_order_release);
        readIndex.store(0, std::memory_order_relaxed);
    }

    float getNextSample() {
        int len = length.load(std::memory_order_acquire);
        if (len <= 0) return 0.0f;
        
        float v = volume.load(std::memory_order_relaxed);
        if (v <= 0.0f) return 0.0f;
        
        int idx = readIndex.load(std::memory_order_relaxed);
        if (idx >= len) {
            if (loop.load(std::memory_order_relaxed)) {
                idx = 0;
            } else {
                return 0.0f;
            }
        }
        
        float sample = buffer[idx] * v;
        
        int nextIdx = idx + 1;
        if (nextIdx >= len) {
            if (loop.load(std::memory_order_relaxed)) {
                nextIdx = 0;
            } else {
                nextIdx = len; // Mantém em len para que leituras subsequentes retornem 0
            }
        }
        readIndex.store(nextIdx, std::memory_order_relaxed);
        
        return sample;
    }
};
