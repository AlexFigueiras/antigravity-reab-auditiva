---
name: treino-distinguir-sons
description: Funcionamento do treino "Distinguir sons" (Nível 2, discriminação fonêmica / par mínimo). Use ao mexer em playPhonemicStimulus, getSmartPhoneme, phoneme_map.dart ou na seleção/personalização de pares de palavras (Sala/Fala). Carrega só o contexto deste treino.
---

# Treino: Distinguir sons (Nível 2 — Discriminação fonêmica)

Treino de par mínimo: ouve 1 palavra, escolhe entre 2 (ex. Sala/Fala).

**Leia o doc de referência antes de mexer:** [docs/treinos/distinguir-sons.md](../../../docs/treinos/distinguir-sons.md)

Pontos-chave (detalhes no doc):
- Engine: `playPhonemicStimulus` em `lib/audio_engine/audio_engine.dart` — zera o panning (fala binaural), aplica meio-ganho.
- Seleção: `getSmartPhoneme` em `lib/core/gamification_controller.dart` — retorna `null` sem audiograma (não fingir personalização).
- Conteúdo: `PHONEME_REHAB_DATA['level_2']` em `lib/core/phoneme_map.dart` (tem pendência de pseudo-palavras a corrigir).
- Tela: `lib/ui/screens/training_dashboard.dart`. A tela DEVE inicializar o motor, senão a fala sai muda.
