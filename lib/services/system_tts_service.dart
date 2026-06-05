import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// Resultado da síntese: caminho do WAV e seu sample rate real (lido do header).
/// O sample rate é necessário porque o motor de TTS do sistema gera o áudio
/// em uma taxa própria (ex.: 22050 Hz), que pode diferir da taxa do DSP nativo.
class SynthesizedSpeech {
  const SynthesizedSpeech(this.path, this.sampleRate);
  final String path;
  final int sampleRate;
}

/// Síntese de fala usando o motor TTS nativo do dispositivo (offline, gratuito).
///
/// Gera um arquivo WAV (PCM 16-bit) via `synthesizeToFile`, que é então
/// alimentado no pipeline de DSP nativo (Oboe) — preservando o ganho
/// compensatório de meia-perda. Mantém um cache em disco, indexado por hash
/// do texto + parâmetros, para evitar re-sintetizar a mesma palavra.
class SystemTtsService {
  SystemTtsService() {
    _tts = FlutterTts();
  }

  late final FlutterTts _tts;

  Future<void> _ensureConfigured({
    required String languageCode,
    required double speakingRate,
    required double pitch,
  }) async {
    // Sempre reaplica idioma/voz: o motor pode ter sido usado com outros params.
    await _tts.setLanguage(languageCode);
    // flutter_tts usa escala 0.0–1.0 para a velocidade no Android (0.5 ≈ normal).
    // Mapeamos speakingRate (1.0 = normal) para essa escala de forma estável.
    await _tts.setSpeechRate((speakingRate * 0.5).clamp(0.0, 1.0));
    await _tts.setPitch(pitch == 0.0 ? 1.0 : (1.0 + pitch / 20.0).clamp(0.5, 2.0));
    await _tts.awaitSynthCompletion(true);
  }

  /// Sintetiza [text] para um arquivo WAV e retorna o caminho + sample rate real.
  Future<SynthesizedSpeech> synthesize(
    String text, {
    String languageCode = 'pt-BR',
    double speakingRate = 1.0,
    double pitch = 0.0,
  }) async {
    final cacheKey = _cacheKey(text, languageCode, speakingRate, pitch);
    final cacheFile = await _cacheFile(cacheKey);

    if (await cacheFile.exists() && await cacheFile.length() > 44) {
      final rate = await _readWavSampleRate(cacheFile);
      return SynthesizedSpeech(cacheFile.path, rate);
    }

    await _ensureConfigured(
      languageCode: languageCode,
      speakingRate: speakingRate,
      pitch: pitch,
    );

    // Pede a síntese gravando diretamente no caminho absoluto de cache
    // (isFullPath: true). Algumas engines OEM ignoram o caminho e gravam no
    // diretório de arquivos do app; _resolveGeneratedFile cobre esse caso.
    final fileName = 'tts_$cacheKey.wav';
    final result =
        await _tts.synthesizeToFile(text, cacheFile.path, true);
    // O plugin retorna 1 (ou "1") em sucesso — o tipo varia por plataforma.
    if (result.toString() != '1') {
      throw Exception('Falha na síntese de fala (flutter_tts retornou $result).');
    }

    final generated = await _resolveGeneratedFile(fileName, cacheFile);
    final rate = await _readWavSampleRate(generated);
    return SynthesizedSpeech(generated.path, rate);
  }

  /// Localiza o arquivo gerado pela engine e garante que ele esteja em
  /// [target] (o caminho de cache esperado).
  Future<File> _resolveGeneratedFile(String fileName, File target) async {
    if (await target.exists() && await target.length() > 44) return target;

    // A engine pode ter escrito em getExternalStorageDirectory ou no
    // diretório de arquivos do app. Procuramos nos locais conhecidos.
    final candidates = <Directory?>[
      await getApplicationSupportDirectory(),
      await getTemporaryDirectory(),
      await getApplicationDocumentsDirectory(),
      if (!kIsWeb && Platform.isAndroid) await getExternalStorageDirectory(),
    ];

    for (final dir in candidates) {
      if (dir == null) continue;
      final f = File('${dir.path}/$fileName');
      if (await f.exists() && await f.length() > 44) {
        if (f.path != target.path) {
          await f.copy(target.path);
          return target;
        }
        return f;
      }
    }
    throw Exception('Arquivo de fala não encontrado após a síntese: $fileName');
  }

  /// Lê o sample rate (campo de 4 bytes no offset 24) do header WAV canônico.
  Future<int> _readWavSampleRate(File file) async {
    final raf = await file.open();
    try {
      await raf.setPosition(24);
      final b = await raf.read(4);
      if (b.length < 4) return 22050; // fallback comum de engines TTS
      return b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);
    } finally {
      await raf.close();
    }
  }

  String _cacheKey(String text, String lang, double rate, double pitch) {
    final input = '$text|$lang|$rate|$pitch';
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<File> _cacheFile(String key) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/tts_cache_$key.wav');
  }
}
