import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rehab_session.dart';
import 'supabase_service.dart';

/// GATEKEEPER SERVICE: Gestor de Acesso por Desempenho e Assinatura
///
/// Regras de desbloqueio (ver PRODUTO.md §6):
///   - Nível 2 (Distinguir sons): sempre liberado (com audiograma)
///   - Nível 3 (De que lado): desbloqueia com ≥70% de acerto no nível 2 (média de 3 sessões)
///   - Nível 4 (No barulho): desbloqueia com ≥70% de acerto no nível 3 (média de 3 sessões)
///   - Nível 5 (Frases): paywall — exige assinatura
class GatekeeperService {
  static final GatekeeperService _instance = GatekeeperService._internal();
  factory GatekeeperService() => _instance;
  GatekeeperService._internal();

  /// TEMPORÁRIO: o paywall está DESLIGADO enquanto o Stripe não está
  /// configurado. Com isto, o nível 5 (Frases) fica liberado para todos.
  /// Quando a cobrança via Stripe entrar no ar, voltar para `true` para
  /// reativar a checagem de assinatura em `_checkSubscription`.
  static const bool kPaywallEnabled = false;

  /// Cache do nível desbloqueado (evita queries repetidas numa mesma sessão de uso).
  int? _cachedUnlockedLevel;

  /// Limpa o cache — chamar após cada sessão de treino para reavaliar.
  void invalidateCache() => _cachedUnlockedLevel = null;

  /// Verifica se o usuário tem permissão para acessar o nível solicitado.
  Future<bool> checkAccess(int level) async {
    // Nível 2 é gratuito e sempre acessível
    if (level <= 2) return true;

    // Níveis 3 e 4: desbloqueio por desempenho
    if (level <= 4) {
      return await _checkPerformanceUnlock(level);
    }

    // Nível 5+: paywall (assinatura)
    return await _checkSubscription();
  }

  /// Retorna o nível máximo desbloqueado por desempenho (2, 3 ou 4).
  /// Usa cache para evitar queries repetidas.
  Future<int> getUnlockedLevel() async {
    if (_cachedUnlockedLevel != null) return _cachedUnlockedLevel!;

    final sessions = await SupabaseService().getAllSessions();
    _cachedUnlockedLevel = RehabSession.calculateUnlockedLevel(sessions);
    return _cachedUnlockedLevel!;
  }

  /// Verifica desbloqueio por desempenho: o nível N requer ≥70% no nível N-1.
  Future<bool> _checkPerformanceUnlock(int level) async {
    final unlockedLevel = await getUnlockedLevel();
    return level <= unlockedLevel;
  }

  /// Retorna a acurácia média recente de um nível — usado na UI para mostrar
  /// progresso ao desbloqueio ("Você está com 58% — falta pouco!").
  Future<double> getAverageAccuracy(int level) async {
    final sessions = await SupabaseService().getSessionsByLevel(level);
    if (sessions.isEmpty) return 0;
    final rehabLevel = RehabLevel.values.firstWhere(
      (e) => e.value == level,
      orElse: () => RehabLevel.phonemicDiscrimination,
    );
    return RehabSession.averageAccuracyForLevel(
        sessions.cast<RehabSession>(), rehabLevel);
  }

  /// Verifica assinatura no Supabase (para nível 5+).
  Future<bool> _checkSubscription() async {
    // Paywall desligado (Stripe ainda não configurado): libera o acesso.
    if (!kPaywallEnabled) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();

      final status = res?['subscription_status'] as String? ?? 'free';
      return status != 'free';
    } catch (e) {
      debugPrint("Erro ao verificar assinatura: $e");
      return false; // fail-closed
    }
  }

  /// Recarrega o status de assinatura a partir do backend.
  ///
  /// IMPORTANTE: a promoção para 'pro' NÃO é feita pelo cliente. O cliente
  /// não tem permissão para alterar `subscription_status` (protegido por
  /// trigger no Postgres — ver supabase_migration_003.sql). O upgrade real
  /// deve ocorrer no backend, via webhook do Stripe (service_role).
  Future<bool> refreshSubscriptionStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();
      return (res?['subscription_status'] as String? ?? 'free') != 'free';
    } catch (e) {
      debugPrint("Erro ao recarregar assinatura: $e");
      return false;
    }
  }
}
