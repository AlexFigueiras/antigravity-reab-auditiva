---
name: teste-de-audicao
description: Funcionamento do "Teste de audição" (módulo âncora — mede o audiograma que personaliza todos os treinos). Use ao mexer em threshold_test_screen.dart, playPureTone, isolamento de orelha por panning, staircase Hughson-Westlake, catch-trials, familiarização ou na persistência do Audiogram (saveAudiogram/getLatestAudiogram). Carrega só o contexto deste módulo.
---

# Teste de audição (módulo âncora — gera o audiograma)

Mede o limiar por frequência em cada orelha (tom puro isolado por panning) e produz o
`Audiogram` que personaliza N2/N3/N4 (fonemas, ganho de meia-perda, zona morta coclear).
Não é diagnóstico — triagem relativa. UI: "teste de audição relativo" / "nível de som".

**Leia o doc de referência antes de mexer:** [docs/treinos/teste-de-audicao.md](../../../docs/treinos/teste-de-audicao.md)

Pontos-chave (detalhes no doc):
- Tela/lógica: `lib/screens/threshold_test_screen.dart` — máquina de estados completa
  (confirmação sem aparelho → escolher orelha → familiarização → staircase → catch-trials).
- Engine: `playPureTone` em `lib/audio_engine/audio_engine.dart` com **panning de amplitude**
  (`setTargetPanning ±1.0`) para isolar a orelha — NÃO a binauralização dos treinos.
- Staircase Hughson-Westlake adaptado: ouviu → −10 dB; não ouviu → +5 dB; limiar confirmado
  com 2 "ouviu" no mesmo nível. Catch-trials de silêncio (20%, sem dois seguidos).
- Frequências (código, 10 pontos): `250,500,750,1000,1500,2000,3000,4000,6000,8000`.
- **Contrato de persistência:** a tela só MEDE e devolve via `Navigator.pop` (`left`/`right`).
  Quem SALVA é o chamador — `home_screen.dart`/`onboarding_screen.dart` → `saveAudiogram`.
  Se "não salva", olhe o chamador, não a tela.
- Esta tela inicializa o motor sozinha (não usa `AudioServiceManager` como os treinos).
- ⚠️ Há inconsistências entre o código e SYSTEM.md §2.2/§8.4/§8.11 (nº de frequências e dB de
  familiarização) — ver seção final do doc; corrigir o doc-mestre ao tocar nisso.
