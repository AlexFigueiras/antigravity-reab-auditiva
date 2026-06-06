# GEMINI.md

As regras de workspace deste projeto são as de **[AGENTS.md](AGENTS.md)** — leia-o antes
de qualquer tarefa. Ele define o que **consultar** antes de codar e o que **atualizar**
depois (é o que mantém PRODUTO.md / SYSTEM.md / docs vivos).

Para trabalho de audiologia/clínica ou do motor de áudio, as skills do projeto estão em
`.agent/skills/AUDIOLOGIA_CLINICA` e `.agent/skills/DSP_AUDIO_ENGINE`.

Lembretes inegociáveis (detalhe em AGENTS.md §3 e SYSTEM.md §10):

- Linguagem humana (público 55–75), **sem** tema cockpit/militar nem jargão.
- **Sem** métrica falsa (XP, IAB, Energia/Fadiga Neural) nem gráfico decorativo.
- TTS = `flutter_tts` nativo; fala sempre pelo DSP nativo (ganho de meia-perda).
- Corrigiu um bug → registre em SYSTEM.md §8. Mudou comportamento → atualize o doc dono.
