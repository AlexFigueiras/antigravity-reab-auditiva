# Teste de fala no barulho (módulo âncora — mede o SRT / desfecho)

> Doc de referência de UM módulo. Carregue só este quando o trabalho for sobre o teste
> de desfecho / SRT / frases Matrix, para não varrer o código inteiro.
> Visão geral: [SYSTEM.md](../../SYSTEM.md). Produto/UX: [PRODUTO.md](../../PRODUTO.md).
>
> ⚠️ **Não confundir com o treino "No barulho" (Nível 4)** — [no-barulho.md](no-barulho.md).
> O treino *exercita* (gamificado, XP, desbloqueio); este teste *mede o desfecho* e fica
> **fora** da gamificação. Os dois usam o mesmo áudio (`playCocktailStimulus`), propósitos
> opostos.

## O que é
Mede o **SRT** (Speech Reception Threshold) — o nível de ruído em que a pessoa ainda
entende ~metade da fala. É o "antes e depois" clínico: aplicado periodicamente, mostra se
a reabilitação está dando resultado. Material = **frases Matrix**: a pessoa ouve uma frase
no ruído e a remonta escolhendo 5 palavras (uma por categoria). 20 frases por aplicação.

> UI em linguagem humana: "Teste de fala no barulho", "Limiar de fala (SRT)". Evitar
> "Matrix" e "desfecho" na tela (jargão — ver AGENTS.md §3 / SYSTEM.md §10).

## Posição no fluxo (decisão de produto)
É o **segundo teste-âncora**, ao lado do **Teste de audição** na Home — não um nível de
treino. Decisão deliberada:
- **Por que âncora e não nível:** medir ≠ treinar. Se desse XP/desbloqueio, a pessoa
  "treinaria para o teste" e a métrica de desfecho perderia o valor clínico.
- **Liberação:** **sempre disponível**, mas exige o **teste de audição feito** antes (o
  audiograma personaliza o ganho de meia-perda aplicado à fala). Mesma regra do treino de
  Frases. Sem audiograma → SnackBar pedindo o teste de audição.
- **Entrada vs. histórico:** o card para **fazer** o teste fica na **Home**
  (`_buildOutcomeTestCard` em [home_screen.dart](../../lib/ui/screens/home_screen.dart)). O
  **histórico/evolução** do SRT (gráfico + delta primeiro↔último) fica na tela de progresso
  ([progress_screen.dart](../../lib/ui/screens/progress_screen.dart)) — lá há um "Fazer o
  teste de novo".

> Histórico: antes desta organização o teste vivia **só** dentro da tela de evolução, sem
> ponto de entrada no fluxo principal. Movido para a Home como âncora. Ver SYSTEM.md §8.

## Fluxo
1. **Boas-vindas** → explica e "Começar Teste".
2. **20 frases** (`_totalTrials`): ouve a frase no ruído, monta selecionando Nome → Verbo →
   Número → Objeto → Cor. "Ouvir Frase" repete o estímulo atual (mesmo SNR).
3. Ao confirmar: conta palavras certas; **acerto do trial = ≥3 de 5** (regra dos 50%);
   alimenta o staircase; mostra feedback ("acertou X de 5") e "Próxima Frase".
4. **Resultado**: SRT final em dB + interpretação textual (excelente / leve / moderada-severa).
   Salva automaticamente.

## Áudio
- Reusa **`AudioRehabEngine.playCocktailStimulus({text, snrDb, noiseEnvironment:'RESTAURANTE'})`**
  — o MESMO motor do Nível 4 (fala varia com o SNR, ruído fixo confortável). Ver
  [no-barulho.md](no-barulho.md) §Fluxo de áudio. **Não tem engine própria.**
