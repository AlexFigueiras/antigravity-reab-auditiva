import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/rehab_session.dart';
import '../../services/supabase_service.dart';
import 'outcome_test_screen.dart';

/// Tela de evolução do usuário — visual rico com cards por módulo,
/// paleta consistente com a Home, sem verde fosforescente.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF101418);
  static const _card = Color(0xFF1B2128);
  static const _primary = Color(0xFF4F8DF7);
  static const _textMain = Color(0xFFF2F4F7);
  static const _textSoft = Color(0xFFB4BCC8);
  static const _correct = Color(0xFF3FB37F);
  static const _warn = Color(0xFFE6A23C);

  final SupabaseService _supabase = SupabaseService();

  bool _loading = true;
  List<Map<String, dynamic>> _accuracyHistory = [];
  List<MapEntry<String, int>> _hardestPairs = [];
  double? _latestSrt;
  int _totalSessions = 0;
  int _streak = 0;
  double _overallAccuracy = 0;
  Map<int, int> _sessionCounts = {};
  Map<int, double> _levelAccuracies = {};
  List<Map<String, dynamic>> _outcomeHistory = [];
  double? _latestOutcomeSrt;
  double? _baselineOutcomeSrt;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final history = await _supabase.getAccuracyHistory();
    final List<RehabSession> sessions = await _supabase.getAllSessions();
    final streak = await _supabase.getTrainingStreak();
    final sessionCounts = await _supabase.getSessionCountsByLevel();
    final outcomeHistory = await _supabase.getOutcomeTestHistory();

    // Agrega erros por par a partir dos logs das sessões.
    final Map<String, int> errorsByPair = {};
    double? latestSrt;
    double totalAcc = 0;
    int accCount = 0;

    for (final s in sessions) {
      totalAcc += s.accuracy;
      accCount++;

      final meta = s.metadata;
      if (meta == null) continue;
      final srt = meta['srt'];
      if (srt is num) latestSrt = srt.toDouble();

      final log = meta['log'];
      if (log is List) {
        for (final entry in log) {
          if (entry is Map &&
              entry['correct'] == false &&
              entry['pair'] != null) {
            final pair = entry['pair'].toString();
            errorsByPair[pair] = (errorsByPair[pair] ?? 0) + 1;
          }
        }
      }
    }

    final sorted = errorsByPair.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Acurácia por nível
    final Map<int, double> levelAccs = {};
    for (final lvl in [2, 3, 4]) {
      final lvlSessions = sessions.where((s) => s.level.value == lvl).toList();
      if (lvlSessions.isNotEmpty) {
        levelAccs[lvl] = lvlSessions.map((s) => s.accuracy).reduce((a, b) => a + b) /
            lvlSessions.length;
      }
    }

    if (mounted) {
      setState(() {
        _accuracyHistory = history;
        _hardestPairs = sorted.take(5).toList();
        _latestSrt = latestSrt;
        _totalSessions = sessions.length;
        _streak = streak;
        _overallAccuracy = accCount > 0 ? totalAcc / accCount : 0;
        _sessionCounts = sessionCounts;
        _levelAccuracies = levelAccs;
        _outcomeHistory = outcomeHistory;
        if (outcomeHistory.isNotEmpty) {
          _latestOutcomeSrt = (outcomeHistory.last['srt_db'] as num).toDouble();
          _baselineOutcomeSrt = (outcomeHistory.first['srt_db'] as num).toDouble();
        } else {
          _latestOutcomeSrt = null;
          _baselineOutcomeSrt = null;
        }
        _loading = false;
      });
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text("Sua evolução",
            style: TextStyle(
                color: _textMain, fontSize: 22, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final hasData = _accuracyHistory.isNotEmpty ||
        _hardestPairs.isNotEmpty ||
        _latestSrt != null ||
        _outcomeHistory.isNotEmpty;

    if (!hasData) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, color: _textSoft, size: 64),
              const SizedBox(height: 20),
              Text(
                "Ainda não há treinos por aqui.\nFaça seu primeiro treino para "
                "acompanhar sua evolução.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: _textSoft, fontSize: 18, height: 1.4),
              ),
              const SizedBox(height: 28),
              _buildOutcomeTestCard(),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Painel de resumo animado
          _buildSummaryPanel(),
          const SizedBox(height: 24),

          // Teste de desfecho independente (Matrix)
          _buildOutcomeTestCard(),
          const SizedBox(height: 24),

          // Cards por módulo
          _buildModuleCards(),
          const SizedBox(height: 24),

          if (_latestSrt != null) ...[
            _buildSrtCard(),
            const SizedBox(height: 24),
          ],

          // Gráfico de acertos
          Text("Acertos ao longo do tempo",
              style: TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildChart(),
          const SizedBox(height: 24),

          // Sons mais difíceis
          Text("Sons mais difíceis para você",
              style: TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Estas foram as palavras que você mais confundiu. Treinar mais "
            "ajuda a ouvir melhor.",
            style: TextStyle(color: _textSoft, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildHardestList(),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // Anel de acurácia geral
            _buildOverallRing(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow(
                      Icons.calendar_today, "$_totalSessions sessões"),
                  const SizedBox(height: 10),
                  if (_streak > 0)
                    _summaryRow(
                        Icons.local_fire_department, "$_streak dias seguidos",
                        color: const Color(0xFFFF6B35)),
                  if (_streak > 0) const SizedBox(height: 10),
                  _summaryRow(Icons.trending_up,
                      "Média: ${_overallAccuracy.toStringAsFixed(0)}%"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallRing() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _overallAccuracy / 100),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  color: _bg,
                  strokeCap: StrokeCap.round,
                ),
              ),
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  color: value >= 0.7 ? _correct : _primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                "${(value * 100).round()}%",
                style: TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? _textSoft, size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
              color: _textMain, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildModuleCards() {
    final modules = [
      (
        2,
        "Distinguir sons",
        Icons.graphic_eq,
      ),
      (
        3,
        "De que lado",
        Icons.surround_sound,
      ),
      (
        4,
        "No barulho",
        Icons.hearing,
      ),
    ];

    return Row(
      children: modules.map((m) {
        final count = _sessionCounts[m.$1] ?? 0;
        final acc = _levelAccuracies[m.$1] ?? 0.0;
        final hasData = count > 0;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
                right: m.$1 < 4 ? 8 : 0, left: m.$1 > 2 ? 8 : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: hasData
                  ? Border.all(
                      color: acc >= 70
                          ? _correct.withValues(alpha: 0.3)
                          : _primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Column(
              children: [
                Icon(m.$3,
                    color: hasData ? _primary : _textSoft, size: 24),
                const SizedBox(height: 8),
                Text(
                  m.$2,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (hasData) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: acc / 100),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Column(
                        children: [
                          Text(
                            "${(value * 100).round()}%",
                            style: TextStyle(
                                color: value >= 0.7 ? _correct : _primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: value,
                            backgroundColor: _bg,
                            color: value >= 0.7 ? _correct : _primary,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$count ${count == 1 ? 'sessão' : 'sessões'}",
                    style: TextStyle(color: _textSoft, fontSize: 11),
                  ),
                ] else
                  Text(
                    "Sem treinos",
                    style: TextStyle(color: _textSoft, fontSize: 12),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSrtCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hearing, color: _primary, size: 20),
              const SizedBox(width: 10),
              Text("Entender no barulho",
                  style: TextStyle(
                      color: _textSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _latestSrt!),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text("${value.toStringAsFixed(0)} dB",
                  style: TextStyle(
                      color: _primary,
                      fontSize: 34,
                      fontWeight: FontWeight.bold));
            },
          ),
          const SizedBox(height: 8),
          Text(
            "Esse é o nível de barulho em que você ainda entende as palavras. "
            "Quanto menor, melhor!",
            style: TextStyle(color: _textSoft, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_accuracyHistory.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text("Sem dados de acertos ainda.",
            style: TextStyle(color: _textSoft, fontSize: 14)),
      );
    }
    final spots = _accuracyHistory.asMap().entries.map((e) {
      final acc = (e.value['accuracy'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), acc);
    }).toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white10,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                        style: TextStyle(
                            color: _textSoft, fontSize: 12)))),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble().clamp(1, double.infinity),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: _primary,
                  strokeWidth: 2,
                  strokeColor: _bg,
                ),
              ),
              belowBarData: BarAreaData(
                  show: true, color: _primary.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardestList() {
    if (_hardestPairs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          "Você ainda não errou palavras suficientes para mostrarmos um padrão. "
          "Continue treinando!",
          style: TextStyle(color: _textSoft, fontSize: 14),
        ),
      );
    }
    final maxErrors =
        _hardestPairs.isNotEmpty ? _hardestPairs.first.value : 1;

    return Column(
      children: _hardestPairs.map((e) {
        final ratio = e.value / maxErrors;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(e.key,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: _textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _warn.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        "${e.value} ${e.value == 1 ? 'erro' : 'erros'}",
                        style: TextStyle(
                            color: _warn,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: _bg,
                    color: _warn,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildDeltaWidget() {
    if (_baselineOutcomeSrt == null || _latestOutcomeSrt == null) {
      return const SizedBox.shrink();
    }
    final double diff = _baselineOutcomeSrt! - _latestOutcomeSrt!;

    if (diff > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_downward, color: _correct, size: 20),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Melhorou ${diff.toStringAsFixed(1)} dB",
                style: const TextStyle(
                  color: _correct,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Text(
                "desde o início",
                style: TextStyle(color: _textSoft, fontSize: 11),
              ),
            ],
          ),
        ],
      );
    } else if (diff == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "Sem alteração",
            style: TextStyle(
              color: _textSoft,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Text(
            "desde o início",
            style: TextStyle(color: _textSoft, fontSize: 11),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward, color: _warn, size: 20),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "+${(-diff).toStringAsFixed(1)} dB",
                style: const TextStyle(
                  color: _warn,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Text(
                "desde o início",
                style: TextStyle(color: _textSoft, fontSize: 11),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildOutcomeChart() {
    if (_outcomeHistory.length < 2) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          "Realize mais testes para ver a evolução.",
          style: TextStyle(color: _textSoft, fontSize: 13),
        ),
      );
    }

    final spots = _outcomeHistory.asMap().entries.map((e) {
      final srt = (e.value['srt_db'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), srt);
    }).toList();

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2.0;
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2.0;

    if (minY > -2) minY = -2;
    if (maxY < 10) maxY = 10;

    return Container(
      height: 150,
      padding: const EdgeInsets.only(top: 10, right: 10, bottom: 5),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white10,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  '${v.toStringAsFixed(0)} dB',
                  style: TextStyle(color: _textSoft, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble().clamp(1, double.infinity),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: _primary,
                  strokeWidth: 2,
                  strokeColor: _bg,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeTestCard() {
    final hasHistory = _outcomeHistory.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assessment, color: _primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    "Teste de Fala no Ruído",
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (hasHistory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Matrix",
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasHistory) ...[
            const Text(
              "Avalie sua capacidade de compreender falas no barulho de forma independente dos treinos (Matrix).",
              style: TextStyle(color: _textSoft, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OutcomeTestScreen(),
                    ),
                  );
                  _load(); // recarrega os dados ao voltar
                },
                child: const Text("Fazer Teste de Desfecho",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Limiar de Fala (SRT)",
                      style: TextStyle(color: _textSoft, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_latestOutcomeSrt!.toStringAsFixed(1)} dB SNR",
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                _buildDeltaWidget(),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Evolução do Limiar (Menos dB = Melhor)",
              style: TextStyle(
                color: _textMain,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildOutcomeChart(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OutcomeTestScreen(),
                    ),
                  );
                  _load();
                },
                child: const Text(
                  "Refazer Teste de Desfecho",
                  style: TextStyle(
                    color: _primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
