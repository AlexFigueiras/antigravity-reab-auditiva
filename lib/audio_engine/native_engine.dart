import 'dart:ffi' as ffi;
import 'dart:io';

// Classe Opaca correspondente à struct EngineContext do C++
final class EngineContext extends ffi.Opaque {}

// Definição do Garbage Collector Híbrido (NativeFinalizer)
final ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<EngineContext>)>> pFreeEngine = 
  _lib.lookup('destroy_engine');
final finalizer = ffi.NativeFinalizer(pFreeEngine);

// Instanciação da Biblioteca Nativa Shared Object
final ffi.DynamicLibrary _lib = Platform.isAndroid 
    ? ffi.DynamicLibrary.open('libdsp_audio_engine.so') 
    : Platform.isWindows 
      ? ffi.DynamicLibrary.open('dsp_audio_engine.dll') 
      : Platform.isIOS
        ? ffi.DynamicLibrary.process() 
        : throw UnsupportedError('Unsupported platform');

// --- C-Signatures & Dart Callbacks ---
typedef CreateEngineC = ffi.Pointer<EngineContext> Function();
typedef CreateEngineDart = ffi.Pointer<EngineContext> Function();
final CreateEngineDart _createEngine = _lib.lookupFunction<CreateEngineC, CreateEngineDart>('create_engine');

typedef StartEngineC = ffi.Bool Function(ffi.Pointer<EngineContext>);
typedef StartEngineDart = bool Function(ffi.Pointer<EngineContext>);
final StartEngineDart _startEngine = _lib.lookupFunction<StartEngineC, StartEngineDart>('start_engine');

typedef StopEngineC = ffi.Void Function(ffi.Pointer<EngineContext>);
typedef StopEngineDart = void Function(ffi.Pointer<EngineContext>);
final StopEngineDart _stopEngine = _lib.lookupFunction<StopEngineC, StopEngineDart>('stop_engine');

/// Abstração FFI Limpa e de Performance para integração com a UI.
class NativeDSPBridge {
  late final ffi.Pointer<EngineContext> _enginePtr;

  NativeDSPBridge() {
    _enginePtr = _createEngine();
    // Prevenção de Leaks: quando este objeto Dart for coletado, destrói o engine C++.
    finalizer.attach(this, _enginePtr.cast(), detach: this);
  }

  /// Hook Nativo: Dá ignição na thread do Oboe no modo EXCLUSIVE
  bool startHardwareAudio() {
    return _startEngine(_enginePtr);
  }

  /// Desliga o fluxo contínuo de áudio (Desbloqueia os recursos MMAP)
  void stopHardwareAudio() {
    _stopEngine(_enginePtr);
  }

  void dispose() {
    finalizer.detach(this);
    stopHardwareAudio();
    final destroy = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>), 
        void Function(ffi.Pointer<EngineContext>)
    >('destroy_engine');
    destroy(_enginePtr);
  }
}

