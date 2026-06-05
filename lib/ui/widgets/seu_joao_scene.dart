import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/environments.dart';

/// Estado de humor do Seu João, controlado pela tela de treino.
enum JoaoMood {
  /// Parado, esperando começar.
  idle,

  /// Ouvindo a frase (o áudio está tocando) — balão com ondas de som.
  listening,

  /// A pessoa acertou — Seu João sorri e balança a cabeça.
  happy,

  /// A pessoa errou — leve "que pena", sem punir.
  sad,
}

/// Cena animada do Seu João num ambiente (restaurante, academia, praça,
/// mercado). Tudo desenhado em Flutter puro — sem assets de arte:
/// - avatar com respiração sutil (escala em loop);
/// - balão de fala com ondas de som pulsando quando ele "ouve";
/// - reação de acerto (bounce) / erro (shake leve).
class SeuJoaoScene extends StatefulWidget {
  final TrainingEnvironment environment;
  final JoaoMood mood;

  const SeuJoaoScene({
    super.key,
    required this.environment,
    required this.mood,
  });

  @override
  State<SeuJoaoScene> createState() => _SeuJoaoSceneState();
}

class _SeuJoaoSceneState extends State<SeuJoaoScene>
    with TickerProviderStateMixin {
  late final AnimationController _breath; // respiração contínua
  late final AnimationController _wave; // ondas de som no balão
  late final AnimationController _reaction; // bounce/shake na reação

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _syncToMood();
  }

  @override
  void didUpdateWidget(SeuJoaoScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _syncToMood();
  }

  void _syncToMood() {
    if (widget.mood == JoaoMood.listening) {
      _wave.repeat();
    } else {
      _wave.stop();
    }
    if (widget.mood == JoaoMood.happy || widget.mood == JoaoMood.sad) {
      _reaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _wave.dispose();
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.environment.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Balão de fala com ondas de som (aparece quando ele está ouvindo).
        SizedBox(
          height: 64,
          child: AnimatedOpacity(
            opacity: widget.mood == JoaoMood.listening ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: _SpeechBubble(wave: _wave, color: color),
          ),
        ),
        const SizedBox(height: 8),
        // Avatar com respiração + reação (bounce no acerto, shake no erro).
        AnimatedBuilder(
          animation: Listenable.merge([_breath, _reaction]),
          builder: (context, _) {
            final breathScale = 1.0 + _breath.value * 0.035;
            double dx = 0;
            double bounce = 0;
            if (widget.mood == JoaoMood.sad) {
              // shake horizontal que decai
              dx = math.sin(_reaction.value * math.pi * 4) *
                  8 *
                  (1 - _reaction.value);
            } else if (widget.mood == JoaoMood.happy) {
              // pequeno pulo que decai
              bounce = -math.sin(_reaction.value * math.pi) * 14;
            }
            return Transform.translate(
              offset: Offset(dx, bounce),
              child: Transform.scale(
                scale: breathScale,
                child: CustomPaint(
                  size: const Size(170, 170),
                  painter: _JoaoFacePainter(
                    mood: widget.mood,
                    accent: color,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Balão branco com três barras de som que pulsam (indica "ele está ouvindo").
class _SpeechBubble extends StatelessWidget {
  final AnimationController wave;
  final Color color;
  const _SpeechBubble({required this.wave, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2128),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: AnimatedBuilder(
        animation: wave,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(4, (i) {
              // Cada barra com fase própria, formando uma "onda".
              final phase = wave.value * 2 * math.pi + i * 0.9;
              final h = 10 + (math.sin(phase) * 0.5 + 0.5) * 22;
              return Container(
                width: 6,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Desenha o rosto do Seu João (senhor simpático, cabelo grisalho, óculos e
/// bigode) com a expressão variando conforme o humor. Tudo em vetor, sem assets.
class _JoaoFacePainter extends CustomPainter {
  final JoaoMood mood;
  final Color accent;

  _JoaoFacePainter({required this.mood, required this.accent});

  static const _skin = Color(0xFFE8C39A);
  static const _skinShade = Color(0xFFD9AE82);
  static const _hair = Color(0xFFCBD2DA);
  static const _dark = Color(0xFF2A2F36);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 6);
    final r = size.width * 0.32;

    final fill = Paint()..isAntiAlias = true;

    // Pescoço/ombros (sugestão), para não ficar uma cabeça flutuando.
    fill.color = const Color(0xFF3A4350);
    final shoulders = Path()
      ..moveTo(c.dx - r * 1.4, size.height)
      ..quadraticBezierTo(
          c.dx - r * 1.2, c.dy + r * 0.6, c.dx - r * 0.5, c.dy + r * 0.95)
      ..lineTo(c.dx + r * 0.5, c.dy + r * 0.95)
      ..quadraticBezierTo(
          c.dx + r * 1.2, c.dy + r * 0.6, c.dx + r * 1.4, size.height)
      ..close();
    canvas.drawPath(shoulders, fill);

    // Cabelo grisalho (atrás da cabeça).
    fill.color = _hair;
    canvas.drawCircle(c.translate(0, -r * 0.25), r * 1.04, fill);

    // Rosto.
    fill.color = _skin;
    canvas.drawCircle(c, r, fill);

    // Orelhas.
    canvas.drawCircle(c.translate(-r, 0), r * 0.18, fill);
    canvas.drawCircle(c.translate(r, 0), r * 0.18, fill);

    // Sombra suave no queixo.
    fill.color = _skinShade.withValues(alpha: 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.92),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = _skinShade.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..strokeCap = StrokeCap.round,
    );

    final eyeY = c.dy - r * 0.15;
    final eyeDx = r * 0.42;

    // Óculos (aro do accent do ambiente).
    final glasses = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(c.dx - eyeDx, eyeY), r * 0.28, glasses);
    canvas.drawCircle(Offset(c.dx + eyeDx, eyeY), r * 0.28, glasses);
    canvas.drawLine(Offset(c.dx - eyeDx + r * 0.24, eyeY),
        Offset(c.dx + eyeDx - r * 0.24, eyeY), glasses);

    // Olhos — fecham num sorriso quando feliz.
    final eyePaint = Paint()
      ..color = _dark
      ..isAntiAlias = true
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (mood == JoaoMood.happy) {
      // olhos em "^" (sorriso nos olhos)
      for (final ex in [c.dx - eyeDx, c.dx + eyeDx]) {
        final p = Path()
          ..moveTo(ex - r * 0.12, eyeY + r * 0.02)
          ..quadraticBezierTo(ex, eyeY - r * 0.12, ex + r * 0.12, eyeY + r * 0.02);
        canvas.drawPath(p, eyePaint);
      }
    } else {
      final dot = Paint()
        ..color = _dark
        ..isAntiAlias = true;
      final eyeR = mood == JoaoMood.listening ? r * 0.11 : r * 0.09;
      canvas.drawCircle(Offset(c.dx - eyeDx, eyeY), eyeR, dot);
      canvas.drawCircle(Offset(c.dx + eyeDx, eyeY), eyeR, dot);
    }

    // Sobrancelhas (levemente erguidas quando ouvindo; tristes quando sad).
    final brow = Paint()
      ..color = _hair
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    final browY = eyeY - r * 0.42;
    double browTilt = 0;
    if (mood == JoaoMood.sad) browTilt = r * 0.10;
    if (mood == JoaoMood.listening) browTilt = -r * 0.06;
    canvas.drawLine(
        Offset(c.dx - eyeDx - r * 0.16, browY + browTilt),
        Offset(c.dx - eyeDx + r * 0.16, browY - browTilt * 0.4),
        brow);
    canvas.drawLine(
        Offset(c.dx + eyeDx - r * 0.16, browY - browTilt * 0.4),
        Offset(c.dx + eyeDx + r * 0.16, browY + browTilt),
        brow);

    // Bigode grisalho.
    final mouthY = c.dy + r * 0.42;
    fill.color = _hair;
    final mustache = Path()
      ..moveTo(c.dx, mouthY - r * 0.12)
      ..quadraticBezierTo(
          c.dx - r * 0.30, mouthY - r * 0.28, c.dx - r * 0.42, mouthY - r * 0.02)
      ..quadraticBezierTo(
          c.dx - r * 0.28, mouthY - r * 0.06, c.dx, mouthY - r * 0.04)
      ..quadraticBezierTo(
          c.dx + r * 0.28, mouthY - r * 0.06, c.dx + r * 0.42, mouthY - r * 0.02)
      ..quadraticBezierTo(
          c.dx + r * 0.30, mouthY - r * 0.28, c.dx, mouthY - r * 0.12)
      ..close();
    canvas.drawPath(mustache, fill);

    // Boca — varia com o humor.
    final mouth = Paint()
      ..color = const Color(0xFF7A4B3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final mPath = Path();
    switch (mood) {
      case JoaoMood.happy:
        mPath
          ..moveTo(c.dx - r * 0.26, mouthY + r * 0.02)
          ..quadraticBezierTo(
              c.dx, mouthY + r * 0.34, c.dx + r * 0.26, mouthY + r * 0.02);
        break;
      case JoaoMood.sad:
        mPath
          ..moveTo(c.dx - r * 0.22, mouthY + r * 0.20)
          ..quadraticBezierTo(
              c.dx, mouthY + r * 0.02, c.dx + r * 0.22, mouthY + r * 0.20);
        break;
      case JoaoMood.listening:
        // boca levemente aberta (atento)
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx, mouthY + r * 0.14),
              width: r * 0.22,
              height: r * 0.20),
          Paint()..color = const Color(0xFF7A4B3A),
        );
        break;
      case JoaoMood.idle:
        mPath
          ..moveTo(c.dx - r * 0.20, mouthY + r * 0.10)
          ..quadraticBezierTo(
              c.dx, mouthY + r * 0.20, c.dx + r * 0.20, mouthY + r * 0.10);
        break;
    }
    canvas.drawPath(mPath, mouth);
  }

  @override
  bool shouldRepaint(_JoaoFacePainter old) =>
      old.mood != mood || old.accent != accent;
}
