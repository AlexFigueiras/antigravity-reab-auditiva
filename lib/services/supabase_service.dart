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

  /// Recupera o histórico de sessões de reabilitação [TELEMETRIA]
  Future<List<RehabSession>> getRehabHistory(String patientId) async {
    final List<dynamic> response = await Supabase.instance.client
        .from('rehab_sessions')
        .select()
        .eq('patient_id', patientId)
        .order('date', ascending: true);

    return response.map((data) => RehabSession.fromJson(data)).toList();
  }
}
