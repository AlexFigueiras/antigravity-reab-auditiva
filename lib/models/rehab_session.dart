enum RehabLevel {
  toneIsolation(1, unlockThreshold: 70.0),
  phonemicDiscrimination(2, unlockThreshold: 70.0),
  spatialAttention(3, unlockThreshold: 70.0),
  speechInNoise(4, unlockThreshold: 0.0); // Nível final — paywall (Frases)

  final int value;
  /// Acurácia média (últimas 3 sessões) necessária para desbloquear o
  /// próximo nível. 70% = melhora clínica sustentada, não sorte num único dia.
  final double unlockThreshold;

  const RehabLevel(this.value, {this.unlockThreshold = 70.0});
}

class RehabSession {
  final String? id;
  final String patientId;
  final DateTime date;
  final RehabLevel level;
  final int totalTrials;
  final int correctAnswers;
  final double averageResponseTimeMs;
  final Map<String, dynamic>? metadata; // Para armazenar fonemas testados, SNR, etc.

  RehabSession({
    this.id,
    required this.patientId,
    required this.date,
    required this.level,
    required this.totalTrials,
    required this.correctAnswers,
    required this.averageResponseTimeMs,
    this.metadata,
  });

  double get accuracy => totalTrials > 0 ? (correctAnswers / totalTrials) * 100 : 0;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'date': date.toIso8601String(),
    'level': level.value,
    'total_trials': totalTrials,
    'correct_answers': correctAnswers,
    'avg_response_time_ms': averageResponseTimeMs,
    'metadata': metadata,
    'accuracy': accuracy,
  };

  factory RehabSession.fromJson(Map<String, dynamic> json) => RehabSession(
    id: json['id'],
    patientId: json['patient_id'],
    date: DateTime.parse(json['date'] ?? json['created_at']),
    level: RehabLevel.values.firstWhere(
      (e) => e.value == json['level'],
      orElse: () => RehabLevel.toneIsolation,
    ),
    totalTrials: json['total_trials'],
    correctAnswers: json['correct_answers'],
    averageResponseTimeMs: (json['avg_response_time_ms'] as num).toDouble(),
    metadata: json['metadata'],
  );

  /// Determina o nível máximo desbloqueado com base no desempenho real.
  ///
  /// Regra: média de acertos das **últimas 3 sessões** do nível anterior
  /// precisa atingir [unlockThreshold] (70%). Isso evita desbloqueios por
  /// sorte em uma sessão isolada e garante melhora sustentada.
  ///
  /// Nível 2 (Distinguir sons) está sempre liberado após o audiograma.
  /// Nível 5 (Frases) exige assinatura — não entra aqui.
  static int calculateUnlockedLevel(List<RehabSession> history) {
    // Nível 2 (Distinguir sons) sempre começa liberado
    // Se o nível 2 (phonemicDiscrimination) tiver média >= 70% nas últimas 3 sessões,
    // então desbloqueia nível 3 E nível 4.
    final sessionsL2 = history
        .where((s) => s.level == RehabLevel.phonemicDiscrimination)
        .toList();
    if (sessionsL2.length >= 3) {
      final lastThree = sessionsL2
          .reversed
          .take(3)
          .map((s) => s.accuracy)
          .toList();
      final avgL2 = lastThree.reduce((a, b) => a + b) / lastThree.length;
      if (avgL2 >= RehabLevel.phonemicDiscrimination.unlockThreshold) {
        return 4; // Desbloqueia nível 3 e nível 4
      }
    }
    return 2;
  }

  /// Retorna a acurácia média das últimas [count] sessões de um nível.
  /// Útil para mostrar progresso ao desbloqueio na UI.
  static double averageAccuracyForLevel(
      List<RehabSession> history, RehabLevel level,
      {int count = 3}) {
    final sessions = history
        .where((s) => s.level == level)
        .toList();
    if (sessions.isEmpty) return 0;
    final recent = sessions.reversed.take(count).map((s) => s.accuracy).toList();
    return recent.reduce((a, b) => a + b) / recent.length;
  }
}
