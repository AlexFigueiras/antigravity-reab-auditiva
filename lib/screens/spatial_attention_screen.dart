import 'dart:math';
import 'package:flutter/material.dart';
import '../audio_engine/audio_engine.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/supabase_service.dart';

enum SpatialDirection { left, center, right }

class SpatialAttentionScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SpatialAttentionScreen({super.key, required this.audiogram});

  @override
  State<SpatialAttentionScreen> createState() => _SpatialAttentionScreenState();
}

class _SpatialAttentionScreenState extends State<SpatialAttentionScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  
  int _currentTrial = 0;
  final int _maxTrials = 12;
  int _correctAnswers = 0;
  DateTime _sessionStart = DateTime.now();
  
  SpatialDirection? _targetDirection;
  bool _canRespond = false;
  
  final List<String> _stimuli = [
    'Faca', 
    'Saca', 
    'Pato',
    'Tato',
  ];

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
    // 0 = Esquerda, 1 = Centro, 2 = Direita
    int dirIndex = random.nextInt(3);
    _targetDirection = SpatialDirection.values[dirIndex];
    
    setState(() {
      _canRespond = false;
    });

    _playSpatialSound();
  }

  void _playSpatialSound() async {
    double pan = 0.0;
    if (_targetDirection == SpatialDirection.left) pan = -1.0;
    if (_targetDirection == SpatialDirection.right) pan = 1.0;

    final randomText = _stimuli[Random().nextInt(_stimuli.length)];

    await _engine.playSpatialStimulus(
      text: randomText,
      panning: pan,
    );
    
    setState(() {
      _canRespond = true;
    });
  }

  void _handleResponse(SpatialDirection selected) {
    if (!_canRespond) return;

    final isCorrect = selected == _targetDirection;
    if (isCorrect) _correctAnswers++;

    setState(() {
      _currentTrial++;
    });

    _startTrial();
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    
    final session = RehabSession(
      patientId: widget.audiogram.patientId,
      date: DateTime.now(),
      level: RehabLevel.spatialAttention,
      totalTrials: _maxTrials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: duration / _maxTrials,
    );

    try {
      await _supabase.saveRehabSession(session);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Treino Espacial Concluído"),
            content: Text("Acertos: $_correctAnswers / $_maxTrials\nPrecisão: ${session.accuracy.toStringAsFixed(1)}%"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Sair")),
            ],
          ),
        ).then((_) => Navigator.pop(context));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("NÍVEL 3: ATENÇÃO ESPACIAL"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "De onde veio o som?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 64),
          
          // Visualização de Headphones
          const Icon(Icons.headset, size: 100, color: Colors.blueAccent),
          const SizedBox(height: 64),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SpatialButton(
                label: "ESQUERDA",
                icon: Icons.chevron_left,
                onPressed: () => _handleResponse(SpatialDirection.left),
              ),
              const SizedBox(width: 20),
              _SpatialButton(
                label: "CENTRO",
                icon: Icons.center_focus_strong,
                onPressed: () => _handleResponse(SpatialDirection.center),
              ),
              const SizedBox(width: 20),
              _SpatialButton(
                label: "DIREITA",
                icon: Icons.chevron_right,
                onPressed: () => _handleResponse(SpatialDirection.right),
              ),
            ],
          ),
          
          const SizedBox(height: 80),
          Text(
            "Sessão: ${_currentTrial + 1} / $_maxTrials",
            style: const TextStyle(color: Colors.grey, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _SpatialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SpatialButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: const BorderSide(color: Colors.white10),
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 32, color: Colors.blueAccent),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
