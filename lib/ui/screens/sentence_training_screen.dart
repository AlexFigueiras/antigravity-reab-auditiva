import 'package:flutter/material.dart';
import '../../core/sentence_bank.dart';
import '../../core/environments.dart';
import '../../models/audiogram.dart';
import '../../models/rehab_session.dart';
import '../../services/audio_service_manager.dart';
import '../../services/supabase_service.dart';
import '../widgets/seu_joao_scene.dart';
import '../../core/adaptive_staircase.dart';

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
  JoaoMood _mood = JoaoMood.idle;
  String? _feedbackText;

  late final List<Map<String, String>> _pool;
  // Fila embaralhada: toca todas as frases antes de repetir qualquer uma, e
  // nunca repete a mesma logo em seguida. Evita a sensação de "frases repetidas".
  final List<Map<String, String>> _queue = [];

  final List<Map<String, dynamic>> _sessionLog = [];
  final List<double> _reversals = [];
  bool? _lastCorrect;

  @override
  void initState() {
    super.initState();
    _pool = SENTENCE_BANK_BY_ENV[widget.environment.key] ?? allSentences;
    _staircase = AdaptiveStaircase(
      start: 15.0,
      floor: 0.0,
      ceiling: 20.0,
      stepDown: 2.0,
      stepUp: 3.0,
      minReversalsForEstimate: 6,
    );
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

  void _playStimulus() async {
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

    setState(() {
      _currentTrial++;
      _canRespond = false;
      _mood = isCorrect ? JoaoMood.happy : JoaoMood.sad;
      _feedbackText = isCorrect
          ? 'Isso! O Seu João entendeu.'
          : 'Quase. Era "$target".';
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2128),
        title: const Text("Você ajudou bastante o Seu João!",
            style: TextStyle(color: Colors.white, fontSize: 20)),
        content: Text(
          "No ${widget.environment.title.toLowerCase()}, o Seu João entendeu as "
          "frases com até ${srt.toStringAsFixed(0)} dB de barulho de fundo. "
          "Quanto menor esse número, melhor ele ouve no meio do barulho. "
          "Continue treinando!",
          style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Entendi",
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: Text(env.title),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.3,
            colors: [
              env.color.withValues(alpha: 0.18),
              const Color(0xFF0D0D0F),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _progressRow(env),
                const Spacer(),
                SeuJoaoScene(environment: env, mood: _mood),
                const SizedBox(height: 16),
                // Fala de abertura / feedback do Seu João.
                Text(
                  _feedbackText ?? env.joaoOpening,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _feedbackText == null
                        ? Colors.white70
                        : (_mood == JoaoMood.happy
                            ? const Color(0xFF3FB37F)
                            : Colors.orangeAccent),
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Qual frase ele ouviu?",
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                ..._options.map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B2128),
                            disabledBackgroundColor:
                                const Color(0xFF1B2128).withValues(alpha: 0.5),
                            minimumSize: const Size(0, 76),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: env.color.withValues(alpha: 0.35))),
                          ),
                          onPressed:
                              _canRespond ? () => _handleResponse(opt) : null,
                          child: Text(opt,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                // Ouvir de novo (não muda o SNR — só repete a frase).
                TextButton.icon(
                  onPressed: _canRespond ? _playStimulus : null,
                  icon: Icon(Icons.replay,
                      color: _canRespond ? env.color : Colors.white24),
                  label: Text("Ouvir de novo",
                      style: TextStyle(
                          color: _canRespond ? env.color : Colors.white24,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressRow(TrainingEnvironment env) {
    return Row(
      children: [
        Text("Frase ${(_currentTrial + 1).clamp(1, _maxTrials)} de $_maxTrials",
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: env.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text("Barulho: ${_currentSnr.toInt()} dB",
              style: TextStyle(
                  color: env.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
