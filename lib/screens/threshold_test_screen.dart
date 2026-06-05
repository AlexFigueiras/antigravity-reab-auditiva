import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../audio_engine/audio_engine.dart';
import '../models/audiogram.dart';
import '../services/audio_accessibility.dart';

class ThresholdTestScreen extends StatefulWidget {
  const ThresholdTestScreen({super.key});

  @override
  State<ThresholdTestScreen> createState() => _ThresholdTestScreenState();
}

class _ThresholdTestScreenState extends State<ThresholdTestScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final List<int> _frequencies = [250, 500, 1000, 2000, 4000, 8000];
  
  // Controle de Estado do Teste
  EarSide _currentEar = EarSide.left;
  int _currentFreqIndex = 0;
  double _currentDb = 40.0;
  bool _heardOnce = false;
  double _lastHeardDb = 40.0;
  
  // Resultados Separados por Orelha
  final List<AudiometryPoint> _leftEarPoints = [];
  final List<AudiometryPoint> _rightEarPoints = [];

  bool _isTesting = false;
  bool _testFinished = false;

  // Escolha de ouvido: o usuário decide qual lado testar (null = nada escolhido).
  bool _earChosen = false;
  // Quais orelhas já foram concluídas (para guiar o usuário a fazer as duas).
  final Set<EarSide> _completedEars = {};

  // Acessibilidade: "Áudio mono" do Android invalida o teste (toca igual nos
  // dois ouvidos). Detectamos e avisamos.
  bool _monoAudioOn = false;

  @override
  void initState() {
    super.initState();
    // Inicia o motor para o teste (mesmo que com audiograma em branco inicialmente)
    _engine.initializeEngine(Audiogram(
      id: "TEMP_CALIBRATION",
      patientId: "TEMP_CALIBRATION",
      date: DateTime.now(),
      leftEar: [],
      rightEar: [],
    ));
    _checkMonoAudio();
  }

  Future<void> _checkMonoAudio() async {
    final mono = await AudioAccessibility.isMonoAudioEnabled();
    if (mounted) setState(() => _monoAudioOn = mono);
  }

  void _chooseEar(EarSide ear) {
    setState(() {
      _currentEar = ear;
      _earChosen = true;
      // Recomeça do grave (250 Hz): reseta o índice de frequência para 0.
      // Sem isto, a orelha seguinte começava em 8000 Hz (resto da sessão anterior).
      _currentFreqIndex = 0;
      // Refaz os pontos desta orelha se ela já tinha sido testada.
      if (ear == EarSide.left) {
        _leftEarPoints.clear();
      } else {
        _rightEarPoints.clear();
      }
    });
    _startFrequencyTest();
  }

  Widget _buildEarChooser() {
    // Espaço para não ficar atrás da AppBar transparente (evita sobreposição
    // do título "Teste de audição" com a pergunta abaixo).
    final topGap = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, topGap, 24, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Qual ouvido você quer testar?",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Coloque os fones. Vamos testar um ouvido de cada vez.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 28),

          // Aviso de "Áudio mono" — invalida o teste.
          if (_monoAudioOn)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFFE11D48)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.hearing_disabled, color: Color(0xFFFF6B8A)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text("Áudio mono está ligado",
                          style: TextStyle(
                              color: Color(0xFFFF6B8A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    "Seu celular está tocando o mesmo som nos dois ouvidos, o que "
                    "atrapalha o teste. Desligue em:\n"
                    "Configurações → Acessibilidade → Áudio → Áudio mono.",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.45),
                  ),
                ],
              ),
            ),

          _earCard(EarSide.left),
          const SizedBox(height: 16),
          _earCard(EarSide.right),
          const SizedBox(height: 28),

          // Ver resultado (habilitado quando pelo menos uma orelha foi testada).
          if (_completedEars.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F8DF7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _finishTest,
                child: Text(
                  _completedEars.length == 2
                      ? "Ver resultado"
                      : "Ver resultado (só 1 ouvido testado)",
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earCard(EarSide ear) {
    final isLeft = ear == EarSide.left;
    final done = _completedEars.contains(ear);
    final color = isLeft ? Colors.blueAccent : Colors.redAccent;
    return InkWell(
      onTap: () => _chooseEar(ear),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(isLeft ? Icons.volume_up : Icons.volume_up,
                color: color, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isLeft ? "Ouvido esquerdo" : "Ouvido direito",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  Text(
                    done ? "Já testado — toque para refazer" : "Tocar para testar",
                    style: TextStyle(
                        color: done ? const Color(0xFF4CAF7D) : Colors.white54,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(done ? Icons.check_circle : Icons.chevron_right,
                color: done ? const Color(0xFF4CAF7D) : Colors.white38,
                size: 26),
          ],
        ),
      ),
    );
  }

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
      ear: _currentEar,
      dbLevel: _currentDb,
    );
  }

  void _onResponse(bool detected) {
    if (!_isTesting) return; // ignora toques fora de uma sessão ativa
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
        // Se não ouviu o volume inicial de 40dB, tem perda nesta frequência.
        // Vai aumentando até o limite audiométrico de 120 dB HL. Ao atingir
        // o teto sem resposta, registra "sem resposta" (120) e segue adiante,
        // evitando loop infinito em perdas profundas / setup incorreto.
        if (_currentDb >= 120.0) {
          _recordThresholdAndNext(120.0);
        } else {
          setState(() {
            _currentDb = (_currentDb + 5.0).clamp(0.0, 120.0);
          });
          _playCurrentTestTone();
        }
      } else {
        // Parou de ouvir após ir baixando o volume. Pega o valor audível anterior.
        _recordThresholdAndNext(_lastHeardDb);
      }
    }
  }

  void _recordThresholdAndNext(double thresholdDb) {
    final point = AudiometryPoint(
      frequency: _frequencies[_currentFreqIndex],
      threshold: thresholdDb,
    );
    
    if (_currentEar == EarSide.left) {
      _leftEarPoints.add(point);
    } else {
      _rightEarPoints.add(point);
    }
    
    if (_currentFreqIndex < _frequencies.length - 1) {
      // Próxima frequência na mesma orelha
      setState(() {
        _currentFreqIndex++;
        _currentDb = 40.0;
        _heardOnce = false;
        _lastHeardDb = 40.0;
      });
      _playCurrentTestTone();
    } else {
      // Terminou esta orelha. Volta para a escolha (o usuário decide se faz a
      // outra ou finaliza) — fluxo explícito e fácil de acompanhar.
      setState(() {
        _completedEars.add(_currentEar);
        _isTesting = false;
        _earChosen = false;
      });
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
          "Teste de audição",
          style: TextStyle(letterSpacing: 1, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
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
        child: (!_earChosen && !_testFinished)
            ? _buildEarChooser()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicador grande do ouvido em teste (◀ esquerdo / direito ▶)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentEar == EarSide.left)
                  const Icon(Icons.volume_up, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 8),
                Text(
                  _currentEar == EarSide.left ? "◀  OUVIDO ESQUERDO" : "OUVIDO DIREITO  ▶",
                  style: TextStyle(
                    color: _currentEar == EarSide.left ? Colors.blueAccent : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                if (_currentEar == EarSide.right)
                  const Icon(Icons.volume_up, color: Colors.redAccent, size: 28),
              ],
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 60),

            if (_testFinished) ...[
              const Text(
                "Resultado do teste", 
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
                      // ORELHA ESQUERDA (AZUL)
                      LineChartBarData(
                        spots: List.generate(_leftEarPoints.length, (i) => FlSpot(i.toDouble(), -_leftEarPoints[i].threshold)),
                        isCurved: false,
                        color: Colors.blueAccent,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                      // ORELHA DIREITA (VERMELHA)
                      LineChartBarData(
                        spots: List.generate(_rightEarPoints.length, (i) => FlSpot(i.toDouble(), -_rightEarPoints[i].threshold)),
                        isCurved: false,
                        color: Colors.redAccent,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 30, 
                          interval: 1, // Impede a repetição de rótulos entre pontos
                          getTitlesWidget: _ThresholdTestScreenState._topTitleWidget
                        )
                      ),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 20, // Grid clínico padrão de 20dB
                          getTitlesWidget: (value, meta) => Text("${(-value).toInt()}dB", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        )
                      ),
                    ),
                    gridData: const FlGridData(
                      show: true, 
                      drawVerticalLine: true, 
                      horizontalInterval: 20,
                      verticalInterval: 1, // Sincroniza grid com frequências
                    ),
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
                  onPressed: () => Navigator.pop(context, {
                    'left': _leftEarPoints,
                    'right': _rightEarPoints,
                  }), 
                  child: const Text("Salvar e voltar", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
