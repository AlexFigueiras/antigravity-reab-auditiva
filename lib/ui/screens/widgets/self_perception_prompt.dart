import 'package:flutter/material.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Pergunta semanal de autopercepção (Fase 3).
/// Escala 1-5 acessível: 1 = Muito difícil ... 5 = Muito bem.
/// Retorna a nota escolhida (1-5) via [onSubmit].
class SelfPerceptionPrompt extends StatelessWidget {
  final void Function(int score) onSubmit;
  final VoidCallback? onDismiss;

  const SelfPerceptionPrompt({
    super.key,
    required this.onSubmit,
    this.onDismiss,
  });

  static const List<Map<String, dynamic>> _scores = [
    {'score': 1, 'emoji': '😟', 'key': 'veryHard'},
    {'score': 2, 'emoji': '🙁', 'key': 'hard'},
    {'score': 3, 'emoji': '😐', 'key': 'soSo'},
    {'score': 4, 'emoji': '🙂', 'key': 'well'},
    {'score': 5, 'emoji': '😀', 'key': 'veryWell'},
  ];

  String _label(String key, AppLocalizations l10n) {
    switch (key) {
      case 'veryHard': return l10n.selfPerceptionVeryHard;
      case 'hard':     return l10n.selfPerceptionHard;
      case 'soSo':     return l10n.selfPerceptionSoSo;
      case 'well':     return l10n.selfPerceptionWell;
      default:         return l10n.selfPerceptionVeryWell;
    }
  }

  /// Exibe como diálogo modal. Salva via [onSubmit] ao escolher.
  static Future<void> show(
    BuildContext context, {
    required void Function(int score) onSubmit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.all(20),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SelfPerceptionPrompt(
          onSubmit: (score) {
            Navigator.of(ctx).pop();
            onSubmit(score);
          },
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.selfPerceptionQuestion,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white38),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selfPerceptionSubtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ..._scores.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 60),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.white12)),
                    ),
                    onPressed: () => onSubmit(opt['score'] as int),
                    child: Row(
                      children: [
                        Text(opt['emoji'] as String,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Text(_label(opt['key'] as String, l10n),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
