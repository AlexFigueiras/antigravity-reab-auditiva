#include <stdint.h>
#include <cstdlib>

#ifdef __ANDROID__
#include "oboe_engine.h"
#define NATIVE_EXPORT __attribute__((visibility("default")))
#else
#include "dsp_engine.h"
#define NATIVE_EXPORT __declspec(dllexport)
#endif

extern "C" {

struct EngineContext {
#ifdef __ANDROID__
    OboeEngine* engine;
#else
    DspEngine* engine;
#endif
};

NATIVE_EXPORT
EngineContext* create_engine() {
    EngineContext* ctx = new EngineContext();
#ifdef __ANDROID__
    ctx->engine = new OboeEngine();
#else
    ctx->engine = new DspEngine(48000.0f);
#endif
    return ctx;
}

// Hook de Ignição Nativa (Inicia o MMAP Oboe no Android)
NATIVE_EXPORT
bool start_engine(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) {
        return ctx->engine->start();
    }
#endif
    return true; // No Windows simulamos sucesso imediato
}

// Hook de Pausa Nativa
NATIVE_EXPORT
void stop_engine(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) {
        ctx->engine->stop();
    }
#endif
}

// Cleanup Determinístico (via NativeFinalizer)
NATIVE_EXPORT
void destroy_engine(EngineContext* ctx) {
    if (ctx) {
        if (ctx->engine) {
#ifdef __ANDROID__
            ctx->engine->stop();
#endif
            delete ctx->engine;
        }
        delete ctx;
    }
}

// --- NOVOS MÉTODOS CLÍNICOS ---

NATIVE_EXPORT
void set_test_tone(EngineContext* ctx, float freq, float amp, int32_t left, int32_t right) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setTestTone(freq, amp, left != 0, right != 0);
#endif
}

NATIVE_EXPORT
void set_target_sample(EngineContext* ctx, float* data, int32_t len, float vol, int32_t loop) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setTargetSample(data, len, vol, loop != 0);
#endif
}

NATIVE_EXPORT
void set_noise_sample(EngineContext* ctx, float* data, int32_t len, float vol, int32_t loop) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setNoiseSample(data, len, vol, loop != 0);
#endif
}

NATIVE_EXPORT
void set_noise_intensity(EngineContext* ctx, float intensity) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setNoiseIntensity(intensity);
#endif
}

NATIVE_EXPORT
void set_target_panning(EngineContext* ctx, float panning) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setTargetPanning(panning);
#endif
}

} // extern "C"
