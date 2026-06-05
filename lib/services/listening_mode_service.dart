import 'package:shared_preferences/shared_preferences.dart';
import '../core/listening_mode.dart';

/// Persiste e expõe a [ListeningMode] (com/sem aparelho) escolhida no onboarding.
///
/// Guardamos em SharedPreferences (local, síncrono após [load]) para que telas
/// de áudio possam decidir o gate do EQ sem um round-trip ao Supabase a cada
/// sessão. A fonte de verdade do "usa aparelho?" continua no perfil do Supabase
/// (onboarding); aqui é só o espelho local que dirige o áudio.
class ListeningModeService {
  static const _key = 'listening_mode';

  static final ListeningModeService _instance = ListeningModeService._internal();
  factory ListeningModeService() => _instance;
  ListeningModeService._internal();

  ListeningMode _cached = ListeningMode.unaided;

  /// Último valor carregado/definido (default: sem aparelho).
  ListeningMode get cached => _cached;

  Future<ListeningMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached =
        prefs.getString(_key) == 'aided' ? ListeningMode.aided : ListeningMode.unaided;
    return _cached;
  }

  Future<void> set(ListeningMode mode) async {
    _cached = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.isAided ? 'aided' : 'unaided');
  }

  /// Conveniência: deriva a política da resposta booleana do onboarding.
  Future<void> setFromUsesHearingAid(bool usesAid) =>
      set(usesAid ? ListeningMode.aided : ListeningMode.unaided);
}
