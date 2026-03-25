import 'dart:math';
import 'package:flutter/material.dart';
import '../audio_engine/audio_engine.dart';
import '../audio_engine/native_engine.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../models/phonemic_pair.dart';
import '../services/supabase_service.dart';

class PhonemicDiscriminationScreen extends StatefulWidget {
  final Audiogram audiogram;
  const PhonemicDiscriminationScreen({super.key, required this.audiogram});

  @override
  State<PhonemicDiscriminationScreen> createState() => _PhonemicDiscriminationScreenState();
}

class _PhonemicDiscriminationScreenState extends State<PhonemicDiscriminationScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final NativeDSPBridge _hardwareBridge = NativeDSPBridge();
  final SupabaseService _supabase = SupabaseService();
  bool _isHardwareActive = false;

  
  int _currentTrial = 0;
  final int _maxTrials = 10;
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
    _playTarget();
  }

  void _playTarget() async {
    // Escolhe aleatoriamente se usa o alvo ou o distrator para o estímulo auditivo
    // mas a resposta correta continua sendo o alvo definido no par.
    // Na verdade, na discriminação clássica, tocamos o ALVO.
    await _engine.playPhonemicStimulus(
      text: _currentPair!.target,
    );
    setState(() => _canRespond = true);
  }

  void _handleResponse(String selected) {
    if (!_canRespond) return;

    final isCorrect = selected == _currentPair!.target;
    if (isCorrect) _correctAnswers++;

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'pair': "${_currentPair!.target}/${_currentPair!.distractor}",
      'selected': selected,
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
      level: RehabLevel.phonemicDiscrimination,
      totalTrials: _maxTrials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: duration / _maxTrials,
      metadata: {'log': _sessionLog},
    );

    try {
      await _supabase.saveRehabSession(session);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  void dispose() {
    _hardwareBridge.dispose();
    super.dispose();
  }

  void _toggleHardwareEngine() {
    setState(() {
      if (_isHardwareActive) {
        _hardwareBridge.stopHardwareAudio();
        _isHardwareActive = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Motor C++: DESLIGADO")));
      } else {
        bool started = _hardwareBridge.startHardwareAudio();
        _isHardwareActive = started;
        if (!started) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao inicializar DSP de Hardware.")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Motor C++ (Oboe/TEE) ATIVO!")));
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("NÍVEL 2: PROCESSO FONÊMICO"),
        actions: [
          // Hardware Native Hook Toggle
          IconButton(
            icon: Icon(
              Icons.memory, 
              color: _isHardwareActive ? Colors.greenAccent : Colors.grey,
            ),
            tooltip: 'Ligar Processador DSP Biônico',
            onPressed: _toggleHardwareEngine,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentTrial / _maxTrials,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PulseIcon(),
            const SizedBox(height: 48),
            const Text("Qual palavra você ouviu?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70)),
            const SizedBox(height: 64),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Row(
                key: ValueKey(_currentTrial),
                mainAxisAlignment: MainAxisAlignment.center,
                children: _options.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _AnimatedOptionCard(label: opt, onTap: () => _handleResponse(opt)),
                )).toList(),
              ),
            ),
            const SizedBox(height: 80),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.grey, size: 32), onPressed: _playTarget),
          ],
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon();

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent.withOpacity(0.05),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
        ),
        child: const Icon(Icons.hearing, size: 64, color: Colors.blueAccent),
      ),
    );
  }
}

class _AnimatedOptionCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AnimatedOptionCard({required this.label, required this.onTap});

  @override
  State<_AnimatedOptionCard> createState() => _AnimatedOptionCardState();
}

class _AnimatedOptionCardState extends State<_AnimatedOptionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 150,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(widget.label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}
