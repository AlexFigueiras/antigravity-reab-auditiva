import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/sentence_bank.dart';
import '../../core/environments.dart';
import '../../models/audiogram.dart';
import '../../models/rehab_session.dart';
import '../../services/audio_service_manager.dart';
import '../../services/locale_controller.dart';
import '../../services/supabase_service.dart';
import '../widgets/seu_joao_scene.dart';
import '../../core/adaptive_staircase.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/audio_accessibility.dart';

import '../widgets/volume_drift_banner.dart';

/// MÓDULO DE FRASES (Fase 3): compreensão de frases do dia a dia em ruído,
/// agora dentro da narrativa "Ajude o Seu João" num ambiente específico
/// (restaurante, academia, praça, mercado). Staircase adaptativo de SNR (±2dB)
/// com ~10 tentativas e cálculo de SRT.
class SentenceTrainingScreen extends StatefulWidget {
  final Audiogram audiogram;
  final TrainingEnvironment environment;
  const SentenceTrainingScreen({
    super.key,
    required this.audiogram,
    required this.environment,
  });

  @override
  State<SentenceTrainingScreen> createState() => _SentenceTrainingScreenState();
}

class _SentenceTrainingScreenState extends State<SentenceTrainingScreen> {
  final SupabaseService _supabase = SupabaseService();

  late final AdaptiveStaircase _staircase;
  double _currentSnr = 15.0;
  int _currentTrial = 0;
  final int _maxTrials = 10;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  Map<String, String>? _currentSentence;
  List<String> _options = [];
  bool _canRespond = false;
  bool _volumeDriftWarning = false;
  JoaoMood _mood = JoaoMood.idle;
  String? _feedbackText;

  late final List<Map<String, String>> _pool;
  // Fila embaralhada: toca todas as frases antes de repetir qualquer uma, e
  // nunca repete a mesma logo em seguida. Evita a sensação de "frases repetidas".
  final List<Map<String, String>> _queue = [];

  final List<Map<String, dynamic>> _sessionLog = [];

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _staircase = AdaptiveStaircase(
      start: 15.0,
      floor: 0.0,
      ceiling: 20.0,
      stepDown: 2.0,
      stepUp: 3.0,
      minReversalsForEstimate: 6,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final lang = context.read<LocaleController>().audioLanguageCode;
    if (lang == 'en') {
      _pool = SENTENCE_BANK_BY_ENV_EN[widget.environment.key] ?? allSentencesEn;
    } else {
      _pool = SENTENCE_BANK_BY_ENV[widget.environment.key] ?? allSentences;
    }
    _init();
  }

  Future<void> _init() async {
    await AudioServiceManager().initializeEngineForUser(widget.audiogram);
    // Carrega a ambiência do lugar (restaurante/academia/praça/mercado) no
    // looper nativo antes do primeiro estímulo, para o som de fundo ser o certo.
    AudioServiceManager().engine.loadAmbience(widget.environment.key);
    if (mounted) _startTrial();
  }

  /// Próxima frase da fila embaralhada. Quando a fila esvazia, reembaralha o
  /// banco inteiro garantindo que a primeira nova não seja igual à última tocada.
  Map<String, String> _nextSentence() {
    if (_queue.isEmpty) {
      // Cópia modificável — _pool é a lista CONST de SENTENCE_BANK_BY_ENV e não
      // pode ser embaralhada no lugar (lança "Cannot modify an unmodifiable list").
      final shuffled = List<Map<String, String>>.from(_pool)..shuffle();
      _queue.addAll(shuffled);
      if (_queue.length > 1 && _currentSentence != null &&
          _queue.first['target'] == _currentSentence!['target']) {
        _queue.add(_queue.removeAt(0)); // joga a repetida para o fim
      }
    }
    return _queue.removeAt(0);
  }

