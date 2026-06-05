---
name: treino-de-que-lado
description: Funcionamento do treino "De que lado" (Nível 3, atenção espacial / panning binaural esquerda-centro-direita). Use ao mexer em playSpatialStimulus, SpatialController, erro angular ou telemetria de RT espacial. Carrega só o contexto deste treino.
---

# Treino: De que lado (Nível 3 — Atenção espacial)

A palavra vem da esquerda, centro ou direita; a pessoa indica o lado.

**Leia o doc de referência antes de mexer:** [docs/treinos/de-que-lado.md](../../../docs/treinos/de-que-lado.md)

Pontos-chave (detalhes no doc):
- Engine: `playSpatialStimulus` em `lib/audio_engine/audio_engine.dart` — aqui o panning é intencional (-1 esq / 0 centro / +1 dir), ≠ níveis 2/4.
- Lógica: `processSpatialResponse` em `lib/core/spatial_controller.dart` — acerto se erro angular < 0.1; RT em 3 fatores.
- ⚠️ `spatial_controller.dart` ainda tem linguagem "cockpit/radar" proibida (SYSTEM.md §10) — humanizar ao editar.
- Tela: `lib/ui/screens/training_dashboard.dart`. A tela DEVE inicializar o motor, senão a fala sai muda.
