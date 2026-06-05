import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/audiogram.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import '../../screens/threshold_test_screen.dart';
import 'training_dashboard.dart';
import 'progress_screen.dart';
import 'sentence_hub_screen.dart';
import 'widgets/self_perception_prompt.dart';

/// Tela inicial: acolhedora, clara e simples. Pensada para 55–75 anos —
/// linguagem humana, fontes grandes, cores calmas (ver PRODUTO.md §5 e §7).
///
/// Cada card de treino navega diretamente para a tela do seu módulo.
/// Desbloqueio é por desempenho (≥70% no anterior), não por assinatura.
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
  int _unlockedLevel = 2;
  int _streak = 0;
  Map<int, double> _levelAccuracies = {};
  double _todayMinutes = 0.0;

  // Paleta acolhedora — nada de verde fosfórico de "cockpit".
  static const Color _bg = Color(0xFF101418);
  static const Color _card = Color(0xFF1B2128);
  static const Color _primary = Color(0xFF4F8DF7);
  static const Color _textMain = Color(0xFFF2F4F7);
  static const Color _textSoft = Color(0xFFB4BCC8);

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadAllData();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAskSelfPerception());
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
      _checkPermissions();
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    final history = await SupabaseService().getAccuracyHistory();
    final audiogram = await SupabaseService().getLatestAudiogram();
    final streak = await SupabaseService().getTrainingStreak();
    final sessions = await SupabaseService().getAllSessions();

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todaySessions = sessions.where((s) => s.date.isAfter(todayStart)).toList();
    double totalMs = 0;
    for (final s in todaySessions) {
      final meta = s.metadata;
      if (meta != null && meta['duration_ms'] != null) {
        totalMs += (meta['duration_ms'] as num).toDouble();
      } else {
        totalMs += 180000; // 3 minutos de fallback
      }
    }
    final todayMinutes = totalMs / 60000;

    // Calcular nível desbloqueado e acurácias por nível
    GatekeeperService().invalidateCache();
    final unlockedLevel = await GatekeeperService().getUnlockedLevel();
    final Map<int, double> levelAccs = {};
    for (final lvl in [2, 3, 4]) {
      levelAccs[lvl] = await GatekeeperService().getAverageAccuracy(lvl);
    }

    if (mounted) {
      setState(() {
        _accuracyHistory = history;
        _hasAudiogram = audiogram != null;
        _unlockedLevel = unlockedLevel;
        _streak = streak;
        _levelAccuracies = levelAccs;
        _todayMinutes = todayMinutes;
      });
    }
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    final bluetooth = await Permission.bluetoothConnect.status;

    setState(() {
      _hasPermissions = mic.isGranted && bluetooth.isGranted;
      _isPermanentlyDenied =
          mic.isPermanentlyDenied || bluetooth.isPermanentlyDenied;
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

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildProgressSummary(),
              const SizedBox(height: 16),
              _buildDailyDoseWidget(),
              const SizedBox(height: 28),
              Text("Seus treinos",
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  "Comece pelo teste de audição — ele deixa tudo no seu ritmo.",
                  style:
                      TextStyle(color: _textSoft, fontSize: 15, height: 1.4)),
              const SizedBox(height: 16),
              _buildAudiogramCard(context),
              const SizedBox(height: 12),
              _buildLevelCard(
                context,
                level: 2,
                title: "Distinguir sons parecidos",
                subtitle:
                    'Treine sons que se confundem, como "fala" e "sala".',
                icon: Icons.graphic_eq,
              ),
              const SizedBox(height: 12),
              _buildLevelCard(
                context,
                level: 3,
                title: "De que lado vem o som",
                subtitle:
                    "Perceba a direção do som — esquerda, centro, direita.",
                icon: Icons.surround_sound,
              ),
              const SizedBox(height: 12),
              _buildLevelCard(
                context,
                level: 4,
                title: "Entender no meio do barulho",
                subtitle: "Acompanhe a fala mesmo com som de fundo.",
                icon: Icons.hearing,
              ),
              const SizedBox(height: 12),
              _buildSentenceCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionGuard() {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.volume_up_rounded, color: _primary, size: 72),
              const SizedBox(height: 28),
              Text("Vamos preparar o som",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(
                "Para tocar os sons do treino e reconhecer seus fones, "
                "o app precisa da sua permissão para o microfone e o Bluetooth.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: _textSoft, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 36),
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
                  onPressed: _isPermanentlyDenied
                      ? openAppSettings
                      : _requestPermissions,
                  child: Text(
                      _isPermanentlyDenied
                          ? "Abrir configurações"
                          : "Permitir",
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              if (_isPermanentlyDenied)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    "A permissão foi recusada. Toque acima para abrir as "
                    "configurações e habilitar manualmente.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _textSoft, fontSize: 14, height: 1.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Olá!",
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text("Que bom ter você aqui. Vamos treinar um pouco hoje?",
                  style:
                      TextStyle(color: _textSoft, fontSize: 16, height: 1.4)),
            ],
          ),
        ),
        if (_streak > 0) ...[
          const SizedBox(width: 12),
          _buildStreakBadge(),
        ],
      ],
    );
  }

  Widget _buildStreakBadge() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🔥",
                style: TextStyle(fontSize: 22)),
            Text(
              "$_streak",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const Text(
              "dias",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDoseWidget() {
    final progress = (_todayMinutes / 15.0).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final completed = _todayMinutes >= 15.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed ? const Color(0xFF3FB37F).withValues(alpha: 0.3) : _primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Progresso circular com animação
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutBack,
                    builder: (context, val, _) {
                      return CircularProgressIndicator(
                        value: val,
                        strokeWidth: 6,
                        color: completed ? const Color(0xFF3FB37F) : _primary,
                        backgroundColor: _bg,
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                ),
                Text(
                  "$percent%",
                  style: TextStyle(
                    color: completed ? const Color(0xFF3FB37F) : _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Meta diária (15 min)",
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed
                      ? "Meta batida! Excelente treino hoje."
                      : "${_todayMinutes.toStringAsFixed(1)} min treinados de 15 min.",
                  style: TextStyle(
                    color: completed ? const Color(0xFF3FB37F) : _textSoft,
                    fontSize: 14,
                    fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Resumo honesto de progresso: acerto recente real (não XP, não "índice").
  Widget _buildProgressSummary() {
    final hasData = _accuracyHistory.isNotEmpty;
    final lastAcc = hasData
        ? ((_accuracyHistory.last['accuracy'] as num?)?.toDouble() ?? 0.0)
        : 0.0;

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProgressScreen()),
        );
        // Reload data when returning from progress screen
        _loadAllData();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Sua evolução",
                      style: TextStyle(
                          color: _textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    hasData
                        ? "Últimos acertos: ${lastAcc.toStringAsFixed(0)}%. Toque para ver mais."
                        : "Faça seu primeiro treino para acompanhar aqui.",
                    style: TextStyle(
                        color: _textSoft, fontSize: 15, height: 1.4),
                  ),
                  if (hasData) ...[
                    const SizedBox(height: 16),
                    SizedBox(height: 70, child: _buildMiniChart()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: _textSoft, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChart() {
    final spots = _accuracyHistory.asMap().entries.map((e) {
      final acc = (e.value['accuracy'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), acc);
    }).toList();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
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
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: _primary.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAudiogramCard(BuildContext context) {
    final isDone = _hasAudiogram;
    return _Card(
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
              const SnackBar(
                  content: Text(
                      "Teste salvo! O treino agora é personalizado para você.")),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Erro ao salvar o teste. Tente novamente.")),
            );
          }
        }
      },
      icon: isDone ? Icons.check_circle : Icons.hearing,
      iconColor: isDone ? const Color(0xFF4CAF7D) : _primary,
      highlight: !isDone,
      title: "Teste de audição",
      subtitle: isDone
          ? "Concluído. Você pode refazer quando quiser."
          : "Comece por aqui — ele personaliza todo o seu treino.",
    );
  }

  Widget _buildSentenceCard(BuildContext context) {
    return _Card(
      onTap: () async {
        final hasAccess = await GatekeeperService().checkAccess(5);
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
                content: Text(
                    "Faça primeiro o teste de audição para liberar este treino.")),
          );
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SentenceHubScreen(audiogram: audiogram)));
      },
      icon: Icons.chat_bubble_outline,
      iconColor: _primary,
      title: "Frases do dia a dia",
      subtitle:
          "Ajude o Seu João a entender frases inteiras no barulho.",
    );
  }

  Widget _buildLevelCard(
    BuildContext context, {
    required int level,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isLocked = level > _unlockedLevel;
    final accuracy = _levelAccuracies[level] ?? 0.0;
    final hasProgress = accuracy > 0;

    // Texto de desbloqueio para cards bloqueados
    String lockSubtitle;
    if (isLocked) {
      final prevLevel = (level == 3 || level == 4) ? 2 : (level - 1);
      final prevAcc = _levelAccuracies[prevLevel] ?? 0.0;
      if (prevAcc > 0) {
        lockSubtitle =
            "Acerte 70% no \"Distinguir sons\" para liberar. Você está com ${prevAcc.toStringAsFixed(0)}%.";
      } else {
        lockSubtitle =
            "Acerte 70% no \"Distinguir sons\" para liberar este treino.";
      }
    } else {
      lockSubtitle = subtitle;
    }

    return _Card(
      onTap: () async {
        if (isLocked) {
          _showLockedExplanation(context, level);
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => TrainingDashboard(level: level)),
        );
        // Recarrega dados ao voltar (novo desbloqueio possível)
        _loadAllData();
      },
      icon: icon,
      iconColor: isLocked ? _textSoft : _primary,
      locked: isLocked,
      title: title,
      subtitle: lockSubtitle,
      progress: hasProgress && !isLocked ? accuracy / 100 : null,
      isNewlyUnlocked: _isNewlyUnlocked(level),
    );
  }

  bool _isNewlyUnlocked(int level) {
    // Nível recém-desbloqueado: está desbloqueado mas sem sessões
    if (level > 2 && level <= _unlockedLevel) {
      final acc = _levelAccuracies[level] ?? 0.0;
      return acc == 0;
    }
    return false;
  }

  void _showLockedExplanation(BuildContext context, int level) {
    final prevLevel = (level == 3 || level == 4) ? 2 : (level - 1);
    final prevAcc = _levelAccuracies[prevLevel] ?? 0.0;
    final prevName = prevLevel == 2
        ? "Distinguir sons"
        : prevLevel == 3
            ? "De que lado vem o som"
            : "Entender no barulho";

    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                    color: _textSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text("Como desbloquear",
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(
                "Esse treino é liberado quando você atingir 70% de acertos "
                "no \"$prevName\" (média das últimas 3 sessões).",
                style:
                    TextStyle(color: _textSoft, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (prevAcc > 0) ...[
                _ProgressBar(
                    value: prevAcc / 100, target: 0.7, label: prevName),
                const SizedBox(height: 12),
                Text(
                  prevAcc >= 60
                      ? "Quase lá! Você está com ${prevAcc.toStringAsFixed(0)}%."
                      : "Você está com ${prevAcc.toStringAsFixed(0)}%. Continue treinando!",
                  style: TextStyle(
                      color: _primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ] else
                Text(
                  "Faça pelo menos 3 sessões de \"$prevName\" para começar a medir seu progresso.",
                  style: TextStyle(
                      color: _textSoft, fontSize: 15, height: 1.4),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              TrainingDashboard(level: prevLevel)),
                    );
                  },
                  child: Text("Treinar \"$prevName\"",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                    color: _textSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text("Treino completo",
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                "O treino de frases do dia a dia faz parte da assinatura. "
                "Assim você treina de ponta a ponta, no seu ritmo.",
                style:
                    TextStyle(color: _textSoft, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 28),
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
                  onPressed: () async {
                    // TODO(pagamento): integrar o fluxo real do flutter_stripe.
                    debugPrint("Checkout Stripe ainda não integrado.");
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Pagamento indisponível: integração Stripe pendente.")),
                      );
                    }
                  },
                  child: const Text("Assinar",
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barra de progresso animada para o bottom sheet de desbloqueio.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.target,
    required this.label,
  });

  final double value;
  final double target;
  final String label;

  static const _primary = Color(0xFF4F8DF7);
  static const _correct = Color(0xFF3FB37F);
  static const _card = Color(0xFF1B2128);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Background
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            // Progress
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: value >= target
                        ? [_correct, _correct]
                        : [_primary, _primary.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            // Target marker
            Positioned(
              left:
                  (target * (MediaQuery.of(context).size.width - 56 - 28 * 2))
                      .clamp(0, double.infinity),
              child: Container(
                width: 2,
                height: 14,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${(value * 100).toStringAsFixed(0)}% atual",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text("Meta: ${(target * 100).toStringAsFixed(0)}%",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

/// Cartão de treino reutilizável: grande, arredondado, com ícone claro.
class _Card extends StatelessWidget {
  const _Card({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.locked = false,
    this.highlight = false,
    this.progress,
    this.isNewlyUnlocked = false,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool locked;
  final bool highlight;
  final double? progress;
  final bool isNewlyUnlocked;

  static const Color _card = Color(0xFF1B2128);
  static const Color _primary = Color(0xFF4F8DF7);
  static const Color _textMain = Color(0xFFF2F4F7);
  static const Color _textSoft = Color(0xFFB4BCC8);
  static const Color _correct = Color(0xFF3FB37F);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: highlight
                ? Border.all(color: _primary, width: 1.5)
                : isNewlyUnlocked
                    ? Border.all(color: _correct, width: 1.5)
                    : null,
          ),
          child: Row(
            children: [
              // Ícone com mini anel de progresso
              _buildIconWithProgress(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: TextStyle(
                                  color: locked ? _textSoft : _textMain,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (isNewlyUnlocked)
                          _NewBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: _textSoft,
                            fontSize: 14,
                            height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: _textSoft,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithProgress() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring (if available)
          if (progress != null)
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress!),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3,
                    color: value >= 0.7 ? _correct : _primary,
                    backgroundColor: _card,
                    strokeCap: StrokeCap.round,
                  );
                },
              ),
            ),
          // Icon background
          Container(
            width: progress != null ? 42 : 52,
            height: progress != null ? 42 : 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(progress != null ? 21 : 14),
            ),
            child: Icon(icon, color: iconColor, size: progress != null ? 22 : 28),
          ),
        ],
      ),
    );
  }
}

/// Badge "NOVO" animado quando um módulo é recém-desbloqueado.
class _NewBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF3FB37F),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          "NOVO",
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5),
        ),
      ),
    );
  }
}
