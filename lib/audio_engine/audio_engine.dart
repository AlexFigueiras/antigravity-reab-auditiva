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
  static const double _fs = 48000.0; // Sample Rate padrão do Engine

  AudioRehabEngine._internal() {
    final apiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
    _tts = GoogleTTSService(apiKey);
  }

  Future<void> initializeEngine(Audiogram audiogram) async {
    _securePatientId = audiogram.patientId;
    _currentAudiogram = audiogram;
    _nativeBridge.startHardwareAudio();
    _isInitialized = true;
    print("AudioRehabEngine Inicializado (Native Stereo DSP | Clinical EQ Active)");
  }

  /// Regra de Meio Ganho (Half-Gain) [AUDIOLOGIA]
  /// Gain = Loss / 2
  double getCompensatoryGain(double frequencyHz) {
    if (_currentAudiogram == null) return 0.0;
    
    // Busca a perda média para a frequência alvo (L+R)
    final leftPoint = _currentAudiogram!.leftEar.firstWhere(
      (p) => p.frequency >= frequencyHz, orElse: () => _currentAudiogram!.leftEar.last
    );
    final rightPoint = _currentAudiogram!.rightEar.firstWhere(
      (p) => p.frequency >= frequencyHz, orElse: () => _currentAudiogram!.rightEar.last
    );
    
    double avgLoss = (leftPoint.threshold + rightPoint.threshold) / 2.0;
    return avgLoss / 2.0; // REGRA DE OURO
  }

  /// NÍVEL 2: Discriminação Fonêmica com EQ Dinâmico
  Future<void> playPhonemicStimulus({
    required String text,
    required double freqBand,
    double extraBoostDb = 0.0,
  }) async {
    _verifySecurityScope();
    
    // 1. Calcula Ganho Clínico (Shelf Gain)
    double clinicalGainDb = getCompensatoryGain(freqBand) + extraBoostDb;
    
    // 2. Síntese de Fala
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    Float32List samples = _convertInt16ToFloat32(bytes);
    
    // 3. Aplica High-Shelf Filter via DSP Software (Dart) antes de carregar
    // Para agudos, aplicamos o filtro shelf a partir da freqBand
    samples = _applyHighShelf(samples, clinicalGainDb, freqBand);
    
    // 4. Carrega e executa no Native DSP
    _loadSampleToNative(samples, isTarget: true);
    
    print("ESTÍMULO N2: '$text' | Freq: $freqBand Hz | Gain EQ: +$clinicalGainDb dB");
  }

  /// NÍVEL 3: Atenção Espacial (Panning Binaural)
  Future<void> playSpatialStimulus({
    required String text,
    required double panning, // -1.0 a 1.0
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    
    // 1. Configura Panning Nativo
    _nativeBridge.setTargetPanning(panning);
    
    // 2. Aplica EQ de Meio Ganho (Otimizado p/ agudos)
    double gainDb = getCompensatoryGain(freqBand);
    
    // 3. Síntese e Processamento High-Shelf
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    Float32List samples = _convertInt16ToFloat32(bytes);
    samples = _applyHighShelf(samples, gainDb, freqBand);
    
    // 4. Carrega no Mixer
    _loadSampleToNative(samples, isTarget: true);
    
    print("ESTÍMULO ESPACIAL: '$text' | Pan: $panning | EQ: +$gainDb dB");
  }

  /// Implementação de Filtro Biquad High-Shelf em Software
  Float32List _applyHighShelf(Float32List input, double gainDb, double frequencyHz) {
    if (gainDb <= 0) return input;

    final double a = math.pow(10, gainDb / 40).toDouble();
    final double w0 = 2 * math.pi * frequencyHz / _fs;
    final double sinW0 = math.sin(w0);
    final double cosW0 = math.cos(w0);
    final double alpha = sinW0 / 2 * math.sqrt((a + 1 / a) * (1 / 0.707 - 1) + 2); // Q = 0.707

    final double b0 = a * ((a + 1) + (a - 1) * cosW0 + 2 * math.sqrt(a) * alpha);
    final double b1 = -2 * a * ((a - 1) + (a + 1) * cosW0);
    final double b2 = a * ((a + 1) + (a - 1) * cosW0 - 2 * math.sqrt(a) * alpha);
    final double a0 = (a + 1) - (a - 1) * cosW0 + 2 * math.sqrt(a) * alpha;
    final double a1 = 2 * ((a - 1) - (a + 1) * cosW0);
    final double a2 = (a + 1) - (a - 1) * cosW0 - 2 * math.sqrt(a) * alpha;

    final output = Float32List(input.length);
    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;

    for (int i = 0; i < input.length; i++) {
      double x0 = input[i];
      double y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2;
      
      output[i] = y0.clamp(-1.0, 1.0);
      
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    return output;
  }

  /// CALIBRAÇÃO: Tom senoidal puro para ajuste de hardware
  Future<void> playCalibrationTone({
    double frequencyHz = 1000.0,
    double durationSeconds = 1.0,
  }) async {
    // 1. Garante que o hardware esteja ativo (mesmo sem audiograma inicial)
    if (!_isInitialized) _nativeBridge.startHardwareAudio();

    // 2. Gera Senoide
    final int numSamples = (durationSeconds * _fs).toInt();
    final Float32List samples = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      samples[i] = math.sin(2 * math.pi * frequencyHz * i / _fs);
    }

    // 3. Carrega no motor nativo
    _loadSampleToNative(samples, isTarget: true);
    
    print("CALIBRAÇÃO: Tom de $frequencyHz Hz emitido por $durationSeconds segundos.");
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado [AMBIENTE HOSTIL]
  Future<void> playCocktailStimulus({
    required String text,
    required double snrDb,
    required String noiseEnvironment, // Restaurante, Trânsito, Vento
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();

    // 1. Configura Intensidade do Ruído Camada 2 ( SNR )
    // A cada +2dB de ruído, o valor linear sobe
    double noiseIntensity = math.pow(10, (-snrDb) / 20).toDouble();
    _nativeBridge.setNoiseIntensity(noiseIntensity.clamp(0.0, 1.0));

    // 2. Aplica EQ Clínico no Alvo (Camada 1)
    double clinicalGainDb = getCompensatoryGain(freqBand);
    
    // 3. Síntese e EQ
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    Float32List samples = _convertInt16ToFloat32(bytes);
    samples = _applyHighShelf(samples, clinicalGainDb, freqBand);

    // 4. Carrega no motor nativo
    _loadSampleToNative(samples, isTarget: true);
    
    print("MISTURA COQUETEL: ENV=$noiseEnvironment | SNR=$snrDb dB | Vol Ruído=$noiseIntensity");
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado
  @Deprecated("Use playCocktailStimulus para maior controle clínico")
  Future<void> playSpeechInNoise({

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
    calloc.free(pointer);
  }

  Float32List _convertInt16ToFloat32(Uint8List bytes) {
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
