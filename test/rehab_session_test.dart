import 'package:flutter_test/flutter_test.dart';
import 'package:ear_training/models/rehab_session.dart';

void main() {
  RehabSession session({
    required RehabLevel level,
    required int total,
    required int correct,
  }) =>
      RehabSession(
        patientId: 'p1',
        date: DateTime(2026, 1, 1),
        level: level,
        totalTrials: total,
        correctAnswers: correct,
        averageResponseTimeMs: 500,
      );

  group('RehabSession.accuracy', () {
    test('calcula porcentagem corretamente', () {
      expect(session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 8).accuracy, 80);
    });

    test('retorna 0 quando não há tentativas (sem divisão por zero)', () {
      expect(session(level: RehabLevel.phonemicDiscrimination, total: 0, correct: 0).accuracy, 0);
    });
  });

  group('RehabSession.fromJson', () {
    test('faz round-trip de toJson sem lançar', () {
      final s = session(level: RehabLevel.spatialAttention, total: 4, correct: 3);
      final parsed = RehabSession.fromJson(s.toJson());
      expect(parsed.level, RehabLevel.spatialAttention);
      expect(parsed.correctAnswers, 3);
    });

    test('nível desconhecido cai no padrão em vez de lançar', () {
      final json = {
        'patient_id': 'p1',
        'date': DateTime(2026, 1, 1).toIso8601String(),
        'level': 999,
        'total_trials': 1,
        'correct_answers': 1,
        'avg_response_time_ms': 100,
      };
      expect(RehabSession.fromJson(json).level, RehabLevel.toneIsolation);
    });
  });

  group('calculateUnlockedLevel', () {
    test('histórico vazio já libera o nível 2 (Distinguir sons) após o audiograma', () {
      expect(RehabSession.calculateUnlockedLevel([]), 2);
    });

    test('3 sessões do nível 2 com média >= 70% liberam os níveis 3 e 4', () {
      final history = [
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 8), // 80%
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 7), // 70%
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 9), // 90%
      ];
      expect(RehabSession.calculateUnlockedLevel(history), 4);
    });

    test('nível 2 abaixo da média de 70% mantém apenas o nível 2 liberado', () {
      final history = [
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 5), // 50%
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 6), // 60%
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 5), // 50%
      ];
      expect(RehabSession.calculateUnlockedLevel(history), 2);
    });

    test('menos de 3 sessões do nível 2 não libera os níveis seguintes', () {
      final history = [
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 10), // 100%
        session(level: RehabLevel.phonemicDiscrimination, total: 10, correct: 10), // 100%
      ];
      expect(RehabSession.calculateUnlockedLevel(history), 2);
    });
  });
}
