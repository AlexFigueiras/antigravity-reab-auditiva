# SYSTEM.md — BOSYN / ear_training

> Documento-mestre de funcionamento do sistema. Objetivo: qualquer IA ou dev
> consegue se orientar sobre **como as coisas funcionam, por quê, e onde mexer**.
> Para princípios de produto/UX, ver [PRODUTO.md](PRODUTO.md). Este arquivo é o
> **técnico**: arquitetura, fluxo de áudio, regras clínicas e armadilhas conhecidas.
>
> Mantenha atualizado: toda correção de bug ou regra nova entra aqui.

---

## 1. O que é o app

BOSYN é um app Flutter de **reabilitação auditiva** para público 55–75 anos com
perda auditiva. Alvo: Android (celular Xiaomi/MediaTek). O app:

1. Faz um **teste de audição** (audiograma) por tom puro, isolando cada orelha.
2. Usa esse audiograma para **personalizar treinos de fala** com ganho clínico.
3. Treina discriminação de sons, atenção espacial e fala no ruído.

Público idoso ⇒ linguagem humana, fontes grandes, alto contraste, **sem jargão
e sem tema "cockpit/militar"** (ver PRODUTO.md).

---

## 2. Stack

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.44.1 / Dart 3.12.1 |
| Áudio nativo | C++ via FFI, motor **Oboe** (modo EXCLUSIVE/MMAP, estéreo) |
| Voz (TTS) | `flutter_tts` (TTS **nativo do device**, offline, gratuito) |
| Backend | Supabase (auth + audiograma + sessões), RLS ativo |
| Pagamento | Stripe |
| Dev | Windows. Device por **adb wireless (TLS)**. |

---

## 3. Arquitetura de áudio (o coração do sistema)

### 3.1 Pipeline geral

```
Dart gera/obtém amostras Float32 (48 kHz, mono)
        │
        ▼
AudioRehabEngine._loadSampleToNative()  ── calloc<Float> ──► setTargetSample()
        │                                                         │
        ▼                                                         ▼
NativeDSPBridge (FFI)  ──►  native_bridge.cpp  ──►  OboeEngine (oboe_engine.h)
                                                          │
                              SamplePlayer.setData() COPIA p/ ring buffer SPSC
                                                          │
                                            Oboe render thread → L/R → fone
```

**Regra de ouro do FFI:** `setData` (sample_player.h) **copia** os dados para um
ring buffer de 5 MB na hora. Por isso o Dart pode `calloc.free()` o ponteiro
imediatamente após `setTargetSample` — não é use-after-free.

### 3.2 Sample rate

- DSP nativo opera a **48000 Hz** (`_fs`).
- O TTS do device grava WAV PCM 16-bit mono em sua própria taxa
  (**24000 Hz neste device**; varia por OEM — sempre lido do header, offset 24).
- `_resampleTo` faz reamostragem linear src→48000. **Sem isso, a voz toca em
  tom/velocidade errados.**

### 3.3 Isolamento de orelha (panning)

No mixer nativo, o target player é mono; a separação L/R vem do **panning**:

| `setTargetPanning(x)` | Efeito |
|---|---|
| `-1.0` | zera canal **direito** → som só na orelha **esquerda** |
| `+1.0` | zera canal **esquerdo** → som só na orelha **direita** |
| `0.0` | binaural (centro), os dois ouvidos |

- **Tom puro / teste de audição:** usa ±1.0 para isolar a orelha testada.
- **Fala (treino):** SEMPRE `0.0` (binaural). Ver armadilha #2.

### 3.4 Garantia de stream estéreo

Oboe pode abrir mono em Exclusive/MMAP. `start()` força estéreo com fallback
Shared. (Ver memória `stereo-stream-guarantee`.)

---

## 4. Regras clínicas (audiologia)

### 4.1 Regra de Meio Ganho (Half-Gain)

