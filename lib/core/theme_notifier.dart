import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla o tema (claro/escuro) e persiste a escolha do usuário.
/// Padrão de produto: claro (público 55-75 anos).
class ThemeNotifier extends ChangeNotifier {
  static const _key = 'app_theme_mode';
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_key) == 'dark') _mode = ThemeMode.dark;
    } catch (_) {}
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
