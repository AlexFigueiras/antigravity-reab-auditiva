# Teste de audição (módulo âncora — gera o audiograma)

> Não é um "treino": é a **medição** que personaliza todos os treinos. Mapeia o
> limiar de audibilidade por frequência, em cada orelha, e produz o `Audiogram`
> usado por `getSmartPhoneme`, pelo ganho de meia-perda e pela detecção de zona
> morta coclear. Linguagem na UI: "teste de audição relativo" (não "audiograma"),
> "nível de som" (não "dB HL") — não assustar o idoso.

## O que é

Triagem audiométrica por **tom puro**, uma orelha de cada vez, isolada por panning.
Para cada frequência, busca o menor nível que a pessoa ainda detecta (limiar),
seguindo um Hughson-Westlake adaptado, com familiarização e catch-trials de
controle de falso positivo. **Triagem relativa, não diagnóstico** (honestidade clínica).

## Fluxo

1. **Confirmação de condição:** o teste é SEMPRE sem aparelho auditivo; a UI exige
   confirmação ativa (`_testConditionConfirmed`) antes de liberar a escolha da orelha.
2. **Escolher orelha** (`_chooseEar`): reseta `_currentFreqIndex = 0` ao trocar de orelha
   (regressão conhecida: sem isso o teste reiniciava em 8000 Hz — SYSTEM.md §8.4).
3. **Familiarização** (`_isFamiliarizing`): toca um tom de referência; só avança quando a
   pessoa confirma que ouviu. Se não ouvir, sobe **+10 dB** até ouvir ou atingir 120 dB.
4. **Busca do limiar** (Hughson-Westlake adaptado, `_onResponse`):
   - **Ouviu** → desce **10 dB**. Limiar **confirmado com 2 "ouviu" no mesmo nível**
     (`_positiveResponses[db] == 2` → `_recordThresholdAndNext`).
   - **Não ouviu** → sobe **5 dB** (clamp −10…120).
5. **Catch-trials (silêncio, 20%, sem dois seguidos):** se a pessoa responde "ouvi" no
   silêncio (falso positivo por ansiedade), mostra SnackBar educativo e repete o nível.
6. **Próxima frequência** na mesma orelha: volta a familiarizar, limpa `_positiveResponses`.
7. **Fim das frequências** → volta à escolha de orelha; ao concluir as duas, mostra o
   gráfico e o botão **"Salvar e voltar"**.

## Frequências testadas

`_frequencies` em `threshold_test_screen.dart` (**10 pontos**):
```
250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000
```
> ⚠️ Difere do que o SYSTEM.md §2.2/§8.4 documenta (6 freqs). O **código é a verdade**;
> o SYSTEM.md está desatualizado neste ponto (ver pendência no fim).

## Áudio

- `AudioRehabEngine.playPureTone(frequencyHz, db, ear)` — tom puro com **isolamento de
  orelha por panning de amplitude** (`setTargetPanning ±1.0` silencia a contralateral),
  não a espacialização binaural dos treinos N3/N4 (SYSTEM.md §3.3).
- Esta tela **inicializa o motor por conta própria** (`initializeEngine` + áudio de
  hardware) — não depende do `AudioServiceManager` como os treinos (SYSTEM.md §7).
- `_engine.stopTarget()` corta o tom ativo imediatamente ao receber a resposta e nas
  transições; botões ficam desabilitados/cinza durante a emissão e o intervalo (~1.2 s).
- Amplitude do tom: linear = `10^((dB − 80)/20)`, `_kRefDb = 80` (SYSTEM.md §4.2).

## Resultado e persistência (contrato importante)

- A tela **mede e devolve**, não salva: `Navigator.pop(context, {'left': _leftEarPoints,
  'right': _rightEarPoints})` (listas de `AudiometryPoint{frequency, threshold}`).
- **Quem salva é o chamador:** `home_screen.dart` (~542) e `onboarding_screen.dart` (~67)
  montam o `Audiogram` e chamam `SupabaseService().saveAudiogram(...)` (RLS por `user_id`).
- Releitura: `SupabaseService().getLatestAudiogram()` (carregado em `_loadSavedAudiogram`
  e pelos treinos para personalizar). Modelo: `lib/models/audiogram.dart`.

## Mapa de arquivos

- Tela/lógica: `lib/screens/threshold_test_screen.dart` (toda a máquina de estados).
- Modelo: `lib/models/audiogram.dart` (`Audiogram`, `AudiometryPoint`, `EarSide`).
- Engine: `lib/audio_engine/audio_engine.dart` (`playPureTone`, `setTargetPanning`, `stopTarget`).
- Persistência: `lib/services/supabase_service.dart` (`saveAudiogram`, `getLatestAudiogram`).
- Consumidores do audiograma: `getSmartPhoneme` (`gamification_controller.dart`),
  ganho de meia-perda (`getCompensatoryGain`), `coclear_dead_region.dart`.

## Armadilhas

- **Reset de frequência ao trocar de orelha:** `_chooseEar` precisa zerar `_currentFreqIndex`
  (SYSTEM.md §8.4).
- **"Som nos dois ouvidos":** antes de culpar o código, checar "Áudio mono" do Android
  (`master_mono`, `AudioAccessibility.isMonoAudioEnabled()`) — soma L+R e invalida o teste.
  O mixer C++ deve aplicar `panLeftGain`/`panRightGain` absolutos (SYSTEM.md §8.3).
- **Persistência não é responsabilidade da tela** — se o resultado "não salva", olhe o
  chamador (home/onboarding), não o `threshold_test_screen`.
- **Inicialização do motor:** esta tela inicializa sozinha; não copiar esse padrão para
  os treinos (que usam `AudioServiceManager().initializeEngineForUser`).

## Notas de manutenção

Este doc e o SYSTEM.md (§2.2/§8.4/§8.11) foram reconciliados com o código em 2026-06-06
(10 frequências; familiarização a 40 dB; staircase assimétrico −10/+5). Se mudar a lista de
frequências, o dB inicial ou os passos no código, atualize **os dois** (AGENTS.md §2).
