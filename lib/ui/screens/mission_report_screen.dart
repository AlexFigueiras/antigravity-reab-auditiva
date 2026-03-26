import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/gamification_controller.dart';
import '../../services/pdf_service.dart';

/// MISSION REPORT: Dashboard de Encerramento Clínico [SSOT]
class MissionReportScreen extends StatelessWidget {
  final int sessionXP;
  final double noiseThreshold;

  const MissionReportScreen({
    super.key,
    required this.sessionXP,
    required this.noiseThreshold,
  });

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
              _buildHeader(),
              const SizedBox(height: 40),
              _buildMetricCard(
                "REPORTAGEM DE CAMPO",
                "MISSÃO CONCLUÍDA",
                const Color(0xFF00FF41),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildDataRow("XP DA SESSÃO", "+$sessionXP", Colors.white70),
                    _buildDataRow("LIMIAR DE RUÍDO (SNR)", "$noiseThreshold dB", const Color(0xFFFFBF00)),
                    _buildDataRow("NÍVEL DE ACUIDADE (IAB)", controller.acuityLevel, const Color(0xFF2563EB)),
                    _buildDataRow("XP TOTAL ACUMULADO", "${controller.totalXP}", Colors.white38),
                  ],
                ),
              ),
              _buildActionPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ANÁLISE DE PERFORMANCE", style: TextStyle(color: Colors.white24, letterSpacing: 4, fontSize: 10)),
        const SizedBox(height: 8),
        Container(height: 2, width: 60, color: const Color(0xFF00FF41)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 12, fontFamily: 'monospace')),
          Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    final controller = context.read<GamificationController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () => PdfService.exportClinicalReport(
              acuityLevel: controller.acuityLevel,
              totalXP: controller.totalXP,
              noiseThreshold: noiseThreshold,
              sessionXP: sessionXP,
            ),
            child: const Text("EXPORTAR PDF CLÍNICO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00FF41),
              side: const BorderSide(color: Color(0xFF00FF41)),
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text("RETORNAR AO DASHBOARD CENTRAL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
