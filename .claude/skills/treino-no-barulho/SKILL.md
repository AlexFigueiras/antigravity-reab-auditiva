---
name: treino-no-barulho
description: Funcionamento do treino "No barulho" (Nível 4, efeito coquetel / fala no ruído com SNR adaptativo). Use ao mexer em playCocktailStimulus, setNoiseIntensity, currentSNR/maxNoiseThreshold ou na progressão de ruído. Carrega só o contexto deste treino.
---

# Treino: No barulho (Nível 4 — Efeito coquetel / fala no ruído)

Fala + ruído de fundo a um SNR controlado (entender alguém num restaurante cheio).

**Leia o doc de referência antes de mexer:** [docs/treinos/no-barulho.md](../../../docs/treinos/no-barulho.md)

Pontos-chave (detalhes no doc):
- Engine: `playCocktailStimulus` em `lib/audio_engine/audio_engine.dart` — zera panning (fala binaural); ruído = `10^(-snrDb/20)`.
- Progressão: `GamificationController` — SNR começa em 20 dB; acerto ≥80% baixa SNR em 2 dB (mais difícil). Não inverter o sinal.
- Tela: `lib/ui/screens/training_dashboard.dart`. A tela DEVE inicializar o motor, senão a fala sai muda.
