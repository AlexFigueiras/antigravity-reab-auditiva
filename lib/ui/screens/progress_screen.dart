import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/rehab_session.dart';
import '../../services/supabase_service.dart';

/// Tela de evolução do usuário [PROGRESSO]
/// Mostra histórico de acertos, sons mais difíceis e o último SRT.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final SupabaseService _supabase = SupabaseService();

  bool _loading = true;
  List<Map<String, dynamic>> _accuracyHistory = [];
  List<MapEntry<String, int>> _hardestPairs = [];
  double? _latestSrt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await _supabase.getAccuracyHistory();
    final sessions = await _supabase.getAllSessions();

    // Agrega erros por par a partir dos logs das sessões.
    final Map<String, int> errorsByPair = {};
    double? latestSrt;
    for (final s in sessions) {
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

    if (mounted) {
      setState(() {
        _accuracyHistory = history;
        _hardestPairs = sorted.take(5).toList();
        _latestSrt = latestSrt;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Sua evolução",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF41)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final hasData = _accuracyHistory.isNotEmpty ||
        _hardestPairs.isNotEmpty ||
        _latestSrt != null;

    if (!hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            "Ainda não há treinos por aqui.\nFaça seu primeiro treino para "
            "acompanhar sua evolução.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 18, height: 1.4),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_latestSrt != null) ...[
            _buildSrtCard(),
            const SizedBox(height: 28),
          ],
          const Text("Seus acertos ao longo do tempo",
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildChart(),
          const SizedBox(height: 28),
          const Text("Sons mais difíceis para você",
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Estas foram as palavras que você mais confundiu. Treinar mais "
            "ajuda a ouvir melhor.",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildHardestList(),
        ],
      ),
    );
  }

  Widget _buildSrtCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF2563EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Entender no barulho",
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 8),
          Text("${_latestSrt!.toStringAsFixed(0)} dB",
              style: const TextStyle(
                  color: Color(0xFF00FF41),
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Esse é o nível de barulho em que você ainda entende as palavras. "
            "Quanto menor, melhor!",
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text("Sem dados de acertos ainda.",
            style: TextStyle(color: Colors.white38, fontSize: 14)),
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
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: Colors.white12),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(
              show: true, drawVerticalLine: false, horizontalInterval: 20),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)))),
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
              color: const Color(0xFF2563EB),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                  show: true, color: const Color(0xFF2563EB).withOpacity(0.1)),
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
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          "Você ainda não errou palavras suficientes para mostrarmos um padrão. "
          "Continue treinando!",
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }
    return Column(
      children: _hardestPairs.map((e) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(
                  "${e.value} ${e.value == 1 ? 'erro' : 'erros'}",
                  style: const TextStyle(
                      color: Color(0xFFE11D48), fontSize: 16)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
