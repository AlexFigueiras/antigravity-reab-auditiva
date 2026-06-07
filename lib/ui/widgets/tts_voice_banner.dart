import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/audio_accessibility.dart';

/// Aviso (Home) de que a variante de voz do idioma atual NÃO está instalada no
/// device — então a fala dos treinos sairá com outro sotaque (ex.: pt-PT lendo
/// os pares mínimos do português). Estilo do [ListeningModeBanner]: público
/// 55–75, ícone grande, frase curta, alto contraste e o "porquê" humano.
///
/// O SO não deixa o app instalar voz silenciosamente; só guiamos o usuário:
/// no Android, um botão abre as configurações de TTS; no iOS/desktop, uma
/// instrução de onde habilitar. Ver docs/i18n.md (disponibilidade de voz).
class TtsVoiceBanner extends StatelessWidget {
  /// Nome humano da voz faltante, já no idioma da UI (ex.: "português do
  /// Brasil"). Vem da Home, que sabe qual locale está ativo.
  final String voiceName;

  /// Re-checa se a voz já foi instalada AGORA. Cobre o caso raro em que o TTS
  /// do device ainda não re-indexou a voz quando o usuário volta ao app (o
  /// auto-sumir do `resumed` não pegou). Botão "Já instalei a voz".
  final VoidCallback onRecheck;

  const TtsVoiceBanner({
    super.key,
    required this.voiceName,
    required this.onRecheck,
  });

  bool get _canOpenSettings => !kIsWeb && Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const accent = Color(0xFFE0A23C); // âmbar de atenção (não erro/vermelho)

    return Container(
      width: double.infinity,
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
              const Icon(Icons.record_voice_over, color: accent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.ttsVoiceMissingTitle(voiceName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ttsVoiceMissingWhy,
            style: const TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (_canOpenSettings)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: AudioAccessibility.openTtsSettings,
                icon: const Icon(Icons.settings, size: 22),
                label: Text(
                  l10n.ttsVoiceInstallButton,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            // iOS/desktop: a plataforma não expõe intent de instalação de voz —
            // só dá para orientar onde habilitar nos ajustes do sistema.
            Text(
              l10n.ttsVoiceMissingIosHint,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 14, height: 1.4),
            ),
          // "Já instalei" — re-checa na hora, para o caso raro do TTS ainda não
          // ter re-indexado a voz quando o usuário voltou (o auto-sumir falhou).
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onRecheck,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.ttsVoiceRecheck,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
