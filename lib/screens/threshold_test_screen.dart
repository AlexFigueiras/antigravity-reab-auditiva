import 'package:flutter/material.dart';
import '../audio_engine/audio_engine.dart';
import '../models/audiogram.dart';

class ThresholdTestScreen extends StatefulWidget {
  const ThresholdTestScreen({super.key});

  @override
  State<ThresholdTestScreen> createState() => _ThresholdTestScreenState();
}

class _ThresholdTestScreenState extends State<ThresholdTestScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final List<int> _frequencies = [250, 500, 1000, 2000, 4000, 8000];
  int _currentFreqIndex = 0;
  double _currentDb = 0.0;
  
  final List<AudiometryPoint> _recollectedPoints = [];

  bool _isTesting = false;

  void _startFrequencyTest() async {
    setState(() {
      _isTesting = true;
      _currentDb = 0.0; // Inicia em 0dB HL
    });
    _playCurrentTestTone();
  }

  void _playCurrentTestTone() {
    _engine.playPureTone(
      frequencyHz: _frequencies[_currentFreqIndex],
      durationMs: 1500,
    );
  }

  void _onResponse(bool detected) {
    if (detected) {
      // Registrar limiar e pular para próxima frequência
      _recollectedPoints.add(AudiometryPoint(
        frequency: _frequencies[_currentFreqIndex],
        threshold: _currentDb,
      ));
      
      if (_currentFreqIndex < _frequencies.length - 1) {
        setState(() {
          _currentFreqIndex++;
          _currentDb = 0.0;
        });
        _playCurrentTestTone();
      } else {
        _finishTest();
      }
    } else {
      // Aumentar intensidade do som (Escada de Hughson-Westlake simplificada)
      setState(() {
        _currentDb += 5.0;
      });
      _playCurrentTestTone();
    }
  }

  void _finishTest() {
    setState(() => _isTesting = false);
    // Salvar no estado global ou exibir sumário
    print("Teste Concluído: $_recollectedPoints");
    Navigator.pop(context, _recollectedPoints);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text("CALIBRAÇÃO")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${_frequencies[_currentFreqIndex]} Hz",
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Intensidade Detectada: ${_currentDb.toInt()} dB HL",
              style: TextStyle(color: Colors.redAccent.shade100, fontSize: 18),
            ),
            const SizedBox(height: 64),
            
            if (!_isTesting)
              ElevatedButton(
                onPressed: _startFrequencyTest, 
                child: const Text("INICIAR CALIBRAÇÃO"),
              )
            else ...[
              const Text("Você ouviu o som?", style: TextStyle(fontSize: 20)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ResponseButton(
                    label: "NÃO", 
                    color: Colors.grey, 
                    onPressed: () => _onResponse(false),
                  ),
                  const SizedBox(width: 24),
                  _ResponseButton(
                    label: "SIM", 
                    color: Colors.blueAccent, 
                    onPressed: () => _onResponse(true),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  
  const _ResponseButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
