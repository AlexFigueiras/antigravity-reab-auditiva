import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/gamification_controller.dart';
import '../../core/phoneme_map.dart';
import '../../core/spatial_controller.dart';
import '../../models/rehab_session.dart';
import '../../services/audio_service_manager.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/supabase_service.dart';
import 'mission_report_screen.dart';
import 'dart:math' as math;

/// Tela de treino auditivo — focada num único módulo por vez.
/// O [level] define qual exercício é treinado (2, 3 ou 4).
/// Sem abas — o usuário entra aqui sabendo exatamente o que vai treinar.
class TrainingDashboard extends StatefulWidget {
  final int level;
  const TrainingDashboard({super.key, required this.level});

  @override
  State<TrainingDashboard> createState() => _TrainingDashboardState();
}

class _TrainingDashboardState extends State<TrainingDashboard>
    with SingleTickerProviderStateMixin {
  // Paleta calma (mesma da home).
  static const _bg = Color(0xFF101418);
  static const _card = Color(0xFF1B2128);
  static const _primary = Color(0xFF4F8DF7);
  static const _textMain = Color(0xFFF2F4F7);
  static const _textSoft = Color(0xFFB4BCC8);
  static const _correct = Color(0xFF3FB37F);

  bool _isTrainingActive = false;

  // Estado do Exercício
  Map<String, dynamic>? _currentStimulus;
  double _extraBoost = 0.0;
  double _targetPanning = 0.0;
  List<Map<String, dynamic>> _audiogramData = [];
  bool _audiogramLoading = true;

  // Rastreio da sessão (métricas reais — sem XP/pontos fake)
  int _totalTrials = 0;
  int _correctAnswers = 0;
  final List<Map<String, dynamic>> _sessionLog = [];
  final Stopwatch _trialStopwatch = Stopwatch();

  // Embaralha qual botão (esquerda/direita) recebe o alvo, para o usuário
  // não decorar a posição. Recalculado a cada novo estímulo.
  bool _targetOnLeft = true;
  // Feedback visual da última resposta ("Isso!" / "Quase — era ...").
  String? _feedbackMsg;
  bool _feedbackPositive = false;

  // Animação de feedback
  late AnimationController _feedbackAnim;

  @override
  void initState() {
    super.initState();
    _feedbackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAudiogram();
  }

  Future<void> _loadAudiogram() async {
    final audiogram = await SupabaseService().getLatestAudiogram();
    if (audiogram == null) {
      if (mounted) setState(() => _audiogramLoading = false);
      return;
    }
    // Liga o motor de áudio nativo (Oboe) e carrega o audiograma para o ganho
    // de meia-perda. SEM ISTO, _verifySecurityScope lança exceção e TODA fala
    // sai muda — os bipes do teste de audição funcionam porque aquela tela
    // inicializa o motor por conta própria.
    await AudioServiceManager().initializeEngineForUser(audiogram);
    final data = <Map<String, dynamic>>[];
    for (final p in audiogram.leftEar) {
      final right = audiogram.rightEar
          .where((r) => r.frequency == p.frequency)
          .firstOrNull;
      final avgThreshold =
          right != null ? (p.threshold + right.threshold) / 2 : p.threshold;
      data.add({'frequency': p.frequency, 'threshold': avgThreshold});
    }
    if (mounted) {
      setState(() {
        _audiogramData = data;
        _audiogramLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _feedbackAnim.dispose();
    AudioServiceManager().forceStopAll();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Títulos e descrições por nível
  // ---------------------------------------------------------------------------

  String get _title {
    switch (widget.level) {
      case 3:
        return "De que lado vem o som";
      case 4:
        return "Entender no barulho";
      default:
        return "Distinguir sons";
    }
  }

  String get _description {
    switch (widget.level) {
      case 3:
        return "Você vai ouvir um som e dizer de que lado ele veio: esquerda, centro ou direita.";
      case 4:
        return "Você vai ouvir uma palavra com barulho de fundo e escolher qual foi dita. Treina entender no meio do ruído.";
      default:
        return "Você vai ouvir uma palavra e escolher, entre duas parecidas, qual foi dita. Treina sons que se confundem.";
    }
  }

  // ---------------------------------------------------------------------------
  // Lógica do exercício (preservada do design anterior)
  // ---------------------------------------------------------------------------

  void _startExercise() {
    _trialStopwatch.reset();
    if (widget.level == 2) {
      _startLevel2();
    } else if (widget.level == 3) {
      _startLevel3();
    } else {
      _startLevel4();
    }
  }

  void _newStimulusLayout() {
    _targetOnLeft = math.Random().nextBool();
    _feedbackMsg = null;
  }

  void _startLevel2() {
    final controller = context.read<GamificationController>();
    final phoneme = controller.getSmartPhoneme(_audiogramData);

    // Sem audiograma não há personalização — não treinamos "às cegas".
    if (phoneme == null) {
      _requireAudiogram();
      return;
    }

    setState(() {
      _currentStimulus = phoneme;
      _isTrainingActive = true;
      _extraBoost = 0.0;
      _targetPanning = 0.0;
      _newStimulusLayout();
    });
    _trialStopwatch.start();
    _playLevel2Stimulus();
  }

  /// Bloqueia o treino quando falta o teste de audição e explica o porquê,
  /// em linguagem humana (honestidade clínica — PRODUTO.md §5).
  void _requireAudiogram() {
    if (!mounted) return;
    setState(() => _isTrainingActive = false);
    final msg = _audiogramLoading
        ? "Carregando seu teste de audição… tente de novo em instantes."
        : "Faça primeiro o teste de audição. É ele que escolhe os sons "
            "certos para o seu treino — sem ele, não dá para personalizar.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  void _startLevel4() {
    final controller = context.read<GamificationController>();
    final environments = ['RESTAURANTE', 'TRÂNSITO', 'VENTO'];

    final phoneme = controller.getSmartPhoneme(_audiogramData);
    if (phoneme == null) {
      _requireAudiogram();
      return;
    }

    setState(() {
      _currentStimulus = phoneme;
      _isTrainingActive = true;
      _newStimulusLayout();
    });

    _trialStopwatch.start();
    AudioServiceManager().engine.playCocktailStimulus(
          text: _currentStimulus!['target'],
          snrDb: controller.currentSNR,
          noiseEnvironment: environments[math.Random().nextInt(3)],
          freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
        );
  }

  void _handleN2Choice(String choice) {
    if (_currentStimulus == null) return;
    _trialStopwatch.stop();
    final controller = context.read<GamificationController>();
    final target = _currentStimulus!['target'] as String;
    final distractor = _currentStimulus!['distractor'] as String;
    bool isCorrect = choice == target;

    _totalTrials++;
    if (isCorrect) _correctAnswers++;
    _sessionLog.add({
      'pair': '$target / $distractor',
      'chosen': choice,
      'correct': isCorrect,
      'rt_ms': _trialStopwatch.elapsedMilliseconds,
    });

    if (isCorrect) {
      _feedbackAnim.forward(from: 0);
      setState(() {
        _feedbackMsg = "Isso! Você ouviu certo.";
        _feedbackPositive = true;
        controller.addAcuityXP(1.0, [target[0].toLowerCase()]);
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _startLevel2();
      });
    } else {
      controller.consumeEnergy();
      setState(() {
        _extraBoost += 3.0;
        _feedbackMsg = "Quase. A palavra era \"$target\". Ouça de novo.";
        _feedbackPositive = false;
      });
      _playLevel2Stimulus();
    }
  }

  final List<bool> _level4History = [];

  void _handleN4Choice(String choice) {
    if (_currentStimulus == null) return;
    _trialStopwatch.stop();
    final gamification = context.read<GamificationController>();
    final target = _currentStimulus!['target'] as String;
    final distractor = _currentStimulus!['distractor'] as String;
    bool isCorrect = choice == target;

    _totalTrials++;
    if (isCorrect) _correctAnswers++;
    _sessionLog.add({
      'pair': '$target / $distractor',
      'chosen': choice,
      'correct': isCorrect,
      'rt_ms': _trialStopwatch.elapsedMilliseconds,
    });

    _level4History.add(isCorrect);
    if (_level4History.length > 5) _level4History.removeAt(0);

    if (_level4History.length == 5) {
      int successCount = _level4History.where((val) => val).length;
      if (successCount < 3) {
        debugPrint("REGRESSÃO CLÍNICA (<50%). Recalibrando.");
        setState(() {
          _level4History.clear();
        });
      }
    }

    gamification.addAcuityXP(isCorrect ? 1.0 : 0.0, ['cocktail']);

    if (isCorrect) {
      _feedbackAnim.forward(from: 0);
      setState(() {
        _feedbackMsg = "Isso! Mesmo no barulho.";
        _feedbackPositive = true;
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _startLevel4();
      });
    } else {
      gamification.consumeEnergy();
      setState(() {
        _feedbackMsg = "Quase. A palavra era \"$target\".";
        _feedbackPositive = false;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _startLevel4();
      });
    }
  }

  void _startLevel3() {
    final stimuli = PHONEME_REHAB_DATA['level_2'] as List;
    setState(() {
      _currentStimulus = stimuli[math.Random().nextInt(stimuli.length)];
      final options = [-1.0, 0.0, 1.0];
      _targetPanning = options[math.Random().nextInt(3)];
      _isTrainingActive = true;
      _feedbackMsg = null;
    });
    _trialStopwatch.start();
    _playLevel3Stimulus();
  }

  Future<void> _playLevel2Stimulus() async {
    if (_currentStimulus == null) return;
    await AudioServiceManager().engine.playPhonemicStimulus(
          text: _currentStimulus!['target'],
          freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
          extraBoostDb: _extraBoost,
        );
  }

  Future<void> _playLevel3Stimulus() async {
    if (_currentStimulus == null) return;
    await AudioServiceManager().engine.playSpatialStimulus(
          text: _currentStimulus!['target'],
          panning: _targetPanning,
          freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
        );
  }

  Future<void> _replayCurrent() async {
    if (widget.level == 2) {
      await _playLevel2Stimulus();
    } else if (widget.level == 3) {
      await _playLevel3Stimulus();
    } else {
      _startLevel4();
    }
  }

  void _handleN3Choice(double pannedAngle) {
    _trialStopwatch.stop();
    final spatialController = context.read<SpatialController>();
    final gamification = context.read<GamificationController>();

    spatialController.processSpatialResponse(
      targetPanning: _targetPanning,
      selectedPanning: pannedAngle,
      phoneme: _currentStimulus?['target'] ?? "N/A",
    );

    final hit = spatialController.lastAngularError < 0.1;
    _totalTrials++;
    if (hit) _correctAnswers++;
    final dirLabel = _targetPanning < 0
        ? 'esquerda'
        : _targetPanning > 0
            ? 'direita'
            : 'centro';
    _sessionLog.add({
      'direction': dirLabel,
      'correct': hit,
      'rt_ms': _trialStopwatch.elapsedMilliseconds,
    });

    if (hit) {
      _feedbackAnim.forward(from: 0);
    }
    setState(() {
      _feedbackMsg = hit ? "Isso! Lado certo." : "Quase. Ouça de novo.";
      _feedbackPositive = hit;
    });

    if (hit) {
      gamification.addAcuityXP(1.5, ['spatial']);
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _startLevel3();
      });
    } else {
      gamification.consumeEnergy();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _playLevel3Stimulus();
      });
    }
  }

  /// Monta a explicação do som ("o porquê"), derivada do alvo.
  /// Ex.: alvo "Dedo" -> "Som do D — como em dedo".
  String _soundExplanation() {
    final target = (_currentStimulus?['target'] as String?) ?? '';
    if (target.isEmpty) return '';
    final letter = target[0].toUpperCase();
    return "Som do $letter — como em \"${target.toLowerCase()}\".";
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _title,
          style: const TextStyle(
              color: _textMain, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // Indicador de sessão (acertos/tentativas)
              if (_isTrainingActive) _buildSessionIndicator(),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: _isTrainingActive
                      ? _buildActiveExercise()
                      : _buildStandby(),
                ),
              ),
              const SizedBox(height: 12),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionIndicator() {
    final accuracy = _totalTrials > 0
        ? (_correctAnswers / _totalTrials * 100).toStringAsFixed(0)
        : '--';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: _correct, size: 20),
          const SizedBox(width: 8),
          Text(
            "$_correctAnswers/$_totalTrials acertos",
            style: const TextStyle(
                color: _textMain, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Text(
            "$accuracy%",
            style: TextStyle(
                color: _totalTrials > 0 ? _primary : _textSoft,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildStandby() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.headphones_rounded, color: _textSoft, size: 72),
        const SizedBox(height: 24),
        Text(
          _description,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _textSoft, fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 16),
        const Text(
          "Coloque os fones para começar.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSoft, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildActiveExercise() {
    switch (widget.level) {
      case 3:
        return _buildSpatialExercise();
      default:
        return _buildWordChoiceExercise(); // níveis 2 e 4
    }
  }

  /// Níveis 2 e 4: ouve 1 palavra, escolhe entre 2 botões grandes.
  Widget _buildWordChoiceExercise() {
    if (_currentStimulus == null) return const SizedBox.shrink();
    final target = _currentStimulus!['target'] as String;
    final distractor = _currentStimulus!['distractor'] as String;
    final isN4 = widget.level == 4;

    final leftWord = _targetOnLeft ? target : distractor;
    final rightWord = _targetOnLeft ? distractor : target;
    final onChoice = isN4 ? _handleN4Choice : _handleN2Choice;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Faixa fixa: o "porquê" do treino.
        _explanationBanner(),
        const SizedBox(height: 28),

        // Botão "Ouvir de novo" — central, grande.
        _replayButton(),
        const SizedBox(height: 16),
        const Text("Qual palavra você ouviu?",
            style: TextStyle(color: _textSoft, fontSize: 17)),
        const SizedBox(height: 20),

        Row(
          children: [
            _wordButton(leftWord, () => onChoice(leftWord)),
            const SizedBox(width: 14),
            _wordButton(rightWord, () => onChoice(rightWord)),
          ],
        ),

        const SizedBox(height: 20),
        _feedbackArea(),
      ],
    );
  }

  Widget _explanationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: _primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _soundExplanation(),
              style: const TextStyle(
                  color: _textMain, fontSize: 16, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replayButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _replayCurrent,
        icon: const Icon(Icons.volume_up_rounded, size: 28),
        label: const Text("Ouvir de novo",
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _wordButton(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textMain,
                fontSize: 26,
                fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _feedbackArea() {
    if (_feedbackMsg == null) {
      return const SizedBox(height: 28);
    }
    final color = _feedbackPositive ? _correct : const Color(0xFFE6A23C);
    return FadeTransition(
      opacity: _feedbackPositive
          ? _feedbackAnim.drive(CurveTween(curve: Curves.easeOut))
          : const AlwaysStoppedAnimation(1.0),
      child: ScaleTransition(
        scale: _feedbackPositive
            ? _feedbackAnim.drive(
                Tween(begin: 0.8, end: 1.0)
                    .chain(CurveTween(curve: Curves.elasticOut)),
              )
            : const AlwaysStoppedAnimation(1.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _feedbackPositive
                    ? Icons.check_circle_rounded
                    : Icons.refresh_rounded,
                color: color,
                size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _feedbackMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nível 3: de que lado veio o som.
  Widget _buildSpatialExercise() {
    return Consumer<SpatialController>(
      builder: (context, spatial, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _replayButton(),
            const SizedBox(height: 24),
            const Text("De que lado veio o som?",
                style: TextStyle(color: _textSoft, fontSize: 18)),
            const SizedBox(height: 24),
            Row(
              children: [
                _sideButton("Esquerda", Icons.arrow_back_rounded,
                    () => _handleN3Choice(-1.0)),
                const SizedBox(width: 10),
                _sideButton("Centro", Icons.circle_outlined,
                    () => _handleN3Choice(0.0)),
                const SizedBox(width: 10),
                _sideButton("Direita", Icons.arrow_forward_rounded,
                    () => _handleN3Choice(1.0)),
              ],
            ),
            const SizedBox(height: 20),
            _feedbackArea(),
          ],
        );
      },
    );
  }

  Widget _sideButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _primary, size: 30),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      color: _textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (context.watch<GamificationController>().neuralEnergy <= 2 &&
            _isTrainingActive)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              "Bom esforço! Pode continuar ou voltar amanhã.",
              style: TextStyle(color: Color(0xFFE6A23C), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTrainingActive
                  ? const Color(0xFF2A323C)
                  : _primary,
              foregroundColor:
                  _isTrainingActive ? _textSoft : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _isTrainingActive
                ? _stopAndReport()
                : _startExercise(),
            child: Text(
              _isTrainingActive ? "Encerrar treino" : "Começar o treino",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _stopAndReport() async {
    setState(() => _isTrainingActive = false);
    AudioServiceManager().forceStopAll();

    // Salva sessão real no Supabase (métrica clínica, não XP de videogame)
    final accuracy = _totalTrials > 0
        ? (_correctAnswers / _totalTrials * 100)
        : 0.0;
    final avgRt = _sessionLog.isNotEmpty
        ? _sessionLog
                .map((e) => (e['rt_ms'] as int?) ?? 0)
                .reduce((a, b) => a + b) /
            _sessionLog.length
        : 0.0;

    try {
      final user = await SupabaseService().getLatestAudiogram();
      final patientId = user?.patientId ?? 'local';
      final rehabLevel = RehabLevel.values.firstWhere(
        (e) => e.value == widget.level,
        orElse: () => RehabLevel.phonemicDiscrimination,
      );

      final gamification = context.read<GamificationController>();
      final session = RehabSession(
        patientId: patientId,
        date: DateTime.now(),
        level: rehabLevel,
        totalTrials: _totalTrials,
        correctAnswers: _correctAnswers,
        averageResponseTimeMs: avgRt,
        metadata: {
          'log': _sessionLog,
          if (widget.level == 4) 'srt': gamification.currentSNR,
        },
      );
      await SupabaseService().saveRehabSession(session);

      // Invalida cache do gatekeeper para reavaliar desbloqueios
      GatekeeperService().invalidateCache();
    } catch (e) {
      debugPrint("Erro ao salvar sessão: $e");
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissionReportScreen(
          totalTrials: _totalTrials,
          correctAnswers: _correctAnswers,
          level: widget.level,
          sessionLog: _sessionLog,
        ),
      ),
    );
  }
}
