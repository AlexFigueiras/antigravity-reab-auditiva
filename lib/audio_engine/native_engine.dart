import 'dart:ffi' as ffi;
import 'dart:io';

// Instanciação da Biblioteca Nativa Shared Object
final ffi.DynamicLibrary _lib = Platform.isAndroid 
    ? ffi.DynamicLibrary.open('libdsp_audio_engine.so') 
    : Platform.isWindows 
      ? ffi.DynamicLibrary.open('dsp_audio_engine.dll') 
      : Platform.isIOS
        ? ffi.DynamicLibrary.process() 
        : throw UnsupportedError('Unsupported platform');

// Classe Opaca correspondente à struct EngineContext do C++
final class EngineContext extends ffi.Opaque {}

// Definição do Garbage Collector Híbrido (NativeFinalizer)
// O callback do NativeFinalizer deve receber um Pointer<Void>
final ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>> pFreeEngine = 
  _lib.lookup('destroy_engine');
final finalizer = ffi.NativeFinalizer(pFreeEngine);

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
class NativeDSPBridge implements ffi.Finalizable {
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

  // --- Novos canais de controle clínico ---

  void setTestTone(double frequency, double amplitude, bool left, bool right) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float, ffi.Float, ffi.Int32, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, double, double, int, int)
    >('set_test_tone');
    func(_enginePtr, frequency, amplitude, left ? 1 : 0, right ? 1 : 0);
  }

  void setTargetSample(ffi.Pointer<ffi.Float> data, int length, double volume, bool loop) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Float, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, int, double, int)
    >('set_target_sample');
    func(_enginePtr, data, length, volume, loop ? 1 : 0);
  }

  void setNoiseSample(ffi.Pointer<ffi.Float> data, int length, double volume, bool loop) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Float, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, int, double, int)
    >('set_noise_sample');
    func(_enginePtr, data, length, volume, loop ? 1 : 0);
  }

  void setNoiseIntensity(double intensity) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float),
        void Function(ffi.Pointer<EngineContext>, double)
    >('set_noise_intensity');
    func(_enginePtr, intensity);
  }

  void setTargetPanning(double panning) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float),
        void Function(ffi.Pointer<EngineContext>, double)
    >('set_target_panning');
    func(_enginePtr, panning);
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

