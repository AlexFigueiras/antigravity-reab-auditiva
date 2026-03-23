#pragma once
#include <vector>
#include <atomic>

class SamplePlayer {
private:
    std::vector<float> data;
    std::atomic<int> position{0};
    std::atomic<float> volume{1.0f};
    bool loop = false;
    bool active = false;

public:
    void setData(const float* source, int length) {
        data.assign(source, source + length);
        position = 0;
        active = (length > 0);
    }

    void setVolume(float v) {
        volume = v;
    }

    void setLoop(bool l) {
        loop = l;
    }

    void stop() {
        active = false;
        position = 0;
    }

    float getNextSample() {
        if (!active || data.empty()) return 0.0f;

        int pos = position.load();
        if (pos >= data.size()) {
            if (loop) {
                position = 0;
                pos = 0;
            } else {
                active = false;
                return 0.0f;
            }
        }

        float sample = data[pos] * volume.load();
        position++;
        return sample;
    }

    bool isActive() const { return active; }
};