`getCompensatoryGain(freq)` em audio_engine.dart:
```
ganho_dB = (perda_média_L_R na frequência) / 2
```
Compensa a perda sem estourar (regra clássica de adaptação de prótese).

### 4.2 Tom puro audiométrico

Amplitude linear = `10^((dB_HL - 80) / 20)`. `_kRefDb = 80` → 80 dB HL = 1.0 linear.

### 4.3 Personalização real

Treino **bloqueia sem audiograma** (`_requireAudiogram`). Não se treina "às cegas":
o audiograma escolhe os fonemas certos (`getSmartPhoneme`). Honestidade clínica.

---

## 5. Os 4 níveis de treino

| Nível | Nome humano (UI) | Método engine | O que faz |
|---|---|---|---|
| 2 | Distinguir sons | `playPhonemicStimulus` | Ouve 1 palavra, escolhe entre 2 (par mínimo fonêmico) |
| 3 | De que lado | `playSpatialStimulus` | Palavra vem da esq/centro/dir (panning) — atenção espacial |
| 4 | No barulho | `playCocktailStimulus` | Fala + ruído de fundo a um SNR (efeito coquetel) |

- Formato adotado (decisão do usuário): **ouve 1, escolhe entre 2**.
- Banner fixo no topo explica o som: *"💡 Som do D — como em dedo."*
- Botões grandes, posição do alvo embaralhada (`_targetOnLeft`).
- Feedback humano: *"Isso! Você ouviu certo."* / *"Quase. A palavra era 'X'."*

---

## 6. Mapa de arquivos (onde mexer)

### Áudio
- `lib/audio_engine/audio_engine.dart` — **AudioRehabEngine** (singleton). Toda
  geração/roteamento de estímulo. Half-gain, resample, panning, play*.
- `lib/audio_engine/native_engine.dart` — **NativeDSPBridge**: bindings FFI.
- `lib/services/audio_service_manager.dart` — **AudioServiceManager** (singleton):
  ciclo de vida do motor. `initializeEngineForUser`, `forceStopAll`.
- `lib/services/system_tts_service.dart` — TTS device → WAV + cache + leitura do
  sample rate. (Substitui o antigo `tts_service.dart`.)
- `lib/services/audio_accessibility.dart` — detecta "Áudio mono" do Android.
- `cpp/oboe_engine.{h,cpp}` — motor Oboe, mixer, panning, timestamps.
- `cpp/sample_player.h` — SamplePlayer + ring buffer SPSC (copia os dados).
- `cpp/native_bridge.cpp` — funções `NATIVE_EXPORT` chamadas pelo FFI.
- `cpp/dsp_engine.*`, `biquad_filter.h`, `fir_filter.*`, `noise_generator.h` — DSP.

### Telas
- `lib/screens/threshold_test_screen.dart` — teste de audição (tom puro).
- `lib/ui/screens/training_dashboard.dart` — tela principal de treino (níveis 2/3/4).
- `lib/screens/spatial_attention_screen.dart`, `phonemic_discrimination_screen.dart`,
  `speech_in_noise_screen.dart`, `lib/ui/screens/sentence_training_screen.dart` — telas legadas/específicas.
- `lib/ui/screens/{home,auth,onboarding,calibration,progress,mission_report}_screen.dart`.

### Conteúdo / lógica
- `lib/core/phoneme_map.dart` — pares mínimos `{target, distractor, freq_band, type}`.
- `lib/core/sentence_bank.dart` — frases (nível frase).
- `lib/core/gamification_controller.dart` — `getSmartPhoneme`, progressão.
- `lib/core/spatial_controller.dart` — lógica espacial.
- `lib/models/{audiogram,rehab_session,phonemic_pair}.dart`.

### Backend
- `lib/services/supabase_service.dart` — auth, `getLatestAudiogram`, sessões.
- `supabase/schema.sql` — schema completo com RLS (aplicar no painel; banco
  começou vazio). Ver memória `supabase-schema-setup`.
- `lib/services/{gatekeeper,pdf,event_buffer}_service.dart`.

