import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import '../models/audiogram.dart';

/// Motor de Áudio Central para Reabilitação Auditiva
/// Responsável pela mixagem em tempo real (Cocktail Effect) e calibração de dB HL.
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  AudioRehabEngine._internal();

  bool _isInitialized = false;
  String? _securePatientId;
  Audiogram? _currentAudiogram;

  final _targetPlayer = AudioPlayer();
  final _noisePlayer = AudioPlayer();

  /// Inicializa o motor com as configurações e identidade do paciente [SEGURANÇA/INFRA]
  Future<void> initializeEngine(Audiogram audiogram) async {
    _securePatientId = audiogram.patientId;
    _currentAudiogram = audiogram;

    // Configura a sessão de áudio nativa
    await _configureNativeAudioSession();

    _isInitialized = true;
    print("AudioRehabEngine Inicializado para o Paciente: $_securePatientId");
  }

  Future<void> _configureNativeAudioSession() async {
    // Placeholder para configuração via audio_session
  }

  /// NÍVEL 1: Emite um som puro (Pure Tone) isolado para detecção de limiar
  Future<void> playPureTone({required int frequencyHz, required int durationMs}) async {
    // Para calibração não exigimos inicialização completa, apenas o player livre
    final tonePlayer = AudioPlayer();
    
    final int sampleRate = 44100;
    final int numSamples = (sampleRate * (durationMs / 1000)).toInt();
    final double amplitude = 0.5; // Amplitude fixa para calibração relativa

    final Int16List samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
        samples[i] = (amplitude * 32767 * math.sin(2 * math.pi * frequencyHz * i / sampleRate)).toInt();
    }

    final bytes = _generateWavBytes(samples, sampleRate);
    final uri = Uri.dataFromBytes(bytes, mimeType: 'audio/wav');
    
    try {
      await tonePlayer.setAudioSource(AudioSource.uri(uri));
      await tonePlayer.play();
      // Aguarda a duração do tom antes de fechar o player
      await Future.delayed(Duration(milliseconds: durationMs));
      await tonePlayer.dispose();
    } catch (e) {
      print("Erro ao tocar tom puro: $e");
    }
  }

  Uint8List _generateWavBytes(Int16List samples, int sampleRate) {
    final int bytesPerSample = 2;
    final int fileSize = 44 + samples.length * bytesPerSample;
    final ByteData wavHeader = ByteData(44);

    // RIFF header
    wavHeader.setUint8(0, 0x52); // R
    wavHeader.setUint8(1, 0x49); // I
    wavHeader.setUint8(2, 0x46); // F
    wavHeader.setUint8(3, 0x46); // F
    wavHeader.setUint32(4, fileSize - 8, Endian.little);
    // WAVE header
    wavHeader.setUint8(8, 0x57);  // W
    wavHeader.setUint8(9, 0x41);  // A
    wavHeader.setUint8(10, 0x56); // V
    wavHeader.setUint8(11, 0x45); // E
    // fmt chunk
    wavHeader.setUint8(12, 0x66); // f
    wavHeader.setUint8(13, 0x6d); // m
    wavHeader.setUint8(14, 0x74); // t
    wavHeader.setUint8(15, 0x20); // space
    wavHeader.setUint32(16, 16, Endian.little); // chunk size
    wavHeader.setUint16(20, 1, Endian.little);  // PCM format
    wavHeader.setUint16(22, 1, Endian.little);  // numbers of channels
    wavHeader.setUint32(24, sampleRate, Endian.little);
    wavHeader.setUint32(28, sampleRate * bytesPerSample, Endian.little); // byte rate
    wavHeader.setUint16(32, bytesPerSample, Endian.little); // block align
    wavHeader.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    wavHeader.setUint8(36, 0x64); // d
    wavHeader.setUint8(37, 0x61); // a
    wavHeader.setUint8(38, 0x74); // t
    wavHeader.setUint8(39, 0x61); // a
    wavHeader.setUint32(40, samples.length * bytesPerSample, Endian.little);

    final Uint8List wavBytes = Uint8List(fileSize);
    wavBytes.setAll(0, wavHeader.buffer.asUint8List());
    wavBytes.setAll(44, samples.buffer.asUint8List());

    return wavBytes;
  }

  double _lastSnr = 0.0;

  /// Atualiza o SNR do áudio em execução em tempo real [UX/FRONTEND]
  void updateSNR(double newSnr) {
    if (!_isInitialized) return;
    _lastSnr = newSnr;
    _applyVolumes();
  }

  void _applyVolumes() {
    // 1. Compensação de Ganho baseada no Audiograma (Regra de Meio Ganho)
    double thresholdCompensation = 0.0;
    if (_currentAudiogram != null) {
      thresholdCompensation = _currentAudiogram!.calculatePTA() / 2.0; 
    }

    // 2. Cálculo SNR (dB -> Linear)
    double targetVol = 1.0;
    double noiseVol = 1.0;

    if (_lastSnr > 0) {
      noiseVol = math.pow(10, -(_lastSnr / 20)).toDouble();
    } else if (_lastSnr < 0) {
      targetVol = math.pow(10, (_lastSnr / 20)).toDouble();
    }

    // 3. Aplicação do Ganho de Compensação no Sinal Alvo
    // Convertemos a compensação dB para multiplicador linear
    double gainMultiplier = math.pow(10, (thresholdCompensation / 20)).toDouble();
    targetVol *= gainMultiplier;

    // Normalização básica para evitar clipping (limitamos a 1.2 para dar headroom seguro)
    if (targetVol > 1.2) targetVol = 1.2;

    _targetPlayer.setVolume(targetVol);
    _noisePlayer.setVolume(noiseVol);

    print("Volumes Refinados: Target ${targetVol.toStringAsFixed(2)} | Ruído ${noiseVol.toStringAsFixed(2)} (SNR: $_lastSnr dB)");
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado
  Future<void> playSpeechInNoise({
    required String targetAudioPath,
    required String noiseAudioPath,
    required double snrDb,
    bool isAsset = false,
  }) async {
    _verifySecurityScope();
    _lastSnr = snrDb;

    try {
      if (isAsset) {
        await _targetPlayer.setAudioSource(AudioSource.asset(targetAudioPath));
        await _noisePlayer.setAudioSource(AudioSource.asset(noiseAudioPath));
      } else {
        await _targetPlayer.setAudioSource(AudioSource.uri(Uri.parse(targetAudioPath)));
        await _noisePlayer.setAudioSource(AudioSource.uri(Uri.parse(noiseAudioPath)));
      }

      _applyVolumes();
      _noisePlayer.setLoopMode(LoopMode.one);

      await Future.wait([
        _targetPlayer.play(),
        _noisePlayer.play(),
      ]);
    } catch (e) {
      print("ERRO NO ENGINE: $e");
    }
  }

  void stop() async {
    await _targetPlayer.stop();
    await _noisePlayer.stop();
  }

  void _verifySecurityScope() {
    if (!_isInitialized || _securePatientId == null || _securePatientId!.isEmpty) {
      throw Exception("FALHA CRÍTICA DE SEGURANÇA: Motor de áudio não inicializado.");
    }
  }
}
