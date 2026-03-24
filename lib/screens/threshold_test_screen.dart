import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  double _currentDb = 40.0;
  bool _heardOnce = false;
  double _lastHeardDb = 40.0;
  
  final List<AudiometryPoint> _recollectedPoints = [];

  bool _isTesting = false;
  bool _testFinished = false;

  void _startFrequencyTest() async {
    setState(() {
      _isTesting = true;
      _testFinished = false;
      _currentDb = 40.0; // Inicia em intensidade audível segura (40dB HL)
      _heardOnce = false;
      _lastHeardDb = 40.0;
    });
    _playCurrentTestTone();
  }

  void _playCurrentTestTone() {
    _engine.playPureTone(
      frequencyHz: _frequencies[_currentFreqIndex],
      durationMs: 1500,
      dbLevel: _currentDb,
    );
  }

  void _onResponse(bool detected) {
    if (detected) {
      // Ouviu normalmente
      _heardOnce = true;
      _lastHeardDb = _currentDb;
      
      if (_currentDb <= 0.0) {
        // Se chegou no limite inferior normal, encerra esta frequência
        _recordThresholdAndNext(0.0);
      } else {
        // Vai descendo 5dB até o paciente não ouvir mais
        setState(() {
          _currentDb -= 5.0; 
        });
        _playCurrentTestTone();
      }
    } else {
      if (!_heardOnce) {
        // Se não ouviu o volume inicial de 40dB, tem perda nesta frequência. Vai aumentando.
        setState(() {
          _currentDb += 5.0;
        });
        _playCurrentTestTone();
      } else {
        // Parou de ouvir após ir baixando o volume. Pega o valor audível anterior.
        _recordThresholdAndNext(_lastHeardDb);
      }
    }
  }

  void _recordThresholdAndNext(double thresholdDb) {
    _recollectedPoints.add(AudiometryPoint(
      frequency: _frequencies[_currentFreqIndex],
      threshold: thresholdDb,
    ));
    
    if (_currentFreqIndex < _frequencies.length - 1) {
      setState(() {
        _currentFreqIndex++;
        _currentDb = 40.0; // Reset para a pŕoxima frequência
        _heardOnce = false;
        _lastHeardDb = 40.0;
      });
      _playCurrentTestTone();
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
    setState(() {
      _isTesting = false;
      _testFinished = true;
    });
  }

  static Widget _topTitleWidget(double value, TitleMeta meta) {
    const freqs = ['250', '500', '1K', '2K', '4K', '8K'];
    int idx = value.toInt();
    if (idx >= 0 && idx < freqs.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(freqs[idx], style: const TextStyle(color: Colors.white54, fontSize: 10)),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        title: const Text(
          "CALIBRAÇÃO CLÍNICA", 
          style: TextStyle(letterSpacing: 2, fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.5,
            colors: [Color(0xFF1E1E24), Color(0xFF0D0D0F)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Container de Frequência Moderno
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(
                    "${_frequencies[_currentFreqIndex]} Hz",
                    style: const TextStyle(
                      fontSize: 64, 
                      fontWeight: FontWeight.w800, 
                      letterSpacing: -2,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "Frequência de Teste",
                    style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            // Intensidade com Glow sutil
            Text(
              "Intensidade: ${_currentDb.toInt()} dB HL",
              style: TextStyle(
                color: Colors.redAccent.shade100, 
                fontSize: 22, 
                fontWeight: FontWeight.w300,
                shadows: [
                  Shadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 20),
                ],
              ),
            ),
            const SizedBox(height: 80),
            
            const SizedBox(height: 80),
            
            if (!_isTesting && !_testFinished) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "METODOLOGIA DE CALIBRAGEM:\nAtive o volume do PC/Celular em 100%. O som começará audível (40dB) e diminuirá a cada 'SIM'. Quando o som desaparecer e você clicar 'NÃO', o sistema registrará seu último limiar ouvido e passará para a próxima frequência.",
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 250,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                  ),
                  onPressed: _startFrequencyTest, 
                  child: const Text("INICIAR PROTOCOLO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ] else if (_testFinished) ...[
              const Text(
                "CURVA DO AUDIOGRAMA", 
                style: TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                height: 300,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LineChart(
                  LineChartData(
                    minY: -120, // Inferior (Perda profunda)
                    maxY: 10,   // Superior (Audição excelente)
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(_recollectedPoints.length, (i) => FlSpot(i.toDouble(), -_recollectedPoints[i].threshold)),
                        isCurved: false,
                        color: Colors.blueAccent,
                        barWidth: 4,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: _ThresholdTestScreenState._topTitleWidget)
                      ),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text("${(-value).toInt()}dB", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        )
                      ),
                    ),
                    gridData: const FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 20),
                    borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.white10), left: BorderSide(color: Colors.white10))),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 250,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                  ),
                  onPressed: () => Navigator.pop(context, _recollectedPoints), 
                  child: const Text("SALVAR E VOLTAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ] else ...[
              const Text(
                "Você percebeu o estímulo sonoro?", 
                style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _ResponseButton(
                    label: "NÃO", 
                    color: const Color(0xFF1E1E24), 
                    textColor: Colors.white60,
                    onPressed: () => _onResponse(false),
                  ),
                  const SizedBox(width: 40),
                  _ResponseButton(
                    label: "SIM", 
                    color: const Color(0xFF2563EB), 
                    textColor: Colors.white,
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
  final Color textColor;
  final VoidCallback onPressed;
  
  const _ResponseButton({
    required this.label, 
    required this.color, 
    required this.textColor,
    required this.onPressed
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 25,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: const CircleBorder(),
          elevation: 0,
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        onPressed: onPressed,
        child: Text(
          label, 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
