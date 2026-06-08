import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/audiogram.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import '../../screens/threshold_test_screen.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/locale_controller.dart';
import '../../core/theme_notifier.dart';
import '../../audio_engine/audio_engine.dart';
import '../widgets/tts_voice_banner.dart';
import 'package:provider/provider.dart';
import 'training_dashboard.dart';
import 'progress_screen.dart';
import 'sentence_hub_screen.dart';
import 'outcome_test_screen.dart';
import 'auth_screen.dart';
import 'widgets/self_perception_prompt.dart';
import '../../services/ad_manager.dart';

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

  /// True quando a variante de voz do idioma atual (ex.: pt-BR) NÃO está
  /// instalada no device → a fala sairá com outro sotaque. Mostra o aviso.
  bool _ttsVoiceMissing = false;

  ColorScheme get _cs => Theme.of(context).colorScheme;
  Color get _card => _cs.surface;
  Color get _primary => _cs.primary;
  Color get _textMain => _cs.onSurface;
  Color get _textSoft => _cs.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadAllData();
    _checkTtsVoice();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAskSelfPerception());
    // Pré-carrega o anúncio premiado para o limite diário da versão grátis
    AdManager().loadRewardedAd();
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
                SnackBar(content: Text(AppLocalizations.of(context).homeSelfPerceptionThanks)),
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
      // Ao voltar das configurações de TTS, re-checa: se o usuário instalou a
      // voz, o aviso some sozinho.
      _checkTtsVoice();
    }
  }

  /// Verifica se a variante de voz do idioma atual está instalada e atualiza o
  /// aviso. Degrada gracioso: em falha/plataforma sem suporte, não alarma.
  Future<void> _checkTtsVoice() async {
    final installed = await AudioRehabEngine().isTtsLocaleInstalled();
    if (!mounted) return;
    if (_ttsVoiceMissing == !installed) return; // sem mudança → evita rebuild
    setState(() => _ttsVoiceMissing = !installed);
  }

  /// Toque no "Já instalei a voz": re-checa na hora. Se a voz apareceu, o banner
  /// some via _checkTtsVoice; se ainda não, avisa (o TTS pode demorar a indexar).
  Future<void> _recheckTtsVoiceTapped() async {
    await _checkTtsVoice();
    if (!mounted || !_ttsVoiceMissing) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).ttsVoiceStillMissing)),
    );
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

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _buildLanguageButton(context),
              ),
              if (_ttsVoiceMissing) ...[
                TtsVoiceBanner(
                  voiceName: _missingVoiceName(context, l10n),
                  onRecheck: _recheckTtsVoiceTapped,
                ),
                const SizedBox(height: 16),
              ],
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildProgressSummary(),
              const SizedBox(height: 16),
              _buildDailyDoseWidget(),
              const SizedBox(height: 28),
              Text(l10n.homeYourTrainings,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(l10n.homeStartWithHearingTest,
                  style:
                      TextStyle(color: _textSoft, fontSize: 15, height: 1.4)),
              const SizedBox(height: 16),
              _buildAudiogramCard(context),
              const SizedBox(height: 12),
              _buildOutcomeTestCard(context),
              const SizedBox(height: 12),
              _buildLevelCard(
                context,
                level: 2,
                title: l10n.level2Title,
                subtitle: l10n.level2Subtitle,
                icon: Icons.graphic_eq,
              ),
              const SizedBox(height: 12),
              _buildLevelCard(
                context,
                level: 3,
                title: l10n.level3Title,
                subtitle: l10n.level3Subtitle,
                icon: Icons.surround_sound,
              ),
              const SizedBox(height: 12),
              _buildLevelCard(
                context,
                level: 4,
                title: l10n.level4Title,
                subtitle: l10n.level4Subtitle,
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_up_rounded, color: _primary, size: 72),
              const SizedBox(height: 28),
              Text(AppLocalizations.of(context).homePermissionTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).homePermissionBody,
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
                          ? AppLocalizations.of(context).homePermissionOpenSettings
                          : AppLocalizations.of(context).homePermissionAllow,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              if (_isPermanentlyDenied)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    AppLocalizations.of(context).homePermissionDeniedHint,
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
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.homeGreeting,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(l10n.homeGreetingSubtitle,
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
                  AppLocalizations.of(context).homeDailyGoalTitle,
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed
                      ? AppLocalizations.of(context).homeDailyGoalDone
                      : AppLocalizations.of(context).homeDailyGoalProgress(
                          _todayMinutes.toStringAsFixed(1)),
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
                  Text(AppLocalizations.of(context).homeProgressTitle,
                      style: TextStyle(
                          color: _textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    hasData
                        ? AppLocalizations.of(context).homeProgressLastAccuracy(
                            lastAcc.toStringAsFixed(0))
                        : AppLocalizations.of(context).homeProgressEmpty,
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
              SnackBar(
                  content: Text(
                      AppLocalizations.of(context).homeSavedAudiogram)),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context).homeSaveAudiogramError)),
            );
          }
        }
      },
      icon: isDone ? Icons.check_circle : Icons.hearing,
      iconColor: isDone ? const Color(0xFF4CAF7D) : _primary,
      highlight: !isDone,
      title: AppLocalizations.of(context).hearingTestTitle,
      subtitle: isDone
          ? AppLocalizations.of(context).hearingTestSubtitleDone
          : AppLocalizations.of(context).hearingTestSubtitleNew,
    );
  }

  /// Segundo teste-âncora: mede o SRT (limiar de fala no ruído) — o "desfecho"
  /// clínico que mostra se a pessoa melhorou. Fica ao lado do teste de audição,
  /// não vira nível/XP (medir ≠ treinar). Sempre disponível após o audiograma,
  /// que personaliza o ganho. O histórico/evolução do SRT aparece na tela de
  /// progresso. Ver docs/treinos/teste-fala-no-ruido.md.
  Widget _buildOutcomeTestCard(BuildContext context) {
    return _Card(
      onTap: () async {
        final audiogram = await SupabaseService().getLatestAudiogram();
        if (!context.mounted) return;
        if (audiogram == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context).speechInNoiseNeedsHearingTest)),
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OutcomeTestScreen()),
        );
        if (context.mounted) setState(() {}); // reflete novo resultado ao voltar
      },
      icon: Icons.record_voice_over,
      iconColor: _primary,
      title: AppLocalizations.of(context).speechInNoiseTestTitle,
      subtitle: AppLocalizations.of(context).speechInNoiseTestSubtitle,
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
            SnackBar(
                content: Text(
                    AppLocalizations.of(context).homeSentenceNeedsAudiogram)),
          );
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SentenceHubScreen(audiogram: audiogram)));
      },
      icon: Icons.chat_bubble_outline,
      iconColor: _primary,
      title: AppLocalizations.of(context).sentenceTitle,
      subtitle: AppLocalizations.of(context).sentenceSubtitle,
    );
  }

  /// Menu no topo da Home: idioma + logout. Um ícone só abre os dois.
  /// Nome humano (no idioma da UI) da voz faltante, conforme o idioma de áudio
  /// ativo. Mapeia o código curto do conteúdo para o rótulo da variante.
  String _missingVoiceName(BuildContext context, AppLocalizations l10n) {
    final lang = context.read<LocaleController>().audioLanguageCode;
    return lang == 'en' ? l10n.ttsVoiceEnUsName : l10n.ttsVoicePtBrName;
  }

  /// Menu de configurações no topo da Home (⋮): idioma, visual (tema) e sair.
  /// Um único menu agrupa tudo — o usuário troca o tema clicando em "Visual
  /// claro/escuro", que persiste e reconstrói o app na hora.
  Widget _buildLanguageButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<LocaleController>();
    final themeNotifier = context.read<ThemeNotifier>();
    final isDark = context.watch<ThemeNotifier>().mode == ThemeMode.dark;
    return PopupMenuButton<String>(
      color: _card,
      tooltip: l10n.settingsMenuTooltip,
      icon: Icon(Icons.more_vert, color: _textSoft, size: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) async {
        if (value == 'pt' || value == 'en') {
          await controller.setLocale(Locale(value));
          // O locale alvo mudou → a variante de voz exigida também. Re-checa.
          await _checkTtsVoice();
        } else if (value == 'theme') {
          await themeNotifier.toggle();
        } else if (value == 'logout') {
          await _logout(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pt',
          child: Text("Português",
              style: TextStyle(
                  color: _textMain,
                  fontWeight: controller.locale?.languageCode == 'pt'
                      ? FontWeight.w700
                      : FontWeight.normal)),
        ),
        PopupMenuItem(
          value: 'en',
          child: Text("English",
              style: TextStyle(
                  color: _textMain,
                  fontWeight: controller.locale?.languageCode == 'en'
                      ? FontWeight.w700
                      : FontWeight.normal)),
        ),
        const PopupMenuDivider(),
        // Troca de visual: o rótulo mostra o tema PARA O QUAL vai (ação), com o
        // ícone correspondente — sol para ir ao claro, lua para ir ao escuro.
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                  color: _primary, size: 18),
              const SizedBox(width: 10),
              Text(isDark ? l10n.themeUseLight : l10n.themeUseDark,
                  style: TextStyle(color: _textMain)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, color: Colors.redAccent, size: 18),
              const SizedBox(width: 10),
              Text(l10n.logout,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
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
    final l10n = AppLocalizations.of(context);
    String lockSubtitle;
    if (isLocked) {
      final prevLevel = (level == 3 || level == 4) ? 2 : (level - 1);
      final prevAcc = _levelAccuracies[prevLevel] ?? 0.0;
      if (prevAcc > 0) {
        lockSubtitle = l10n.homeLockUnlockHint(prevAcc.toStringAsFixed(0));
      } else {
        lockSubtitle = l10n.homeLockUnlockHintNoProgress;
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
        
        // Verificar limite diário de treino (apenas para níveis de reabilitação grátis: 2, 3, 4)
        final isReached = await GatekeeperService().checkDailyLimitReached();
        if (isReached && context.mounted) {
          _showDailyLimitSheet(context, level);
          return;
        }

        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => TrainingDashboard(level: level)),
          );
          // Recarrega dados ao voltar (novo desbloqueio possível)
          _loadAllData();
        }
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
    final l10n = AppLocalizations.of(context);
    final prevLevel = (level == 3 || level == 4) ? 2 : (level - 1);
    final prevAcc = _levelAccuracies[prevLevel] ?? 0.0;
    final prevName = prevLevel == 2
        ? l10n.levelNameL2
        : prevLevel == 3
            ? l10n.levelNameL3
            : l10n.levelNameL4;

    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final l10n = AppLocalizations.of(context);
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
              Text(l10n.homeLockHowTitle,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(
                l10n.homeLockHowBody(prevName),
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
                      ? l10n.homeLockNearlyThere(prevAcc.toStringAsFixed(0))
                      : l10n.homeLockKeepGoing(prevAcc.toStringAsFixed(0)),
                  style: TextStyle(
                      color: _primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ] else
                Text(
                  l10n.homeLockNeedSessions(prevName),
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
                  child: Text(l10n.homeLockTrainButton(prevName),
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
        final l10n = AppLocalizations.of(context);
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
              Text(l10n.paywallTitle,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                l10n.paywallBody,
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
                  child: Text(l10n.paywallSubscribeButton,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDailyLimitSheet(BuildContext context, int targetLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        bool localAdLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    l10n.dailyLimitTitle,
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.dailyLimitBody,
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (localAdLoading) ...[
                    Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: _primary),
                          const SizedBox(height: 16),
                          Text(
                            "Carregando vídeo...",
                            style: TextStyle(color: _textSoft, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Botão 1: Assistir Vídeo Premiado
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3FB37F), // cor verde
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline, size: 24),
                        label: Text(
                          l10n.dailyLimitWatchAdButton,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          setState(() {
                            localAdLoading = true;
                          });

                          // Tenta carregar o anúncio caso não esteja pronto
                          if (!AdManager().isAdReady) {
                            await AdManager().loadRewardedAd();
                          }

                          // Se após tentar carregar ele ainda não estiver pronto (erro de rede, etc.)
                          if (!AdManager().isAdReady) {
                            if (context.mounted) {
                              setState(() {
                                localAdLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.dailyLimitLoadingAd),
                                ),
                              );
                            }
                            return;
                          }

                          // Exibir o anúncio
                          AdManager().showRewardedAd(
                            onRewardEarned: () async {
                              // Concede bônus de +2 treinos
                              await GatekeeperService().grantAdRewardSession();
                              _loadAllData();
                            },
                            onAdClosed: () {
                              if (context.mounted) {
                                Navigator.pop(sheetContext); // fecha o bottom sheet
                                // Se ganhou o bônus, inicia o treino imediatamente
                                GatekeeperService().checkDailyLimitReached().then((reached) {
                                  if (!reached && context.mounted) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TrainingDashboard(level: targetLevel),
                                      ),
                                    ).then((_) => _loadAllData());
                                  }
                                });
                              }
                            },
                            onAdFailed: () {
                              if (context.mounted) {
                                setState(() {
                                  localAdLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Erro ao carregar o anúncio. Tente novamente."),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botão 2: Assinar Premium
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showPaywall(context);
                        },
                        child: Text(
                          l10n.dailyLimitSubscribeButton,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botão 3: Voltar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: _textSoft,
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: Text(
                          l10n.dailyLimitCancelButton,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final correct = cs.tertiary;
    final card = cs.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Background
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: card,
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
                        ? [correct, correct]
                        : [primary, primary.withValues(alpha: 0.7)],
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
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).progressBarCurrentLabel(
                    (value * 100).toStringAsFixed(0)),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            Text(AppLocalizations.of(context).progressBarTargetLabel(
                    (target * 100).toStringAsFixed(0)),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final card = cs.surface;
    final primary = cs.primary;
    final textMain = cs.onSurface;
    final textSoft = cs.onSurfaceVariant;
    final correct = cs.tertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: highlight
                ? Border.all(color: primary, width: 1.5)
                : isNewlyUnlocked
                    ? Border.all(color: correct, width: 1.5)
                    : null,
          ),
          child: Row(
            children: [
              // Ícone com mini anel de progresso
              _buildIconWithProgress(card, primary, correct),
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
                                  color: locked ? textSoft : textMain,
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
                            color: textSoft,
                            fontSize: 14,
                            height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: textSoft,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithProgress(Color card, Color primary, Color correct) {
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
                    color: value >= 0.7 ? correct : primary,
                    backgroundColor: card,
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
