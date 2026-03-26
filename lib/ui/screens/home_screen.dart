import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/gamification_controller.dart';
import '../../services/gatekeeper_service.dart';
import 'training_dashboard.dart';

/// HOME SCREEN: Dashboard Central de Progressão [ORQUESTRADOR]
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GamificationController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainHeader(controller.acuityLevel),
              const SizedBox(height: 30),
              _buildProgressCard(controller.totalXP),
              const SizedBox(height: 30),
              const Text("EVOLUÇÃO DO ÍNDICE DE ACUIDADE (IAB)", 
                style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 15),
              _buildEvolutionChart(),
              const Spacer(),
              _buildStartButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainHeader(String level) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("BOSYN - REABILITAÇÃO NEURAL", style: TextStyle(color: Colors.white38, letterSpacing: 5, fontSize: 10)),
        const SizedBox(height: 8),
        Text("STATUS: $level", style: const TextStyle(color: Color(0xFF00FF41), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Container(height: 2, width: 120, color: const Color(0xFF00FF41).withOpacity(0.5)),
      ],
    );
  }

  Widget _buildProgressCard(int xp) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.white12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("XP ACUMULADO", style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text(xp.toString().padLeft(6, '0'), style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'monospace')),
            ],
          ),
          const Icon(Icons.show_chart, color: Color(0xFF2563EB), size: 40),
        ],
      ),
    );
  }

  Widget _buildEvolutionChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.white12)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: 6, minY: 0, maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 20), const FlSpot(1, 35), const FlSpot(2, 30),
                const FlSpot(3, 50), const FlSpot(4, 65), const FlSpot(5, 60), const FlSpot(6, 88),
              ],
              isCurved: true,
              color: const Color(0xFF00FF41),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF00FF41).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Column(
      children: [
        _buildLevelCard(context, 2, "CALIBRAÇÃO FONÊMICA", "ACESSO LIBERADO"),
        const SizedBox(height: 12),
        _buildLevelCard(context, 3, "ESCALONAMENTO ESPACIAL", "REQUER PRO", isLocked: true),
        const SizedBox(height: 12),
        _buildLevelCard(context, 4, "AMBIENTE HOSTIL [COQUETEL]", "REQUER PRO", isLocked: true),
      ],
    );
  }

  Widget _buildLevelCard(BuildContext context, int level, String title, String subtitle, {bool isLocked = false}) {
    return InkWell(
      onTap: () async {
        final hasAccess = await GatekeeperService().checkAccess(level);
        if (hasAccess) {
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingDashboard()));
          }
        } else {
          if (context.mounted) _showPaywall(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: isLocked ? Colors.white10 : const Color(0xFF2563EB).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isLocked ? Colors.white38 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                Text(subtitle, style: TextStyle(color: isLocked ? const Color(0xFFE11D48) : const Color(0xFF00FF41), fontSize: 8)),
              ],
            ),
            Icon(isLocked ? Icons.lock_outline : Icons.play_arrow, color: isLocked ? Colors.white10 : const Color(0xFF00FF41), size: 20),
          ],
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const BeveledRectangleBorder(),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("BOSYN PRO REQUERIDO", style: TextStyle(color: Color(0xFF00FF41), fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text(
                "O treinamento avançado de Escalonamento Espacial e Efeito Coquetel exige processamento neural de alta densidade sincronizado com a nuvem.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: const BeveledRectangleBorder()),
                  onPressed: () async {
                    // MOCK STRIPE CHECKOUT
                    debugPrint("Iniciando Stripe Checkout...");
                    await Future.delayed(const Duration(seconds: 2));
                    await GatekeeperService().upgradeToPro();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ACESSO ELITE ATIVADO!")));
                    }
                  },
                  child: const Text("ATIVAR ACESSO ELITE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
