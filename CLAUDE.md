# CLAUDE.md

As regras de workspace deste projeto são as de **[AGENTS.md](AGENTS.md)** — leia-o antes
de qualquer tarefa. Ele define o que **consultar** antes de codar e o que **atualizar**
depois (é o que mantém PRODUTO.md / SYSTEM.md / docs vivos).

Lembretes inegociáveis (detalhe em AGENTS.md §3 e SYSTEM.md §10):

- Linguagem humana (público 55–75), **sem** tema cockpit/militar nem jargão.
- **Sem** métrica falsa (XP, IAB, Energia/Fadiga Neural) nem gráfico decorativo.
- TTS = `flutter_tts` nativo; fala sempre pelo DSP nativo (ganho de meia-perda).
- Trabalhando em **um** treino? Carregue só a skill `.claude/skills/treino-*` dele.
- Corrigiu um bug → registre em SYSTEM.md §8. Mudou comportamento → atualize o doc dono.
