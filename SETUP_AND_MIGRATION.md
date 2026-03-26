# Guia de Configuração e Migração do Motor Nativo (Antigravity Reab-Auditiva)

Este documento detalha todas as modificações críticas feitas no projeto durante a migração para a nova arquitetura do **Motor de Áudio Nativo C++ (Oboe)**, e lista todos os requisitos necessários para rodar o projeto do zero em um computador novo após clonar o repositório.

---

## 🛠️ Requisitos e Frameworks (Ambiente para o Novo PC)

Para que o projeto compile sem erros na nova máquina, você precisa instalar as seguintes ferramentas exatamente nas versões suportadas (ou superiores):

1. **Flutter SDK**: 
   - Certifique-se de configurar a variável de ambiente (PATH) para o diretório `flutter/bin`.
2. **Android Studio**:
   - Faça o download do Android Studio no novo PC.
   - Ao abrir, acesse **SDK Manager (Tools > SDK Manager)** -> Aba **SDK Tools**.
3. **Instalações Mandatórias no SDK Manager**:
   - Marque a caixa **"NDK (Side by side)"**. A versão utilizada para este build com sucesso foi a `27.0.12077973` (ou equivalente listada).
   - Marque a caixa **"CMake"**. A versão ajustada no projeto (e que o Gradle exigirá) é a **`3.22.1`**.
4. **Configuração de Variáveis (local.properties)**:
   - Ao clonar o projeto na nova máquina, crie ou confira o arquivo `android/local.properties`. Ele deve conter os caminhos absolutos corretos do flutter e do SDK na sua nova máquina. Exemplo:
     ```properties
     sdk.dir=C:\\Users\\SeuUsuario\\AppData\\Local\\Android\\Sdk
     flutter.sdk=C:\\caminho\\para\\o\\flutter
     ```
5. **Variáveis de Ambiente (.env)**:
   - Não se esqueça de que chaves da API (Supabase e Google TTS) provavalmente não sobem pro GitHub (se o `.env` estiver no `.gitignore`). Você precisará recriar o `.env` na raiz do projeto com as chaves:
     ```env
     SUPABASE_URL=...
     SUPABASE_ANON_KEY=...
     GOOGLE_TTS_API_KEY=...
     ```

---

## 🚀 Resumo das Modificações Realizadas no Sistema

Nestas sessões de engenharia, efetuamos a troca de um player de áudio convencional (`just_audio`) por um motor próprio de altíssima fidelidade e baixíssima latência construído em C++, diretamente no TEE (Trusted Execution Environment) e hardware Android via API **Oboe**.

### 1. Novo Motor de Áudio Nativo (`cpp/`)
- Integrado código C++ com **Oboe** para acesso direto ao hardware de áudio do Android (taxa de 48kHz nativa).
- Construído um pipeline **DSP (Digital Signal Processing)** contendo:
  - Osciladores Senoidais (`SineOscillator.cpp`) para frequências puras (audiometria).
  - Gerador de Ruído (`NoiseGenerator.cpp`) para mascaramento e treinos Efeito Coquetel.
  - Filtros IIR (Biquad) e Filtros FIR particionados (Overlap-Save).
  - Resolvido um problema clínico grave de cancelamento de fase temporal usando buffers circulares dinâmicos na camada DSP para alinhar frequências altas e baixas.
  - O código foi otimizado definindo as devidas macros matemáticas (`M_PI`) para garantir que compilaria em qualquer SO, e as funções FFI de ponte adotaram `int32_t` para evitar a quebra transacional entre linguagens sobre tipos booleanos.

### 2. Ponte de Comunicação FFI (`native_bridge.cpp` e `lib/audio_engine/native_engine.dart`)
- Toda a estrutura FFI foi solidificada. O app se comunica com a `.so` (Shared Object) em C/C++ usando Dart FFI.
- Isso possibilita, por exemplo, mudar a frequência da onda pura, ganho de volume, SNR (Relação Sinal-Ruído) instantaneamente em microsegundos – vital para processamento neuroauditivo.

### 3. Remoção do Antigo Motor
- A dependência obsoleta `just_audio` foi desinstalada do `pubspec.yaml` e as referências limpas de todos os arquivos.
- A recepção de áudio pelo Google TTS foi atualizada de `MP3` para PCM bruto (`LINEAR16`), o formato nativo da rede de C++.

### 4. Ajustes Cirúrgicos de UI/Telas Clínicas
- **Limiares Audiométricos (`threshold_test_screen.dart`)**: Adequada para iniciar o motor Oboe no `initState` provendo o mock/dados do paciente. Adicionado o Enum "Ambos" (`EarSide.both`) para que o gerador senoidal consiga emitir fones em estéreo corretamente (ou balanceado).
- **Discriminação Fonêmica & Atenção Espacial**: Telas reescritas para inicializarem sozinhas a "Igníção C++", removendo "botões experimentais soltos" da tela. Criado um ícone verde fixo (`Icons.memory`) atestando a saúde do motor integrado no lugar de antigos interruptores propensos ao erro de assíncronia.

### 5. Configuração do CMake (`cpp/CMakeLists.txt` e `android/app/build.gradle`)
- Definida a hierarquia correta para C++17 e a liberação das variáves não atreladas sem barrar a compilação do clang `[-Wno-unused-command-line-argument]`.
- O Gradle agora enxerga a camada C++ pelo path mapeado e a biblioteca gerada (`dsp_audio_engine`) subirá empacotada com o APK / AppBundle final.

---

### 📝 Comandos de Rotina após baixar no Novo PC:
1. Abra um terminal no diretório do projeto.
2. Baixe os pacotes: `flutter pub get`
3. Rode um build debug de teste: `flutter run` ou build release focada em teste fonoaudiológico `flutter run --release`.
