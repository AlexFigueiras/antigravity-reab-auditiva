/// Política de condição de escuta do usuário durante teste e treino.
///
/// Regra clínica (ver SYSTEM.md §11 e o plano 0.4): o aparelho auditivo já
/// amplifica os agudos. Se o app TAMBÉM amplificar (EQ de meia-perda), os ganhos
/// empilham e estouram a fala. Por isso:
///
///   - [unaided]  "sem aparelho": o app é o amplificador → EQ por audiograma LIGADO.
///   - [aided]    "com aparelho": quem compensa é o aparelho → EQ do app DESLIGADO;
///                o app treina apenas a discriminação (plasticidade do cérebro).
///
/// O teste de tom puro é SEMPRE feito sem aparelho (a compressão do aparelho
/// invalida a leitura do limiar). A condição do treino deve bater com a do teste.
enum ListeningMode { unaided, aided }

extension ListeningModeX on ListeningMode {
  bool get isAided => this == ListeningMode.aided;

  /// Rótulo curto para chips/lembretes (ex.: na home).
  String get shortLabel => isAided ? 'Com aparelho' : 'Sem aparelho';

  /// Instrução clara, em frase curta, para o INÍCIO do teste e de cada treino.
  /// Pensada para o público idoso (letra grande / alto contraste na UI).
  String get instruction => isAided
      ? 'Mantenha seu aparelho auditivo ligado, na regulagem de sempre.'
      : 'Tire o aparelho auditivo e coloque os fones.';

  /// O "porquê" em linguagem humana (sem jargão).
  String get why => isAided
      ? 'Assim o treino combina com o seu dia a dia, em que você usa o aparelho.'
      : 'Assim o app ajusta o som no jeito certo para os seus ouvidos.';

  /// Texto da confirmação ativa antes de começar.
  String get confirmLabel =>
      isAided ? 'Estou com o aparelho' : 'Estou sem o aparelho';
}
