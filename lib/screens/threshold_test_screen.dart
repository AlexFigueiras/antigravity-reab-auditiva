import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../audio_engine/audio_engine.dart';
import '../core/listening_mode.dart';
import '../models/audiogram.dart';
import '../services/audio_accessibility.dart';
import '../services/supabase_service.dart';
import '../ui/widgets/listening_mode_banner.dart';

class ThresholdTestScreen extends StatefulWidget {
  const ThresholdTestScreen({super.key});

  @override
  State<ThresholdTestScreen> createState() => _ThresholdTestScreenState();
}

class _ThresholdTestScreenState extends State<ThresholdTestScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  // Frequências audiométricas, incluindo as intermediárias (750/1500/3000/6000)
  // para um teste mais afinado. Ordem ascendente — o teste percorre da grave à aguda.
  final List<int> _frequencies = [
    250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000
  ];
  
  // Controle de Estado do Teste
  EarSide _currentEar = EarSide.left;
  int _currentFreqIndex = 0;
  double _currentDb = 40.0;
  bool _isFamiliarizing = true;
  bool _isCatchTrial = false;
  bool _wasLastCatchTrial = false;
  final Map<double, int> _positiveResponses = {};
  bool _isWaitingForNext = false;
  bool _isPlayingTone = false;
  Timer? _playbackTimer;
  Timer? _transitionTimer;

  
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

  // O teste de tom puro é SEMPRE feito SEM aparelho (a compressão do aparelho
  // invalida o limiar). Exigimos confirmação ativa antes de escolher a orelha. (0.4)
  bool _testConditionConfirmed = false;

  // Resultado já salvo: ao abrir a tela, em vez de recomeçar do zero, mostramos
  // o último teste feito (com o gráfico) e um botão "Refazer teste". Só quem
  // nunca testou cai direto no fluxo de escolher orelha.
  bool _loadingSaved = true;
  Audiogram? _savedAudiogram; // null = nenhum teste salvo ainda
  bool _showingSavedResult = false;

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
    _loadSavedAudiogram();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _transitionTimer?.cancel();
    _engine.stopTarget();
    super.dispose();
  }

  /// Carrega o último teste salvo. Se existir, abrimos direto na tela de
  /// resultado (a pessoa vê o que já fez e decide se refaz).
  Future<void> _loadSavedAudiogram() async {
    final saved = await SupabaseService().getLatestAudiogram();
    if (!mounted) return;
    setState(() {
      _savedAudiogram = saved;
      _showingSavedResult = saved != null;
      _loadingSaved = false;
    });
  }

  /// "Refazer teste": sai da tela de resultado e vai para a escolha de orelha,
  /// começando uma medição nova do zero.
  void _retakeTest() {
    setState(() {
      _showingSavedResult = false;
      _earChosen = false;
      _testFinished = false;
      _leftEarPoints.clear();
      _rightEarPoints.clear();
      _completedEars.clear();
    });
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

          // Instrução: o teste é SEMPRE sem aparelho, com confirmação ativa (0.4).
          ListeningModeBanner(
            mode: ListeningMode.unaided,
            confirmed: _testConditionConfirmed,
            onConfirmedChanged: (v) =>
                setState(() => _testConditionConfirmed = v),
          ),
          const SizedBox(height: 20),

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
    // Só libera a escolha da orelha após confirmar a condição (sem aparelho).
    final enabled = _testConditionConfirmed;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
      onTap: enabled ? () => _chooseEar(ear) : null,
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
      ),
    );
  }

  void _startFrequencyTest() async {
    setState(() {
      _isTesting = true;
      _testFinished = false;
      _currentDb = 40.0; // Inicia em tom de familiarização de 40 dB
      _isFamiliarizing = true;
      _isCatchTrial = false;
      _positiveResponses.clear();
    });
    _playCurrentTestTone();
  }

  void _playCurrentTestTone() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlayingTone = true;
    });

    if (_isFamiliarizing) {
      _isCatchTrial = false;
      _engine.playPureTone(
        frequencyHz: _frequencies[_currentFreqIndex],
        durationMs: 1500,
        ear: _currentEar,
        dbLevel: _currentDb,
      );
    } else {
      // 20% chance of catch trial, avoiding consecutive catch trials
      if (!_wasLastCatchTrial && math.Random().nextDouble() < 0.20) {
        _isCatchTrial = true;
        _wasLastCatchTrial = true;
        debugPrint("[CATCH_TRIAL] Silence presented at ${_frequencies[_currentFreqIndex]} Hz, $_currentDb dB");
      } else {
        _isCatchTrial = false;
        _wasLastCatchTrial = false;
        _engine.playPureTone(
          frequencyHz: _frequencies[_currentFreqIndex],
          durationMs: 1500,
          ear: _currentEar,
          dbLevel: _currentDb,
        );
      }
    }

    _playbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _isPlayingTone = false;
      });
    });
  }

  void _transitionToNext(VoidCallback stateUpdateAndPlay) {
    _engine.stopTarget();
    _playbackTimer?.cancel();
    _transitionTimer?.cancel();
    setState(() {
      _isWaitingForNext = true;
      _isPlayingTone = false;
    });
    _transitionTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isWaitingForNext = false;
        stateUpdateAndPlay();
      });
    });
  }

  void _onResponse(bool detected) {
    if (!_isTesting || _isWaitingForNext || _isPlayingTone) return; // ignora se não está testando ou se está no intervalo/tocando

    // Caso seja um catch trial (silêncio)
    if (_isCatchTrial) {
      _isCatchTrial = false;
      if (detected) {
        // Falso positivo detectado (ansiedade)
        _showCatchTrialWarning();
      }
      _transitionToNext(() {
        _playCurrentTestTone(); // repete ou continua com som real no mesmo nível
      });
      return;
    }

    if (_isFamiliarizing) {
      if (detected) {
        // Usuário confirmou que ouviu o tom de familiarização.
        // Inicia o teste real na orelha atual.
        _transitionToNext(() {
          _isFamiliarizing = false;
          _currentDb = 40.0; // Começa a busca do limiar a partir de 40 dB
          _playCurrentTestTone();
        });
      } else {
        // Não ouviu o tom de familiarização. Aumenta em passos de 10 dB até ouvir ou atingir 120 dB.
        if (_currentDb >= 120.0) {
          _recordThresholdAndNext(120.0);
        } else {
          _transitionToNext(() {
            _currentDb = (_currentDb + 10.0).clamp(-10.0, 120.0);
            _playCurrentTestTone();
          });
        }
      }
      return;
    }

    // --- Procedimento Hughson-Westlake adaptado ---
    if (detected) {
      // Acerto: descer 10 dB
      _positiveResponses[_currentDb] = (_positiveResponses[_currentDb] ?? 0) + 1;

      if (_positiveResponses[_currentDb] == 2) {
        // Limiar confirmado com 2 acertos no mesmo nível
        _recordThresholdAndNext(_currentDb);
        return;
      }

      _transitionToNext(() {
        _currentDb = (_currentDb - 10.0).clamp(-10.0, 120.0);
        _playCurrentTestTone();
      });
    } else {
      // Erro/Não ouviu: subir 5 dB
      if (_currentDb >= 120.0) {
        _recordThresholdAndNext(120.0);
      } else {
        _transitionToNext(() {
          _currentDb = (_currentDb + 5.0).clamp(-10.0, 120.0);
          _playCurrentTestTone();
        });
      }
    }
  }

  void _showCatchTrialWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amberAccent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Atenção: Nenhum som foi tocado agora. Por favor, responda apenas quando realmente ouvir o som.",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
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
      _transitionToNext(() {
        _currentFreqIndex++;
        _currentDb = 40.0;
        _isFamiliarizing = true;
        _positiveResponses.clear();
        _isCatchTrial = false;
        _playCurrentTestTone();
      });
    } else {
      // Terminou esta orelha. Volta para a escolha
      _engine.stopTarget();
      _playbackTimer?.cancel();
      _transitionTimer?.cancel();
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

  /// Gráfico do audiograma (azul = esquerdo, vermelho = direito). Reusado tanto
  /// no resultado recém-medido quanto no resultado salvo carregado do banco.
  Widget _audiogramChart(
      List<AudiometryPoint> leftPoints, List<AudiometryPoint> rightPoints) {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LineChart(
        LineChartData(
          minY: -120, // Inferior (Perda profunda)
          maxY: 10, // Superior (Audição excelente)
          lineBarsData: [
            // ORELHA ESQUERDA (AZUL)
            LineChartBarData(
              spots: List.generate(leftPoints.length,
                  (i) => FlSpot(i.toDouble(), -leftPoints[i].threshold)),
              isCurved: false,
              color: Colors.blueAccent,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
            // ORELHA DIREITA (VERMELHA)
            LineChartBarData(
              spots: List.generate(rightPoints.length,
                  (i) => FlSpot(i.toDouble(), -rightPoints[i].threshold)),
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
                    interval: 1,
                    getTitlesWidget:
                        _ThresholdTestScreenState._topTitleWidget)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) => Text("${(-value).toInt()}dB",
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
            )),
          ),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 20,
            verticalInterval: 1,
          ),
          borderData: FlBorderData(
              show: true,
              border: const Border(
                  bottom: BorderSide(color: Colors.white10),
                  left: BorderSide(color: Colors.white10))),
        ),
      ),
    );
  }

  /// Legenda do gráfico (azul = esquerdo, vermelho = direito).
  Widget _chartLegend() {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(Colors.blueAccent, "Ouvido esquerdo"),
        const SizedBox(width: 28),
        dot(Colors.redAccent, "Ouvido direito"),
      ],
    );
  }

  /// Tela de resultado do teste já salvo: mostra o gráfico do último teste e
  /// um botão "Refazer teste" embaixo.
  Widget _buildSavedResult() {
    final saved = _savedAudiogram!;
    final topGap = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    final d = saved.date;
    final dataStr =
        "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, topGap, 16, 32),
        child: Column(
          children: [
            const Text(
              "Seu último teste de audição",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Feito em $dataStr",
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 24),
            _audiogramChart(saved.leftEar, saved.rightEar),
            const SizedBox(height: 16),
            _chartLegend(),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _retakeTest,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Refazer teste",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Voltar",
                  style: TextStyle(color: Colors.white60, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _topTitleWidget(double value, TitleMeta meta) {
    // Rótulos casados com a lista de frequências (10 pontos: inclui as
    // intermediárias 750/1500/3000/6000). Mantém a ordem do eixo X.
    const freqs = [
      '250', '500', '750', '1K', '1.5K', '2K', '3K', '4K', '6K', '8K'
    ];
    int idx = value.toInt();
    if (idx >= 0 && idx < freqs.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(freqs[idx], style: const TextStyle(color: Colors.white54, fontSize: 9)),
      );
    }
    return const SizedBox.shrink();
  }

  Color get _earColor => _currentEar == EarSide.left ? Colors.blueAccent : Colors.redAccent;

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
        child: _loadingSaved
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F8DF7)))
            : _showingSavedResult
            ? _buildSavedResult()
            : (!_earChosen && !_testFinished)
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
            if (_isFamiliarizing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Fase de Familiarização",
                  style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            // Container de Frequência Moderno com Glow Animado e Feedback de Escuta
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: _isPlayingTone 
                    ? _earColor.withValues(alpha: 0.1) 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: _isPlayingTone 
                      ? _earColor 
                      : (_isWaitingForNext ? Colors.white24 : Colors.white10),
                  width: _isPlayingTone ? 2.0 : 1.0,
                ),
                boxShadow: _isPlayingTone
                    ? [
                        BoxShadow(
                          color: _earColor.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
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
            const SizedBox(height: 16),
            // Legenda clínica do estado de reprodução
            SizedBox(
              height: 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isWaitingForNext
                    ? const Text(
                        "Preparando próximo tom...",
                        key: ValueKey("status_preparing"),
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : _isPlayingTone
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            key: const ValueKey("status_listening"),
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _earColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Ouça com atenção...",
                                style: TextStyle(
                                  color: _earColor.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "Você ouviu o som?",
                            key: ValueKey("status_idle"),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              "Nível de som: ${_currentDb.toInt()}",
              style: TextStyle(
                color: Colors.redAccent.shade100, 
                fontSize: 22, 
                fontWeight: FontWeight.w300,
                shadows: [
                  Shadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 20),
                ],
              ),
            ),
            const SizedBox(height: 48),

            if (_testFinished) ...[
              const Text(
                "Resultado do teste", 
                style: TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _audiogramChart(_leftEarPoints, _rightEarPoints),
              const SizedBox(height: 16),
              _chartLegend(),
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
              Text(
                _isFamiliarizing 
                    ? "Você ouviu o som de teste?"
                    : "Você percebeu o estímulo sonoro?", 
                style: TextStyle(
                  fontSize: 18, 
                  color: (_isWaitingForNext || _isPlayingTone) ? Colors.white24 : Colors.white70, 
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _ResponseButton(
                    label: "NÃO", 
                    color: const Color(0xFF1E1E24), 
                    textColor: Colors.white60,
                    onPressed: (_isWaitingForNext || _isPlayingTone) ? null : () => _onResponse(false),
                  ),
                  const SizedBox(width: 40),
                  _ResponseButton(
                    label: "SIM", 
                    color: const Color(0xFF2563EB), 
                    textColor: Colors.white,
                    onPressed: (_isWaitingForNext || _isPlayingTone) ? null : () => _onResponse(true),
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
  final VoidCallback? onPressed;
  
  const _ResponseButton({
    required this.label, 
    required this.color, 
    required this.textColor,
    required this.onPressed
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? color : const Color(0xFF1E293B),
          foregroundColor: isEnabled ? textColor : Colors.white24,
          shape: const CircleBorder(),
          elevation: 0,
          side: BorderSide(color: Colors.white.withOpacity(isEnabled ? 0.1 : 0.05)),
        ),
        onPressed: onPressed,
        child: Text(
          label, 
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.5,
            color: isEnabled ? textColor : Colors.white24,
          ),
        ),
      ),
    );
  }
}
