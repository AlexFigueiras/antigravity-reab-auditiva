import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio_engine/audio_engine.dart';

/// Controla o idioma do app (i18n) e persiste a escolha do usuário.
///
/// - `locale == null` → o app segue o idioma do dispositivo (resolvido pelo
///   `MaterialApp` contra `supportedLocales`, caindo no template pt se não houver
///   correspondência).
/// - O usuário pode fixar um idioma; a escolha é salva em SharedPreferences e
///   reaplicada no próximo início.
///
/// A camada de ÁUDIO CLÍNICO (TTS, pares mínimos, frases Matrix) deve consultar
/// `audioLanguageCode` — não basta trocar o texto da UI; ver SYSTEM.md (i18n).
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_locale';

  /// Idiomas que o app realmente suporta. Manter em sincronia com os arquivos
  /// `lib/l10n/app_<code>.arb` e com `supportedLocales` no MaterialApp.
  static const List<Locale> supportedLocales = [
    Locale('pt'),
    Locale('en'),
  ];

  Locale? _locale;
  Locale? get locale => _locale;

  /// Código de idioma CURTO (ex.: 'pt', 'en') para SELECIONAR o conteúdo clínico
  /// (qual banco de pares mínimos / frases Matrix). Resolve o efetivo (escolha do
  /// usuário ou idioma do device), com fallback seguro em 'pt'.
  String get audioLanguageCode {
    final code = _locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return supportedLocales.any((l) => l.languageCode == code) ? code : 'pt';
  }

  /// Mapeia cada idioma suportado para o LOCALE COMPLETO da VOZ do TTS. Fixar a
  /// variante regional (pt-BR, en-US) evita que a engine OEM escolha um sotaque
  /// indesejado (pt-PT, en-GB...) — garante não só "voz no idioma certo" mas a
  /// variante certa. Manter em sincronia com [supportedLocales].
  static const Map<String, String> _audioLocaleByLang = {
    'pt': 'pt-BR',
    'en': 'en-US',
  };

  /// Locale COMPLETO da voz do TTS (ex.: 'pt-BR', 'en-US') — usado só ao
  /// configurar o motor de fala, não para selecionar conteúdo.
  String get audioLocaleCode => _audioLocaleByLang[audioLanguageCode] ?? 'pt-BR';

  /// Carrega a escolha salva (chamar no boot, antes do runApp).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null &&
          supportedLocales.any((l) => l.languageCode == code)) {
        _locale = Locale(code);
      }
    } catch (_) {
      // sem prefs → segue o idioma do device (locale null).
    }
    _syncAudioLanguage();
  }

  /// Mantém a voz do TTS em sincronia com o idioma efetivo. Ponto único — assim
  /// nenhuma tela precisa setar idioma no motor de áudio manualmente.
  void _syncAudioLanguage() {
    AudioRehabEngine().setTtsLanguage(audioLocaleCode);
  }

  /// Fixa um idioma e persiste. Passar null volta a seguir o device.
  Future<void> setLocale(Locale? locale) async {
    if (locale != null &&
        !supportedLocales.any((l) => l.languageCode == locale.languageCode)) {
      return; // idioma não suportado → ignora
    }
    _locale = locale;
    _syncAudioLanguage();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, locale.languageCode);
      }
    } catch (_) {
      // persistência best-effort; a troca em memória já valeu para a sessão.
    }
  }
}
