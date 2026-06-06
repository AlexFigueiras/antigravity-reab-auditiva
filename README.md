# BOSYN — Treino auditivo (ear_training)

App Flutter de **reabilitação auditiva** para pessoas 55–75 anos com perda de sons
agudos. Faz um teste de audição (audiograma), usa esse resultado para personalizar
treinos de fala com ganho clínico, e treina a pessoa a distinguir sons, localizar a
origem do som e entender fala no meio do barulho. Áudio processado por um motor
nativo C++ (Oboe) de baixa latência via FFI. Alvo: Android.

> **Honestidade clínica é inegociável:** o app é um complemento ao aparelho auditivo
> e ao acompanhamento profissional — **não** é cura, diagnóstico nem substituto de
> fonoaudiólogo/otorrino. Nenhuma métrica é inventada.

## Por onde começar (mapa de docs)

| Quer entender… | Leia |
|---|---|
| **Para quem, o quê, por quê** — norte de produto e clínico, métricas reais | [PRODUTO.md](PRODUTO.md) |
| **Como funciona e onde mexer** — arquitetura, áudio, regras clínicas, bugs resolvidos | [SYSTEM.md](SYSTEM.md) |
| Um treino específico (N2/N3/N4/Frases) | [docs/treinos/](docs/treinos/) + skill `.claude/skills/treino-*` |
| Histórico de auditoria clínica | [docs/HISTORICO.md](docs/HISTORICO.md) |

> **Trabalhando em UM treino?** Carregue só a skill dele (`.claude/skills/treino-*`),
> que aponta para o doc de referência em `docs/treinos/`. Evita varrer o código todo.

## Setup em um PC novo

### Ferramentas
1. **Flutter SDK** — adicione `flutter/bin` ao PATH.
2. **Android Studio** → SDK Manager → aba **SDK Tools**, instale:
   - **NDK (Side by side)** versão `27.0.12077973`
   - **CMake** versão `3.22.1`

### Configuração do projeto
3. Crie `android/local.properties` com os paths do SDK Android e do Flutter.
4. Crie o `.env` na raiz (carregado por `flutter_dotenv`, listado em `pubspec.yaml`):
   ```env
   SUPABASE_URL=...
   SUPABASE_ANON_KEY=...
   STRIPE_PUBLISHABLE_KEY=...
   ```
   > A voz das palavras usa o **TTS nativo do device** (`flutter_tts`), offline e
   > gratuito — **não** há mais chave de Google TTS (a antiga falhava com 401; ver
   > [PRODUTO.md](PRODUTO.md) §8 e [SYSTEM.md](SYSTEM.md) §2).

### Rodar
```powershell
flutter pub get
flutter run                 # device por adb wireless (TLS)
# ou, para teste fonoaudiológico:
flutter run --release
```

### Diagnóstico de áudio
```powershell
adb -s <device-id> logcat | Select-String "TTS_DIAG"
```

## Stack

Flutter/Dart · motor de áudio nativo **C++ (Oboe)** via FFI · **Supabase**
(auth + audiograma + sessões, RLS) · **Stripe** (paywall do módulo de frases).
Detalhes em [SYSTEM.md](SYSTEM.md) §2.
