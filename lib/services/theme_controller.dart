import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme/app_palette.dart';

/// Controla o VISUAL do app (tema claro/escuro) e persiste a escolha.
///
/// Decisão de produto: o app ABRE no tema **claro** (amigável, público 55–75).
/// Quem nunca escolheu cai no claro; quem trocar para escuro tem a escolha
/// salva e reaplicada no próximo início. Não há "seguir o sistema": o padrão é
/// sempre claro até o usuário decidir o contrário.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  // Padrão de produto: claro para todos.
  AppThemeMode _mode = AppThemeMode.light;
  AppThemeMode get mode => _mode;

  bool get isDark => _mode == AppThemeMode.dark;

  /// Paleta resolvida do tema atual — fonte única de cor para todas as telas.
  AppPalette get palette => AppPalette.of(_mode);

  /// Carrega a escolha salva (chamar no boot, antes do runApp).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'dark') {
        _mode = AppThemeMode.dark;
      } else if (saved == 'light') {
        _mode = AppThemeMode.light;
      }
    } catch (_) {
      // sem prefs → mantém o padrão claro.
    }
  }

  /// Alterna claro ↔ escuro e persiste.
  Future<void> toggle() => setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);

  Future<void> setMode(AppThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode == AppThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      // persistência best-effort; a troca em memória já valeu para a sessão.
    }
  }
}
