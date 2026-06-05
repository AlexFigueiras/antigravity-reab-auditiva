# Treino: De que lado (Nível 3 — Atenção espacial)

> Doc de referência de UM treino. Carregue só este quando o trabalho for sobre
> atenção espacial / panning, para não varrer o código inteiro.
> Visão geral: [SYSTEM.md](../../SYSTEM.md). Produto/UX: [PRODUTO.md](../../PRODUTO.md).

## O que é
A palavra vem da **esquerda, centro ou direita**; a pessoa indica de que lado
ouviu. Treina atenção espacial / localização binaural.

## Fluxo de áudio
`AudioRehabEngine.playSpatialStimulus({text, panning, freqBand=4000})`
— [audio_engine.dart:132](../../lib/audio_engine/audio_engine.dart#L132).
- **Panning aqui é intencional** (≠ nível 2/4, que sempre zeram): `-1.0` esquerda,
  `0.0` centro, `+1.0` direita. A separação L/R vem do mixer nativo (oboe_engine.cpp):
  `-1.0` zera o canal direito, `+1.0` zera o esquerdo.
- Ganho clínico de meio-ganho aplicado em `freqBand` (default 4 kHz, otimizado p/ agudos).
- TTS nativo → WAV → 48 kHz → DSP.

## Lógica de resposta e progressão
`SpatialController.processSpatialResponse({targetPanning, selectedPanning, phoneme})`
— [spatial_controller.dart:19](../../lib/core/spatial_controller.dart#L19).
- Erro angular = `|targetPanning - selectedPanning|`. Acerto se **< 0.1**.
- 5 acertos consecutivos → reporte de voz e reseta a sequência.
- Telemetria de RT (3 fatores: HW timestamp, latência nativa, offset sistêmico)
  gravada em `SessionEventBuffer`. Descarta cliques < 10 ms; alerta RT suspeito no Bluetooth.

## Telas
- Principal: [training_dashboard.dart](../../lib/ui/screens/training_dashboard.dart).
- Legada: [spatial_attention_screen.dart](../../lib/screens/spatial_attention_screen.dart).

## Armadilhas
- **Motor não inicializado → fala muda** (SYSTEM.md §7). A tela DEVE inicializar o motor.
- ⚠️ **Regressão de tema (SYSTEM.md §10):** `spatial_controller.dart` ainda usa
  linguagem "cockpit/radar" — `"SISTEMA DE RADAR ATIVO"`, `"DESVIO DE ROTA DETECTADO"`,
  `"ACUIDADE ESPACIAL EM 98%"`. O produto proíbe tema cockpit/militar. Trocar por
  linguagem humana ("Ouvindo...", "Quase, era do outro lado") quando for mexer aqui.
