import 'dart:math' as math;
import 'dart:typed_data';
import '../models/audiogram.dart';

/// Gerenciador de Zona Morta Coclear (Cochlear Dead Regions - CDR)
/// Contém as heurísticas clínicas de detecção e o processador de Frequency Lowering.
class CochlearDeadRegionManager {
  static const double kDeadRegionThresholdDb = 70.0;
  static const List<int> kHighFrequencies = [6000, 8000];

  /// Determina se há suspeita de zona morta coclear em alta frequência para o paciente.
  static bool hasHighFrequencyDeadRegion(Audiogram? audiogram) {
    if (audiogram == null) return false;
    for (final freq in kHighFrequencies) {
      final leftPt = audiogram.leftEar.firstWhere(
        (p) => p.frequency == freq,
        orElse: () => AudiometryPoint(frequency: freq, threshold: 0.0),
      );
      final rightPt = audiogram.rightEar.firstWhere(
        (p) => p.frequency == freq,
        orElse: () => AudiometryPoint(frequency: freq, threshold: 0.0),
      );
      if (leftPt.threshold >= kDeadRegionThresholdDb || rightPt.threshold >= kDeadRegionThresholdDb) {
        return true;
      }
    }
    return false;
  }

  /// Retorna true se uma frequência específica for considerada zona morta coclear.
  static bool isFrequencyDead(Audiogram? audiogram, double frequencyHz) {
    if (audiogram == null) return false;
    final leftPoints = audiogram.leftEar;
    final rightPoints = audiogram.rightEar;
    if (leftPoints.isEmpty || rightPoints.isEmpty) return false;

    final leftPoint = leftPoints.firstWhere(
      (p) => p.frequency >= frequencyHz,
      orElse: () => leftPoints.last,
    );
    final rightPoint = rightPoints.firstWhere(
      (p) => p.frequency >= frequencyHz,
      orElse: () => rightPoints.last,
    );

    double avgThreshold = (leftPoint.threshold + rightPoint.threshold) / 2.0;
    return avgThreshold >= kDeadRegionThresholdDb;
  }

  /// Filtro passa-alta de 1ª ordem configurado para 4000 Hz a 48000 Hz.
  /// Extrai apenas as componentes agudas (> 4.000 Hz) que contêm pistas de fricativas.
  static Float32List _highPassFilter(Float32List input) {
    final int len = input.length;
    final Float32List output = Float32List(len);
    double xPrev = 0.0;
    double yPrev = 0.0;

    // Coeficientes normatizados com ganho unitário na frequência crítica:
    const double b0 = 0.204;
    const double b1 = -0.204;
    const double a1 = -0.592;

    for (int i = 0; i < len; i++) {
      final double x = input[i];
      final double y = b0 * x + b1 * xPrev - a1 * yPrev;
      output[i] = y;
      xPrev = x;
      yPrev = y;
    }
    return output;
  }

  /// Extrator de envoltória temporal (detector de envelope de ~5ms).
  static Float32List _extractEnvelope(Float32List hpInput) {
    final int len = hpInput.length;
    final Float32List env = Float32List(len);
    double envPrev = 0.0;

    // Beta para constante de tempo de ~5ms a 48 kHz
    const double beta = 0.9958;
    const double oneMinusBeta = 1.0 - beta;

    for (int i = 0; i < len; i++) {
      final double absVal = hpInput[i].abs();
      final double currentEnv = oneMinusBeta * absVal + beta * envPrev;
      env[i] = currentEnv;
      envPrev = currentEnv;
    }
    return env;
  }

  /// Filtro passa-banda de 2ª ordem para sintonizar ruído na faixa de 1.500 Hz a 2.500 Hz.
  static Float32List _bandPassFilter2k(Float32List noise) {
    final int len = noise.length;
    final Float32List output = Float32List(len);

    const double b0 = 0.1215;
    const double b2 = -0.1215;
    const double a1 = -1.8145;
    const double a2 = 0.8785;

    double x1 = 0.0;
    double x2 = 0.0;
    double y1 = 0.0;
    double y2 = 0.0;

    for (int i = 0; i < len; i++) {
      final double x = noise[i];
      final double y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
      output[i] = y;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
    }
    return output;
  }

  /// Gera ruído branco limitado na banda de audibilidade residual (1.5 kHz a 2.5 kHz).
  static Float32List _generateBandPassNoise(int length) {
    final rand = math.Random();
    final Float32List rawNoise = Float32List(length);
    for (int i = 0; i < length; i++) {
      rawNoise[i] = rand.nextDouble() * 2.0 - 1.0;
    }
    return _bandPassFilter2k(rawNoise);
  }

  /// Aplica rebaixamento de frequência (Frequency Lowering) por modulação de envoltória.
  /// Projeta as fricativas agudas para a zona de restos auditivos de 1.5 kHz a 2.5 kHz.
  static Float32List applyFrequencyLowering(Float32List original) {
    final int len = original.length;
    if (len == 0) return original;

    final hp = _highPassFilter(original);
    final env = _extractEnvelope(hp);
    final bpNoise = _generateBandPassNoise(len);

    final Float32List processed = Float32List(len);
    // Reforço compensatório automático de +4.5 dB para recuperar a atenuação da transposição
    const double boostFactor = 1.678;

    for (int i = 0; i < len; i++) {
      final double modulatedNoise = bpNoise[i] * env[i] * boostFactor;
      processed[i] = (original[i] + modulatedNoise).clamp(-1.0, 1.0);
    }

    return processed;
  }
}