---

## 7. Ciclo de vida do motor (CRÍTICO — fonte de bug)

O `AudioRehabEngine` tem `_isInitialized`. `_verifySecurityScope()` **lança
exceção** se o motor não foi inicializado, e essa exceção é **engolida pela UI**
(falha silenciosa).

**Cada tela que toca som DEVE inicializar o motor:**
- Teste de audição: inicializa por conta própria (`startHardwareAudio`).
- Treino (`training_dashboard`): chama `AudioServiceManager().initializeEngineForUser(audiogram)`
  dentro de `_loadAudiogram`, depois de carregar o audiograma do Supabase.

⚠️ Se criar uma **nova tela com áudio**, lembre de inicializar o motor, senão a
fala sai muda sem erro visível.

---

## 8. Armadilhas conhecidas (bugs já resolvidos — não repita)

1. **Fala muda porque o motor não foi inicializado** (causa raiz real).
   Os bipes do teste funcionavam (aquela tela inicializa sozinha), mas a tela de
   treino nunca chamava `initializeEngine` ⇒ `_verifySecurityScope` lançava e a
   exceção era engolida. **Fix:** `initializeEngineForUser` em `_loadAudiogram`.
   Diagnóstico: log `[TTS_DIAG]` em `_synthesizeSpeechSamples` mostra
   bytes/srcRate/samples/peak.

2. **Fala herdando panning do teste de audição.** Após o teste, o panning ficava
   em ±1.0 e zerava um canal da voz. **Fix:** `setTargetPanning(0.0)` no início de
   `playPhonemicStimulus` e `playCocktailStimulus`.

3. **"Som nos dois ouvidos" no teste de audição.** Antes de culpar o código,
   checar **"Áudio mono" do Android** (`master_mono`) — essa opção soma L+R e
   invalida o teste. `AudioAccessibility.isMonoAudioEnabled()`.

4. **Teste reiniciava em 8000 Hz ao trocar de orelha.** `_chooseEar` não resetava
   `_currentFreqIndex`. **Fix:** `_currentFreqIndex = 0;`. Frequências: `[250,500,1000,2000,4000,8000]`.

5. **Título sobreposto na tela de escolher orelha.** AppBar transparente +
   `extendBodyBehindAppBar`. **Fix:** `SafeArea` + `topGap` (padding.top + kToolbarHeight + 16).

6. **WAV binário corrompido ao puxar do device com PowerShell `>`** (BOM UTF-16).
   **Use:** `adb exec-out run-as <pkg> base64` + `[System.Convert]::FromBase64String`.

7. **adb device ID muda** (USB `2311DRK48G` → wireless `adb-...tls-connect._tcp`).
   Instale com `adb -s <id-atual> install -r build/app/outputs/flutter-apk/app-debug.apk`.

8. **Conteúdo:** vários distratores em `phoneme_map.dart` são pseudo-palavras
   ("Tedo", "Felo", "Fopa"). Confundem o público. **A revisar** (usar só palavras
   reais, ex.: Dado/Tato, Vila/Fila). Não é bug de áudio nem de UI.

---

## 9. Build & deploy (Windows + device wireless)

```powershell
flutter build apk --debug
adb -s <device-id> install -r build\app\outputs\flutter-apk\app-debug.apk
# Diagnóstico de áudio:
adb -s <device-id> logcat | Select-String "TTS_DIAG"
```

---

## 10. Decisões a manter (não regredir)

- Fala SEMPRE passa pelo **DSP nativo** (ganho de meia-perda), nunca playback direto.
- **Não** reintroduzir Oboe Shared/None nem getters de diagnóstico removidos.
- **Não** voltar tema cockpit (verde fosforescente, sonar, "XP", "Energia Neural",
  monospace, "MODO COCKPIT", jargão).
- TTS = device nativo (flutter_tts), **não** Google Cloud.
- Linguagem humana, "o porquê" antes do treino, fontes grandes, alto contraste.
