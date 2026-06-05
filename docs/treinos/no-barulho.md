# Treino: No barulho (Nível 4 — Efeito coquetel / fala no ruído)

> Doc de referência de UM treino. Carregue só este quando o trabalho for sobre
> fala no ruído / SNR, para não varrer o código inteiro.
> Visão geral: [SYSTEM.md](../../SYSTEM.md). Produto/UX: [PRODUTO.md](../../PRODUTO.md).

## O que é
Fala + ruído de fundo a um **SNR** (Signal-to-Noise Ratio) controlado, simulando o
"efeito coquetel" (entender alguém num restaurante cheio). Ouve 1, escolhe entre 2.

## Fluxo de áudio
`AudioRehabEngine.playCocktailStimulus({text, snrDb, noiseEnvironment, freqBand=4000})`
— [audio_engine.dart:177](../../lib/audio_engine/audio_engine.dart#L177).
- **Zera o panning** (`setTargetPanning(0.0)`) — fala binaural (igual nível 2).
- **Ruído FIXO e confortável** (`_kNoiseLevel = 0.32`, ~-10 dBFS) via `setNoiseIntensity`.
  Nunca muda com a dificuldade.
- **A FALA é que varia** com o SNR: `volFala = _kNoiseLevel * 10^(snrDb/20)`, clamp [0,1],
  passada como `targetVolume` em `_loadSampleToNative`.
  → SNR menor = fala mais baixa (abaixo do ruído) = mais difícil.
  Por quê: subir o ruído ficava alto e cansativo para o idoso; baixar a fala
  mantém o nível total de som constante (é como funcionam os testes clínicos de
  fala no ruído). Ver SYSTEM.md §8.
- Ganho clínico de meio-ganho no alvo. TTS nativo → 48 kHz → DSP.
- `noiseEnvironment`: Restaurante / Trânsito / Vento.
- Alias legado: `playSpeechInNoise({targetText, snrDb})` força `RESTAURANTE`.

## Progressão adaptativa de SNR
`GamificationController` — [gamification_controller.dart](../../lib/core/gamification_controller.dart).
- `_currentSNR` começa em **+10 dB** (`_kSnrStart`: fala no teto, ruído audível mas
  confortável). Getter: `currentSNR`. `resetSNR()` volta a +10.
- Em `addAcuityXP`: se `successRate >= 0.8` **e** `phonemes` contém `'cocktail'`,
  `_currentSNR -= 2.0` (a fala abaixa 2 dB), **até o piso `_kSnrFloor = 0 dB`**
  (fala no MESMO nível do ruído). Não descemos abaixo de 0 porque, com ruído fixo,
  SNR negativo deixa a fala baixa demais em termos absolutos (vol linear < 0.32) —
  inaudível até para quem ouve bem. Atualiza `_maxNoiseThreshold` (melhor/menor SNR
  vencido a 80% — métrica clínica persistida em `max_noise_threshold`).

## Telas
- Principal: [training_dashboard.dart](../../lib/ui/screens/training_dashboard.dart).
- Legada: [speech_in_noise_screen.dart](../../lib/screens/speech_in_noise_screen.dart).

## "Ouvir de novo" (replay)
`_replayCurrent()` deve chamar `_playLevel4Stimulus()` — que **repete** o estímulo
atual (mesmo par, mesmo SNR, mesmo `_currentEnvironment`). **Não** chamar
`_startLevel4()` no replay: isso sorteia um novo par e "avança" em vez de repetir.
O ambiente (`_currentEnvironment`) é sorteado **uma vez por estímulo** em
`_startLevel4` e reusado, para a repetição soar igual.

## Armadilhas
- **Motor não inicializado → fala muda** (SYSTEM.md §7). A tela DEVE inicializar o motor.
- SNR é em dB e **inversamente** ligado à dificuldade: subtrair de `_currentSNR` deixa
  MAIS difícil. Não inverter o sinal por engano.
- **Dificuldade = baixar a FALA, nunca subir o ruído.** O ruído é fixo (`_kNoiseLevel`).
  Voltar a variar o ruído reintroduz o incômodo de volume alto (SYSTEM.md §8, item 10).
- **Ruído vaza para outras telas se não for zerado** (SYSTEM.md §8, item 9). `stop()` e
  os estímulos limpos chamam `setNoiseIntensity(0.0)`.
