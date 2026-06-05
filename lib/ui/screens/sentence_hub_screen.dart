import 'package:flutter/material.dart';
import '../../core/environments.dart';
import '../../models/audiogram.dart';
import 'sentence_training_screen.dart';

/// Hub "Ajude o Seu João": lista os ambientes que ele frequenta. A pessoa
/// escolhe um lugar e entra na cena daquele ambiente para treinar a
/// compreensão de frases no barulho real do local.
///
/// Linguagem humana, cards grandes e alto contraste (público 55–75 — PRODUTO.md).
class SentenceHubScreen extends StatelessWidget {
  final Audiogram audiogram;
  const SentenceHubScreen({super.key, required this.audiogram});

  static const Color _bg = Color(0xFF101418);
  static const Color _textMain = Color(0xFFF2F4F7);
  static const Color _textSoft = Color(0xFFB4BCC8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Frases do dia a dia',
            style: TextStyle(color: _textMain, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text('Ajude o Seu João',
                style: TextStyle(
                    color: _textMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Ele vai a vários lugares cheios de barulho. Escolha um e ajude '
              'o Seu João a entender o que falam com ele.',
              style: TextStyle(color: _textSoft, fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 24),
            for (final env in kEnvironments) ...[
              _EnvironmentCard(
                env: env,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SentenceTrainingScreen(
                      audiogram: audiogram,
                      environment: env,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  final TrainingEnvironment env;
  final VoidCallback onTap;
  const _EnvironmentCard({required this.env, required this.onTap});

  static const Color _card = Color(0xFF1B2128);
  static const Color _textMain = Color(0xFFF2F4F7);
  static const Color _textSoft = Color(0xFFB4BCC8);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: env.color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: env.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(env.icon, color: env.color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(env.title,
                        style: const TextStyle(
                            color: _textMain,
                            fontSize: 19,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(env.subtitle,
                        style: const TextStyle(
                            color: _textSoft, fontSize: 14, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _textSoft, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
