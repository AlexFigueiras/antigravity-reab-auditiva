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
  // Vozes disponíveis por idioma (chave = languageCode minúsculo, ex.: 'pt', 'en').
  // Cache por idioma para suportar i18n: a voz da fala TEM de bater com o idioma
  // do conteúdo, senão a pronúncia fica errada (ex.: voz inglesa lendo "Sala").
  final Map<String, List<String>> _voicesByLang = {};
  int _voiceCycleIndex = 0;

  /// True se a variante EXATA da voz (ex.: 'pt-BR') está instalada no device.
  ///
  /// Diferente de [_voicesFor], que casa por PREFIXO (qualquer pt serve para não
  /// ficar mudo): aqui queremos saber se a variante CERTA existe, para avisar o
  /// usuário quando a fala vai sair com outro sotaque (ex.: pt-PT lendo os pares
  /// mínimos). Ver docs/i18n.md (disponibilidade de voz no device).
  ///
  /// Em falha/plataforma sem suporte retorna `true` — não alarmar à toa; a fala
  /// continua funcionando na variante disponível.
  Future<bool> isLocaleInstalled(String localeCode) async {
    try {
      final installed = await _tts.isLanguageInstalled(localeCode);
      return installed == true;
    } catch (_) {
      return true;
    }
  }

  /// Carrega (e cacheia) as vozes do dispositivo para [languageCode] — casa pelo
  /// prefixo do locale (ex.: 'pt' pega pt-BR/pt-PT; 'en' pega en-US/en-GB...).
  Future<List<String>> _voicesFor(String languageCode) async {
    final lang = languageCode.split('-').first.toLowerCase();
    final cached = _voicesByLang[lang];
    if (cached != null) return cached;

    List<String> result = [];
    try {
      final voices = await _tts.getVoices;
      if (voices != null) {
        final parsed = voices
            .map((v) => Map<String, dynamic>.from(v as Map))
            .cast<Map<String, dynamic>>();
        result = parsed
            .where((v) =>
                ((v['locale'] as String?)?.toLowerCase() ?? '').startsWith(lang))
            .map((v) => (v['name'] as String?) ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    _voicesByLang[lang] = result;
    return result;
  }

  Future<void> _ensureConfigured({
    required String languageCode,
    required double speakingRate,
    required double pitch,
    String? voiceName,
  }) async {
    // Sempre reaplica idioma/voz: o motor pode ter sido usado com outros params.
    await _tts.setLanguage(languageCode);
    if (voiceName != null) {
      try {
        final voices = await _tts.getVoices;
        if (voices != null) {
          final voice = voices.firstWhere(
            (v) => v['name'] == voiceName,
            orElse: () => null,
          );
          if (voice != null) {
            await _tts.setVoice(Map<String, String>.from(voice as Map));
          }
        }
      } catch (_) {}
    }
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
    String? voiceName,
  }) async {
    final langVoices = await _voicesFor(languageCode);

    String? activeVoice = voiceName;
    if (activeVoice == null && langVoices.isNotEmpty) {
      activeVoice = langVoices[_voiceCycleIndex % langVoices.length];
      _voiceCycleIndex++;
    }

    final cacheKey = _cacheKey(text, languageCode, speakingRate, pitch, activeVoice);
    final cacheFile = await _cacheFile(cacheKey);

    if (await cacheFile.exists() && await cacheFile.length() > 44) {
      final rate = await _readWavSampleRate(cacheFile);
      return SynthesizedSpeech(cacheFile.path, rate);
    }

    await _ensureConfigured(
      languageCode: languageCode,
      speakingRate: speakingRate,
      pitch: pitch,
      voiceName: activeVoice,
    );

    // Pede a síntese gravando diretamente no caminho absoluto de cache
    // (isFullPath: true). Algumas engines OEM ignoram o caminho e gravam no
    // diretório de arquivos do app; _resolveGeneratedFile deita esse caso.
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

  String _cacheKey(String text, String lang, double rate, double pitch, String? voiceName) {
    final input = '$text|$lang|$rate|$pitch|${voiceName ?? "default"}';
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<File> _cacheFile(String key) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/tts_cache_$key.wav');
  }
}
