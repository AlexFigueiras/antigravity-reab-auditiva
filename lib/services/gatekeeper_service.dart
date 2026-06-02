import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// GATEKEEPER SERVICE: Gestor de Acesso e Monetização [GATEKEEPER]
class GatekeeperService {
  static final GatekeeperService _instance = GatekeeperService._internal();
  factory GatekeeperService() => _instance;
  GatekeeperService._internal();

  /// Verifica se o usuário tem permissão para acessar o nível solicitado
  Future<bool> checkAccess(int level) async {
    // Níveis 1 e 2 são gratuitos [REABILITAÇÃO BASE]
    if (level <= 2) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    // Consulta Status de Assinatura no Perfil
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('subscription_status')
          .eq('user_id', user.id)
          .maybeSingle();

      final status = res?['subscription_status'] as String? ?? 'free';

      // Níveis 3 e 4 exigem status 'pro' ou 'elite'
      return status != 'free';
    } catch (e) {
      debugPrint("Erro ao verificar acesso: $e");
      // Em caso de falha, negamos acesso ao conteúdo pago (fail-closed).
      return false;
    }
  }

  /// Recarrega o status de assinatura a partir do backend.
  ///
  /// IMPORTANTE: a promoção para 'pro' NÃO é feita pelo cliente. O cliente
  /// não tem permissão para alterar `subscription_status` (protegido por
  /// trigger no Postgres — ver supabase_migration_003.sql). O upgrade real
  /// deve ocorrer no backend, via webhook do provedor de pagamento (Stripe),
  /// que usa a service_role para escrever 'pro' no perfil. Após o pagamento,
  /// o cliente apenas re-consulta o status atualizado.
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
