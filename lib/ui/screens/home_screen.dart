import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/gamification_controller.dart';
import '../../models/audiogram.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import '../../screens/widgets/technical_dashboard.dart';
import '../../screens/threshold_test_screen.dart';
import 'training_dashboard.dart';
import 'calibration_screen.dart';
import 'progress_screen.dart';
import 'sentence_training_screen.dart';
import 'widgets/self_perception_prompt.dart';

/// HOME SCREEN: Dashboard Central de Progressão [ORQUESTRADOR]
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasPermissions = false;
  bool _isPermanentlyDenied = false;
  List<Map<String, dynamic>> _accuracyHistory = [];
  bool _hasAudiogram = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadAccuracyHistory();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskSelfPerception());
  }

  Future<void> _maybeAskSelfPerception() async {
    try {
      final last = await SupabaseService().getLastSelfPerceptionDate();
      final due = last == null ||
          DateTime.now().difference(last) > const Duration(days: 7);
      if (!due || !mounted) return;
      await SelfPerceptionPrompt.show(
        context,
        onSubmit: (score) async {
          try {
            await SupabaseService().saveSelfPerception(score);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Obrigado por compartilhar!")),
              );
            }
          } catch (e) {
            debugPrint("Erro ao salvar autopercepção: $e");
          }
        },
      );
    } catch (e) {
      debugPrint("Erro na autopercepção: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions(); // Re-checa se o usuário voltou das configurações
    }
  }

  Future<void> _loadAccuracyHistory() async {
    final history = await SupabaseService().getAccuracyHistory();
    final audiogram = await SupabaseService().getLatestAudiogram();
    if (mounted) setState(() {
      _accuracyHistory = history;
      _hasAudiogram = audiogram != null;
    });
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    final bluetooth = await Permission.bluetoothConnect.status;

    setState(() {
      _hasPermissions = mic.isGranted && bluetooth.isGranted;
      _isPermanentlyDenied = mic.isPermanentlyDenied || bluetooth.isPermanentlyDenied;
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.bluetoothConnect,
    ].request();

    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermissions) return _buildPermissionGuard();

    final controller = context.watch<GamificationController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TechnicalDashboard(),
                  );
                },
                child: _buildMainHeader(controller.acuityLevel),
              ),
              const SizedBox(height: 30),
              _buildProgressCard(controller.totalXP),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Sua evolução",
                      style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          letterSpacing: 2)),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ProgressScreen()),
                    ),
                    child: const Text("Ver detalhes",
                        style: TextStyle(
                            color: Color(0xFF2563EB), fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProgressScreen()),
                ),
                child: _buildEvolutionChart(),
              ),
              const Spacer(),
              _buildStartButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionGuard() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, color: Color(0xFFE11D48), size: 64),
              const SizedBox(height: 24),
              const Text("Precisamos de permissões", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 16),
              Text(
                "A reabilitação neural exige acesso ao Microfone (para calibração) e ao Bluetooth (detecção de fones).",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: _isPermanentlyDenied ? openAppSettings : _requestPermissions,
                  child: Text(_isPermanentlyDenied ? "ABRIR CONFIGURAÇÕES" : "AUTORIZAR ACESSO"),
                ),
              ),
              if (_isPermanentlyDenied)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text("O acesso foi negado permanentemente. Por favor, habilite manualmente.", 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainHeader(String level) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("TREINO AUDITIVO", style: TextStyle(color: Colors.white38, letterSpacing: 5, fontSize: 10)),
            const SizedBox(height: 8),
            Text(level, style: const TextStyle(color: Color(0xFF00FF41), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            Container(height: 2, width: 120, color: const Color(0xFF00FF41).withOpacity(0.5)),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationScreen())),
          icon: const Icon(Icons.tune, color: Colors.white24),
          tooltip: "Calibrar Latência",
        ),
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
              const Text("Pontos de treino", style: TextStyle(color: Colors.white38, fontSize: 8)),
              Text(xp.toString().padLeft(6, '0'), style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'monospace')),
            ],
          ),
          const Icon(Icons.show_chart, color: Color(0xFF2563EB), size: 40),
        ],
      ),
    );
  }

  Widget _buildEvolutionChart() {
    if (_accuracyHistory.isEmpty) {
      return Container(
        height: 120,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.white12)),
        child: const Center(
          child: Text(
            "Faça seu primeiro treino para ver sua evolução aqui.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }
    final spots = _accuracyHistory.asMap().entries.map((e) {
      final acc = (e.value['accuracy'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), acc);
    }).toList();
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.white12)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 9)))),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: (spots.length - 1).toDouble().clamp(1, double.infinity), minY: 0, maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF2563EB),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Column(
      children: [
        _buildAudiogramCard(context),
        const SizedBox(height: 12),
        _buildLevelCard(context, 2, "Distinguir sons", "Disponível"),
        const SizedBox(height: 12),
        _buildLevelCard(context, 3, "De que lado vem o som", "Requer assinatura", isLocked: true),
        const SizedBox(height: 12),
        _buildLevelCard(context, 4, "Entender no barulho", "Requer assinatura", isLocked: true),
        const SizedBox(height: 12),
        _buildSentenceCard(context),
      ],
    );
  }

  Widget _buildAudiogramCard(BuildContext context) {
    final isDone = _hasAudiogram;
    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const ThresholdTestScreen()),
        );
        if (result == null || !context.mounted) return;
        final leftEar = (result['left'] as List<AudiometryPoint>?) ?? [];
        final rightEar = (result['right'] as List<AudiometryPoint>?) ?? [];
        if (leftEar.isEmpty && rightEar.isEmpty) return;
        try {
          final user = await SupabaseService().getLatestAudiogram();
          final audiogram = Audiogram(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            patientId: user?.patientId ?? 'local',
            date: DateTime.now(),
            leftEar: leftEar,
            rightEar: rightEar,
          );
          await SupabaseService().saveAudiogram(audiogram);
          if (context.mounted) {
            setState(() => _hasAudiogram = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Teste salvo! O treino agora é personalizado para você.")),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Erro ao salvar o teste. Tente novamente.")),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFF111111) : const Color(0xFF0D2137),
          border: Border.all(
            color: isDone ? Colors.white12 : const Color(0xFF2563EB),
            width: isDone ? 1 : 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Teste de audição",
                  style: TextStyle(
                    color: isDone ? Colors.white54 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isDone ? "Feito — refazer a qualquer hora" : "Faça primeiro — personaliza todo o treino",
                  style: TextStyle(
                    color: isDone ? Colors.white24 : const Color(0xFF2563EB),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            Icon(
              isDone ? Icons.check_circle_outline : Icons.hearing,
              color: isDone ? Colors.white24 : const Color(0xFF2563EB),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        final hasAccess = await GatekeeperService().checkAccess(4);
        if (!context.mounted) return;
        if (!hasAccess) {
          _showPaywall(context);
          return;
        }
        final audiogram = await SupabaseService().getLatestAudiogram();
        if (!context.mounted) return;
        if (audiogram == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Faça primeiro o teste de audição para liberar este treino.")),
          );
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SentenceTrainingScreen(audiogram: audiogram)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Frases do dia a dia",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                Text("Requer assinatura",
                    style: TextStyle(color: Color(0xFFE11D48), fontSize: 8)),
              ],
            ),
            const Icon(Icons.lock_outline, color: Colors.white10, size: 20),
          ],
        ),
      ),
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
              const Text("BOSYN Pro", style: TextStyle(color: Color(0xFF00FF41), fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text(
                "Os módulos de direção do som e entender no barulho estão disponíveis com a assinatura.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: const BeveledRectangleBorder()),
                  onPressed: () async {
                    // TODO(pagamento): integrar o fluxo real do flutter_stripe.
                    // O cliente NÃO promove a assinatura — quem grava 'pro' é o
                    // webhook do Stripe no backend (service_role). Aqui apenas:
                    //   1) abrir o PaymentSheet do Stripe;
                    //   2) após confirmação, chamar refreshSubscriptionStatus().
                    // Enquanto a integração não existe, NÃO concedemos acesso.
                    debugPrint("Checkout Stripe ainda não integrado.");
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Pagamento indisponível: integração Stripe pendente.")),
                      );
                    }
                  },
                  child: const Text("Assinar BOSYN Pro", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
