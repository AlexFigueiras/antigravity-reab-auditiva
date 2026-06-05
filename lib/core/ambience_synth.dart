import 'dart:math' as math;
import 'dart:typed_data';

/// Gera ambiências sonoras PROCEDURAIS (sem arquivos de áudio externos), uma por
/// ambiente do treino de frases. Não são gravações reais, mas cada lugar soa
/// claramente diferente — o que importa para o "efeito coquetel": um som de
/// fundo distinto e contínuo por baixo da fala.
///
/// Saída: Float32List mono a 48 kHz, ~10 s, com loop SEM EMENDA (crossfade nas
/// pontas) e normalizada. O nível final é controlado pelo volume do
/// `AmbienceLooper` nativo (ver audio_engine.dart). Para trocar por gravações
/// reais depois, basta carregar um WAV no mesmo `setAmbienceSample`.
class AmbienceSynth {
  static const int _sr = 48000;
  static const int _seconds = 10;

  /// Cache por ambiente — a síntese é determinística, então gera uma vez só.
  static final Map<String, Float32List> _cache = {};

  static Float32List generate(String env) {
    final cached = _cache[env];
    if (cached != null) return cached;

    final n = _sr * _seconds;
    final out = Float32List(n);
    final rng = math.Random(env.hashCode & 0x7fffffff);

    switch (env) {
      case 'restaurante':
        _restaurant(out, rng);
        break;
      case 'academia':
        _gym(out, rng);
        break;
      case 'praca':
        _plaza(out, rng);
        break;
      case 'mercado':
        _market(out, rng);
        break;
      default:
        _restaurant(out, rng);
    }

    _seamlessLoop(out);
    _normalize(out, 0.85);
    _cache[env] = out;
    return out;
  }

  // --- RESTAURANTE: murmúrio grave e quente + tilintar de talheres ---
  static void _restaurant(Float32List out, math.Random rng) {
    // Base: ruído passa-baixa (murmúrio de conversa difusa), com LFO lento.
    double lp = 0.0;
    for (int i = 0; i < out.length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      lp += 0.04 * (white - lp); // passa-baixa de um polo (quente)
      final lfo = 0.7 + 0.3 * math.sin(2 * math.pi * 0.15 * i / _sr);
      out[i] = lp * 1.8 * lfo;
    }
    // Tilintar de talheres: bursts agudos curtos, esparsos.
    _scatterEvents(out, rng, avgGapSec: 1.8, count: 6, paint: (buf, start) {
      final dur = (0.06 * _sr).toInt();
      final freq = 2600.0 + rng.nextDouble() * 2400.0;
      for (int k = 0; k < dur && start + k < buf.length; k++) {
        final env = math.exp(-k / (dur * 0.18));
        buf[start + k] += 0.5 * env * math.sin(2 * math.pi * freq * k / _sr);
      }
    });
  }

  // --- ACADEMIA: batida grave de música (~120 BPM) + cama de ruído ---
  static void _gym(Float32List out, math.Random rng) {
    // Cama de fundo leve.
    double lp = 0.0;
    for (int i = 0; i < out.length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      lp += 0.02 * (white - lp);
      out[i] = lp * 0.7;
    }
    // Batida: 120 BPM = 0.5 s/beat = 20 beats em 10 s (loop perfeito).
    final beatSamples = (_sr * 0.5).toInt();
    final kickDur = (0.16 * _sr).toInt();
    for (int b = 0; b < out.length ~/ beatSamples; b++) {
      final start = b * beatSamples;
      for (int k = 0; k < kickDur && start + k < out.length; k++) {
        final env = math.exp(-k / (kickDur * 0.25));
        // pitch caindo de ~90 Hz para ~45 Hz (kick eletrônico)
        final freq = 90.0 - 45.0 * (k / kickDur);
        out[start + k] += 0.9 * env * math.sin(2 * math.pi * freq * k / _sr);
      }
      // contratempo (hi-hat) no meio do beat
      final hatStart = start + beatSamples ~/ 2;
      final hatDur = (0.03 * _sr).toInt();
      for (int k = 0; k < hatDur && hatStart + k < out.length; k++) {
        final env = math.exp(-k / (hatDur * 0.3));
        out[hatStart + k] += 0.18 * env * (rng.nextDouble() * 2 - 1);
      }
    }
  }

