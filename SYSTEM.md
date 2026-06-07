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
| i18n | `flutter_localizations` + `gen-l10n` (.arb pt/en). Ver [docs/i18n.md](docs/i18n.md) |
| Tema (visual) | Claro/escuro via `ThemeController` + `AppPalette` (fonte única de cor). Padrão **claro**. |
| Dev | Windows. Device por **adb wireless (TLS)**. |

> **Tema (claro/escuro):** o app abre no **tema claro** (amigável, público 55–75); o usuário
> troca pelo menu (⋮) na Home, e a escolha persiste em SharedPreferences. A cor NÃO é mais
> hardcoded por tela: existe uma **fonte única**, `lib/ui/theme/app_palette.dart` (`AppPalette`
> com `bg`, `card`, `primary`, `textMain`, `textSoft`, `correct`, `wrong`), e o
> `ThemeController` (`lib/services/theme_controller.dart`, provido no topo via `provider`)
> resolve a paleta do modo ativo. As telas leem `context.watch<ThemeController>().palette` —
> trocar o tema reconstrói o app. **Não voltar a declarar `static const Color _bg = ...` por
> tela.** Cores **semânticas/ilustrativas** (azul/vermelho de orelha L/R no teste de audição,
> séries do gráfico de audiograma, cor por ambiente do Seu João) NÃO seguem o tema — são
> fixas de propósito.
>
> **Vender em outro idioma = DUAS frentes** (ver [docs/i18n.md](docs/i18n.md)): (1) texto da
> UI — infra de i18n já pronta, `AppLocalizations.of(context)`, Home migrada como padrão; e
> (2) **conteúdo clínico** (pares mínimos, frases Matrix, voz TTS) — NÃO é tradução, é
> recriação com listas validadas por idioma. Não liberar venda clínica num idioma sem a
> Frente 2. O TTS seleciona a voz pelo idioma E pela variante regional — dois getters em
> `LocaleController`: `audioLanguageCode` (curto `pt`/`en`, seleciona conteúdo) vs.
> `audioLocaleCode` (`pt-BR`/`en-US`, configura a voz, fixa a variante). Não confundir;
> detalhe + limites de instalação de voz no device em [docs/i18n.md](docs/i18n.md).

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
                              SamplePlayer.setData() COPIA p/ buffer linear atômico
                                                          │
                                            Oboe render thread → L/R → fone
