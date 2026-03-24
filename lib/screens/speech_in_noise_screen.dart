import 'dart:math';
import 'package:flutter/material.dart';
import '../audio_engine/audio_engine.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../models/phonemic_pair.dart'; // Reutilizar pares para identificação rápida
import '../services/supabase_service.dart';

class SpeechInNoiseScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SpeechInNoiseScreen({super.key, required this.audiogram});

  @override
  State<SpeechInNoiseScreen> createState() => _SpeechInNoiseScreenState();
}

class _SpeechInNoiseScreenState extends State<SpeechInNoiseScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  
  double _currentSnr = 15.0; // Inicia facilitado (+15dB)
  int _currentTrial = 0;
  final int _maxTrials = 12;
  int _correctAnswers = 0;
  DateTime _sessionStart = DateTime.now();
  
  PhonemicPair? _currentPair;
  List<String> _options = [];
  bool _canRespond = false;
  
  final List<Map<String, dynamic>> _sessionLog = [];

  @override
  void initState() {
    super.initState();
    _startTrial();
  }

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }

    final random = Random();
    _currentPair = phonemicPairs[random.nextInt(phonemicPairs.length)];
    _options = [_currentPair!.target, _currentPair!.distractor]..shuffle();
    
    setState(() => _canRespond = false);
    _playStimulus();
  }

  void _playStimulus() async {
    // NÍVEL 4: Mixagem dinâmica de Sinal + Ruído Sintético
    await _engine.playSpeechInNoise(
      targetText: _currentPair!.target,
      snrDb: _currentSnr,
    );
    
    setState(() => _canRespond = true);
  }

  void _handleResponse(String selected) {
    if (!_canRespond) return;

    final isCorrect = selected == _currentPair!.target;
    if (isCorrect) {
      _correctAnswers++;
      // Lógica de Plasticidade: Se acertou, dificulta o SNR (-2dB)
      _currentSnr -= 2.0;
    } else {
      // Se errou, facilita o SNR (+2dB) para manter motivação e aprendizado
      _currentSnr += 2.0;
    }

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'pair': _currentPair!.target,
      'snr': _currentSnr,
      'correct': isCorrect,
    });

    setState(() => _currentTrial++);
    _startTrial();
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
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
      },
    );

    try {
      await _supabase.saveRehabSession(session);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: const Text("NÍVEL 4: EFEITO COQUETEL"),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Indicador de Dificuldade SNR
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("DIFICULDADE ADAPTATIVA (SNR)", style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                  Text("${_currentSnr.toInt()} dB", style: TextStyle(color: _currentSnr < 5 ? Colors.orange : Colors.greenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Spacer(),
            const Icon(Icons.forum, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 32),
            const Text("Compreensão em Ruído", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Identifique a palavra no meio do som ambiente", style: TextStyle(color: Colors.grey)),
            const Spacer(),
            Row(
              children: _options.map((opt) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E24),
                      minimumSize: const Size(0, 100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _handleResponse(opt),
                    child: Text(opt, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