  // --- PRAÇA: ar livre (vento suave agudo) + pássaros ---
  static void _plaza(Float32List out, math.Random rng) {
    // Base: ruído passa-alta suave (sensação aérea/aberta).
    double lp = 0.0;
    for (int i = 0; i < out.length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      lp += 0.10 * (white - lp);
      final hp = white - lp; // passa-alta
      final lfo = 0.6 + 0.4 * math.sin(2 * math.pi * 0.08 * i / _sr);
      out[i] = hp * 0.6 * lfo;
    }
    // Pássaros: chilreios curtos (sweep de frequência), esparsos.
    _scatterEvents(out, rng, avgGapSec: 2.2, count: 5, paint: (buf, start) {
      final dur = (0.14 * _sr).toInt();
      final f0 = 2200.0 + rng.nextDouble() * 1500.0;
      for (int k = 0; k < dur && start + k < buf.length; k++) {
        final t = k / dur;
        // sweep sobe e desce (trinado)
        final freq = f0 * (1.0 + 0.4 * math.sin(2 * math.pi * 3 * t));
        final env = math.sin(math.pi * t); // ataque/decay suave
        buf[start + k] += 0.4 * env * math.sin(2 * math.pi * freq * k / _sr);
      }
    });
  }

  // --- MERCADO / FEIRA: movimento médio agitado + pregões indistintos ---
  static void _market(Float32List out, math.Random rng) {
    // Base: ruído de banda média com modulação de amplitude rápida (agitação).
    double lp1 = 0.0, lp2 = 0.0;
    for (int i = 0; i < out.length; i++) {
      final white = rng.nextDouble() * 2 - 1;
      lp1 += 0.20 * (white - lp1);
      lp2 += 0.03 * (white - lp2);
      final band = lp1 - lp2; // passa-banda (médios)
      final am = 0.55 + 0.45 * math.sin(2 * math.pi * 0.9 * i / _sr);
      out[i] = band * 1.4 * am;
    }
    // Pregões: "vozes" indistintas (sine médio modulado), esparsas.
    _scatterEvents(out, rng, avgGapSec: 1.4, count: 7, paint: (buf, start) {
      final dur = (0.25 * _sr).toInt();
      final base = 240.0 + rng.nextDouble() * 160.0;
      for (int k = 0; k < dur && start + k < buf.length; k++) {
        final t = k / dur;
        final env = math.sin(math.pi * t);
        // formante simples: portadora + leve vibrato
        final freq = base * (1.0 + 0.05 * math.sin(2 * math.pi * 6 * t));
        buf[start + k] += 0.3 * env * math.sin(2 * math.pi * freq * k / _sr);
      }
    });
  }

  /// Espalha [count] eventos pelo buffer, com intervalo médio ~[avgGapSec],
  /// chamando [paint] para "desenhar" cada evento numa posição.
  static void _scatterEvents(
    Float32List buf,
    math.Random rng, {
    required double avgGapSec,
    required int count,
    required void Function(Float32List buf, int start) paint,
  }) {
    final gap = (avgGapSec * _sr).toInt();
    int pos = (rng.nextDouble() * gap).toInt();
    for (int e = 0; e < count; e++) {
      if (pos >= buf.length) break;
      paint(buf, pos);
      pos += (gap * (0.6 + rng.nextDouble() * 0.8)).toInt();
    }
  }

  /// Faz o loop sem emenda: cruza o fim com o começo num crossfade curto
  /// (raised cosine) para não estalar a cada volta.
  static void _seamlessLoop(Float32List out) {
    final fade = (0.05 * _sr).toInt(); // 50 ms
    if (out.length <= fade * 2) return;
    for (int k = 0; k < fade; k++) {
      final w = 0.5 - 0.5 * math.cos(math.pi * k / fade); // 0→1
      final tail = out[out.length - fade + k];
      final head = out[k];
      // mistura o rabo no começo de forma simétrica
      out[k] = head * w + tail * (1 - w);
    }
  }

  static void _normalize(Float32List out, double target) {
    double peak = 0.0;
    for (final s in out) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    if (peak <= 1e-6) return;
    final g = target / peak;
    for (int i = 0; i < out.length; i++) {
      out[i] *= g;
    }
  }
}
