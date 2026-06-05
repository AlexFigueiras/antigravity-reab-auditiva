# Treino: Frases (Compreensão de fala em frase)

> Doc de referência de UM treino. Carregue só este quando o trabalho for sobre o
> módulo de frases, para não varrer o código inteiro.
> Visão geral: [SYSTEM.md](../../SYSTEM.md). Produto/UX: [PRODUTO.md](../../PRODUTO.md).

## O que é
Em vez de uma palavra isolada, a pessoa ouve uma **frase curta do dia a dia** e
escolhe entre a frase-alvo e uma distratora que difere em **uma consoante de alta
frequência** (difícil de ouvir na perda auditiva). Ex.: "A casa é bonita" vs
"A taça é bonita".

## Conteúdo
`SENTENCE_BANK` em [sentence_bank.dart](../../lib/core/sentence_bank.dart) —
lista de `{target, distractor}`. Contextos: família, telefone, restaurante, cotidiano.

## Fluxo de áudio
Não há método de engine dedicado a frases: o módulo reutiliza o caminho de fala
binaural. A frase entra como `text` em `playPhonemicStimulus` (panning 0.0, meio-ganho)
— [audio_engine.dart:105](../../lib/audio_engine/audio_engine.dart#L105). TTS nativo
sintetiza a frase inteira → WAV → 48 kHz → DSP.

## Tela
[sentence_training_screen.dart](../../lib/ui/screens/sentence_training_screen.dart).

## Armadilhas
- **Motor não inicializado → fala muda** (SYSTEM.md §7). A tela DEVE chamar
  `AudioServiceManager().initializeEngineForUser(audiogram)`.
- Frase é mais longa que palavra → mais amostras no ring buffer (5 MB) e maior
  tempo de síntese TTS. Confirmar que a frase inteira cabe e toca sem corte.
- Ao adicionar frases, manter a regra do par mínimo: diferença de UMA consoante
  de alta frequência, palavras reais (sem pseudo-palavra).
