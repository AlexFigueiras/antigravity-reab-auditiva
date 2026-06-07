import 'package:flutter/services.dart';

/// Acesso a configurações de acessibilidade de áudio do dispositivo.
class AudioAccessibility {
  static const _channel = MethodChannel('bosyn/audio_accessibility');

  /// Volume de mídia de REFERÊNCIA do app (fração 0..1).
  ///
  /// Por que existe: o nível que chega ao tímpano é
  /// `amplitude digital × volume do sistema × sensibilidade do fone`. O app só
  /// controla a amplitude digital. Para o teste de audição e os treinos viverem
  /// no MESMO referencial (senão o limiar medido não bate com o ganho aplicado),
  /// fixamos o volume de mídia neste ponto único e conhecido.
  ///
  /// 85% (e não 100%) de propósito: deixa headroom para o EQ de meia-perda somar
  /// ganho sem bater no soft-limiter de -3 dBFS do DSP, e protege o ouvido.
  /// Ponto de verdade — ajuste aqui se calibrar no aparelho.
  static const double kReferenceVolumeFraction = 0.85;

  /// Margem para considerar que o volume "está no nível" (evita falso alarme por
  /// 1 passo de diferença na granularidade do volume do device).
  static const double kVolumeTolerance = 0.07;

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

  /// Volume de mídia atual como fração 0..1.
  ///
  /// Fallback 1.0 em plataforma sem nativo (desktop) → tratado como "no nível",
  /// para não travar o fluxo onde não há como controlar o volume.
  static Future<double> getMediaVolumeFraction() async {
    try {
      final result =
          await _channel.invokeMethod<double>('getMediaVolumeFraction');
      return result ?? 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  /// Define o volume de mídia a partir de uma fração 0..1 (silencioso, sem a UI
  /// de volume do sistema). No-op gracioso em plataforma sem nativo.
  static Future<void> setMediaVolumeFraction(double fraction) async {
    try {
      await _channel.invokeMethod('setMediaVolumeFraction', {
        'fraction': fraction.clamp(0.0, 1.0),
      });
    } catch (_) {
      // sem nativo / falha → ignora; o gate de UI cuida do aviso ao usuário.
    }
  }

  /// True se o volume atual está dentro da tolerância do nível de referência.
  static Future<bool> isAtReferenceVolume() async {
    final current = await getMediaVolumeFraction();
    return (current - kReferenceVolumeFraction).abs() <= kVolumeTolerance;
  }

  /// Abre as configurações de Texto-para-fala do sistema, para o usuário
  /// instalar a voz da variante certa (ex.: pt-BR). Só faz sentido no Android —
  /// o SO não permite instalar voz silenciosamente, apenas guiar o usuário.
  /// Retorna true se conseguiu abrir; false (no-op) fora do Android ou em falha.
  static Future<bool> openTtsSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openTtsSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// "Subida suave": leva o volume de mídia até o nível de referência em poucos
  /// passos curtos, para não dar um susto de som alto de uma vez (público idoso,
  /// fone já no ouvido). Se já está no nível, não faz nada.
  static Future<void> rampToReferenceVolume() async {
    final current = await getMediaVolumeFraction();
    if ((current - kReferenceVolumeFraction).abs() <= kVolumeTolerance) return;

    // Sobe (ou desce) em 3 degraus de ~120ms. A interpolação linear é suficiente
    // — a granularidade real do volume é discreta no device de qualquer forma.
    const steps = 3;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final value = current + (kReferenceVolumeFraction - current) * t;
      await setMediaVolumeFraction(value);
      if (i < steps) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
  }
}
