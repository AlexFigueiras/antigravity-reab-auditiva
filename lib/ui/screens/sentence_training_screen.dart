import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/sentence_bank.dart';
import '../../models/audiogram.dart';
import '../../models/rehab_session.dart';
import '../../services/audio_service_manager.dart';
import '../../services/supabase_service.dart';

/// MÓDULO DE FRASES (Fase 3): compreensão de frases do dia a dia em ruído.
/// Staircase adaptativo de SNR (±2dB) com ~10 tentativas e cálculo de SRT.
class SentenceTrainingScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SentenceTrainingScreen({super.key, required this.audiogram});

  @override
  State<SentenceTrainingScreen> createState() => _SentenceTrainingScreenState();
}

class _SentenceTrainingScreenState extends State<SentenceTrainingScreen> {
  final SupabaseService _supabase = SupabaseService();

  double _currentSnr = 15.0;
  int _currentTrial = 0;
  final int _maxTrials = 10;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  Map<String, dynamic>? _currentSentence;
  List<String> _options = [];
  bool _canRespond = false;

  final List<Map<String, dynamic>> _sessionLog = [];
  final List<double> _reversals = [];
  bool? _lastCorrect;

  @override
  void initState() {
    super.initState();
    AudioServiceManager().initializeEngineForUser(widget.audiogram);
    _startTrial();
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
    final random = Random();
    _currentSentence = SENTENCE_BANK[random.nextInt(SENTENCE_BANK.length)];
    _options = [
      _currentSentence!['target'] as String,
      _currentSentence!['distractor'] as String,
    ]..shuffle();

    setState(() => _canRespond = false);
    _playStimulus();
  }

  void _playStimulus() async {
    await AudioServiceManager().engine.playCocktailStimulus(
          text: _currentSentence!['target'] as String,
          snrDb: _currentSnr,
          noiseEnvironment: 'RESTAURANTE',
        );
    if (mounted) setState(() => _canRespond = true);
  }

  void _handleResponse(String selected) {
    if (!_canRespond) return;
    final target = _currentSentence!['target'] as String;
    final isCorrect = selected == target;

    if (_lastCorrect != null && _lastCorrect != isCorrect) {
      _reversals.add(_currentSnr);
    }
    _lastCorrect = isCorrect;

    if (isCorrect) {
      _correctAnswers++;
      _currentSnr -= 2.0;
    } else {
      _currentSnr += 2.0;
    }

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'pair': target,
      'snr': _currentSnr,
      'correct': isCorrect,
    });

    setState(() => _currentTrial++);
    _startTrial();
  }

  /// SRT = média do SNR nas reversões, ignorando a primeira quando há ≥2.
  double _calculateSRT() {
    if (_reversals.length < 2) {
      return _reversals.isNotEmpty ? _reversals.last : _currentSnr;
    }
    final relevant = _reversals.sublist(1);
    final sum = relevant.reduce((a, b) => a + b);
    return sum / relevant.length;
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
        'final_snr': _currentSnr,
        'srt': srt,
        'module': 'sentences',
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Muito bem!", style: TextStyle(color: Colors.white)),
        content: Text(
          "Você entendeu as frases com até ${srt.toStringAsFixed(0)} dB de "
          "barulho de fundo. Quanto menor esse número, melhor você ouve no "
          "meio do barulho. Continue treinando!",
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Entendi",
                style: TextStyle(color: Color(0xFF00FF41), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: const Text("Frases do dia a dia"),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Barulho de fundo",
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text("${_currentSnr.toInt()} dB",
                      style: TextStyle(
                          color: _currentSnr < 5
                              ? Colors.orange
                              : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            const Spacer(),
            const Icon(Icons.record_voice_over,
                size: 80, color: Colors.blueAccent),
            const SizedBox(height: 32),
            const Text("Qual frase você ouviu?",
                style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Toque na frase que você entendeu",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const Spacer(),
            ..._options.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E24),
                        minimumSize: const Size(0, 80),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _canRespond ? () => _handleResponse(opt) : null,
                      child: Text(opt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
