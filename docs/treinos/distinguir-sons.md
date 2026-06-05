# Treino: Distinguir sons (Nível 2 — Discriminação fonêmica)

> Doc de referência de UM treino. Carregue só este quando o trabalho for sobre
> discriminação fonêmica, para não varrer o código inteiro.
> Visão geral do sistema: [SYSTEM.md](../../SYSTEM.md). Princípios de produto: [PRODUTO.md](../../PRODUTO.md).

## O que é
Ouve **1 palavra**, escolhe entre **2** botões (par mínimo fonêmico). Ex.: ouve
"Sala" e decide entre `Sala` / `Fala`. Treina a discriminação de consoantes que
a perda auditiva confunde (fricativas/sibilantes agudas, plosivas).

## Fluxo de áudio
1. UI escolhe um par (ver "Seleção de estímulo" abaixo).
2. `AudioRehabEngine.playPhonemicStimulus({text, freqBand, extraBoostDb})`
   — [audio_engine.dart:105](../../lib/audio_engine/audio_engine.dart#L105).
   - **Zera o panning** (`setTargetPanning(0.0)`) — fala é SEMPRE binaural.
     Sem isso herda o ±1.0 do teste de audição e zera um canal (armadilha #2 do SYSTEM.md).
   - Ganho clínico = `getCompensatoryGain(freqBand) + extraBoostDb` (meio-ganho).
   - TTS nativo → WAV → Float32 48 kHz → DSP nativo.
3. Banner fixo explica o som: *"💡 Som do S — como em sala."*
4. Feedback humano: *"Isso! Você ouviu certo."* / *"Quase. A palavra era 'X'."*

## Seleção de estímulo (personalização clínica)
`GamificationController.getSmartPhoneme(audiogramData)`
— [gamification_controller.dart:43](../../lib/core/gamification_controller.dart#L43).
- **Retorna `null` se não há audiograma** → a UI deve pedir o teste de audição,
  NÃO fingir que personaliza (honestidade clínica, SYSTEM.md §4.3).
- Filtra frequências com perda **> 25 dB HL**.
- Prioriza pares cujo `freq_band` está a **±1500 Hz** de uma freq crítica.
- Sem match crítico → sorteio legítimo dentro do nível.

## Conteúdo
`PHONEME_REHAB_DATA['level_2']` em
[phoneme_map.dart](../../lib/core/phoneme_map.dart) — `{target, distractor, freq_band, type}`.
Zonas: alta (6–8 kHz, fricativas/sibilantes), média (3–5 kHz, plosivas/transições).
São **35 pares mínimos de palavras reais** (Sala/Fala, Vila/Fila, Dado/Tato, Rosa/Roça…).
A lista é sorteada dinamicamente (`stimuli.length`), então pode crescer/encolher livre.

> Histórico: antes havia pseudo-palavras ("Felo", "Fopa", "Tedo") e 70 placeholders
> `Palavra1…/Falsa1…` que confundiam o público idoso — substituídos por palavras reais.
> Ao adicionar itens, manter a regra: par mínimo de palavras reais (sem pseudo-palavra).

## Telas
- Principal: [training_dashboard.dart](../../lib/ui/screens/training_dashboard.dart) (níveis 2/3/4).
- Legada/específica: [phonemic_discrimination_screen.dart](../../lib/screens/phonemic_discrimination_screen.dart).

## Armadilhas
- **Motor não inicializado → fala muda sem erro** (`_verifySecurityScope` lança e a
  UI engole). A tela DEVE chamar `AudioServiceManager().initializeEngineForUser(audiogram)`.
  Ver SYSTEM.md §7.
- Diagnóstico de fala: log `[TTS_DIAG]` em `_synthesizeSpeechSamples`.
