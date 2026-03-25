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


} // extern "C"
