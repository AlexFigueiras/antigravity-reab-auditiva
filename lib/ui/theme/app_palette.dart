import 'package:flutter/material.dart';

/// Os dois visuais do app.
enum AppThemeMode { light, dark }

/// Fonte ÚNICA de cor do app. Antes cada tela declarava as mesmas cinco cores
/// como `static const` (fundo, card, texto…), o que travava o app no tema
/// escuro. Agora a tela lê a paleta do tema ativo via
/// `context.watch<ThemeController>().palette` (ou `AppPalette.of(mode)`), e
/// trocar o tema reconstrói tudo com as cores certas.
///
/// Mantemos os MESMOS nomes de campo que as constantes antigas (`bg`, `card`,
/// `primary`, `textMain`, `textSoft`, `correct`, `wrong`) para que a migração
/// das telas seja uma troca mecânica de `_bg` → `p.bg`.
@immutable
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.primary,
    required this.textMain,
    required this.textSoft,
    required this.correct,
    required this.wrong,
  });

  /// Fundo do Scaffold.
  final Color bg;

  /// Superfície de cartões/sheets.
  final Color card;

  /// Cor de marca (azul). Igual nos dois temas.
  final Color primary;

  /// Texto principal (alto contraste com o fundo).
  final Color textMain;

  /// Texto secundário/legenda.
  final Color textSoft;

  /// Verde de acerto/sucesso.
  final Color correct;

  /// Vermelho de erro.
  final Color wrong;

  /// Tema ESCURO — a paleta histórica do app ("cockpit" calmo, fundo grafite).
  static const AppPalette dark = AppPalette(
    bg: Color(0xFF101418),
    card: Color(0xFF1B2128),
    primary: Color(0xFF4F8DF7),
    textMain: Color(0xFFF2F4F7),
    textSoft: Color(0xFFB4BCC8),
    correct: Color(0xFF3FB37F),
    wrong: Color(0xFFE5534B),
  );

  /// Tema CLARO — padrão do app: claro, amigável, alto contraste para 55–75.
  /// Fundo levemente cinza-azulado (não branco puro, que cansa a vista),
  /// cartões brancos, textos escuros. Mantém o azul e o verde de marca.
  static const AppPalette light = AppPalette(
    bg: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFF2E6FE0),
    textMain: Color(0xFF1A2230),
    textSoft: Color(0xFF5C6776),
    correct: Color(0xFF2E9E6B),
    wrong: Color(0xFFD64A42),
  );

  static AppPalette of(AppThemeMode mode) =>
      mode == AppThemeMode.dark ? dark : light;

  Brightness get brightness =>
      bg.computeLuminance() < 0.5 ? Brightness.dark : Brightness.light;
}
