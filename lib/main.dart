import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ear_training/audio_engine/audio_engine.dart';
import 'package:ear_training/models/audiogram.dart';
import 'package:ear_training/screens/threshold_test_screen.dart';
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
  double _snr = 10.0;
  bool _isPlaying = false;

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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DASHBOARD CLÍNICO",
                        style: TextStyle(
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Reabilitação de Plasticidade Neural",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.blueAccent),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ThresholdTestScreen()),
                      );
                      
                      if (result != null && result is List<AudiometryPoint>) {
                        setState(() {
                          _mockAudiogram.rightEar = result;
                        });
                      }
                    },
                    tooltip: "Calibrar Audiograma",
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Widget Gráfico de Audiograma (fl_chart)
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 32, 16),
                  child: LineChart(
                    LineChartData(
                      minY: -10,
                      maxY: 120,
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
                              "${value.toInt()}dB",
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 20),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
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
                        child: Text(_isPlaying ? "PARAR TREINO" : "INICIAR TREINO NEURAL"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      // Usamos o índice (0, 1, 2...) para que 250Hz -> 8000Hz fiquem equidistante
      spots: List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].threshold)),
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
