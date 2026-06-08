import 'package:flutter/material.dart';

/// Fonte única de tema do app. Define light e dark como ThemeData completos.
/// Widgets lêem cores via Theme.of(context).colorScheme — zero hardcoded.
class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        bg: const Color(0xFFF4F6FA),
        card: const Color(0xFFFFFFFF),
        primary: const Color(0xFF2E6FE0),
        onSurface: const Color(0xFF1A2230),
        onSurfaceVariant: const Color(0xFF5C6776),
        tertiary: const Color(0xFF2E9E6B),
        error: const Color(0xFFD64A42),
        outline: const Color(0xFFD1D5DB),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        bg: const Color(0xFF101418),
        card: const Color(0xFF1B2128),
        primary: const Color(0xFF4F8DF7),
        onSurface: const Color(0xFFF2F4F7),
        onSurfaceVariant: const Color(0xFFB4BCC8),
        tertiary: const Color(0xFF3FB37F),
        error: const Color(0xFFE5534B),
        outline: const Color(0xFF2E3542),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color card,
    required Color primary,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color tertiary,
    required Color error,
    required Color outline,
  }) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        secondary: tertiary,
        onSecondary: Colors.white,
        surface: card,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        tertiary: tertiary,
        onTertiary: Colors.white,
        error: error,
        onError: Colors.white,
        outline: outline,
      ),
      textTheme: _scaleTextTheme(base.textTheme, 1.1),
      visualDensity: VisualDensity.comfortable,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(color: onSurface, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static TextTheme _scaleTextTheme(TextTheme base, double factor) {
    TextStyle? scale(TextStyle? s) =>
        (s == null || s.fontSize == null) ? s : s.apply(fontSizeFactor: factor);
    return base.copyWith(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }
}
