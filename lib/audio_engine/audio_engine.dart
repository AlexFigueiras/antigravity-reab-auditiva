import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/audiogram.dart';
import '../services/tts_service.dart';

/// Motor de Áudio Central para Reabilitação Auditiva
/// Responsável pela mixagem em tempo real (Cocktail Effect) e calibração de dB HL.
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  bool _isInitialized = false;
  String? _securePatientId;
  Audiogram? _currentAudiogram;

  final _targetPlayer = AudioPlayer();
  final _noisePlayer = AudioPlayer();
  late final GoogleTTSService _tts;

  // Constantes Clínicas de Segurança [CALIBRAÇÃO]
  // 0.0001 é a nossa referência para 0dB HL com volume do OS em 100%.
  // Isso permite que o volume cresça audivelmente até 80dB HL = 1.0 (Volume Máximo do Sistema).
  // 40dB HL (nível de início do teste) equivalerá a 0.01 linear, evitando picos traumáticos.
  static const double _kBaseGain = 0.0001;

  AudioRehabEngine._internal() {
    final apiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
    _tts = GoogleTTSService(apiKey);
  }

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
  Future<void> playPureTone({
    required int frequencyHz, 
    required int durationMs,
    double dbLevel = 0.0, // Intensidade em dB HL
  }) async {
    // Player temporário para o tom de teste
    final tonePlayer = AudioPlayer();
    
    final int sampleRate = 44100;
    final int numSamples = (sampleRate * (durationMs / 1000)).toInt();
    
    // Gerar tom com amplitude controlada
    final Int16List samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
        samples[i] = (32767 * math.sin(2 * math.pi * frequencyHz * i / sampleRate)).toInt();
    }

    final bytes = _generateWavBytes(samples, sampleRate);
    final uri = Uri.dataFromBytes(bytes, mimeType: 'audio/wav');
    
    try {
      // Cálculo de volume de segurança para o teste de limiar
      // Volume = GanhoBase * 10^(dB/20)
      double calculatedVol = _kBaseGain * math.pow(10, (dbLevel / 20));
      
      // Hard Limit de Segurança: Nunca ultrapassa 1.0 (Digital Clipping/Danger)
      if (calculatedVol > 1.0) calculatedVol = 1.0;

      await tonePlayer.setAudioSource(AudioSource.uri(uri));
      await tonePlayer.setVolume(calculatedVol);
      
      await tonePlayer.play();
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

  /// Gera ruído de fundo sintético (babble-like) baseado em ruído branco com filtragem leve
  Uint8List _generateBabbleNoise({required int durationMs}) {
    final int sampleRate = 44100;
    final int numSamples = (sampleRate * (durationMs / 1000)).toInt();
    final Int16List samples = Int16List(numSamples);
    final random = math.Random();

    for (int i = 0; i < numSamples; i++) {
      // Mistura de ruído branco com modulação aleatória para simular "vozes distantes"
      double noise = (random.nextDouble() * 2 - 1);
      double modulation = math.sin(2 * math.pi * 5 * i / sampleRate) * 0.5 + 0.5; // Modulação 5Hz
      samples[i] = (noise * modulation * 2000).toInt();
    }

    return _generateWavBytes(samples, sampleRate);
  }

  double _lastSnr = 0.0;

  /// Atualiza o SNR do áudio em execução em tempo real [UX/FRONTEND]
  void updateSNR(double newSnr) {
    if (!_isInitialized) return;
    _lastSnr = newSnr;
    _applyVolumes();
  }

  void _applyVolumes() {
    // 1. Compensação de Ganho baseada no Audiograma (Regra de Meio Ganho de POGO/NAL)
    double thresholdCompensation = 0.0;
    if (_currentAudiogram != null) {
      // Compensamos apenas metade da perda para evitar recrutamento e desconforto
      thresholdCompensation = _currentAudiogram!.calculatePTA() / 2.0; 
    }

    // 2. Cálculo SNR (dB -> Linear)
    double targetRelativeVol = 1.0;
    double noiseRelativeVol = 1.0;

    if (_lastSnr > 0) {
      noiseRelativeVol = math.pow(10, -(_lastSnr / 20)).toDouble();
    } else if (_lastSnr < 0) {
      targetRelativeVol = math.pow(10, (_lastSnr / 20)).toDouble();
    }

    // 3. Aplicação do Ganho de Base + Compensação
    double gainMultiplier = math.pow(10, (thresholdCompensation / 20)).toDouble();
    
    // Volume Final = GanhoBase * Relativo * Compensação
    double finalTargetVol = _kBaseGain * targetRelativeVol * gainMultiplier;
    double finalNoiseVol = _kBaseGain * noiseRelativeVol * gainMultiplier;

    // Normalização Estrita de Segurança
    if (finalTargetVol > 1.0) finalTargetVol = 1.0;
    if (finalNoiseVol > 1.0) finalNoiseVol = 1.0;

    _targetPlayer.setVolume(finalTargetVol);
    _noisePlayer.setVolume(finalNoiseVol);

    print("SEGURANÇA ATIVA: Target ${finalTargetVol.toStringAsFixed(3)} | Ruído ${finalNoiseVol.toStringAsFixed(3)}");
  }

  /// Aplica equalização baseada no audiograma [CLÍNICO/DSP]
  /// Realça frequências onde o paciente tem perda e corta graves para evitar mascaramento.
  void _applyClinicalEQ() {
    if (_currentAudiogram == null) return;

    // No just_audio, usamos AndroidLoudnessEnhancer ou filters via ClippingAudioSource
    // Para uma implementação clínica real, idealmente usaríamos um motor FFI ou 
    // AndroidEqualizer / AppleAudioUnit.
    
    // Simulação de EQ via ganho dinâmico por enquanto (conforme Global Rule 2 de Motor de Áudio)
    _applyVolumes();
  }

  /// NÍVEL 2: Discriminação Fonêmica com Síntese Dinâmica ou Assets
  Future<void> playPhonemicStimulus({
    String? assetPath,
    String? text,
  }) async {
    _verifySecurityScope();
    
    try {
      if (text != null) {
        // Geração dinâmica via Google Cloud TTS
        final localPath = await _tts.synthesize(text);
        await _targetPlayer.setAudioSource(AudioSource.file(localPath));
      } else if (assetPath != null) {
        // Carregamento de asset estático tradicional
        await _targetPlayer.setAudioSource(AudioSource.asset(assetPath));
      } else {
        throw Exception("É necessário fornecer 'text' ou 'assetPath' para o estímulo fonêmico.");
      }
      
      // Aplica equalização baseada no audiograma antes do play
      _applyClinicalEQ();
      
      await _targetPlayer.play();
    } catch (e) {
      print("ERRO DISCRIMINAÇÃO FONÊMICA: $e");
    }
  }

  /// NÍVEL 3: Áudio Espacial (Atenção Auditiva Lateralizada) [BINAURAL/CLÍNICO]
  /// [panning]: -1.0 (Total Esquerda) a 1.0 (Total Direita)
  Future<void> playSpatialStimulus({
    String? assetPath,
    String? text,
    required double panning,
  }) async {
    _verifySecurityScope();
    
    try {
      if (text != null) {
        final localPath = await _tts.synthesize(text);
        await _targetPlayer.setAudioSource(AudioSource.file(localPath));
      } else if (assetPath != null) {
        await _targetPlayer.setAudioSource(AudioSource.asset(assetPath));
      } else {
        throw Exception("É necessário fornecer 'text' ou 'assetPath' para o estímulo espacial.");
      }
      
      await _targetPlayer.setSpeed(1.0);
      _targetPlayer.setVolume(1.0);
      
      // Aplica balanço de canal dinâmico (Panning) - Atualmente requer lib complementar em web
      // await _targetPlayer.setBalance(panning); 

      // Aplica EQ clínico antes do play (Global Rule 2)
      _applyClinicalEQ();
      
      await _targetPlayer.play();
    } catch (e) {
      print("ERRO ÁUDIO ESPACIAL: $e");
    }
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado com Síntese Dinâmica
  Future<void> playSpeechInNoise({
    String? targetAudioPath,
    String? targetText,
    String? noiseAudioPath,
    required double snrDb,
    bool isAsset = false,
  }) async {
    _verifySecurityScope();
    _lastSnr = snrDb;

    try {
      // 1. Configurar Sinal Alvo
      if (targetText != null) {
        final localPath = await _tts.synthesize(targetText);
        await _targetPlayer.setAudioSource(AudioSource.file(localPath));
      } else if (targetAudioPath != null) {
        if (isAsset) {
          await _targetPlayer.setAudioSource(AudioSource.asset(targetAudioPath));
        } else {
          await _targetPlayer.setAudioSource(AudioSource.uri(Uri.parse(targetAudioPath)));
        }
      }

      // 2. Configurar Ruído
      if (noiseAudioPath != null) {
        if (isAsset) {
          await _noisePlayer.setAudioSource(AudioSource.asset(noiseAudioPath));
        } else {
          await _noisePlayer.setAudioSource(AudioSource.uri(Uri.parse(noiseAudioPath)));
        }
      } else {
        // Gerar ruído sintético caso não fornecido (Engine Autônoma)
        final noiseBytes = _generateBabbleNoise(durationMs: 5000);
        final noiseUri = Uri.dataFromBytes(noiseBytes, mimeType: 'audio/wav');
        await _noisePlayer.setAudioSource(AudioSource.uri(noiseUri));
      }

      _applyVolumes();
      _noisePlayer.setLoopMode(LoopMode.one);

      await Future.wait([
        _targetPlayer.play(),
        _noisePlayer.play(),
      ]);
    } catch (e) {
      print("ERRO NO ENGINE (SIN): $e");
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
