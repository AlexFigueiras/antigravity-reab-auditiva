import 'package:flutter/services.dart';

/// Acesso a configurações de acessibilidade de áudio do dispositivo.
class AudioAccessibility {
  static const _channel = MethodChannel('bosyn/audio_accessibility');

  /// Retorna true se a opção "Áudio mono" do Android estiver ligada.
  ///
  /// Essa opção soma os canais esquerdo+direito e toca igual nos dois ouvidos,
  /// o que **invalida o teste de audição** (cada orelha precisa ser isolada).
  /// Em plataformas sem o canal nativo, retorna false (não bloqueia).
  static Future<bool> isMonoAudioEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isMonoAudioEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
