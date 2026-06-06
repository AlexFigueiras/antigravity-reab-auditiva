# Regras de workspace — BOSYN (ear_training)

> **Fonte única das regras para qualquer agente** (Claude Code, Antigravity/Gemini, etc.).
> `CLAUDE.md` e `GEMINI.md` apenas apontam para cá. Leia isto **antes** de trabalhar.

## 1. Consulte antes de codar

| Antes de mexer em… | Leia primeiro |
|---|---|
| Qualquer coisa (norte de produto/clínico, métricas, "por quê") | [PRODUTO.md](PRODUTO.md) |
| Arquitetura, áudio, regras clínicas, onde ficam os arquivos, bugs já resolvidos | [SYSTEM.md](SYSTEM.md) |
| **UM** treino (N2/N3/N4/Frases) | só a skill `.claude/skills/treino-*` + `docs/treinos/*.md` dele — não varra o código todo |
| Lógica clínica / audiologia ou motor DSP/áudio | `.agent/skills/AUDIOLOGIA_CLINICA`, `.agent/skills/DSP_AUDIO_ENGINE` |

**Regra doc-antes-de-código:** se a realidade do código contradiz um doc, **corrija o doc
primeiro** (ou avise), depois mexa no código. Doc errado é pior que doc ausente.

## 2. Atualize depois de mudar (o que mantém os docs vivos)

Toda mudança de comportamento **exige** atualizar o doc dono daquele assunto, na mesma tarefa:

| Você… | Atualize |
|---|---|
| Corrigiu um bug ou descobriu uma armadilha | `SYSTEM.md` §8 (bugs resolvidos — não repita o erro) |
| Mudou/criou uma regra clínica ou uma "decisão a manter" | `SYSTEM.md` §4 / §10 |
| Mudou escopo de produto, público ou uma métrica | `PRODUTO.md` |
| Mudou o comportamento de um treino | o `docs/treinos/*.md` dele (e a skill, se a referência mudou) |
| Adicionou/removeu dependência ou passo de setup | `README.md` |
| Fez uma auditoria clínica relevante | índice em `docs/HISTORICO.md` |

## 3. Inegociáveis (não regredir — ver SYSTEM.md §10 e PRODUTO.md §5/§7)

- **Linguagem humana** para público 55–75. Proibido tema "cockpit/militar", verde
  fosforescente, monospace de telemetria e jargão ("PROTOCOLO", "RADAR", "TELEMETRIA").
- **Sem métrica inventada.** Nada de XP, "Energia Neural", "Índice de Acuidade (IAB)",
  "Fadiga Neural"/bloqueio por tempo, ou gráfico decorativo. Só progresso real e honesto.
- **Sem punição:** erros ensinam, não bloqueiam. Sessões curtas, tom gentil.
- **TTS = `flutter_tts` nativo do device**, nunca Google Cloud.
- **Fala SEMPRE pelo DSP nativo** (ganho de meia-perda), nunca playback direto.
- **Nível 4 ("No barulho"):** o ruído é **fixo**; quem dificulta é a fala abaixando.
- Honestidade clínica: o app **complementa**, não cura/diagnostica/substitui profissional.

## 4. Higiene

- **Nunca** commitar segredos. `.env` fica fora do git; use `.env.example` como modelo.
- Testar no celular antes de marcar um treino como pronto (ver SYSTEM.md §9).
- Um doc, um dono de responsabilidade — não duplicar conteúdo entre docs; linkar.
