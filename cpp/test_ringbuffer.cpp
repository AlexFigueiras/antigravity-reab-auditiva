#include <iostream>
#include <vector>
#include <iomanip>
#include "sample_player.h"

int main() {
    std::cout << "=== SPSC Ring Buffer Synthetic Test (Capacity: 512) ===" << std::endl;
    // We will simulate a buffer with capacity 512
    SpscRingBuffer ring(512);

    // Create a 512 frame synthetic burst
    std::vector<float> input_burst(512);
    for(int i=0; i<512; i++) {
        input_burst[i] = (i + 1) * 0.1f;
    }

    std::cout << "[Dart] Writing 512 frames to ring buffer..." << std::endl;
    ring.write(input_burst.data(), 512);

    std::cout << "[Oboe] Reading first 10 frames from buffer:" << std::endl;
    for(int i=0; i<10; i++) {
        float val = ring.read();
        std::cout << "  Frame " << i << ": " << std::fixed << std::setprecision(1) << val << std::endl;
    }

    std::cout << "[Oboe] Reading remaining 502 frames from buffer..." << std::endl;
    for(int i=0; i<502; i++) {
        ring.read(); // Read remaining
    }

    std::cout << "[Oboe] Testing buffer depletion logic (reading 1 extra frame):" << std::endl;
    float empty_val = ring.read();
    std::cout << "  Frame 512 (empty): " << std::fixed << std::setprecision(1) << empty_val << std::endl;

    std::cout << "[Dart] Overwriting with new 256 frame burst..." << std::endl;
    ring.write(input_burst.data(), 256);
    
    std::cout << "[Oboe] Retrieving wrap-around value at new head (should be 0.1):" << std::endl;
    float wrap_val = ring.read();
    std::cout << "  Frame 256 later:   " << std::fixed << std::setprecision(1) << wrap_val << std::endl;
    
    std::cout << "=== Test concluded successfully ===" << std::endl;
    return 0;
}
