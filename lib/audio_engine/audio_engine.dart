import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/audiogram.dart';
import '../services/tts_service.dart';
import 'native_engine.dart';

/// Motor de Áudio Central para Reabilitação Auditiva
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  bool _isInitialized = false;
  String? _securePatientId;
  Audiogram? _currentAudiogram;

  final _nativeBridge = NativeDSPBridge();
  late final GoogleTTSService _tts;

  // Calibração: 0dB HL -> 0.0001 linear. 80dB HL -> 1.0 linear.
  static const double _kRefDb = 80.0;

  AudioRehabEngine._internal() {
    final apiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
    _tts = GoogleTTSService(apiKey);
  }

  Future<void> initializeEngine(Audiogram audiogram) async {
    _securePatientId = audiogram.patientId;
    _currentAudiogram = audiogram;
    _nativeBridge.startHardwareAudio();
    _isInitialized = true;
    print("AudioRehabEngine Inicializado (Native Stereo DSP)");
  }

  Future<void> playPureTone({
    required int frequencyHz, 
    required int durationMs,
    required EarSide ear,
    double dbLevel = 0.0,
  }) async {
    double amplitude = math.pow(10, (dbLevel - _kRefDb) / 20).toDouble();
    if (amplitude > 1.0) amplitude = 1.0;

    bool isLeft = (ear == EarSide.left || (ear == EarSide.both));
    bool isRight = (ear == EarSide.right || (ear == EarSide.both));

    _nativeBridge.setTestTone(frequencyHz.toDouble(), amplitude, isLeft, isRight);
    
    await Future.delayed(Duration(milliseconds: durationMs));
    _nativeBridge.setTestTone(frequencyHz.toDouble(), 0.0, false, false);
  }

  /// Atualiza o SNR em tempo real durante o exercício
  void updateSNR(double snrDb) {
    double noiseIntensity = math.pow(10, (-snrDb) / 20).toDouble();
    _nativeBridge.setNoiseIntensity(noiseIntensity.clamp(0.0, 1.0));
  }

  /// NÍVEL 2: Discriminação Fonêmica
  Future<void> playPhonemicStimulus({
    String? assetPath,
    String? text,
  }) async {
    _verifySecurityScope();
    // No Nível 2 não usamos ruído, então SNR alto
    await playSpeechInNoise(targetText: text, snrDb: 100.0);
  }

  /// NÍVEL 3: Atenção Espacial (Panning)
  Future<void> playSpatialStimulus({
    String? assetPath,
    String? text,
    required double panning,
  }) async {
    _verifySecurityScope();
    // TODO: Implementar Panning Real no SamplePlayer C++
    // Por enquanto, simulamos via playSpeechInNoise sem ruído
    await playSpeechInNoise(targetText: text, snrDb: 100.0);
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado
  Future<void> playSpeechInNoise({
    String? targetText,
    String? targetAudioPath,
    String? noiseAudioPath,
    required double snrDb,
  }) async {
    _verifySecurityScope();

    // 1. Ruído Branco de fundo (Mixer Secundário)
    double noiseIntensity = math.pow(10, (-snrDb) / 20).toDouble();
    _nativeBridge.setNoiseIntensity(noiseIntensity.clamp(0.0, 1.0));

    // 2. Síntese de Fala (Alvo)
    if (targetText != null) {
      final path = await _tts.synthesize(targetText);
      final bytes = await File(path).readAsBytes();
      
      // Converte bytes LINEAR16 para Float32 para o DSP
      final floatList = _convertInt16ToFloat32(bytes);
      _loadSampleToNative(floatList, isTarget: true);
    }
    
    print("COQUETEL ATIVO: SNR=$snrDb dB | Ruído=$noiseIntensity");
  }

  void _loadSampleToNative(Float32List samples, {bool isTarget = true}) {
    final pointer = calloc<ffi.Float>(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pointer[i] = samples[i];
    }
    
    if (isTarget) {
      _nativeBridge.setTargetSample(pointer, samples.length, 1.0, false);
    } else {
      _nativeBridge.setNoiseSample(pointer, samples.length, 1.0, true);
    }
    
    // O Engine Nativo copia os dados, podemos liberar o ponteiro FFI
    calloc.free(pointer);
  }

  Float32List _convertInt16ToFloat32(Uint8List bytes) {
    // Pula cabeçalho WAV se presente (geralmente 44 bytes)
    // Google TTS LINEAR16 às vezes envia raw, às vezes com header.
    // Vamos assumir raw por enquanto para o MVP, mas com verificação simples.
    int offset = 0;
    if (bytes.length > 44 && String.fromCharCodes(bytes.sublist(0, 4)) == "RIFF") {
      offset = 44;
    }

    final int16List = bytes.buffer.asInt16List(offset);
    final floatList = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      floatList[i] = int16List[i] / 32768.0;
    }
    return floatList;
  }

  void stop() {
    _nativeBridge.stopHardwareAudio();
  }

  void _verifySecurityScope() {
    if (!_isInitialized) throw Exception("Erro: Motor não inicializado");
  }
}
