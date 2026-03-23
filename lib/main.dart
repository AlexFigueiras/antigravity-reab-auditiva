import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ear_training/audio_engine/audio_engine.dart';
import 'package:ear_training/models/audiogram.dart';
import 'package:ear_training/screens/threshold_test_screen.dart';
import 'package:ear_training/screens/phonemic_discrimination_screen.dart';
import 'package:ear_training/screens/spatial_attention_screen.dart';
import 'package:ear_training/screens/speech_in_noise_screen.dart';
import 'package:ear_training/screens/widgets/rehab_trends_chart.dart';
import 'package:ear_training/models/rehab_session.dart';
import 'package:ear_training/services/supabase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização de Variáveis de Ambiente e Persistência [SEGURANÇA/INFRA]
  await dotenv.load(fileName: ".env");
  await SupabaseService().initialize();
  
  runApp(const EarTrainingApp());
}

class EarTrainingApp extends StatelessWidget {
  const EarTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        primaryColor: const Color(0xFFE11D48),
      ),
      home: const TrainingDashboard(),
    );
  }
}

class TrainingDashboard extends StatefulWidget {
  const TrainingDashboard({super.key});

  @override
  State<TrainingDashboard> createState() => _TrainingDashboardState();
}

class _TrainingDashboardState extends State<TrainingDashboard> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  double _snr = 10.0;
  bool _isPlaying = false;
  List<RehabSession> _history = [];
  int _unlockedLevel = 1;

  // Mock Audiogram para demonstração
  Audiogram _mockAudiogram = Audiogram(
    id: 'pt-001',
    patientId: 'ALEX-FIG-2026',
    date: DateTime.now(),
    leftEar: [
      AudiometryPoint(frequency: 250, threshold: 20),
      AudiometryPoint(frequency: 500, threshold: 35),
      AudiometryPoint(frequency: 1000, threshold: 40),
      AudiometryPoint(frequency: 2000, threshold: 55),
      AudiometryPoint(frequency: 4000, threshold: 60),
      AudiometryPoint(frequency: 8000, threshold: 70),
    ],
    rightEar: [
      AudiometryPoint(frequency: 250, threshold: 15),
      AudiometryPoint(frequency: 500, threshold: 25),
      AudiometryPoint(frequency: 1000, threshold: 30),
      AudiometryPoint(frequency: 2000, threshold: 45),
      AudiometryPoint(frequency: 4000, threshold: 50),
      AudiometryPoint(frequency: 8000, threshold: 65),
    ],
  );

  @override
  void initState() {
    super.initState();
    _engine.initializeEngine(_mockAudiogram);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _supabase.getRehabHistory(_mockAudiogram.patientId);
      setState(() {
        _history = history;
        _unlockedLevel = RehabSession.calculateUnlockedLevel(history);
      });
    } catch (e) {
      print("Erro ao carregar histórico: $e");
    }
  }

  void _togglePlay() async {
    if (_isPlaying) {
      _engine.stop();
    } else {
      // Inicializa com o audiogram atual para aplicar as regras de ganho [ESPECIALISTA]
      await _engine.initializeEngine(_mockAudiogram);
      
      await _engine.playSpeechInNoise(
        targetAudioPath: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        noiseAudioPath: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3",
        snrDb: _snr,
      );
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DASHBOARD CLÍNICO",
                          style: TextStyle(
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Reabilitação Neural",
                          style: TextStyle(
                            fontSize: 26, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton.icon(
                      icon: const Icon(Icons.hearing, color: Colors.blueAccent),
                      label: const Text("TESTAR", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ThresholdTestScreen()),
                        );
                        
                        if (result != null && result is Map<String, dynamic>) {
                          setState(() {
                            if (result.containsKey('left')) {
                              _mockAudiogram.leftEar = result['left'] as List<AudiometryPoint>;
                            }
                            if (result.containsKey('right')) {
                              _mockAudiogram.rightEar = result['right'] as List<AudiometryPoint>;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Widget Gráfico de Audiograma (fl_chart)
              SizedBox(
                height: 250,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 32, 16),
                  child: LineChart(
                    LineChartData(
                      minY: -120, // Padrão clínico: perdas maiores para baixo
                      maxY: 10,
                      backgroundColor: Colors.transparent,
                      lineBarsData: [
                        _generateLine(EarSide.left),
                        _generateLine(EarSide.right),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1, // Evita repetição de labels entre os índices
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _getFrequencyLabel(value),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Text(
                              "${(-value).toInt()}dB",
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text("ANÁLISE DE PROGRESSO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: Colors.grey)),
              const SizedBox(height: 12),
              
              // Bloco de Tendências Clínicas
              SizedBox(
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: RehabTrendsChart(sessions: _history),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Controle de Treino Coquetel
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isPlaying ? Colors.red.withOpacity(0.5) : Colors.transparent),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("TREINO: EFEITO COQUETEL", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          "${_snr.toInt()} dB SNR", 
                          style: TextStyle(color: _snr < 0 ? Colors.orange : Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Instrução: Foque na voz principal (Sinal) e esforce-se para ignorar o ruído de fundo. "
                      "Ajuste o controle (SNR) para deixar a voz mais alta que o ruído (+dB) ou mais abafada que o ruído (-dB), desafiando seu cérebro.",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _snr,
                      min: -20,
                      max: 20,
                      onChanged: (value) {
                        setState(() => _snr = value);
                        // Atualização dinâmica em tempo real
                        if (_isPlaying) {
                          _engine.updateSNR(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlaying ? Colors.red : const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _togglePlay,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
                            const SizedBox(width: 8),
                            Text(
                              _isPlaying ? "PARAR TREINO" : "INICIAR TREINO NEURAL",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _unlockedLevel >= 2 ? Colors.blueAccent : Colors.white10,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _unlockedLevel >= 2 
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PhonemicDiscriminationScreen(audiogram: _mockAudiogram),
                                ),
                              ).then((_) => _loadHistory()); // Recarregar após o exercício
                            }
                          : null, // Bloqueado
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "NÍVEL 2: DISCRIMINAÇÃO FONÊMICA", 
                                style: TextStyle(
                                  color: _unlockedLevel >= 2 ? Colors.blueAccent : Colors.white24,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_unlockedLevel < 2) 
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.lock_outline, size: 16, color: Colors.white24),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _unlockedLevel >= 3 ? Colors.purpleAccent : Colors.white10,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _unlockedLevel >= 3 
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SpatialAttentionScreen(audiogram: _mockAudiogram),
                                ),
                              ).then((_) => _loadHistory());
                            }
                          : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "NÍVEL 3: ATENÇÃO ESPACIAL", 
                              style: TextStyle(color: _unlockedLevel >= 3 ? Colors.purpleAccent : Colors.white24),
                            ),
                            if (_unlockedLevel < 3) 
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.lock_outline, size: 16, color: Colors.white24),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _unlockedLevel >= 4 ? Colors.orangeAccent : Colors.white10,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _unlockedLevel >= 4 
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SpeechInNoiseScreen(audiogram: _mockAudiogram),
                                ),
                              ).then((_) => _loadHistory());
                            }
                          : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "NÍVEL 4: EFEITO COQUETEL", 
                              style: TextStyle(color: _unlockedLevel >= 4 ? Colors.orangeAccent : Colors.white24),
                            ),
                            if (_unlockedLevel < 4) 
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.lock_outline, size: 16, color: Colors.white24),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  LineChartBarData _generateLine(EarSide side) {
    final List<AudiometryPoint> points = (side == EarSide.left) ? _mockAudiogram.leftEar : _mockAudiogram.rightEar;
    return LineChartBarData(
      isCurved: false, // Audiogramas reais usam linhas retas entre pontos
      color: side == EarSide.left ? const Color(0xFF2563EB) : const Color(0xFFE11D48),
      barWidth: 3,
      dotData: const FlDotData(show: true),
      // Usamos o índice (0, 1, 2...) para que 250Hz -> 8000Hz fiquem equidistantes
      // Invertemos o valor para que maior perda fique para baixo (padrão clínico)
      spots: List.generate(points.length, (i) => FlSpot(i.toDouble(), -points[i].threshold)),
    );
  }

  // Títulos do Eixo X mapeados
  String _getFrequencyLabel(double value) {
    const freqs = ['250', '500', '1K', '2K', '4K', '8K'];
    int idx = value.toInt();
    if (idx >= 0 && idx < freqs.length) return freqs[idx];
    return '';
  }
}
