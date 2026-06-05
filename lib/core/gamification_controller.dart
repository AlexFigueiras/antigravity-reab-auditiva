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

  // NÍVEL 4: Ambiente Hostil [EFEITO COQUETEL]
  double _currentSNR = 20.0; // dB (Início Seguro: 20dB)
  double _maxNoiseThreshold = 0.0; // dB (Onde o acerto foi de 80%)

  // Getters
  int get totalXP => _totalXP;
  int get neuralEnergy => _neuralEnergy;
  int get currentStreak => _currentStreak;
  String get acuityLevel => _acuityLevel;
  bool get hasEnergy => true;
  // Kept for API compatibility — no longer blocks sessions
  Duration get remainingRestTime => Duration.zero;
  double get currentSNR => _currentSNR;
  double get maxNoiseThreshold => _maxNoiseThreshold;

  /// Seleção Inteligente baseada no Audiograma [Fase 1]
  ///
  /// Retorna `null` quando **não há audiograma** — neste caso o app NÃO pode
  /// personalizar e não deve fingir que personaliza (honestidade clínica, §5).
  /// Quem chama deve tratar o null pedindo o teste de audição.
  ///
  /// Com audiograma, prioriza os pares mínimos cujo som distintivo vive nas
  /// faixas de frequência onde a pessoa tem perda > 25 dB HL. Se nenhuma faixa
  /// crítica casar com os estímulos disponíveis, cai num estímulo do nível
  /// (a perda existe, mas fora das bandas mapeadas) — aí o sorteio é legítimo.
  Map<String, dynamic>? getSmartPhoneme(List<dynamic> audiogramData) {
    // Sem dados clínicos -> não há personalização possível.
    if (audiogramData.isEmpty) return null;

    final List<Map<String, dynamic>> level2Stimuli =
        List<Map<String, dynamic>>.from(PHONEME_REHAB_DATA['level_2']);

    // Filtra frequências com perda > 25dB
    final criticalFreqs = audiogramData
        .where((p) => (p['threshold'] as num) > 25)
        .map((p) => p['frequency'] as int)
        .toList();

    if (criticalFreqs.isEmpty) {
      return level2Stimuli[math.Random().nextInt(level2Stimuli.length)];
    }

    // Filtra fonemas na faixa de +/- 1500Hz das frequências críticas
    final smartMatch = level2Stimuli.where((s) {
      final band = s['freq_band'] as int;
      return criticalFreqs.any((f) => (band - f).abs() <= 1500);
    }).toList();

    if (smartMatch.isEmpty) {
      return level2Stimuli[math.Random().nextInt(level2Stimuli.length)];
    }
    return smartMatch[math.Random().nextInt(smartMatch.length)];
  }

  /// Adiciona XP baseado na performance e tipo de fonema [ANALYTICS]
  void addAcuityXP(double successRate, List<String> phonemes) {
    double baseXP = 100 * successRate;
    bool hasHighFrequencyPhonemes = phonemes.any((p) =>
      ['s', 'f', 't', 'ç', 'x', 'ch', 'spatial'].contains(p.toLowerCase())
    );

    double multiplier = hasHighFrequencyPhonemes ? 2.0 : 1.0;
    _totalXP += (baseXP * multiplier).toInt();

    // Automação Clínica Nível 4: Se acerto > 80%, dificulta o ambiente (Diminui SNR)
    if (successRate >= 0.8 && phonemes.contains('cocktail')) {
        _currentSNR -= 2.0; // Aumenta ruído (+2dB)
        if (_currentSNR < _maxNoiseThreshold) _maxNoiseThreshold = _currentSNR;
    }

    if (successRate < 0.8 && hasHighFrequencyPhonemes) {
      consumeEnergy();
    }

    _updateAcuityLevel();
    notifyListeners();
  }

  void resetSNR() {
    _currentSNR = 20.0;
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
      'max_noise_threshold': _maxNoiseThreshold,
      'last_training_at': DateTime.now().toIso8601String(),
    };
  }

  void fromMap(Map<String, dynamic> map) {
    _totalXP = (map['total_xp'] as num?)?.toInt() ?? 0;
    _neuralEnergy = (map['neural_energy'] as num?)?.toInt() ?? 5;
    _currentStreak = (map['current_streak'] as num?)?.toInt() ?? 0;
    _acuityLevel = map['acuity_level'] as String? ?? "Iniciante";
    _maxNoiseThreshold = (map['max_noise_threshold'] as num?)?.toDouble() ?? 0.0;
    notifyListeners();
  }
}
