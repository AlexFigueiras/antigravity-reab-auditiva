---
name: treino-frases
description: Funcionamento do treino "Frases" (compreensão de fala em frase curta do dia a dia, par mínimo de uma consoante). Use ao mexer em sentence_bank.dart, sentence_training_screen ou no módulo de frases. Carrega só o contexto deste treino.
---

# Treino: Frases (Compreensão de fala em frase)

Ouve uma frase curta e escolhe entre alvo e distratora que diferem em uma consoante de alta frequência (ex. "A casa é bonita" vs "A taça é bonita").

**Leia o doc de referência antes de mexer:** [docs/treinos/frases.md](../../../docs/treinos/frases.md)

Pontos-chave (detalhes no doc):
- Conteúdo: `SENTENCE_BANK` em `lib/core/sentence_bank.dart` — `{target, distractor}`.
- Engine: sem método dedicado; reutiliza `playPhonemicStimulus` (panning 0.0, meio-ganho) passando a frase como `text`.
- Tela: `lib/ui/screens/sentence_training_screen.dart`. A tela DEVE inicializar o motor, senão a fala sai muda.