```

**Regra de ouro do FFI:** `setData` (sample_player.h) **copia** os dados para um
buffer linear atômico de 5 MB na hora. Por isso o Dart pode `calloc.free()` o ponteiro
imediatamente após `setTargetSample` — não é use-after-free.

### 3.2 Sample rate

- DSP nativo opera a **48000 Hz** (`_fs`).
- O TTS do device grava WAV PCM 16-bit mono em sua própria taxa
  (**24000 Hz neste device**; varia por OEM — sempre lido do header, offset 24).
- `_resampleTo` faz reamostragem linear src→48000. **Sem isso, a voz toca em
  tom/velocidade errados.**

### 3.3 Isolamento de orelha (panning e espacialização binaural ITD/ILD)

Para tom puro e calibração, usamos panning de amplitude tradicional via `setTargetPanning(x)` (onde ±1.0 silencia completamente a orelha contralateral).

Para estímulos de fala nos treinos (Nível 3 e Nível 4), implementamos espacialização binaural 3D real usando:
1. **Diferença Interaural de Tempo (ITD):** Atraso de fase contralateral via buffers circulares de 64 float samples por canal. O atraso máximo no azimute de 90° é de 0.65 ms (~31 samples a 48 kHz).
2. **Diferença Interaural de Intensidade (ILD):** Atenuação contralateral baseada no ângulo (máximo de 60% de redução no ouvido contralateral a 90°).

- **Tom puro / teste de audição:** usa panning de amplitude linear tradicional para isolamento acústico absoluto.
- **Fala (Nível 3):** Roda estímulo de fala em azimutes de -90° a +90° via `setTargetAzimuth`.
- **Fala no Ruído (Nível 4 - Cocktail / SRM):** Fala no centro (0°) e ruído lateralizado a ±45° via `setNoiseAzimuth` para treinar a Liberação Espacial de Mascaramento (Spatial Release from Masking - SRM).

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

**Premissa de volume (referencial único).** A amplitude digital é só um dos três ganhos em
série até o tímpano: `digital × volume do sistema × sensibilidade do fone`. O `_kRefDb` só
significa algo estável porque o **volume de mídia é fixado** em
`AudioAccessibility.kReferenceVolumeFraction` (~85%) tanto no teste (gate "Ajustar o volume"
+ vigilância de desvio na `threshold_test_screen`) quanto nos treinos
(`AudioServiceManager.initializeEngineForUser`). Sem isso, o limiar é medido num nível e o
treino toca noutro, e o ganho de meia-perda fica desalinhado. 85% (não 100%) deixa headroom
para o EQ não clipar no soft-limiter de -3 dBFS (§3 DSP). **Não é dB HL absoluto** — é
triagem relativa honesta. No Android não dá para travar o botão físico; só detectar e
proteger. Ver §8.

### 4.3 Personalização real

Treino **bloqueia sem audiograma** (`_requireAudiogram`). Não se treina "às cegas":
o audiograma escolhe os fonemas certos (`getSmartPhoneme`). Honestidade clínica.

### 4.4 Proteção de Zona Morta Coclear (CDR) e Transposição de Frequência

- **Proteção contra Recrutamento:** Se a perda média do paciente em uma frequência for $\ge 70\text{ dB HL}$, essa região é identificada como Zona Morta Coclear (CDR). A amplificação compensatória do EQ multibanda para essa frequência é limitada (clamped) a no máximo $10\text{ dB}$ para evitar desconforto, distorção e o fenômeno de recrutamento acústico.
- **Frequency Lowering (Rebaixamento de Frequência):** Quando uma zona morta de alta frequência (6k/8k Hz) é detectada, o app pós-processa estímulos de fala que contêm sibilantes/fricativas (/s/, /f/, /t/, etc.) usando modulação de envoltória:
  1. Extrai a envoltória de energia de alta frequência (> 4.000 Hz) da fala.
  2. Modula um ruído sintético de passa-banda sintonizado na zona de audibilidade residual do idoso (1.500 Hz a 2.500 Hz).
  3. Soma essa envoltória modulada de volta ao sinal com um reforço compensatório de $+4.5\text{ dB}$, permitindo ao paciente perceber auditivamente pistas que estariam perdidas.

### 4.5 Modelo de Limites de Sessões Diárias e Monetização (Freemium)

Para monetização sustentável sem degradar a experiência do idoso:
- **Limite Diário Grátis**: Usuários não-assinantes (`free`) têm um limite diário de **2 sessões** completadas por dia nos níveis de reabilitação (2, 3 e 4). Os testes-âncora (audiometria e fala no barulho) são ilimitados.
- **Anúncios Premiados (Rewarded Ads)**: Se o limite diário for atingido, o usuário pode assistir a um vídeo completo para obter um bônus de **+2 sessões extras** no dia atual.
- **Bypass Assinante**: Usuários com `subscription_status != 'free'` têm treinos ilimitados.
- **Persistência**: Os bônus acumulados no dia são salvos localmente via `SharedPreferences` usando a chave formatada `ad_rewards_unlocked_YYYY_M_D`.

---

## 5. Os 4 níveis de treino

> **Skills por módulo (economia de contexto).** Cada módulo tem uma skill em
> `.claude/skills/*/SKILL.md` que aponta para um doc de referência em
> `docs/treinos/*.md`. Ao trabalhar em UM módulo, carregue só a skill/doc dele em
> vez de varrer o código todo. Treinos: `treino-distinguir-sons` (N2),
> `treino-de-que-lado` (N3), `treino-no-barulho` (N4), `treino-frases`. Manter
> sincronizado ao mudar o módulo.
>
> **Dois testes-âncora (medem, não treinam — fora da gamificação).** Ficam na Home,
> ao lado dos treinos: **Teste de audição** (skill `teste-de-audicao` → audiograma) e
> **Teste de fala no barulho** (skill `teste-fala-no-ruido` → SRT/desfecho). Não dão
> XP nem desbloqueio: gamificar um instrumento de medida contamina a métrica clínica.
> O 2º exige o 1º feito (o audiograma personaliza o ganho).


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

### Tema / aparência (claro/escuro)

- `lib/ui/theme/app_palette.dart` — **AppPalette**: fonte única de cor (`bg`, `card`,
  `primary`, `textMain`, `textSoft`, `correct`, `wrong`) nas variantes `light`/`dark`.
- `lib/services/theme_controller.dart` — **ThemeController**: modo ativo (padrão claro),
  persiste em SharedPreferences, expõe `palette`. Provido no topo (`main.dart`) via `provider`.
- Telas leem `context.watch<ThemeController>().palette`. Troca no menu (⋮) da Home.

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
    invalida o teste. `AudioAccessibility.isMonoAudioEnabled()`. Além disso, o mixer C++ do Oboe
    deve multiplicar o sinal pelos ganhos de pan absoluto (`panLeftGain` e `panRightGain` derivados de `targetPanning`),
    senão a espacialização por azimuth (usada no treino) remove o isolamento de canal do teste de tom puro.

4. **Teste reiniciava em 8000 Hz ao trocar de orelha.** `_chooseEar` não resetava
   `_currentFreqIndex`. **Fix:** `_currentFreqIndex = 0;`. Frequências (10 pontos, `_frequencies`
   em `threshold_test_screen.dart`): `[250,500,750,1000,1500,2000,3000,4000,6000,8000]`.

5. **Título sobreposto na tela de escolher orelha.** AppBar transparente +
   `extendBodyBehindAppBar`. **Fix:** `SafeArea` + `topGap` (padding.top + kToolbarHeight + 16).

6. **WAV binário corrompido ao puxar do device com PowerShell `>`** (BOM UTF-16).
   **Use:** `adb exec-out run-as <pkg> base64` + `[System.Convert]::FromBase64String`.

7. **adb device ID muda** (USB `2311DRK48G` → wireless `adb-...tls-connect._tcp`).
   Instale com `adb -s <id-atual> install -r build/app/outputs/flutter-apk/app-debug.apk`.

8. **Conteúdo (RESOLVIDO):** `phoneme_map.dart` tinha distratores pseudo-palavra
   ("Tedo", "Felo", "Fopa") e 70 placeholders `Palavra1…/Falsa1…`. Substituídos por
   **35 pares mínimos de palavras reais** (Sala/Fala, Vila/Fila, Dado/Tato, Rosa/Roça).
   Regra a manter: só palavras reais, par mínimo. A lista é sorteada por `length`,
   então pode crescer sem mexer no código consumidor.

9. **Ruído do nível 4 vazando para outros treinos e para o teste de audição
   (RESOLVIDO).** `setNoiseIntensity` ajusta a amplitude do gerador de ruído
   branco — uma variável **persistente** no `whiteNoiseGenerator`. O
   `AudioRehabEngine` é **singleton** e `OboeEngine::stop()` só fecha o stream;
   **não** zera o ruído. Logo, depois de "No barulho", a intensidade ficava > 0 e
   o ruído voltava de fundo ao reabrir o stream em qualquer outra tela.
   **Fix:** `stop()` chama `setNoiseIntensity(0.0)` antes de `stopHardwareAudio`,
   e `playPhonemicStimulus`/`playSpatialStimulus`/`playPureTone` zeram o ruído no
   início (defesa em profundidade — todos são estímulos limpos, sem ruído).
   Regra a manter: **só `playCocktailStimulus` (N4) liga ruído**; qualquer estímulo
   limpo deve zerar a intensidade antes de tocar.

10. **Áudio mudo após troca de rota de áudio (RESOLVIDO).** O Oboe DESCONECTA o
    stream numa mudança de dispositivo de saída (fone/Bluetooth, fim de chamada,
    rerouting MMAP do MIUI) — no log: `onAudioDeviceUpdate ... DISCONNECT` +
    `oboe_aaudio_error_thread_proc(-899)` (AAUDIO_ERROR_DISCONNECTED). O
    `onErrorAfterClose` chamava `start()`, mas `start()` é idempotente
    (`if (outputStream) return true`) e o `shared_ptr` ainda segura o stream
    fechado ⇒ não reabre ⇒ TODO áudio fica mudo (todos os treinos, não só frases).
    **Fix:** (1) `OboeEngine::start()` limpa `deviceDisconnected` ao reabrir com
    sucesso; (2) Dart `_ensureStreamHealthy()` checa `isDeviceDisconnected()` no
    início de cada `play*` e chama `restartHardwareAudio()` (stop→reset→start) se
    preciso. Diagnóstico: log `[ENGINE] Stream desconectado`.

11. **Lógica de Hughson-Westlake no Teste de Audição Relativo (IMPLANTADO).**
    Segue o algoritmo clássico de Hughson-Westlake com passos **assimétricos**:
    - Resposta "SIM" (Escutei): diminui a intensidade em 10 dB.
    - Resposta "NÃO" (Não escutei): aumenta a intensidade em 5 dB.
    - Confirmação do limiar: o limiar é confirmado quando o usuário responde "SIM" pelo menos duas vezes no mesmo nível de intensidade durante a fase ascendente.
    - Fase de familiarização: antes de cada frequência, a busca inicia em **40 dB** (`_currentDb = 40.0`); se o usuário não ouvir, sobe +10 dB até ouvir ou atingir 120 dB. O teste só avança após confirmar que escutou.
    - Catch-trials silenciosos: 20% das apresentações são silenciosas. Se o usuário responder "SIM" (falso positivo), é exibido um SnackBar educativo e o nível é testado novamente.
    - Terminologia simplificada na UI: "audiograma" virou "teste de audição relativo" e "dB HL" virou "nível de som" para não assustar o idoso.
    - **Intervalo de Transição Silencioso Clínico (IMPLANTADO):** Há um atraso de 1.2 segundos entre cada tom apresentado no teste. Os botões de resposta "SIM" e "NÃO" são desabilitados e renderizados num estado inativo/cinza durante esse delay para evitar cliques duplos. O tom ativo é interrompido imediatamente no player C++ ao receber a resposta através do método `stopTarget()`.
    - **Visual Trial Paradigm / Feedback Visual de Estímulo (IMPLANTADO):** Durante os 1.5s de emissão do som (ou silêncio do catch-trial), o container de frequência exibe um contorno de cor correspondente à orelha em teste (azul para esquerda, vermelho para direita) com uma sombra de brilho pulsante (`AnimatedContainer` com `withValues`). Um indicador de status clínico exibe um spinner acompanhado de *"Ouça com atenção..."* durante a escuta, *"Preparando próximo tom..."* na transição, e *"Você ouviu o som?"* ao final da emissão, instruindo o idoso mesmo durante as apresentações silenciosas de controle. Os botões e textos de prompt permanecem desativados/esmaecidos durante toda a emissão e a transição.

12. **Centroides de Frequência Acústica Real para Fonemas (IMPLANTADO).**
    Os fonemas em `phoneme_map.dart` foram mapeados para suas frequências centroides reais clinicamente aceitas correspondentes às frequências do teste:
    - 250 Hz (ex: m/n nasais), 500 Hz (vogais graves), 1000/2000 Hz (consoantes plosivas/fricativas médias), 4000/8000 Hz (fricativas agudas / sibilantes como s/z/ch/j).
    - Conectado com o `getSmartPhoneme` em `gamification_controller.dart` para aplicar uma seleção baseada em `targetDifficulty` (1 a 5) com fallback em cascata caso não existam pares mínimos disponíveis na faixa.

13. **Volume do sistema não era fixado ⇒ teste e treino em referenciais distintos
    (RESOLVIDO).** O nível no tímpano = `amplitude digital × volume do sistema ×
    sensibilidade do fone`; o app só controlava o primeiro. O stream abre como
    `Usage::Media` (`oboe_engine.cpp`), então o tom do teste era multiplicado pelo
    volume de mídia do usuário, e não havia nenhum `setStreamVolume`/`AudioManager`
    no nativo. Logo, fazer o teste num volume e treinar noutro desalinhava o limiar
    medido e o ganho de meia-perda aplicado — invalidando a personalização.
    **Fix:** o volume de mídia é fixado em `AudioAccessibility.kReferenceVolumeFraction`
    (~85%) via canal `bosyn/audio_accessibility` (`getMediaVolumeFraction` /
    `setMediaVolumeFraction` no `MainActivity.kt`, `rampToReferenceVolume` no Dart com
    subida suave). No teste: gate "Ajustar o volume" antes de escolher a orelha +
    vigilância em `_playCurrentTestTone` que pausa se o usuário baixar pelo botão
    físico. Nos treinos (Níveis 2, 3, 4 e Frases): verificação reativa de desvio antes
    de cada estímulo via `_verifyVolume()`, exibindo o banner e travando as respostas
    até que o volume de referência de 85% seja restabelecido.
    Regra a manter: **85%, não 100%** — deixa headroom para o EQ não clipar no
    soft-limiter -3 dBFS; é triagem relativa, não dB HL absoluto. No Android não dá
    para travar o botão físico (só detectar/proteger). Degrada gracioso sem nativo
    (`getMediaVolumeFraction` → 1.0). Ver §4.2.

14. **N2 Adaptativo e Tratamento de Repetição de Estímulos (IMPLANTADO).**
    - Módulo 2 ("Distinguir sons") agora usa a classe `AdaptiveStaircase` para modular dinamicamente a dificuldade fonética de 1 a 5.
    - Para evitar que repetições de estímulos alterem a contagem do staircase ou poluam as métricas da sessão de treino, o fluxo detecta tentativas repetidas (`_isRepeatTrial`).
    - As tentativas repetidas ativam um reforço de ganho de +3 dB de forma nativa e audível para facilitar a percepção.

15. **Teste de Desfecho Matrix e Persistência de Resultados (IMPLANTADO).**
    - Implementação de um teste de desfecho baseado em matriz de frases fixas (5 categorias de palavras: Nome, Verbo, Número, Substantivo, Adjetivo).
    - O teste usa um staircase de SNR adaptativo com passos de 2 dB (desce no acerto, sobe no erro).
    - O acerto de uma frase é definido como a identificação correta de pelo menos 3 das 5 palavras que a compõem.
    - Os resultados do teste são salvos na tabela `outcome_tests` do Supabase para provar a eficácia da reabilitação auditiva em ambiente fora de treino (held-out).
    - A tela de progresso (`progress_screen.dart`) carrega e plota o histórico real de testes de desfecho (SRT em dB SNR), comparando o valor atual com o baseline (primeiro teste) e exibindo a melhoria líquida em dB de forma intuitiva.

16. **Espacialização Binaural Real com ITD/ILD, 4-AFC e Liberação Espacial de Mascaramento (IMPLANTADO).**
    - O treino "De que lado" (Nível 3) agora utiliza espacialização binaural baseada em Diferença Interaural de Tempo (ITD) e Diferença Interaural de Intensidade (ILD) calculados em tempo real na thread nativa do Oboe.
    - O delay interaural contralateral é limitado a 0.65 ms (~31 amostras a 48 kHz).
    - O treino "Distinguir sons" (Nível 2) foi expandido para um formato 4-AFC (quatro alternativas de escolha em grid 2x2) com seleção dinâmica de distratores baseados na banda de frequência do fonema alvo para reduzir a taxa de acerto por acaso para 25%.
    - No treino "Entender no barulho" (Nível 4 - Cocktail), implementamos a Liberação Espacial de Mascaramento (SRM), com a fala centralizada (0 graus) e o ruído de mascaramento lateralizado em ±45 graus.

17. **Consciência de Zona Morta Coclear e Transposição de Frequência (IMPLANTADO).**
    - Implementação do `CochlearDeadRegionManager` detectando limiares >= 70 dB HL nas frequências agudas do audiograma do paciente.
    - Limitação automática do ganho do EQ a 10 dB em bandas mortas.
    - Algoritmo DSP de transposição espectral (Frequency Lowering) em Dart que extrai a envoltória de fricativas agudas e modula ruído de passa-banda na faixa residual audível (1.5-2.5 kHz) with boost de +4.5 dB.
    - Seleção inteligente em `getSmartPhoneme` prioriza a região de 2000-4000 Hz se as agudas estiverem mortas.

18. **Fluxo de Desbloqueio N2 → N4, Prática Intercalada, Dosagem Diária e Aconselhamento (IMPLANTADO - FASE 5).**
    - Ajustado o cálculo de desbloqueio em `calculateUnlockedLevel` para liberar os níveis 3 (Espacial) e 4 (No barulho) simultaneamente quando a acurácia média do nível 2 é $\ge 70\%$.
    - Integrado o `AdaptiveStaircase` para ajustar o SNR e estimar o SRT (Speech Reception Threshold) nas Frases (`SentenceTrainingScreen`).
    - Adicionado suporte a interleaving/prática intercalada em `getSmartPhoneme` de `GamificationController` para usuários experientes (XP > 1000) com 30% de chance de sortear dificuldades menores.
    - Acumulador de tempo diário (minutos de treino hoje) calculado a partir das sessões concluídas do dia, exibido em um anel de progresso com meta de 15 minutos na Home.
    - Tela de relatório de missão (`MissionReportScreen`) agora exibe cards de aconselhamento fonoaudiológico com estratégias de comunicação ativa em rotação aleatória.

19. **Erro 'Duplicate root element android' no IDE / JDT.LS (RESOLVIDO):**
    O VS Code com a extensão Java da Red Hat tentava importar o subprojeto Android, gerando conflitos de nomenclatura com o workspace raiz.
    - **Fix:** (1) Adicionado `rootProject.name = "ear-training-android"` no `android/settings.gradle.kts` para desambiguar o projeto raiz. (2) Excluído o diretório `android` do escopo de escaneamento automático do Java no `.vscode/settings.json` via `"java.import.exclusions"`. O Gradle agora sincroniza perfeitamente de forma independente.

20. **Erro 'Missing Gradle project configuration folder: .settings' apontando para diretório inexistente (RESOLVIDO):**
    Após mover/remover subpastas como `antigravity-reab-auditiva/android/app`, o servidor de linguagem Java (JDT.LS) continuava tentando sincronizar os projetos a partir do seu cache interno (`workspaceStorage/<hash>/redhat.java/jdt_ws/.metadata/.plugins/org.eclipse.core.resources/.projects/app`).
    - **Fix:** Deletar manualmente as pastas dos projetos fantasmas (`app` e `android` antigos) do cache do JDT.LS para forçar o servidor a esquecê-los.

21. **Teste de fala no barulho (SRT) estava escondido só na tela de evolução (RESOLVIDO).**
    O teste de desfecho (Matrix/SRT, `outcome_test_screen.dart`) só tinha ponto de entrada
    **dentro** da tela de progresso — fora do fluxo principal, difícil de descobrir.
    **Decisão (dono do produto):** é um **teste-âncora**, irmão do teste de audição, então
    o ponto de entrada foi para a **Home** (`_buildOutcomeTestCard` em `home_screen.dart`),
    logo após o card do teste de audição. **Sempre disponível**, mas exige o **audiograma**
    antes (personaliza o ganho) — sem ele, SnackBar pedindo o teste de audição.
    **NÃO entrou na gamificação** (sem XP/nível/desbloqueio): medir ≠ treinar; gamificar
    contaminaria a métrica de desfecho. A tela de progresso mantém só o **histórico/evolução**
    do SRT (gráfico + delta) com "Fazer o teste de novo". Removido jargão da UI (badge
    "Matrix", "Teste de Desfecho" → "Teste de fala no barulho"). Skill `teste-fala-no-ruido`
    + doc `docs/treinos/teste-fala-no-ruido.md`. Como a tela inicializa o motor por conta
    própria (não passa por `AudioServiceManager`), o ramp de volume de referência (§4.2) é
    chamado no `initState` dela — senão o SRT seria medido noutro volume.

22. **Frente 2 — Conteúdo clínico em inglês (IMPLANTADO).**
    Todo o conteúdo clínico foi criado em inglês e conectado ao `audioLanguageCode` do `LocaleController`:
    - **Pares mínimos EN** (`phoneme_map.dart` → chave `level_2_en`): 62 pares, mesma
      distribuição de `freq_band`/`type` do banco PT. Fontes: literatura de reabilitação
      auditiva adulta (ASHA journals, Frontiers in Audiology, MED-EL Minimal Pairs Test).
      Contraste prioritário: fricativas agudas (s/sh, s/θ, f/θ), oclusivas (vozeamento e
      ponto), sibilantes (sh/ch), nasais e aproximantes — seguindo a hierarquia de impacto
      em SNHL/presbiacusia.
    - **Matrix Sentence Test EN** (`outcome_test_bank.dart` → `MATRIX_NAMES_EN` etc.):
      word matrix do American English Matrix Test (AEMT) publicado.
      Referência: Kollmeier et al. 2015 Int J Audiol 54(sup2):3-16;
      Kiolbasa et al. 2024 Int J Audiol 63(5); CI Brain Lab, Washington University.
      Nomes: Bob, Gene, Jane, Jill, Lynn | Verbos: bought, found, gave, held, lost |
      Números: two, three, four, five, six | Adjetivos: big, blue, cold, hot, new |
      Substantivos: bags, cards, gloves, hats, pens. Função `generateRandomMatrixSentenceEn()`.
    - **Banco de frases EN** (`sentence_bank.dart` → `SENTENCE_BANK_BY_ENV_EN`): 4 ambientes
      × 10 frases (restaurant, gym, park, supermarket), pares mínimos reais, linguagem
      natural para adultos 55+.
    - **Ligação ao idioma:** `training_dashboard._startLevel2` lê `audioLanguageCode` via
      `LocaleController` e passa `phonemeBankKey` correto ao `GamificationController.getSmartPhoneme`.
      `outcome_test_screen._nextTrial` e `_buildTestView` usam variantes EN quando EN.
      `sentence_training_screen.didChangeDependencies` seleciona `SENTENCE_BANK_BY_ENV_EN` quando EN.
    - **`outcome_test_screen.dart`** — todas as strings PT hardcoded migradas para ARB
      (`outcomeTestTitle`, `outcomeTestMatrixTitle`, `outcomeTestDescription1/2`,
      `outcomeTestStart`, `outcomeTestSentenceProgress`, `outcomeTestDifficulty`,
      `outcomeTestListenSentence`, `outcomeTestChooseCategory`, `outcomeTestScore`,
      `outcomeTestNextSentence`, `outcomeTestConfirm`, `outcomeTestDone`,
      `outcomeTestSrtLabel`, `outcomeTestInterpretGood/Mild/Severe`, `outcomeTestBackHome`).
    - **Atenção — Frente 2 clínica requer validação antes de qualquer uso assistencial:**
      os conteúdos EN (pares mínimos, frases Matrix, banco de frases) são válidos como
      texto/linguística; os **áudios gravados** (assets/speech/) ainda são somente PT.
      Antes de ativar o treinamento EN para usuários reais, gravar os áudios EN e validar
      normativamente o AEMT com falantes do público-alvo (55–75).

23. **Familiarização do Teste de Audição reiniciava a busca do limiar em 40 dB fixo
    mesmo quando o usuário não ouvia até 80 dB (RESOLVIDO).**
    No algoritmo Hughson-Westlake, a fase de familiarização sobe de 10 em 10 dB até o
    usuário ouvir. Ao confirmar o som, o código reiniciava em `_currentDb = 40.0`
    independentemente do nível em que o usuário respondeu. Resultado: se o limiar era
    alto (ex: 70–80 dB), o teste descia ao "abismo" (40 dB) e o usuário tinha de
    clicar "Não" várias vezes até o staircase subir de volta — tempo perdido e
    experiência confusa.
    **Fix:** ao confirmar na familiarização, o teste começa em `_currentDb - 10 dB`
    (clampado entre 0 e 110), aproveitando que a familiarização já revelou a região
    aproximada do limiar. Exemplo: confirmou em 80 dB → começa em 70 dB. O descenso
    de 10 dB é clínico: Hughson-Westlake exige começar abaixo do limiar estimado.
    Arquivo: `lib/screens/threshold_test_screen.dart`, método `_onResponse`.

24. **Erro de carregamento do banco de frases e do fonema de treino no idioma Inglês (RESOLVIDO).**
    - **Banco de Frases:** O app buscava frases inglesas usando as chaves de ambiente PT (`restaurante`, `academia`, `praca`, `mercado`) do `TrainingEnvironment`, mas o `SENTENCE_BANK_BY_ENV_EN` usava chaves EN (`restaurant`, `gym`, `park`, `supermarket`), retornando `null` e caindo na lista global achatada. **Fix:** Alinhadas as chaves do banco EN com as chaves padrão do sistema.
    - **Níveis 3 e 4:** O treino espacial (Nível 3) e o treino no barulho (Nível 4) estavam hardcoded para carregar o banco de fonemas PT (`level_2`), gerando reprodução inadequada de sons em inglês pelo TTS do dispositivo. **Fix:** Ajustada a busca para ler reativamente o idioma do `LocaleController` e passar `level_2_en` quando ativo.
    - **Localização Dinâmica:** Migradas todas as telas restantes (`mission_report_screen.dart`, `sentence_hub_screen.dart`, `sentence_training_screen.dart` e contadores de progresso do painel em `training_dashboard.dart`) para usarem `AppLocalizations` de forma limpa e dinâmica (incluindo aconselhamentos indexados e getters de contexto em `TrainingEnvironment`).

25. **Desvio de volume durante os treinos (IMPLANTADO).**
    - **Problema:** Usuários podiam alterar o volume físico de mídia do sistema operacional durante as sessões de treino (Níveis 2, 3, 4 e Frases do dia a dia), saindo do referencial calibrado de 85% e invalidando a acústica do treino/estímulo.
    - **Solução:** Unificação da proteção de drift de volume em um widget compartilhado `VolumeDriftBanner`. Implementado o método de verificação reativa `_verifyVolume()` que é invocado imediatamente antes de tocar qualquer estímulo de fala. Caso um desvio seja detectado, o banner compartilhado é exibido e todos os botões de resposta e repetição são desabilitados até que o usuário clique em "Voltar ao nível e continuar", restabelecendo os 85% do volume de referência.

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
- **Visual padrão = tema CLARO** (amigável). Cor vem da `AppPalette` via `ThemeController`,
  nunca hardcoded por tela. O usuário troca claro↔escuro no menu (⋮); a escolha persiste.
- Linguagem humana, "o porquê" antes do treino, fontes grandes, alto contraste.
- **Nível 4 ("No barulho"): o ruído é FIXO; quem dificulta é a FALA abaixando.**
  Não voltar a subir o ruído para dificultar — fica alto e cansa o idoso.
  Ruído `_kNoiseLevel`; fala `= ruído·10^(SNR/20)`. SNR vai de +10 dB a 0 dB
  (piso 0: com ruído fixo, SNR negativo deixa a fala baixa demais p/ ouvir).
