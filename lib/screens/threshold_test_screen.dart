import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../audio_engine/audio_engine.dart';
import '../core/listening_mode.dart';
import '../models/audiogram.dart';
import '../services/audio_accessibility.dart';
import '../services/supabase_service.dart';
import '../ui/widgets/listening_mode_banner.dart';
import '../ui/widgets/volume_drift_banner.dart';
import '../l10n/gen/app_localizations.dart';

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

  // Volume do sistema: o limiar só é válido se o volume de mídia estiver no
  // nível de referência fixo (mesmo do teste e dos treinos). Antes de liberar a
  // escolha da orelha, o usuário ajusta o volume com uma subida suave. Ver
  // AudioAccessibility.kReferenceVolumeFraction e o plano de trava de volume.
  bool _volumeReady = false;
  // Levantado quando, no meio do teste, o usuário baixou o volume pelo botão
  // físico (não dá pra impedir; dá pra detectar e pausar a medição).
  bool _volumeDriftWarning = false;

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
    _checkVolume();
    _loadSavedAudiogram();
  }

  /// Lê o volume atual ao abrir a tela. Se já estiver no nível de referência,
  /// libera direto (não força quem já está certo). Caso contrário, o gate de
  /// volume aparece e o usuário ajusta com a subida suave.
  Future<void> _checkVolume() async {
    final atLevel = await AudioAccessibility.isAtReferenceVolume();
    if (mounted) setState(() => _volumeReady = atLevel);
  }

  /// "Ajustar volume": faz a subida suave até o nível de referência e libera a
  /// escolha da orelha. Avisamos antes (no card) que o volume vai subir.
  Future<void> _prepareVolume() async {
    await AudioAccessibility.rampToReferenceVolume();
    if (mounted) {
      setState(() {
        _volumeReady = true;
        _volumeDriftWarning = false;
      });
    }
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
    final p = Theme.of(context).colorScheme;
    final topGap = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, topGap, 24, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context).thresholdTestWhichEar,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).thresholdTestPutHeadphones,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.onSurfaceVariant, fontSize: 16, height: 1.4),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.hearing_disabled, color: Color(0xFFFF6B8A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(AppLocalizations.of(context).thresholdTestMonoWarningTitle,
                          style: const TextStyle(
                              color: Color(0xFFFF6B8A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).thresholdTestMonoWarningBody,
                    style: TextStyle(
                        color: p.onSurfaceVariant, fontSize: 14, height: 1.45),
                  ),
                ],
              ),
            ),

          // Volume de referência: o teste só vale se o "nível de som" estiver no
          // ponto certo (o mesmo dos treinos). Subimos com aviso e suavemente.
          if (!_volumeReady)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.10),
                border: Border.all(color: p.primary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.volume_up, color: p.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(AppLocalizations.of(context).hearingTestVolumeCardTitle,
                          style: const TextStyle(
                              color: Color(0xFF9CC2FF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).hearingTestVolumeCardBody,
                    style: TextStyle(
                        color: p.onSurfaceVariant, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _prepareVolume,
                      child: Text(AppLocalizations.of(context).hearingTestAdjustVolume,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
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
                  backgroundColor: p.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _finishTest,
                child: Text(
                  _completedEars.length == 2
                      ? AppLocalizations.of(context).thresholdTestViewResult
                      : AppLocalizations.of(context).thresholdTestViewResultOneEar,
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
    final p = Theme.of(context).colorScheme;
    final isLeft = ear == EarSide.left;
    final done = _completedEars.contains(ear);
    final color = isLeft ? Colors.blueAccent : Colors.redAccent;
    // Só libera a escolha da orelha após confirmar a condição (sem aparelho) E
    // ajustar o volume ao nível de referência.
    final enabled = _testConditionConfirmed && _volumeReady;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
      onTap: enabled ? () => _chooseEar(ear) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface,
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
                  Text(isLeft
                      ? AppLocalizations.of(context).thresholdTestLeftEar
                      : AppLocalizations.of(context).thresholdTestRightEar,
                      style: TextStyle(
                          color: p.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  Text(
                    done
                        ? AppLocalizations.of(context).thresholdTestEarDone
                        : AppLocalizations.of(context).thresholdTestEarTap,
                    style: TextStyle(
                        color: done ? p.tertiary : p.onSurfaceVariant,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(done ? Icons.check_circle : Icons.chevron_right,
                color: done ? p.tertiary : p.onSurfaceVariant,
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
      _currentDb = 70.0; // Familiarização em 70 dB — audível para a maioria sem ser alto demais
      _isFamiliarizing = true;
      _isCatchTrial = false;
      _positiveResponses.clear();
    });
    await _playCurrentTestTone();
  }

  Future<void> _playCurrentTestTone() async {
    _playbackTimer?.cancel();

    // Vigilância de volume: se o usuário baixou o volume pelo botão físico no
    // meio do teste, a medição perde o referencial. Pausa e pede para voltar ao
    // nível antes de tocar o próximo tom (não dá pra impedir o botão; dá pra
    // proteger a validade do limiar).
    final atLevel = await AudioAccessibility.isAtReferenceVolume();
    if (!mounted) return;
    if (!atLevel) {
      setState(() {
        _volumeDriftWarning = true;
        _isPlayingTone = false;
      });
      return;
    }

    setState(() {
      _isPlayingTone = true;
    });

    bool willPlayTone = true;
    if (_isFamiliarizing) {
      _isCatchTrial = false;
    } else {
      // 20% chance of catch trial, avoiding consecutive catch trials
      if (!_wasLastCatchTrial && math.Random().nextDouble() < 0.20) {
        _isCatchTrial = true;
        _wasLastCatchTrial = true;
        willPlayTone = false;
        debugPrint("[CATCH_TRIAL] Silence presented at ${_frequencies[_currentFreqIndex]} Hz, $_currentDb dB");
      } else {
        _isCatchTrial = false;
        _wasLastCatchTrial = false;
      }
    }

    if (willPlayTone) {
      // Aguarda o engine carregar o sample antes de iniciar o timer de duração.
      // Sem await, o timer começa antes do som sair → furos de som.
      await _engine.playPureTone(
        frequencyHz: _frequencies[_currentFreqIndex],
        durationMs: 1500,
        ear: _currentEar,
        dbLevel: _currentDb,
      );
    }

    if (!mounted) return;
    _playbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _isPlayingTone = false;
      });
    });
  }

  void _transitionToNext(Future<void> Function() stateUpdateAndPlay) {
    _engine.stopTarget();
    _playbackTimer?.cancel();
    _transitionTimer?.cancel();
    setState(() {
      _isWaitingForNext = true;
      _isPlayingTone = false;
    });
    _transitionTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isWaitingForNext = false;
      });
      stateUpdateAndPlay();
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
      _transitionToNext(() async {
        await _playCurrentTestTone(); // repete ou continua com som real no mesmo nível
      });
      return;
    }

    if (_isFamiliarizing) {
      if (detected) {
        // Usuário confirmou que ouviu o tom de familiarização.
        // Começa a busca do limiar 10 dB abaixo do nível em que ouviu,
        // para não desperdiçar tentativas subindo do zero quando o limiar
        // já foi revelado pela familiarização.
        final startDb = (_currentDb - 10.0).clamp(0.0, 110.0);
        _transitionToNext(() async {
          _isFamiliarizing = false;
          _currentDb = startDb;
          await _playCurrentTestTone();
        });
      } else {
        // Não ouviu o tom de familiarização. Aumenta em passos de 10 dB até ouvir ou atingir 120 dB.
        if (_currentDb >= 120.0) {
          _recordThresholdAndNext(120.0);
        } else {
          _transitionToNext(() async {
            _currentDb = (_currentDb + 10.0).clamp(-10.0, 120.0);
            await _playCurrentTestTone();
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

      _transitionToNext(() async {
        _currentDb = (_currentDb - 10.0).clamp(-10.0, 120.0);
        await _playCurrentTestTone();
      });
    } else {
      // Erro/Não ouviu: subir 5 dB
      if (_currentDb >= 120.0) {
        _recordThresholdAndNext(120.0);
      } else {
        _transitionToNext(() async {
          _currentDb = (_currentDb + 5.0).clamp(-10.0, 120.0);
          await _playCurrentTestTone();
        });
      }
    }
  }

  void _showCatchTrialWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amberAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).thresholdTestCatchTrialWarning,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
      _transitionToNext(() async {
        _currentFreqIndex++;
        _currentDb = 70.0;
        _isFamiliarizing = true;
        _positiveResponses.clear();
        _isCatchTrial = false;
        await _playCurrentTestTone();
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
    final p = Theme.of(context).colorScheme;
    const freqLabels = ['250', '500', '750', '1K', '1.5K', '2K', '3K', '4K', '6K', '8K'];
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LineChart(
        LineChartData(
          minY: -120,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(leftPoints.length,
                  (i) => FlSpot(i.toDouble(), -leftPoints[i].threshold)),
              isCurved: false,
              color: Colors.blueAccent,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
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
            topTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= freqLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(freqLabels[idx],
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 9)),
                      );
                    })),
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
                  style: TextStyle(color: p.onSurfaceVariant, fontSize: 10)),
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
              border: Border(
                  bottom: BorderSide(color: p.onSurfaceVariant.withValues(alpha: 0.15)),
                  left: BorderSide(color: p.onSurfaceVariant.withValues(alpha: 0.15)))),
        ),
      ),
    );
  }

  /// Legenda do gráfico (azul = esquerdo, vermelho = direito).
  Widget _chartLegend() {
    final p = Theme.of(context).colorScheme;
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: p.onSurfaceVariant, fontSize: 14)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(Colors.blueAccent, AppLocalizations.of(context).thresholdTestLeftEar),
        const SizedBox(width: 28),
        dot(Colors.redAccent, AppLocalizations.of(context).thresholdTestRightEar),
      ],
    );
  }

  /// Tela de resultado do teste já salvo: mostra o gráfico do último teste e
  /// um botão "Refazer teste" embaixo.
  Widget _buildSavedResult() {
    final p = Theme.of(context).colorScheme;
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
            Text(
              AppLocalizations.of(context).thresholdTestLastResult,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: p.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).thresholdTestDoneOn(dataStr),
              style: TextStyle(color: p.onSurfaceVariant, fontSize: 15),
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
                  backgroundColor: p.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _retakeTest,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(AppLocalizations.of(context).commonRetake,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).thresholdTestBack,
                  style: TextStyle(color: p.onSurfaceVariant, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }


  Color get _earColor => _currentEar == EarSide.left ? Colors.blueAccent : Colors.redAccent;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).thresholdTestTitle,
          style: TextStyle(letterSpacing: 1, fontSize: 16, fontWeight: FontWeight.bold, color: p.onSurfaceVariant),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.5,
            colors: [p.surface, p.surface],
          ),
        ),
        child: _loadingSaved
            ? Center(child: CircularProgressIndicator(color: p.primary))
            : _showingSavedResult
            ? _buildSavedResult()
            : (!_earChosen && !_testFinished)
            ? _buildEarChooser()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aviso de desvio de volume no meio do teste: o usuário baixou pelo
            // botão físico. A medição fica em espera até voltar ao nível.
            if (_volumeDriftWarning)
              VolumeDriftBanner(
                onResume: () {
                  if (mounted) {
                    setState(() => _volumeDriftWarning = false);
                    _playCurrentTestTone();
                  }
                },
              ),
            // Indicador grande do ouvido em teste (◀ esquerdo / direito ▶)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentEar == EarSide.left)
                  const Icon(Icons.volume_up, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 8),
                Text(
                  _currentEar == EarSide.left
                      ? AppLocalizations.of(context).thresholdTestLeftEarLabel
                      : AppLocalizations.of(context).thresholdTestRightEarLabel,
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
                child: Text(
                  AppLocalizations.of(context).thresholdTestFamiliarization,
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
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
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      color: p.onSurface,
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
                    ? Text(
                        AppLocalizations.of(context).thresholdTestPreparing,
                        key: const ValueKey("status_preparing"),
                        style: TextStyle(
                          color: p.onSurfaceVariant,
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
                                AppLocalizations.of(context).thresholdTestListening,
                                style: TextStyle(
                                  color: _earColor.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            AppLocalizations.of(context).thresholdTestDidYouHear,
                            key: const ValueKey("status_idle"),
                            style: TextStyle(
                              color: p.onSurfaceVariant,
                              fontSize: 15,
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              AppLocalizations.of(context).thresholdTestSoundLevel(_currentDb.toInt().toString()),
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
              Text(
                AppLocalizations.of(context).thresholdTestResults,
                style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold),
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
                    backgroundColor: p.tertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'left': _leftEarPoints,
                    'right': _rightEarPoints,
                  }), 
                  child: Text(AppLocalizations.of(context).commonSaveAndBack, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ] else ...[
              Text(
                AppLocalizations.of(context).thresholdTestDidYouHear,
                style: TextStyle(
                  fontSize: 18,
                  color: (_isWaitingForNext || _isPlayingTone)
                      ? p.onSurfaceVariant.withValues(alpha: 0.4)
                      : p.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _ResponseButton(
                    label: AppLocalizations.of(context).commonNo,
                    color: p.surface,
                    textColor: p.onSurfaceVariant,
                    onPressed: (_isWaitingForNext || _isPlayingTone || _volumeDriftWarning) ? null : () => _onResponse(false),
                  ),
                  const SizedBox(width: 40),
                  _ResponseButton(
                    label: AppLocalizations.of(context).commonYes,
                    color: p.primary,
                    textColor: Colors.white,
                    onPressed: (_isWaitingForNext || _isPlayingTone || _volumeDriftWarning) ? null : () => _onResponse(true),
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
