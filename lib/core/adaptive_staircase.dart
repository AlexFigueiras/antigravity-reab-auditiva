import 'dart:math' as math;

/// Staircase psicofísico 2-down/1-up reutilizável.
///
/// Converge para ~70,7% de acerto (ponto psicométrico padrão).
///
/// Regras:
///   - 2 acertos consecutivos → passo para baixo (mais difícil)
///   - 1 erro → passo para cima (mais fácil)
///   - Cada mudança de direção (descida→subida ou subida→descida) = reversão
///   - SRT estimado = média das últimas [minReversalsForEstimate] reversões
///
/// O "dificuldade" é um valor double genérico (ex.: SNR em dB, onde menor = mais
/// difícil). O chamador define os limites [floor]/[ceiling] e o tamanho do passo
/// [stepDown]/[stepUp].
class AdaptiveStaircase {
  final double floor;
  final double ceiling;
  final double stepDown;
  final double stepUp;
  final int minReversalsForEstimate;

  double _current;
  int _consecutiveCorrect = 0;
  bool? _lastWasDown; // null = sem histórico de direção ainda
  final List<double> _reversals = [];

  AdaptiveStaircase({
    required double start,
    required this.floor,
    required this.ceiling,
    this.stepDown = 2.0,
    this.stepUp = 2.0,
    this.minReversalsForEstimate = 6,
  }) : _current = start.clamp(floor, ceiling);

  double get current => _current;
  int get reversalCount => _reversals.length;
  bool get hasEstimate => _reversals.length >= minReversalsForEstimate;

  /// Valor médio das últimas [minReversalsForEstimate] reversões.
  /// Retorna null se ainda não há reversões suficientes.
  double? get estimate {
    if (!hasEstimate) return null;
    final last = _reversals.sublist(
        _reversals.length - minReversalsForEstimate);
    return last.reduce((a, b) => a + b) / last.length;
  }

  /// Registra uma resposta e atualiza o nível de dificuldade.
  ///
  /// Retorna o novo valor de [current].
  double respond(bool correct) {
    if (correct) {
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= 2) {
        _consecutiveCorrect = 0;
        _step(down: true);
      }
    } else {
      _consecutiveCorrect = 0;
      _step(down: false);
    }
    return _current;
  }

  void _step({required bool down}) {
    final wasDown = _lastWasDown;
    final isReversal = wasDown != null && wasDown != down;
    if (isReversal) _reversals.add(_current);

    _lastWasDown = down;
    if (down) {
      _current = math.max(floor, _current - stepDown);
    } else {
      _current = math.min(ceiling, _current + stepUp);
    }
  }

  /// Reseta o staircase mantendo os parâmetros (para nova sessão).
  void reset({double? startAt}) {
    _current = (startAt ?? ceiling).clamp(floor, ceiling);
    _consecutiveCorrect = 0;
    _lastWasDown = null;
    _reversals.clear();
  }
}
