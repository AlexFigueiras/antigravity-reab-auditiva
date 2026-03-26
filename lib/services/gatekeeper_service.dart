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
    final res = await Supabase.instance.client
        .from('profiles')
        .select('subscription_status')
        .eq('user_id', user.id)
        .single();

    final status = res['subscription_status'] as String? ?? 'free';
    
    // Níveis 3 e 4 exigem status 'pro' ou 'elite'
    return status != 'free';
  }

  /// Atualiza o status de assinatura após pagamento bem-sucedido [MONETIZAÇÃO]
  Future<void> upgradeToPro() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client
        .from('profiles')
        .update({'subscription_status': 'pro'})
        .eq('user_id', user.id);
    
    print("UPGRADE REALIZADO: Status Pro Ativo para ${user.id}");
  }
}
