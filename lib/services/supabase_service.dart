import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';

/// Serviço Responsável pela Persistência e Segurança [SEGURANÇA/INFRA]
/// Aplica as regras de integridade e comunicação com o Supabase.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    _isInitialized = true;
    print("Supabase Iniciado com SUCESSO.");
  }

  /// Salva um novo Audiograma [SEGURANÇA]
  /// Note: A política RLS deve estar ativa no banco para garantir isolation por user_id.
  Future<void> saveAudiogram(Audiogram audiogram) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    // Mapeamento para o Schema do PostgreSQL
    await Supabase.instance.client.from('audiograms').insert({
      'patient_id': audiogram.patientId,
      'left_ear': audiogram.leftEar.map((e) => e.toJson()).toList(),
      'right_ear': audiogram.rightEar.map((e) => e.toJson()).toList(),
      'user_id': user.id, // Vínculo explícito para RLS
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Recupera o histórico de audiogramas do paciente logado
  Future<List<Audiogram>> getPatientHistory(String patientId) async {
    final List<dynamic> response = await Supabase.instance.client
        .from('audiograms')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return response.map((data) => Audiogram.fromJson(data)).toList();
  }

  /// Salva uma sessão de reabilitação [SSOT/SEGURANÇA]
  Future<void> saveRehabSession(RehabSession session) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    await Supabase.instance.client.from('rehab_sessions').insert({
      ...session.toJson(),
      'user_id': user.id, // Vínculo obrigatório para RLS
    });
  }

  /// Batch upload para respostas granulares clinicamente marcadas [TELEMETRIA]
  Future<void> saveStimulusResultsBatch(List<Map<String, dynamic>> payload) async {
    if (payload.isEmpty) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    // Inject user_id em todos os itens garantindo compliance RLS
    final authorizedPayload = payload.map((e) => {
      ...e,
      'user_id': user.id,
    }).toList();

    await Supabase.instance.client.from('stimulus_results').insert(authorizedPayload);
  }

  /// Recupera o histórico de sessões de reabilitação [TELEMETRIA]
  Future<List<RehabSession>> getRehabHistory(String patientId) async {
    final List<dynamic> response = await Supabase.instance.client
        .from('rehab_sessions')
        .select()
        .eq('patient_id', patientId)
        .order('date', ascending: true);

    return response.map((data) => RehabSession.fromJson(data)).toList();
  }

  /// Recupera a evolução da latência média das últimas 5 sessões [SENIOR-FULLSTACK]
  Future<List<Map<String, dynamic>>> getLatencyEvolution() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    // Query otimizada: Agrega média de reaction_time da stimulus_results
    // limitando às últimas 5 sessões para o gráfico de tendências.
    final List<dynamic> response = await Supabase.instance.client
        .from('stimulus_results')
        .select('session_id, reaction_time_ms, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(100); // Pegamos uma amostra grande para processar no app

    if (response.isEmpty) return [];

    // Agrupamento manual por session_id (Otimizado: preserva ordem temporal)
    final Map<String, List<double>> sessionGroups = {};
    for (var row in response) {
      final id = row['session_id'] as String;
      final rt = (row['reaction_time_ms'] as num).toDouble();
      sessionGroups.putIfAbsent(id, () => []).add(rt);
    }

    final List<Map<String, dynamic>> results = [];
    sessionGroups.forEach((id, times) {
      final avg = times.reduce((a, b) => a + b) / times.length;
      results.add({'session_id': id, 'avg_latency': avg});
    });

    return results.reversed.take(5).toList(); // Últimas 5 sessões em ordem cronológica
  }

  /// Retorna o audiograma mais recente do usuário logado
  Future<Audiogram?> getLatestAudiogram() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await Supabase.instance.client
          .from('audiograms')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return Audiogram.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Retorna as últimas sessões com acurácia para o gráfico de evolução
  Future<List<Map<String, dynamic>>> getAccuracyHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('rehab_sessions')
          .select('date, accuracy, level')
          .eq('user_id', user.id)
          .order('date', ascending: true)
          .limit(10);
      return response.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Retorna todas as sessões de reabilitação do usuário logado (por user_id).
  Future<List<RehabSession>> getAllSessions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('rehab_sessions')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: true);
      return response.map((data) => RehabSession.fromJson(data)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retorna a data da autopercepção mais recente do usuário, ou null.
  Future<DateTime?> getLastSelfPerceptionDate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final res = await Supabase.instance.client
          .from('self_perception')
          .select('created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null || res['created_at'] == null) return null;
      return DateTime.parse(res['created_at'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Salva a autopercepção semanal (escala 1-5) do usuário.
  Future<void> saveSelfPerception(int score) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    await Supabase.instance.client.from('self_perception').insert({
      'user_id': user.id,
      'score': score,
    });
  }

  /// Retorna sessões de um nível específico, ordenadas por data (mais recente primeiro).
  /// Usado para calcular desbloqueio progressivo (média de 3 sessões).
  Future<List<RehabSession>> getSessionsByLevel(int level) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('rehab_sessions')
          .select()
          .eq('user_id', user.id)
          .eq('level', level)
          .order('date', ascending: false)
          .limit(10);
      return response.map((data) => RehabSession.fromJson(data)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Calcula o streak de dias consecutivos de treino.
  /// Conta quantos dias seguidos (incluindo hoje) o usuário tem sessões.
  Future<int> getTrainingStreak() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 0;
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('rehab_sessions')
          .select('date')
          .eq('user_id', user.id)
          .order('date', ascending: false)
          .limit(60);
      if (response.isEmpty) return 0;

      // Extrai datas únicas (ignora horas)
      final dates = response
          .map((r) => DateTime.parse(r['date'] as String))
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Se o dia mais recente não é hoje nem ontem, streak = 0
      final diff = todayDate.difference(dates.first).inDays;
      if (diff > 1) return 0;

      int streak = 1;
      for (int i = 1; i < dates.length; i++) {
        final gap = dates[i - 1].difference(dates[i]).inDays;
        if (gap == 1) {
          streak++;
        } else {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }

  /// Retorna contagem de sessões agrupadas por nível para a tela de progresso.
  Future<Map<int, int>> getSessionCountsByLevel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {};
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('rehab_sessions')
          .select('level')
          .eq('user_id', user.id);
      final Map<int, int> counts = {};
      for (final row in response) {
        final level = row['level'] as int;
        counts[level] = (counts[level] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Salva um teste de desfecho independente (Matrix) [Fase 0.2]
  Future<void> saveOutcomeTest({
    required double srtDb,
    required int totalTrials,
    required int correctAnswers,
    Map<String, dynamic>? metadata,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Usuário não autenticado.");

    await Supabase.instance.client.from('outcome_tests').insert({
      'user_id': user.id,
      'srt_db': srtDb,
      'total_trials': totalTrials,
      'correct_answers': correctAnswers,
      'metadata': metadata,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// Recupera o teste de desfecho mais recente do usuário
  Future<Map<String, dynamic>?> getLatestOutcomeTest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await Supabase.instance.client
          .from('outcome_tests')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Recupera o histórico de testes de desfecho do usuário
  Future<List<Map<String, dynamic>>> getOutcomeTestHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('outcome_tests')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: true);
      return response.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
