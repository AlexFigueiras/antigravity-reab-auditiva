import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Tela de resultado pós-treino — celebratória e baseada em métricas reais.
///
/// Mostra: acurácia da sessão (anel animado), sons treinados, mensagem
/// adaptativa, e progresso ao desbloqueio do próximo módulo.
/// SEM: XP, pontos, "nível de acuidade", badges — nada de teatro (PRODUTO.md §3).
class MissionReportScreen extends StatefulWidget {
  final int totalTrials;
  final int correctAnswers;
  final int level;
  final List<Map<String, dynamic>> sessionLog;

  const MissionReportScreen({
    super.key,
    required this.totalTrials,
    required this.correctAnswers,
    required this.level,
    required this.sessionLog,
  });

  @override
  State<MissionReportScreen> createState() => _MissionReportScreenState();
}

class _MissionReportScreenState extends State<MissionReportScreen>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF101418);
  static const _card = Color(0xFF1B2128);
  static const _primary = Color(0xFF4F8DF7);
  static const _textMain = Color(0xFFF2F4F7);
  static const _textSoft = Color(0xFFB4BCC8);
  static const _correct = Color(0xFF3FB37F);
  static const _warn = Color(0xFFE6A23C);

  late AnimationController _ringController;
  late AnimationController _fadeController;
  late Animation<double> _ringAnimation;
  late Animation<double> _fadeAnimation;

  double get _accuracy =>
      widget.totalTrials > 0 ? widget.correctAnswers / widget.totalTrials : 0;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _ringAnimation = Tween<double>(begin: 0, end: _accuracy).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Stagger: ring first, then content fades in
    _ringController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String get _levelName {
    switch (widget.level) {
      case 3:
        return "De que lado vem o som";
      case 4:
        return "Entender no barulho";
      default:
        return "Distinguir sons";
    }
  }

  String get _adaptiveMessage {
    final pct = (_accuracy * 100).round();
    if (pct >= 90) return "Excelente! Seus ouvidos estão cada vez mais afiados.";
    if (pct >= 70) return "Muito bem! Continue assim e o progresso vai aparecer.";
    if (pct >= 50) return "Bom treino! A prática faz a diferença — volte amanhã.";
    return "Todo treino conta. O importante é a constância.";
  }

  Color get _ringColor {
    final pct = (_accuracy * 100).round();
    if (pct >= 70) return _correct;
    if (pct >= 50) return _warn;
    return _primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            children: [
              // Header
              Text(
                "Treino concluído!",
                style: TextStyle(
                    color: _textMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _levelName,
                style: TextStyle(color: _textSoft, fontSize: 16),
              ),

              const SizedBox(height: 36),

              // Anel de progresso animado
              _buildAnimatedRing(),

              const SizedBox(height: 28),

              // Mensagem adaptativa
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _ringColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _accuracy >= 0.7
                            ? Icons.emoji_events_rounded
                            : Icons.favorite_rounded,
                        color: _ringColor,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _adaptiveMessage,
                          style: TextStyle(
                              color: _textMain,
                              fontSize: 16,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Métricas detalhadas
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildMetricsGrid(),
              ),

              const SizedBox(height: 24),

              // Sons mais errados nesta sessão
              if (_getMostMissedPairs().isNotEmpty)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildMostMissed(),
                ),

              const SizedBox(height: 36),

              // Botão de voltar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  child: const Text(
                    "Voltar ao início",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedRing() {
    return AnimatedBuilder(
      animation: _ringAnimation,
      builder: (context, child) {
        final pct = (_ringAnimation.value * 100).round();
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  color: _card,
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Progress ring
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: _ringAnimation.value,
                  strokeWidth: 12,
                  color: _ringColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$pct%",
                    style: TextStyle(
                        color: _textMain,
                        fontSize: 44,
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    "acertos",
                    style: TextStyle(color: _textSoft, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid() {
    final avgRt = widget.sessionLog.isNotEmpty
        ? (widget.sessionLog
                    .map((e) => (e['rt_ms'] as int?) ?? 0)
                    .reduce((a, b) => a + b) /
                widget.sessionLog.length /
                1000)
            .toStringAsFixed(1)
        : '--';

    return Row(
      children: [
        _metricCard(
          icon: Icons.check_circle_outline,
          value: "${widget.correctAnswers}/${widget.totalTrials}",
          label: "Acertos",
          color: _correct,
        ),
        const SizedBox(width: 12),
        _metricCard(
          icon: Icons.timer_outlined,
          value: "${avgRt}s",
          label: "Tempo médio",
          color: _primary,
        ),
        const SizedBox(width: 12),
        _metricCard(
          icon: Icons.repeat_rounded,
          value: "${widget.totalTrials}",
          label: "Rodadas",
          color: _warn,
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                  color: _textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: _textSoft, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _getMostMissedPairs() {
    final Map<String, int> errorsByPair = {};
    for (final entry in widget.sessionLog) {
      if (entry['correct'] == false) {
        final pair = (entry['pair'] as String?) ?? (entry['direction'] as String?) ?? '?';
        errorsByPair[pair] = (errorsByPair[pair] ?? 0) + 1;
      }
    }
    final sorted = errorsByPair.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  Widget _buildMostMissed() {
    final missed = _getMostMissedPairs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sons para praticar mais",
          style: TextStyle(
              color: _textMain, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          "Estes foram os que mais confundiram nesta sessão.",
          style: TextStyle(color: _textSoft, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ...missed.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                        color: _textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _warn.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${e.value} ${e.value == 1 ? 'erro' : 'erros'}",
                      style: TextStyle(
                          color: _warn,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
