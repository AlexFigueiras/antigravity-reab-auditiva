import 'package:flutter/material.dart';
import '../../core/listening_mode.dart';

/// Banner de instrução da condição de escuta (com/sem aparelho), com confirmação
/// ativa opcional. Pensado para o público idoso: ícone grande, frase curta, alto
/// contraste e o "porquê" em linguagem humana. Ver plano 0.4 (requisito de UX/UI).
///
/// Aparece no INÍCIO do teste de audição e de cada sessão de treino, garantindo
/// que a pessoa esteja na mesma condição em que foi testada (e que o EQ do app
/// não empilhe com o aparelho).
class ListeningModeBanner extends StatelessWidget {
  final ListeningMode mode;

  /// Quando não-nulo, mostra a confirmação ativa ("Estou sem/com o aparelho")
  /// e exige o toque antes de liberar o botão de começar.
  final bool? confirmed;
  final ValueChanged<bool>? onConfirmedChanged;

  const ListeningModeBanner({
    super.key,
    required this.mode,
    this.confirmed,
    this.onConfirmedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        mode.isAided ? const Color(0xFF3FB37F) : const Color(0xFF4F8DF7);
    final showConfirm = confirmed != null && onConfirmedChanged != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mode.isAided ? Icons.hearing : Icons.headphones_rounded,
                  color: accent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mode.instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mode.why,
            style: const TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.4),
          ),
          if (showConfirm) ...[
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onConfirmedChanged!(!(confirmed!)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: confirmed!
                      ? accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                      color: confirmed! ? accent : Colors.white24, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      confirmed!
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: confirmed! ? accent : Colors.white38,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mode.confirmLabel,
                        style: TextStyle(
                          color: confirmed! ? Colors.white : Colors.white70,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
