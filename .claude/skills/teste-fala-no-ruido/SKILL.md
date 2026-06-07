---
name: teste-fala-no-ruido
description: Funcionamento do "Teste de fala no barulho" (segundo módulo âncora — mede o SRT, o desfecho clínico de quanto a pessoa entende fala no ruído; "antes e depois"). Use ao mexer em outcome_test_screen.dart, frases Matrix (outcome_test_bank.dart), AdaptiveStaircase 2-down/1-up, SRT, ou na persistência do desfecho (saveOutcomeTest/getOutcomeTestHistory). NÃO confundir com o treino "No barulho" (Nível 4, gamificado). Carrega só o contexto deste módulo.
---

# Teste de fala no barulho (módulo âncora — mede o SRT / desfecho)

Mede o **SRT** (Speech Reception Threshold) com frases Matrix num staircase adaptativo:
a pessoa ouve uma frase no ruído e a remonta escolhendo 5 palavras. É um teste de
**desfecho** ("a pessoa melhorou?"), irmão do teste de audição — **não** é treino. Por
isso fica **fora da gamificação** (medir ≠ treinar; gamificar contaminaria a métrica).
UI: "Teste de fala no barulho" / "Limiar de fala (SRT)" — sem jargão "Matrix"/"desfecho".

**Leia o doc de referência antes de mexer:** [docs/treinos/teste-fala-no-ruido.md](../../../docs/treinos/teste-fala-no-ruido.md)

Pontos-chave (detalhes no doc):
- Tela/lógica: `lib/ui/screens/outcome_test_screen.dart` — boas-vindas → 20 frases → resultado.
- Frases: `lib/core/outcome_test_bank.dart` (`generateRandomMatrixSentence`, listas
  `MATRIX_NAMES/VERBS/NUMBERS/NOUNS/ADJECTIVES`). 5 categorias, frase = Nome+Verbo+Número+
  Objeto+Cor.
- Áudio: reusa `playCocktailStimulus({text, snrDb, noiseEnvironment:'RESTAURANTE'})` — o
  MESMO motor do treino N4 (fala varia com SNR, ruído fixo). Não é engine própria.
- Staircase: `AdaptiveStaircase` (2-down/1-up, `lib/core/adaptive_staircase.dart`),
  start +10 / floor −10 / ceiling +20 / passo 2 dB / 6 reversões. Converge a ~70,7%.
  Acerto do trial = **≥3 de 5 palavras** (regra clínica dos 50%). SRT final =
  `estimate ?? current` (média das últimas reversões).
- **Posição no fluxo (decisão):** é **teste-âncora na Home**, ao lado do teste de audição,
  **sempre disponível** após o audiograma (que personaliza o ganho). O **histórico/evolução**
  do SRT aparece na tela de progresso (`progress_screen.dart`), mas o ponto de entrada para
  FAZER o teste é a Home. Ver SYSTEM.md §8.
- **Contrato de persistência:** a tela SALVA sozinha via `SupabaseService.saveOutcomeTest`
  (tabela `outcome_tests`) — diferente do teste de audição, que devolve por `Navigator.pop`.
  Histórico: `getOutcomeTestHistory` (ordenado por data; delta = primeiro vs último).
- Esta tela inicializa o motor sozinha (`initializeEngine`) — como o teste de audição,
  não usa `AudioServiceManager`.
- ⚠️ NÃO gamificar nem dar XP/desbloqueio a este teste — quebra a honestidade do desfecho.
  Se precisar de "treino" de fala no ruído, é o Nível 4 (skill `treino-no-barulho`).
