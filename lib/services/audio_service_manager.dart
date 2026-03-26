import 'package:ear_training/audio_engine/audio_engine.dart';
import 'package:flutter/foundation.dart';

/// Centralizador do Gerenciamento de Áudio [ORQUESTRADOR]
/// Garante o controle estrito do Ciclo de Vida do Motor C++/Dart.
class AudioServiceManager {
  static final AudioServiceManager _instance = AudioServiceManager._internal();
  factory AudioServiceManager() => _instance;

  final AudioRehabEngine _engine = AudioRehabEngine();
  
  AudioServiceManager._internal();

  AudioRehabEngine get engine => _engine;

  /// Método Crítico de Segurança Industrial [BOSYN-ZERO-LATENCY]
  /// Interrompe qualquer fluxo de áudio, limpa buffers e reseta o engine nativo.
  /// Deve ser chamado ANTES de qualquer transição de tela.
  void forceStopAll() {
    try {
      _engine.stop();
      debugPrint("[AUDIO_MANAGER] forceStopAll executado: recursos liberados.");
    } catch (e) {
      debugPrint("[AUDIO_MANAGER] Erro durante forceStopAll: $e");
    }
  }

  /// Inicializa o motor clínico com o audiograma atual
  Future<void> initializeEngineForUser(dynamic audiogram) async {
    await _engine.initializeEngine(audiogram);
  }

  /// Liberação absoluta de memória [NATIVE-DSP-FFI]
  void dispose() {
    forceStopAll();
  }
}