- A tela **inicializa o motor sozinha** (`initializeEngine` com audiograma placeholder
  `OUTCOME_TEST`) — como o teste de audição, **não** usa `AudioServiceManager`.
  - ⚠️ Inicializa com audiograma vazio (placeholder); o ganho real personalizado depende do
    audiograma salvo. Se for preciso aplicar o EQ do usuário aqui, passar o audiograma real
    (a Home já garante que ele existe antes de abrir a tela).

## Staircase e SRT
- **`AdaptiveStaircase` 2-down/1-up** ([adaptive_staircase.dart](../../lib/core/adaptive_staircase.dart)),
  configurado em `outcome_test_screen.dart`:
  `start: 10`, `floor: -10`, `ceiling: 20`, `stepDown/Up: 2`, `minReversalsForEstimate: 6`.
- Converge para **~70,7%** de acerto (ponto psicométrico padrão). 2 acertos seguidos →
  desce 2 dB (mais difícil); 1 erro → sobe 2 dB. Cada inversão de direção = reversão.
- **SRT final = `estimate ?? current`**: média das últimas 6 reversões; se não houver
  reversões suficientes nas 20 frases, cai no valor corrente.
- Na UI a "Dificuldade" mostrada é `-current` (SNR invertido) — **menos dB de SNR = mais
  difícil**; **menos SRT final = melhor** (entende com mais ruído).

## Frases (banco)
- [outcome_test_bank.dart](../../lib/core/outcome_test_bank.dart): `MatrixSentence`,
  `generateRandomMatrixSentence`, listas `MATRIX_NAMES / VERBS / NUMBERS / NOUNS /
  ADJECTIVES`. Frase = Nome + Verbo + Número + Objeto(Noun) + Cor(Adjective).

## Persistência (contrato)
- A tela **salva sozinha** (diferente do teste de audição, que devolve por `Navigator.pop`):
  `SupabaseService.saveOutcomeTest({srtDb, totalTrials, correctAnswers, metadata:{log}})`
  → tabela **`outcome_tests`**.
- Leitura: `getOutcomeTestHistory()` (ordenado por `date` asc — base do gráfico e do delta),
  `getLatestOutcomeTest()`.

## Mapa de arquivos
- Tela: [lib/ui/screens/outcome_test_screen.dart](../../lib/ui/screens/outcome_test_screen.dart).
- Staircase: [lib/core/adaptive_staircase.dart](../../lib/core/adaptive_staircase.dart).
- Frases: [lib/core/outcome_test_bank.dart](../../lib/core/outcome_test_bank.dart).
- Áudio: `playCocktailStimulus` em [lib/audio_engine/audio_engine.dart](../../lib/audio_engine/audio_engine.dart).
- Entrada (Home): `_buildOutcomeTestCard` em [lib/ui/screens/home_screen.dart](../../lib/ui/screens/home_screen.dart).
- Histórico/evolução: [lib/ui/screens/progress_screen.dart](../../lib/ui/screens/progress_screen.dart).
- Persistência: `saveOutcomeTest`/`getOutcomeTestHistory` em [lib/services/supabase_service.dart](../../lib/services/supabase_service.dart).

## Armadilhas
- **Não gamificar.** Sem XP, sem desbloqueio, sem virar "nível". Quebra a honestidade do
  desfecho. Treino de fala no ruído é o Nível 4 (`treino-no-barulho`).
- **Motor não inicializado → fala muda** (SYSTEM.md §7). A tela DEVE inicializar o motor.
- **Volume:** o teste usa a mesma premissa de volume de referência dos demais (ver
  [teste-de-audicao.md](teste-de-audicao.md) §Áudio e SYSTEM.md §4.2). Como inicializa o
  motor por conta própria (não passa por `AudioServiceManager`), o
  `AudioAccessibility.rampToReferenceVolume()` é chamado **no `initState`** desta tela — sem
  isso o SRT seria medido num volume potencialmente diferente do teste de audição.
- **Jargão na UI:** "Matrix"/"desfecho"/"SRT" sozinho assustam o público 55–75. Preferir
  "fala no barulho" e explicar o SRT como "limiar de fala".
