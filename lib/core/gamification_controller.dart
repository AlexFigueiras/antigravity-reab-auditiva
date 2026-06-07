import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'phoneme_map.dart';

/// Controlador Central de Gamificação Clínica [ORQUESTRADOR]
/// Gerencia XP, Energia Neural e Nível de Acuidade de forma reativa.
class GamificationController extends ChangeNotifier {
  static final GamificationController _instance = GamificationController._internal();
  factory GamificationController() => _instance;

  GamificationController._internal();

  int _totalXP = 0;
  int _neuralEnergy = 5; // Contador de erros na sessão (não bloqueia)
  int _currentStreak = 0;
  String _acuityLevel = "Iniciante";

  // Getters
  int get totalXP => _totalXP;
  int get neuralEnergy => _neuralEnergy;
  int get currentStreak => _currentStreak;
  String get acuityLevel => _acuityLevel;
  bool get hasEnergy => true;
  // Kept for API compatibility — no longer blocks sessions
  Duration get remainingRestTime => Duration.zero;

  int _getDifficultyForType(String type) {
    switch (type) {
      case 'vowel_contrast':
      case 'bilabial':
        return 1;
      case 'velar':
        return 2;
      case 'plosive':
      case 'postalveolar':
        return 3;
      case 'labiodental':
      case 'voiced_fricative':
      case 'fricative_plosive':
        return 4;
      case 'sibilant':
      case 'fricative':
      case 'voiced_sibilant':
        return 5;
      default:
        return 3;
    }
  }

  /// Seleção Inteligente baseada no Audiograma [Fase 1]
  ///
  /// Retorna `null` quando **não há audiograma** — neste caso o app NÃO pode
  /// personalizar e não deve fingir que personaliza (honestidade clínica, §5).
  /// Quem chama deve tratar o null pedindo o teste de audição.
  Map<String, dynamic>? getSmartPhoneme(
    List<dynamic> audiogramData, {
    int? targetDifficulty,
    String phonemeBankKey = 'level_2',
  }) {
    // Sem dados clínicos -> não há personalização possível.
    if (audiogramData.isEmpty) return null;

    final List<Map<String, dynamic>> level2Stimuli =
        List<Map<String, dynamic>>.from(
            PHONEME_REHAB_DATA[phonemeBankKey] ?? PHONEME_REHAB_DATA['level_2']!);

    final hasHighDeadRegion = audiogramData.any(
      (p) => (p['frequency'] == 6000 || p['frequency'] == 8000) && (p['threshold'] as num) >= 70.0
    );

    // Filtra frequências com perda > 25dB
    List<int> criticalFreqs = audiogramData
        .where((p) => (p['threshold'] as num) > 25)
        .map((p) => p['frequency'] as int)
        .toList();

    if (hasHighDeadRegion) {
      // CDR Heuristic: Desvia o treino de agudos mortos (6k/8k) e foca na audibilidade residual (2k/4k)
      criticalFreqs = criticalFreqs.where((f) => f != 6000 && f != 8000).toList();
      if (!criticalFreqs.contains(2000)) criticalFreqs.add(2000);
      if (!criticalFreqs.contains(4000)) criticalFreqs.add(4000);
    }

    // Cascata de Fallback:
    // Passo 1: Filtrar por frequência crítica E dificuldade (se fornecida)
    if (targetDifficulty != null) {
      int chosenDifficulty = targetDifficulty;
      if (_totalXP > 1000 && targetDifficulty > 1) {
        // 30% de chance de intercalar com uma dificuldade menor
        if (math.Random().nextDouble() < 0.30) {
          chosenDifficulty = math.Random().nextInt(targetDifficulty - 1) + 1;
        }
      }

      final matchFreqAndDiff = level2Stimuli.where((s) {
        final band = s['freq_band'] as int;
        final isFreqMatch = criticalFreqs.any((f) => (band - f).abs() <= 1500);
        final isDiffMatch = _getDifficultyForType(s['type'] as String) == chosenDifficulty;
        return isFreqMatch && isDiffMatch;
      }).toList();

      if (matchFreqAndDiff.isNotEmpty) {
        return matchFreqAndDiff[math.Random().nextInt(matchFreqAndDiff.length)];
      }

      // Passo 2: Filtrar apenas por dificuldade
      final matchDiffOnly = level2Stimuli.where((s) {
        return _getDifficultyForType(s['type'] as String) == chosenDifficulty;
      }).toList();

      if (matchDiffOnly.isNotEmpty) {
        return matchDiffOnly[math.Random().nextInt(matchDiffOnly.length)];
      }
    }

    // Passo 3: Filtrar apenas por frequência crítica
    if (criticalFreqs.isNotEmpty) {
      final matchFreqOnly = level2Stimuli.where((s) {
        final band = s['freq_band'] as int;
        return criticalFreqs.any((f) => (band - f).abs() <= 1500);
      }).toList();

      if (matchFreqOnly.isNotEmpty) {
        return matchFreqOnly[math.Random().nextInt(matchFreqOnly.length)];
      }
    }

    // Passo 4: Sorteio livre
    return level2Stimuli[math.Random().nextInt(level2Stimuli.length)];
  }

  /// Adiciona XP baseado na performance e tipo de fonema [ANALYTICS]
  void addAcuityXP(double successRate, List<String> phonemes) {
    double baseXP = 100 * successRate;
    bool hasHighFrequencyPhonemes = phonemes.any((p) =>
      ['s', 'f', 't', 'ç', 'x', 'ch', 'spatial'].contains(p.toLowerCase())
    );

    double multiplier = hasHighFrequencyPhonemes ? 2.0 : 1.0;
    _totalXP += (baseXP * multiplier).toInt();

    if (successRate < 0.8 && hasHighFrequencyPhonemes) {
      consumeEnergy();
    }

    _updateAcuityLevel();
    notifyListeners();
  }

  void consumeEnergy() {
    if (_neuralEnergy > 0) {
      _neuralEnergy--;
      notifyListeners();
    }
  }

  void resetEnergy() {
    _neuralEnergy = 5;
    notifyListeners();
  }

  void updateStreak(int days) {
    _currentStreak = days;
    notifyListeners();
  }

  void _updateAcuityLevel() {
    if (_totalXP > 5000) {
      _acuityLevel = "Avançado";
    } else if (_totalXP > 1000) {
      _acuityLevel = "Intermediário";
    } else {
      _acuityLevel = "Iniciante";
    }
  }

  /// Sincronização com Supabase [PERSISTÊNCIA]
  Map<String, dynamic> toMapForSupabase() {
    return {
      'total_xp': _totalXP,
      'neural_energy': _neuralEnergy,
      'current_streak': _currentStreak,
      'acuity_level': _acuityLevel,
      'last_training_at': DateTime.now().toIso8601String(),
    };
  }

  void fromMap(Map<String, dynamic> map) {
    _totalXP = (map['total_xp'] as num?)?.toInt() ?? 0;
    _neuralEnergy = (map['neural_energy'] as num?)?.toInt() ?? 5;
    _currentStreak = (map['current_streak'] as num?)?.toInt() ?? 0;
    _acuityLevel = map['acuity_level'] as String? ?? "Iniciante";
    notifyListeners();
  }
}
