import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/adaptive_staircase.dart';
import '../../core/gamification_controller.dart';
import '../../core/listening_mode.dart';
import '../../core/phoneme_map.dart';
import '../../core/spatial_controller.dart';
import '../../models/rehab_session.dart';
import '../../services/audio_service_manager.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/listening_mode_service.dart';
import '../../services/locale_controller.dart';
import '../../services/supabase_service.dart';
import '../widgets/listening_mode_banner.dart';
import '../widgets/volume_drift_banner.dart';
import '../../services/audio_accessibility.dart';
import '../../l10n/gen/app_localizations.dart';
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
  ColorScheme get _cs => Theme.of(context).colorScheme;
  Color get _card => _cs.surface;
  Color get _primary => _cs.primary;
  Color get _textMain => _cs.onSurface;
  Color get _textSoft => _cs.onSurfaceVariant;
  Color get _correct => _cs.tertiary;

  bool _isTrainingActive = false;
  bool _volumeDriftWarning = false;

  // Estado do Exercício
  Map<String, dynamic>? _currentStimulus;
  double _extraBoost = 0.0;
  double _targetPanning = 0.0;
  // Ambiente de ruído do nível 4 (Restaurante/Trânsito/Vento). Sorteado uma vez
  // por estímulo e reusado no "Ouvir de novo", para a repetição ser fiel.
  String _currentEnvironment = 'RESTAURANTE';
  List<Map<String, dynamic>> _audiogramData = [];
  bool _audiogramLoading = true;

  // Condição de escuta (com/sem aparelho). O usuário precisa CONFIRMAR a condição
  // antes de começar — para treinar igual ao teste e evitar empilhar ganho. (0.4)
  ListeningMode _listeningMode = ListeningMode.unaided;
  bool _conditionConfirmed = false;

  // N4: staircase 2-down/1-up (converge ~70,7% de acerto).
  // SNR: +10 dB (fácil) → 0 dB (fala = ruído). Ruído fixo, fala desce/sobe.
  // Passo de 2 dB down / 3 dB up (assimetria clínica: subir rápido para não
  // frustrar o idoso, descer devagar para manter desafio).
  final _n4Staircase = AdaptiveStaircase(
    start: 10.0,
    floor: 0.0,
    ceiling: 10.0,
    stepDown: 2.0,
    stepUp: 3.0,
    minReversalsForEstimate: 6,
  );

  // N2: staircase para nível de dificuldade (1 a 5).
  // 1 (mais fácil - bilabiais/vogais) a 5 (mais difícil - sibilantes).
  // stepDown: 1.0 (fica mais difícil, V desce para 1.0, ou seja, dificuldade 6 - V sobe para 5).
  // stepUp: 1.0 (fica mais fácil, V sobe para 5.0, ou seja, dificuldade 6 - V desce para 1).
  final _n2Staircase = AdaptiveStaircase(
    start: 3.0,
    floor: 1.0,
    ceiling: 5.0,
    stepDown: 1.0,
    stepUp: 1.0,
    minReversalsForEstimate: 4,
  );

  // Rastreio da sessão (métricas reais — sem XP/pontos fake)
  int _totalTrials = 0;
  int _correctAnswers = 0;
  final List<Map<String, dynamic>> _sessionLog = [];
  final Stopwatch _trialStopwatch = Stopwatch();
  bool _isRepeatTrial = false;
  DateTime? _sessionStart;

  // Embaralha qual botão (esquerda/direita) recebe o alvo, para o usuário
  // não decorar a posição. Recalculado a cada novo estímulo.
  bool _targetOnLeft = true;
  // Feedback visual da última resposta ("Isso!" / "Quase — era ...").
  String? _feedbackMsg;
  bool _feedbackPositive = false;

  // Animação de feedback
  late AnimationController _feedbackAnim;
  List<String> _n2Choices = [];

  @override
  void initState() {
    super.initState();
    _feedbackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAudiogram();
    _loadListeningMode();
  }

  Future<void> _loadListeningMode() async {
    final m = await ListeningModeService().load();
    if (mounted) setState(() => _listeningMode = m);
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

  String _title(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (widget.level) {
      case 3:
        return l10n.dashboardTitleL3;
      case 4:
        return l10n.dashboardTitleL4;
      default:
        return l10n.dashboardTitleL2;
    }
  }

  String _description(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (widget.level) {
      case 3:
        return l10n.dashboardDescL3;
      case 4:
        return l10n.dashboardDescL4;
      default:
        return l10n.dashboardDescL2;
    }
  }

  // ---------------------------------------------------------------------------
  // Lógica do exercício (preservada do design anterior)
  // ---------------------------------------------------------------------------

  void _startExercise() {
    _sessionStart = DateTime.now();
    _totalTrials = 0;
    _correctAnswers = 0;
    _sessionLog.clear();
    _trialStopwatch.reset();
    _isRepeatTrial = false;
    if (widget.level == 2) {
      _n2Staircase.reset();
      _startLevel2();
    } else if (widget.level == 3) {
      _startLevel3();
    } else {
      _startLevel4(newSession: true);
    }
  }

  void _newStimulusLayout() {
    _targetOnLeft = math.Random().nextBool();
    _feedbackMsg = null;
  }

  void _startLevel2() {
    _isRepeatTrial = false;
    final controller = context.read<GamificationController>();
    final lang = context.read<LocaleController>().audioLanguageCode;
    final bankKey = lang == 'en' ? 'level_2_en' : 'level_2';
    final targetDifficulty = 6 - _n2Staircase.current.round();
    final phoneme = controller.getSmartPhoneme(
      _audiogramData,
      targetDifficulty: targetDifficulty,
      phonemeBankKey: bankKey,
    );

    // Sem audiograma não há personalização — não treinamos "às cegas".
    if (phoneme == null) {
      _requireAudiogram();
      return;
    }

    // Embaralha quem é target e quem é distractor a cada rodada, para que
    // o mesmo par possa aparecer com qualquer uma das duas palavras como alvo.
    final Map<String, dynamic> stimulus;
    if (math.Random().nextBool()) {
      stimulus = {
        ...phoneme,
        'target': phoneme['distractor'],
        'distractor': phoneme['target'],
      };
    } else {
      stimulus = phoneme;
    }

    final target = stimulus['target'] as String;
    final mainDistractor = stimulus['distractor'] as String;

    final List<Map<String, dynamic>> level2Stimuli =
        List<Map<String, dynamic>>.from(PHONEME_REHAB_DATA[bankKey] ?? PHONEME_REHAB_DATA['level_2']!);
    
    final band = stimulus['freq_band'] as int;
    final candidates = level2Stimuli
        .where((s) => s['freq_band'] == band)
        .expand((s) => [s['target'] as String, s['distractor'] as String])
        .where((w) => w.toLowerCase() != target.toLowerCase() && w.toLowerCase() != mainDistractor.toLowerCase())
        .toSet()
        .toList();

    if (candidates.length < 2) {
      final allWords = level2Stimuli
          .expand((s) => [s['target'] as String, s['distractor'] as String])
          .where((w) => w.toLowerCase() != target.toLowerCase() && w.toLowerCase() != mainDistractor.toLowerCase())
          .toSet()
          .toList();
      candidates.addAll(allWords);
    }

    candidates.shuffle();
    final distractor2 = candidates[0];
    final distractor3 = candidates[1];

    final choices = [target, mainDistractor, distractor2, distractor3];
    choices.shuffle();

    setState(() {
      _currentStimulus = stimulus;
      _n2Choices = choices;
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
    final l10n = AppLocalizations.of(context);
    final msg = _audiogramLoading
        ? l10n.dashboardNoAudiogramLoading
        : l10n.dashboardNoAudiogramNeeded;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  void _startLevel4({bool newSession = false}) {
    final controller = context.read<GamificationController>();
    final environments = ['RESTAURANTE', 'TRÂNSITO', 'VENTO'];

    final lang = context.read<LocaleController>().audioLanguageCode;
    final bankKey = lang == 'en' ? 'level_2_en' : 'level_2';

    final phoneme = controller.getSmartPhoneme(
      _audiogramData,
      phonemeBankKey: bankKey,
    );
    if (phoneme == null) {
      _requireAudiogram();
      return;
    }

    // Nova sessão → staircase começa do teto (10 dB, mais fácil), para não
    // carregar o estado de uma sessão anterior e frustrar o usuário.
    if (newSession) _n4Staircase.reset();

    setState(() {
      _currentStimulus = phoneme;
      _isTrainingActive = true;
      // Sorteia o ambiente UMA vez por estímulo e guarda, para o "Ouvir de novo"
      // repetir o mesmo ambiente (e não trocar a cada toque).
      _currentEnvironment = environments[math.Random().nextInt(3)];
      _newStimulusLayout();
    });

    _trialStopwatch.start();
    _playLevel4Stimulus();
  }

  Future<bool> _verifyVolume() async {
    final atLevel = await AudioAccessibility.isAtReferenceVolume();
    if (!mounted) return false;
    if (!atLevel) {
      setState(() {
        _volumeDriftWarning = true;
      });
      return false;
    }
    return true;
  }

  Future<void> _playLevel4Stimulus() async {
    if (!await _verifyVolume()) return;
    if (_currentStimulus == null) return;
    await AudioServiceManager().engine.playCocktailStimulus(
          text: _currentStimulus!['target'],
          snrDb: _n4Staircase.current,
          noiseEnvironment: _currentEnvironment,
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

    final currentDiff = 6 - _n2Staircase.current.round();

    if (!_isRepeatTrial) {
      _totalTrials++;
      if (isCorrect) _correctAnswers++;
      _n2Staircase.respond(isCorrect);
      _sessionLog.add({
        'pair': '$target / $distractor',
        'chosen': choice,
        'correct': isCorrect,
        'rt_ms': _trialStopwatch.elapsedMilliseconds,
        'difficulty_level': currentDiff,
      });
    }

    final l10n = AppLocalizations.of(context);
    if (isCorrect) {
      _feedbackAnim.forward(from: 0);
      setState(() {
        _feedbackMsg = l10n.dashboardFeedbackCorrect;
        _feedbackPositive = true;
        if (!_isRepeatTrial) {
          controller.addAcuityXP(1.0, [target[0].toLowerCase()]);
        }
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _startLevel2();
      });
    } else {
      if (!_isRepeatTrial) {
        controller.consumeEnergy();
      }
      setState(() {
        _isRepeatTrial = true;
        _extraBoost += 3.0;
        _feedbackMsg = l10n.dashboardFeedbackWrong(target);
        _feedbackPositive = false;
      });
      _playLevel2Stimulus();
    }
  }

  void _handleN4Choice(String choice) {
    if (_currentStimulus == null) return;
    _trialStopwatch.stop();
    final gamification = context.read<GamificationController>();
    final target = _currentStimulus!['target'] as String;
    final distractor = _currentStimulus!['distractor'] as String;
    final isCorrect = choice == target;

    _totalTrials++;
    if (isCorrect) _correctAnswers++;
    _sessionLog.add({
      'pair': '$target / $distractor',
      'chosen': choice,
      'correct': isCorrect,
      'snr_db': _n4Staircase.current,
      'rt_ms': _trialStopwatch.elapsedMilliseconds,
    });

    // Staircase 2-down/1-up: atualiza SNR ANTES do próximo estímulo.
    // Acerto → pode descer (mais difícil) após 2 consecutivos.
    // Erro  → sobe imediatamente (mais fácil), garantindo que o usuário
    //         não trava no piso como no código anterior.
    _n4Staircase.respond(isCorrect);

    gamification.addAcuityXP(isCorrect ? 1.0 : 0.0, ['cocktail']);

    final l10n = AppLocalizations.of(context);
    if (isCorrect) {
      _feedbackAnim.forward(from: 0);
      setState(() {
        _feedbackMsg = l10n.dashboardFeedbackCorrectNoise;
        _feedbackPositive = true;
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _startLevel4();
      });
    } else {
      gamification.consumeEnergy();
      setState(() {
        _feedbackMsg = l10n.dashboardFeedbackWrongNoise(target);
        _feedbackPositive = false;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _startLevel4();
      });
    }
  }

  void _startLevel3() {
    final lang = context.read<LocaleController>().audioLanguageCode;
    final bankKey = lang == 'en' ? 'level_2_en' : 'level_2';
    final stimuli = PHONEME_REHAB_DATA[bankKey] as List;
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
    if (!await _verifyVolume()) return;
    if (_currentStimulus == null) return;
    await AudioServiceManager().engine.playPhonemicStimulus(
          text: _currentStimulus!['target'],
          freqBand: (_currentStimulus!['freq_band'] as num).toDouble(),
          extraBoostDb: _extraBoost,
        );
  }

  Future<void> _playLevel3Stimulus() async {
    if (!await _verifyVolume()) return;
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
      // Nível 4: REPETE o estímulo atual (mesmo par, mesmo ambiente, mesmo SNR).
      // Antes chamava _startLevel4(), que sorteava um novo par e "avançava".
      await _playLevel4Stimulus();
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _feedbackMsg = hit ? l10n.dashboardFeedbackSideCorrect : l10n.dashboardFeedbackSideWrong;
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


  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _title(context),
          style: TextStyle(
              color: _textMain, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: _textMain),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // Indicador de sessão (acertos/tentativas)
              if (_isTrainingActive) _buildSessionIndicator(),
              const SizedBox(height: 12),
              if (_volumeDriftWarning)
                VolumeDriftBanner(
                  margin: const EdgeInsets.only(bottom: 12),
                  onResume: () {
                    if (mounted) {
                      setState(() => _volumeDriftWarning = false);
                      _replayCurrent();
                    }
                  },
                ),
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

  // Dose mínima efetiva por sessão (Sweetow & Sabes 2006): ~20 estímulos.
  // Não bloqueia — é celebração, não barreira.
  static const int _sessionGoalTrials = 20;

  Widget _buildSessionIndicator() {
    final l10n = AppLocalizations.of(context);
    final accuracy = _totalTrials > 0
        ? (_correctAnswers / _totalTrials * 100).toStringAsFixed(0)
        : '--';
    final goalReached = _totalTrials >= _sessionGoalTrials;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                l10n.dashboardCorrectAnswers("$_correctAnswers", "$_totalTrials"),
                style: TextStyle(
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
              if (!goalReached) ...[
                const SizedBox(width: 16),
                Text(
                  l10n.dashboardTrialsRemaining("${_sessionGoalTrials - _totalTrials}"),
                  style: TextStyle(color: _textSoft, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (goalReached)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _correct.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _correct.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration_rounded, color: Color(0xFF3FB37F), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).dashboardGoalReached,
                    style: const TextStyle(
                        color: Color(0xFF3FB37F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStandby() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_rounded, color: _textSoft, size: 64),
          const SizedBox(height: 20),
          Text(
            _description(context),
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSoft, fontSize: 18, height: 1.5),
          ),
          const SizedBox(height: 20),
          // Instrução da condição de escuta + confirmação ativa (0.4): a pessoa
          // tem de confirmar que está na mesma condição em que foi testada.
          ListeningModeBanner(
            mode: _listeningMode,
            confirmed: _conditionConfirmed,
            onConfirmedChanged: (v) => setState(() => _conditionConfirmed = v),
          ),
        ],
      ),
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

    if (isN4) {
      final leftWord = _targetOnLeft ? target : distractor;
      final rightWord = _targetOnLeft ? distractor : target;
      final onChoice = _handleN4Choice;

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _replayButton(),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).dashboardWhichWord,
              style: TextStyle(color: _textSoft, fontSize: 17)),
          const SizedBox(height: 20),
          Row(
            children: [
              _wordButton(leftWord, _volumeDriftWarning ? null : () => onChoice(leftWord)),
              const SizedBox(width: 14),
              _wordButton(rightWord, _volumeDriftWarning ? null : () => onChoice(rightWord)),
            ],
          ),
          const SizedBox(height: 20),
          _feedbackArea(),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _replayButton(),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).dashboardWhichWord,
              style: TextStyle(color: _textSoft, fontSize: 17)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.0,
            children: _n2Choices.map((word) {
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _volumeDriftWarning ? null : () => _handleN2Choice(word),
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _textSoft.withValues(alpha: 0.2), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _textMain,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _feedbackArea(),
        ],
      );
    }
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
        onPressed: _volumeDriftWarning ? null : _replayCurrent,
        icon: const Icon(Icons.volume_up_rounded, size: 28),
        label: Text(AppLocalizations.of(context).dashboardListenAgain,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _wordButton(String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _textSoft.withValues(alpha: 0.2), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
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
            Text(AppLocalizations.of(context).dashboardWhichSide,
                style: TextStyle(color: _textSoft, fontSize: 18)),
            const SizedBox(height: 24),
            Row(
              children: [
                _sideButton(AppLocalizations.of(context).dashboardSideLeft, Icons.arrow_back_rounded,
                    _volumeDriftWarning ? null : () => _handleN3Choice(-1.0)),
                const SizedBox(width: 10),
                _sideButton(AppLocalizations.of(context).dashboardSideCenter, Icons.circle_outlined,
                    _volumeDriftWarning ? null : () => _handleN3Choice(0.0)),
                const SizedBox(width: 10),
                _sideButton(AppLocalizations.of(context).dashboardSideRight, Icons.arrow_forward_rounded,
                    _volumeDriftWarning ? null : () => _handleN3Choice(1.0)),
              ],
            ),
            const SizedBox(height: 20),
            _feedbackArea(),
          ],
        );
      },
    );
  }

  Widget _sideButton(String label, IconData icon, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _textSoft.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _primary, size: 30),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              AppLocalizations.of(context).dashboardGoodEffort,
              style: const TextStyle(color: Color(0xFFE6A23C), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        // Fora do treino, só libera "Começar" depois da confirmação da condição
        // de escuta (com/sem aparelho) — garante teste e treino na mesma condição.
        if (!_isTrainingActive && !_conditionConfirmed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(context).dashboardConfirmCondition,
              style: TextStyle(color: _textSoft, fontSize: 13),
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
              disabledBackgroundColor: const Color(0xFF222932),
              disabledForegroundColor: _textSoft.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isTrainingActive
                ? _stopAndReport
                : (_conditionConfirmed && !_volumeDriftWarning ? _startExercise : null),
            child: Text(
              _isTrainingActive
                  ? AppLocalizations.of(context).dashboardEndTraining
                  : AppLocalizations.of(context).dashboardStartTraining,
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

    final durationMs = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!).inMilliseconds
        : 0;

    // Salva sessão real no Supabase (métrica clínica, não XP de videogame)
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

      if (!mounted) return;
      final session = RehabSession(
        patientId: patientId,
        date: DateTime.now(),
        level: rehabLevel,
        totalTrials: _totalTrials,
        correctAnswers: _correctAnswers,
        averageResponseTimeMs: avgRt,
        metadata: {
          'log': _sessionLog,
          'duration_ms': durationMs,
          if (widget.level == 4)
            'srt': _n4Staircase.estimate ?? _n4Staircase.current,
          if (widget.level == 4)
            'srt_reversals': _n4Staircase.reversalCount,
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
