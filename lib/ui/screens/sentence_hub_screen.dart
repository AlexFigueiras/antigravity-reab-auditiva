import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/environments.dart';
import '../../models/audiogram.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/theme_controller.dart';
import '../theme/app_palette.dart';
import 'sentence_training_screen.dart';

/// Hub "Ajude o Seu João": lista os ambientes que ele frequenta. A pessoa
/// escolhe um lugar e entra na cena daquele ambiente para treinar a
/// compreensão de frases no barulho real do local.
///
/// Linguagem humana, cards grandes e alto contraste (público 55–75 — PRODUTO.md).
class SentenceHubScreen extends StatelessWidget {
  final Audiogram audiogram;
  const SentenceHubScreen({super.key, required this.audiogram});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AppPalette p = context.watch<ThemeController>().palette;
    final Color bg = p.bg;
    final Color textMain = p.textMain;
    final Color textSoft = p.textSoft;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.sentenceHubTitle,
            style: TextStyle(color: textMain, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(l10n.sentenceHubHeadline,
                style: TextStyle(
                    color: textMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              l10n.sentenceHubSubtitle,
              style: TextStyle(color: textSoft, fontSize: 16, height: 1.45),
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

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.watch<ThemeController>().palette;
    final Color card = p.card;
    final Color textMain = p.textMain;
    final Color textSoft = p.textSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
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
                    Text(env.localizedTitle(context),
                        style: TextStyle(
                            color: textMain,
                            fontSize: 19,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(env.localizedSubtitle(context),
                        style: TextStyle(
                            color: textSoft, fontSize: 14, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: textSoft, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
