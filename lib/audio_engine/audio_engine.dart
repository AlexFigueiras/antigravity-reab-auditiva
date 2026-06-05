import 'dart:math' as math;
import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../models/audiogram.dart';
import '../core/ambience_synth.dart';
import '../core/listening_mode.dart';
import '../core/coclear_dead_region.dart';
import '../services/system_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'native_engine.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Motor de Áudio Central para Reabilitação Auditiva
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  bool _isInitialized = false;
  Audiogram? _currentAudiogram;

  // Política de escuta (com/sem aparelho). Decide se o EQ clínico (meia-perda)
  // é aplicado: SEM aparelho → o app compensa; COM aparelho → EQ desligado
  // (o aparelho já compensa; empilhar os dois estoura os agudos). Ver 0.4/1.1.
  ListeningMode _listeningMode = ListeningMode.unaided;

  // Bandas do EQ clínico — DEVEM casar com kEqCenters em dsp_engine.cpp.
  static const List<int> _eqBandCentersHz = [1000, 2000, 4000, 6000, 8000];
  // Teto de segurança do ganho por banda (dB). A 4.1 (zonas mortas) vai refinar
  // isto: numa banda com perda profunda, amplificar cego não ajuda e pode piorar.
  static const double _kMaxEqGainDb = 30.0;

  // Ambiência atualmente carregada no AmbienceLooper nativo (uma por vez).
  // null = nenhuma; o cocktail só usa ambiência se a chave bater com esta.
  String? _loadedAmbienceKey;

  final _nativeBridge = NativeDSPBridge();
  late final SystemTtsService _tts;

  // Calibração: 0dB HL -> 0.0001 linear. 80dB HL -> 1.0 linear.
  static const double _kRefDb = 80.0;
  static const double _fs = 48000.0; // Sample Rate padrão do Engine

  AudioRehabEngine._internal() {
    // Voz das palavras: motor TTS nativo do dispositivo (offline, gratuito).
    // O WAV sintetizado entra no mesmo pipeline DSP (ganho de meia-perda).
    _tts = SystemTtsService();
  }

  static const Map<String, String> _kSpeechAssets = {
    'sala': 'assets/speech/sala.wav',
    'fala': 'assets/speech/fala.wav',
    'vila': 'assets/speech/vila.wav',
    'fila': 'assets/speech/fila.wav',
    'sopa': 'assets/speech/sopa.wav',
    'copa': 'assets/speech/copa.wav',
    'selo': 'assets/speech/selo.wav',
    'zelo': 'assets/speech/zelo.wav',
    'dado': 'assets/speech/dado.wav',
    'tato': 'assets/speech/tato.wav',
    'rosa': 'assets/speech/rosa.wav',
    'roça': 'assets/speech/roça.wav',
    'chapa': 'assets/speech/chapa.wav',
    'japa': 'assets/speech/japa.wav',
  };

  Future<Float32List?> _loadWavAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      if (bytes.length < 44) return null;

      final headerStr = String.fromCharCodes(bytes.sublist(0, 4));
      final formatStr = String.fromCharCodes(bytes.sublist(8, 12));
      if (headerStr != "RIFF" || formatStr != "WAVE") return null;

      int fmtOffset = -1;
      for (int i = 12; i < bytes.length - 8; i++) {
        if (String.fromCharCodes(bytes.sublist(i, i + 4)) == "fmt ") {
          fmtOffset = i;
          break;
        }
      }
      if (fmtOffset == -1) return null;

      final int sampleRate = bytes[fmtOffset + 12] | 
                            (bytes[fmtOffset + 13] << 8) | 
                            (bytes[fmtOffset + 14] << 16) | 
                            (bytes[fmtOffset + 15] << 24);
      final int bitsPerSample = bytes[fmtOffset + 22] | (bytes[fmtOffset + 23] << 8);

      if (bitsPerSample != 16) return null;

      int dataOffset = -1;
      int dataSize = 0;
      for (int i = fmtOffset + 8; i < bytes.length - 8; i++) {
        if (String.fromCharCodes(bytes.sublist(i, i + 4)) == "data") {
          dataOffset = i + 8;
          dataSize = bytes[i + 4] | 
                     (bytes[i + 5] << 8) | 
                     (bytes[i + 6] << 16) | 
                     (bytes[i + 7] << 24);
          break;
        }
      }
      if (dataOffset == -1) return null;

      final int actualDataSize = math.min(dataSize, bytes.length - dataOffset);
      final int numSamples = actualDataSize ~/ 2;
      final Float32List floatSamples = Float32List(numSamples);

      final ByteData byteData = ByteData.sublistView(bytes, dataOffset, dataOffset + numSamples * 2);
      for (int i = 0; i < numSamples; i++) {
        final int sample16 = byteData.getInt16(i * 2, Endian.little);
        floatSamples[i] = sample16 / 32768.0;
      }

      if (sampleRate != 48000) {
        return _resampleTo(floatSamples, sampleRate, 48000);
      }
      return floatSamples;
    } catch (e) {
      debugPrint("Erro ao carregar asset WAV: $e");
      return null;
    }
  }

  /// Sintetiza a fala e devolve as amostras já reamostradas para [_fs].
  /// Centraliza o caminho TTS -> WAV -> Float32 -> (resample) usado por todos
  /// os estímulos de fala, garantindo tom e velocidade corretos no DSP.
  Future<Float32List> _synthesizeSpeechSamples(String text) async {
    final String cleanText = text.trim().toLowerCase();
    Float32List? samples;
    if (_kSpeechAssets.containsKey(cleanText)) {
      samples = await _loadWavAsset(_kSpeechAssets[cleanText]!);
      if (samples != null) {
        debugPrint("[SPEECH_ASSET] Carregado de asset gravado: $cleanText");
      }
    }

    if (samples == null) {
      final speech = await _tts.synthesize(text);
      final bytes = await File(speech.path).readAsBytes();
      final raw = _convertInt16ToFloat32(bytes);
      samples = _resampleTo(raw, speech.sampleRate, _fs.toInt());
      double peak = 0.0;
      for (final s in samples) {
        final a = s.abs();
        if (a > peak) peak = a;
      }
      debugPrint("[TTS_DIAG] '$text' file=${speech.path} bytes=${bytes.length} "
          "srcRate=${speech.sampleRate} rawSamples=${raw.length} "
          "outSamples=${samples.length} peak=${peak.toStringAsFixed(4)}");
    }

    // FASE 4: Transposição de Frequência (Frequency Lowering) se houver zona morta nas altas frequências
    if (CochlearDeadRegionManager.hasHighFrequencyDeadRegion(_currentAudiogram)) {
      final textLower = text.toLowerCase();
      // Aplica apenas para estímulos contendo sibilantes/fricativas críticas
      if (textLower.contains('s') || textLower.contains('f') || textLower.contains('t') || 
          textLower.contains('z') || textLower.contains('ch') || textLower.contains('x') ||
          textLower.contains('v')) {
        debugPrint("[CDR_DSP] Aplicando Frequency Lowering em '$text'...");
        samples = CochlearDeadRegionManager.applyFrequencyLowering(samples);
      }
    }

    return samples;
  }

  /// Reamostragem linear para [targetRate]. Necessária porque o TTS do
  /// sistema costuma gerar 22050 Hz, enquanto o DSP nativo opera a 48 kHz —
  /// sem isso, a voz tocaria em tom/velocidade errados.
  Float32List _resampleTo(Float32List input, int srcRate, int targetRate) {
    if (srcRate == targetRate || input.isEmpty) return input;
    final ratio = targetRate / srcRate;
    final outLen = (input.length * ratio).floor();
    final out = Float32List(outLen);
    for (int i = 0; i < outLen; i++) {
      final srcPos = i / ratio;
      final i0 = srcPos.floor();
      final i1 = (i0 + 1 < input.length) ? i0 + 1 : i0;
      final frac = srcPos - i0;
      out[i] = input[i0] * (1.0 - frac) + input[i1] * frac;
    }
    return out;
  }

  Future<void> restartHardwareAudio() async {
    _nativeBridge.stopHardwareAudio();
    await Future.delayed(const Duration(milliseconds: 200));
    _nativeBridge.startHardwareAudio();
    debugPrint("[ENGINE_REINIT] Hardware Audio Stream Restarted (EXCLUSIVE MODE ACTIVE)");
  }

  /// Garante que o stream de áudio está vivo antes de tocar. O Oboe pode
  /// DESCONECTAR o stream numa troca de rota (fone, Bluetooth, fim de chamada,
  /// MMAP rerouting do MIUI) — o `onErrorAfterClose` não consegue reabrir
  /// sozinho (o ponteiro do stream fechado segura o `start()` idempotente), e
  /// aí TODO áudio sai mudo. Aqui detectamos via `isDeviceDisconnected()` e
  /// reabrimos o stream. Ver SYSTEM.md §8.
  Future<void> _ensureStreamHealthy() async {
    if (_nativeBridge.isDeviceDisconnected()) {
      debugPrint("[ENGINE] Stream desconectado (troca de rota). Reiniciando…");
      await restartHardwareAudio();
    }
  }

  /// Carrega a ambiência procedural de um ambiente (restaurante/academia/praça/
  /// mercado) no AmbienceLooper nativo. Fica em volume 0 até o cocktail ligá-la.
  /// O sintetizador faz cache, então recarregar o mesmo ambiente é barato.
  void loadAmbience(String envKey) {
    if (_loadedAmbienceKey == envKey) return; // já está no looper
    final Float32List samples = AmbienceSynth.generate(envKey);
    final pointer = calloc<ffi.Float>(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pointer[i] = samples[i];
    }
    _nativeBridge.setAmbienceSample(pointer, samples.length, 0.0);
    calloc.free(pointer);
    _loadedAmbienceKey = envKey;
    debugPrint("[ENGINE] Ambiência '$envKey' carregada (${samples.length} amostras).");
  }

  Future<void> initializeEngine(Audiogram audiogram) async {
    _currentAudiogram = audiogram;
    _nativeBridge.startHardwareAudio();
    _isInitialized = true;
    // Aplica o EQ clínico de meia-perda derivado deste audiograma (ou plano, se
    // não houver audiograma ou se o modo for "com aparelho"). Ver 1.1 / 0.4.
    _applyAudiogramEq();
    print("AudioRehabEngine Inicializado (Native Stereo DSP | Clinical EQ Active)");
  }

  /// Define a política de escuta (com/sem aparelho) e reaplica o EQ de acordo.
  /// SEM aparelho → o app aplica o ganho de meia-perda; COM aparelho → EQ plano.
  void setListeningMode(ListeningMode mode) {
    _listeningMode = mode;
    _applyAudiogramEq();
  }

  /// Calcula e envia ao DSP nativo os ganhos por banda do EQ clínico.
  ///
  /// Só amplifica no modo SEM aparelho e com audiograma válido. Caso contrário
  /// (com aparelho, ou sem audiograma — ex.: durante o próprio teste de tom puro)
  /// manda tudo 0 dB (passa-tudo), para não colorir o estímulo nem empilhar com a
  /// compensação do aparelho.
  void _applyAudiogramEq() {
    final ag = _currentAudiogram;
    final bool canEq = _listeningMode == ListeningMode.unaided &&
        ag != null &&
        ag.leftEar.isNotEmpty &&
        ag.rightEar.isNotEmpty;

    final gains = Float32List(_eqBandCentersHz.length);
    if (canEq) {
      for (int i = 0; i < _eqBandCentersHz.length; i++) {
        final g = getCompensatoryGain(_eqBandCentersHz[i].toDouble());
        gains[i] = g.clamp(0.0, _kMaxEqGainDb);
      }
    }
    // (else: permanece tudo 0.0 — EQ plano)

    final pointer = calloc<ffi.Float>(gains.length);
    for (int i = 0; i < gains.length; i++) {
      pointer[i] = gains[i];
    }
    _nativeBridge.setEqBandGains(pointer, gains.length);
    calloc.free(pointer);

    debugPrint("[ENGINE] EQ clínico aplicado | modo=${_listeningMode.name} | "
        "ganhos(dB)=${gains.map((g) => g.toStringAsFixed(1)).toList()}");
  }

  double getNativeLatencyMs() => _nativeBridge.getLatencyMs();
  int getLastStimulusTimestampNs() => _nativeBridge.getStimulusTimestampNs();
  int getNativeCurrentTimestampNs() => _nativeBridge.getCurrentTimestampNs();
  
  NativeDSPBridge get native => _nativeBridge; 

  /// Regra de Meio Ganho (Half-Gain) [AUDIOLOGIA]
  /// Gain = Loss / 2
  double getCompensatoryGain(double frequencyHz) {
    final ag = _currentAudiogram;
    // Sem audiograma OU orelhas vazias (ex.: durante o teste de tom puro, que
    // inicializa o motor com audiograma em branco) → sem ganho. Evita também o
    // `.last` numa lista vazia (StateError).
    if (ag == null || ag.leftEar.isEmpty || ag.rightEar.isEmpty) return 0.0;

    // Busca a perda média para a frequência alvo (L+R)
    final leftPoint = ag.leftEar.firstWhere(
      (p) => p.frequency >= frequencyHz, orElse: () => ag.leftEar.last
    );
    final rightPoint = ag.rightEar.firstWhere(
      (p) => p.frequency >= frequencyHz, orElse: () => ag.rightEar.last
    );

    double avgLoss = (leftPoint.threshold + rightPoint.threshold) / 2.0;

    // FASE 4: Proteção contra recrutamento coclear (Cochlear Dead Regions)
    if (CochlearDeadRegionManager.isFrequencyDead(ag, frequencyHz)) {
      debugPrint("[CDR_PROTECTION] Zona morta detectada em $frequencyHz Hz. Limitando ganho para 10 dB.");
      return 10.0;
    }

    return avgLoss / 2.0; // REGRA DE OURO (meia-perda)
  }

  /// NÍVEL 2: Discriminação Fonêmica com EQ Dinâmico
  Future<void> playPhonemicStimulus({
    required String text,
    required double freqBand,
    double extraBoostDb = 0.0,
  }) async {
    _verifySecurityScope();
    await _ensureStreamHealthy();

    // 0. Centraliza o panning. Sem isto, a fala herdaria o panning do último
    //    teste de audição (±1.0), que zera um dos canais e deixa a voz
    //    inaudível se o fone estiver no lado oposto. Fala = binaural (centro).
    _nativeBridge.setTargetPanning(0.0);
    _nativeBridge.setTargetAzimuth(0.0);
    _nativeBridge.setNoiseAzimuth(0.0);
    // Garante que o ruído do nível 4 não fique de fundo neste treino limpo.
    _nativeBridge.setNoiseIntensity(0.0);

    // A compensação por frequência (meia-perda) já é feita pelo EQ multibanda
    // nativo, configurado a partir do audiograma em _applyAudiogramEq (1.1) —
    // não mais um número só impresso no log. Aqui tratamos só o REFORÇO do N2:
    // ao errar, repetimos a palavra mais ALTA (extraBoostDb) como ganho de
    // volume REAL, para ajudar a captar. Ver plano 1.5.
    final double boostVolume =
        math.pow(10, extraBoostDb / 20).toDouble().clamp(1.0, 4.0);

    // Síntese de Fala (TTS nativo -> WAV -> amostras a 48 kHz) e carga no DSP.
    final samples = await _synthesizeSpeechSamples(text);
    _loadSampleToNative(samples, isTarget: true, targetVolume: boostVolume);

    print("ESTÍMULO N2: '$text' | Freq: $freqBand Hz | "
        "Reforço: +${extraBoostDb.toStringAsFixed(1)} dB "
        "(vol x${boostVolume.toStringAsFixed(2)})");
  }

  /// NÍVEL 3: Atenção Espacial (Panning Binaural)
  Future<void> playSpatialStimulus({
    required String text,
    required double panning, // -1.0 a 1.0
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    await _ensureStreamHealthy();

    // Garante que o ruído do nível 4 não fique de fundo neste treino limpo.
    _nativeBridge.setNoiseIntensity(0.0);

    // 1. Configura Azimute Nativo com ITD/ILD
    _nativeBridge.setTargetPanning(0.0);
    _nativeBridge.setTargetAzimuth(panning * 90.0);
    _nativeBridge.setNoiseAzimuth(0.0);

    // 2. A compensação de meia-perda já é aplicada pelo EQ multibanda nativo
    //    (a partir do audiograma; ver _applyAudiogramEq / 1.1). Aqui só sintetiza
    //    e carrega — a fala sai com o ganho clínico real, não mais "no print".
    final samples = await _synthesizeSpeechSamples(text);
    _loadSampleToNative(samples, isTarget: true);

    print("ESTÍMULO ESPACIAL: '$text' | Pan: $panning | Freq: $freqBand Hz");
  }



  /// CALIBRAÇÃO: Tom senoidal puro para ajuste de hardware
  Future<void> playCalibrationTone({
    double frequencyHz = 1000.0,
    double durationSeconds = 1.0,
  }) async {
    // 1. Garante que o hardware esteja ativo (mesmo sem audiograma inicial)
    if (!_isInitialized) _nativeBridge.startHardwareAudio();
    _nativeBridge.setTargetPanning(0.0);
    _nativeBridge.setTargetAzimuth(0.0);
    _nativeBridge.setNoiseAzimuth(0.0);

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

  /// Nível de ruído FIXO do nível 4 (linear, −14 dBFS ≈ 0.20).
  ///
  /// COORDENAÇÃO COM O LIMITER (1.6): o soft-knee do DSP tem joelho em 0.707
  /// (−3 dBFS). Com ruído fixo em 0.20 e SNR máximo de +10 dB, a fala chega a
  /// 0.20 × 10^(10/20) = 0.632 — abaixo do joelho. Sem isso o limiter comprimia
  /// a fala em SNRs altos e o SNR real era menor que o pretendido, corrompendo
  /// o staircase. O clamp de targetVolume em 0.65 adiciona uma margem de 0.05.
  static const double _kNoiseLevel = 0.20;

  /// NÍVEL 4: "Entender no meio do barulho" (efeito coquetel).
  ///
  /// O ruído fica FIXO num nível confortável; quem varia com o SNR é a FALA.
  /// Assim o nível total de som não cresce e não incomoda — e é como funcionam
  /// os testes clínicos de fala no ruído. SNR alto = fala acima do ruído (fácil);
  /// SNR 0 dB = fala = ruído (desafiador). Ver SYSTEM.md §8.
  Future<void> playCocktailStimulus({
    required String text,
    required double snrDb,
    required String noiseEnvironment, // Restaurante, Trânsito, Vento
    double freqBand = 4000.0,
    String? ambienceKey, // se setado e carregado, usa a AMBIÊNCIA no lugar do ruído branco
  }) async {
    _verifySecurityScope();
    await _ensureStreamHealthy();

    // 0. Fala no centro (0 graus) e ruído lateralizado (±45 graus)
    _nativeBridge.setTargetPanning(0.0);
    _nativeBridge.setTargetAzimuth(0.0);
    final noiseAngle = math.Random().nextBool() ? 45.0 : -45.0;
    _nativeBridge.setNoiseAzimuth(noiseAngle);

    // 1. Fundo FIXO e confortável (não muda com a dificuldade). No treino de
    //    frases usamos a AMBIÊNCIA do ambiente (restaurante/academia/praça/
    //    mercado); no nível 4 de palavras, o ruído branco. Em ambos o nível é
    //    `_kNoiseLevel` — quem dificulta é a fala abaixando (ver SYSTEM.md §10).
    final bool useAmbience =
        ambienceKey != null && ambienceKey == _loadedAmbienceKey;
    if (useAmbience) {
      _nativeBridge.setNoiseIntensity(0.0); // desliga o chiado
      _nativeBridge.setAmbienceVolume(_kNoiseLevel); // liga a ambiência
    } else {
      _nativeBridge.setAmbienceVolume(0.0); // garante ambiência desligada
      _nativeBridge.setNoiseIntensity(_kNoiseLevel); // ruído branco
    }

    // 2. Volume da FALA derivado do SNR: fala = fundo × 10^(SNR/20).
    //    Clamp em 0.65 garante que a fala nunca cruce o joelho do soft-knee
    //    (0.707), mantendo o SNR entregue igual ao SNR pretendido pelo staircase.
    final double targetVolume =
        (_kNoiseLevel * math.pow(10, snrDb / 20)).toDouble().clamp(0.0, 0.65);

    // 3. Síntese
    final samples = await _synthesizeSpeechSamples(text);

    // 4. Carrega no motor nativo com a fala atenuada conforme o SNR.
    _loadSampleToNative(samples, isTarget: true, targetVolume: targetVolume);

    print("MISTURA COQUETEL: ENV=$noiseEnvironment | SNR=$snrDb dB | "
        "Vol Fala=${targetVolume.toStringAsFixed(3)} | "
        "Fundo=${useAmbience ? 'ambiência' : 'ruído'} $_kNoiseLevel");
  }

  /// Copia as amostras para o motor nativo. `targetVolume` permite atenuar a
  /// fala (usado no nível 4, onde a dificuldade vem de BAIXAR a fala, não de
  /// subir o ruído). Os demais treinos usam o padrão 1.0.
  void _loadSampleToNative(Float32List samples,
      {bool isTarget = true, double targetVolume = 1.0}) {
    final pointer = calloc<ffi.Float>(samples.length);
    for (int i = 0; i < samples.length; i++) {
        pointer[i] = samples[i];
    }

    if (isTarget) {
      _nativeBridge.setTargetSample(pointer, samples.length, targetVolume, false);
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

  /// Interrompe imediatamente a reprodução do estímulo alvo no player nativo.
  void stopTarget() {
    final pointer = calloc<ffi.Float>(0);
    _nativeBridge.setTargetSample(pointer, 0, 0.0, false);
    calloc.free(pointer);
    debugPrint("[ENGINE] Target player stopped/silenced.");
  }

  void stop() {
    // Silencia o ruído branco E a ambiência ANTES de parar o hardware. Sem isso,
    // o que ficou ligado no nível 4 / no treino de frases persiste no engine
    // (singleton) e volta a tocar quando outra tela reabre o stream — vazando
    // para o tom puro e para os demais treinos. Ver SYSTEM.md §8.
    _nativeBridge.setNoiseIntensity(0.0);
    _nativeBridge.stopAmbience();
    _loadedAmbienceKey = null;
    _nativeBridge.stopHardwareAudio();
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado (Alias legado)
  Future<void> playSpeechInNoise({
    required String targetText,
    required double snrDb,
  }) async {
    return playCocktailStimulus(
      text: targetText,
      snrDb: snrDb,
      noiseEnvironment: 'RESTAURANTE',
    );
  }

  /// TESTE AUDIOMÉTRICO: Tom puro isolado por orelha.
  ///
  /// O target player é mono; a separação L/R vem do panning aplicado no mixer
  /// nativo: panning -1.0 zera o ganho do canal direito e 1.0 zera o esquerdo
  /// (ver oboe_engine.cpp). Assim o tom soa apenas no ouvido testado.
  Future<void> playPureTone({
    required int frequencyHz,
    required int durationMs,
    required EarSide ear,
    required double dbLevel,
  }) async {
    _verifySecurityScope();
    await _ensureStreamHealthy();

    // 1. Gera Senoide
    final int numSamples = (durationMs / 1000.0 * _fs).toInt();
    final Float32List samples = Float32List(numSamples);

    // Nível Linear: 10^((dB HL - Ref) / 20)
    double amplitude = math.pow(10, (dbLevel - _kRefDb) / 20).toDouble();

    for (int i = 0; i < numSamples; i++) {
      samples[i] = amplitude * math.sin(2 * math.pi * frequencyHz * i / _fs);
    }

    // Garante que o ruído do nível 4 não vaze para o teste de audição.
    // O tom puro tem de soar limpo, senão o limiar medido fica inválido.
    _nativeBridge.setNoiseIntensity(0.0);

    // 2. Configura Panning (L/R) ANTES de carregar o sample.
    double targetPanning = 0.0;
    if (ear == EarSide.left) targetPanning = -1.0;
    if (ear == EarSide.right) targetPanning = 1.0;
    _nativeBridge.setTargetPanning(targetPanning);
    _nativeBridge.setTargetAzimuth(0.0);
    _nativeBridge.setNoiseAzimuth(0.0);

    // 3. Carrega no motor nativo
    _loadSampleToNative(samples, isTarget: true);

    print("PURE TONE: $frequencyHz Hz | $dbLevel dB | Ear: $ear");
  }

  void _verifySecurityScope() {
    if (!_isInitialized) throw Exception("Erro: Motor não inicializado");
  }
}