  @override
  void dispose() {
    AudioServiceManager().forceStopAll();
    super.dispose();
  }

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }
    _currentSentence = _nextSentence();
    _options = [
      _currentSentence!['target']!,
      _currentSentence!['distractor']!,
    ]..shuffle();

    setState(() {
      _canRespond = false;
      _feedbackText = null;
      _mood = JoaoMood.listening;
    });
    _playStimulus();
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

  void _playStimulus() async {
    if (!await _verifyVolume()) return;
    await AudioServiceManager().engine.playCocktailStimulus(
          text: _currentSentence!['target']!,
          snrDb: _currentSnr,
          noiseEnvironment: widget.environment.key,
          ambienceKey: widget.environment.key,
        );
    if (mounted) setState(() => _canRespond = true);
  }

  void _handleResponse(String selected) {
    if (!_canRespond) return;
    final target = _currentSentence!['target']!;
    final isCorrect = selected == target;

    _staircase.respond(isCorrect);
    _currentSnr = _staircase.current;

    if (isCorrect) {
      _correctAnswers++;
    }

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'pair': target,
      'snr': _currentSnr,
      'correct': isCorrect,
    });

    final l10n = AppLocalizations.of(context);
    setState(() {
      _currentTrial++;
      _canRespond = false;
      _mood = isCorrect ? JoaoMood.happy : JoaoMood.sad;
      _feedbackText = isCorrect
          ? l10n.sentenceFeedbackCorrect
          : l10n.sentenceFeedbackWrong(target);
    });

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _startTrial();
    });
  }

  /// SRT = média do SNR nas reversões, ignorando a primeira quando há ≥2.
  double _calculateSRT() {
    return _staircase.estimate ?? _staircase.current;
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    final srt = _calculateSRT();
    final session = RehabSession(
      patientId: widget.audiogram.patientId,
      date: DateTime.now(),
      level: RehabLevel.speechInNoise,
      totalTrials: _maxTrials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: duration / _maxTrials,
      metadata: {
        'log': _sessionLog,
        'duration_ms': duration,
        'final_snr': _currentSnr,
        'srt': srt,
        'module': 'sentences',
        'environment': widget.environment.key,
      },
    );

    try {
      await _supabase.saveRehabSession(session);
      if (mounted) await _showResultDialog(srt);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showResultDialog(double srt) async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(l10n.sentenceResultDialogTitle,
            style: TextStyle(color: cs.onSurface, fontSize: 20)),
        content: Text(
          l10n.sentenceResultDialogBody(widget.environment.localizedTitle(context), srt.toStringAsFixed(0)),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.sentenceResultDialogUnderstood,
                style: TextStyle(
                    color: widget.environment.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.environment;
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(env.localizedTitle(context)),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.3,
            colors: [
              env.color.withValues(alpha: 0.18),
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _progressRow(env, l10n),
                const SizedBox(height: 12),
                if (_volumeDriftWarning)
                  VolumeDriftBanner(
                    margin: const EdgeInsets.only(bottom: 12),
                    onResume: () {
                      if (mounted) {
                        setState(() => _volumeDriftWarning = false);
                        _playStimulus();
                      }
                    },
                  ),
                const Spacer(),
                SeuJoaoScene(environment: env, mood: _mood),
                const SizedBox(height: 16),
                // Fala de abertura / feedback do Seu João.
                Text(
                  _feedbackText ?? env.localizedOpening(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _feedbackText == null
                        ? cs.onSurfaceVariant
                        : (_mood == JoaoMood.happy
                            ? cs.tertiary
                            : Colors.orangeAccent),
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Text(l10n.sentenceWhichSentence,
                    style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                ..._options.map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.surface,
                            disabledBackgroundColor:
                                cs.surface.withValues(alpha: 0.5),
                            minimumSize: const Size(0, 76),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: env.color.withValues(alpha: 0.35))),
                          ),
                          onPressed:
                              (_canRespond && !_volumeDriftWarning) ? () => _handleResponse(opt) : null,
                          child: Text(opt,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                // Ouvir de novo (não muda o SNR — só repete a frase).
                TextButton.icon(
                  onPressed: (_canRespond && !_volumeDriftWarning) ? _playStimulus : null,
                  icon: Icon(Icons.replay,
                      color: (_canRespond && !_volumeDriftWarning) ? env.color : cs.onSurfaceVariant),
                  label: Text(l10n.dashboardListenAgain,
                      style: TextStyle(
                          color: (_canRespond && !_volumeDriftWarning) ? env.color : cs.onSurfaceVariant,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressRow(TrainingEnvironment env, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
            l10n.sentenceTrainingProgress(
                "${(_currentTrial + 1).clamp(1, _maxTrials)}", "$_maxTrials"),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: env.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(l10n.sentenceNoiseLevel("${_currentSnr.toInt()}"),
              style: TextStyle(
                  color: env.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
