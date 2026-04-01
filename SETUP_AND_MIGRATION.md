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
   - Marque a caixa **"NDK (Side by side)"**. Version: `27.0.12077973`.
   - Marque a caixa **"CMake"**. Version: **`3.22.1`**.
4. **Configuração de Variáveis (local.properties)**:
   - Crie `android/local.properties` com os paths do SDK e Flutter.
5. **Variáveis de Ambiente (.env)**:
   - Recrie o `.env` com as chaves:
     ```env
     SUPABASE_URL=...
     SUPABASE_ANON_KEY=...
     GOOGLE_TTS_API_KEY=...
     STRIPE_PUBLISHABLE_KEY=...
     ```
6. **Dependências Críticas Add Hoje (Fase 3)**:
   - `flutter_stripe`: Gatekeeper de pagamentos.
   - `pdf` & `printing`: Relatórios clínicos industriais.
   - `introduction_screen`: Fluxo de calibração.
   - `fl_chart`: Dashboard de evolução.

---

## 🚀 Resumo das Modificações Realizadas no Sistema

Nestas sessões de engenharia, efetuamos a troca de um player de áudio convencional (`just_audio`) por um motor próprio de altíssima fidelidade e baixíssima latência construído em C++, diretamente no hardware Android via API **Oboe**.

### 1. Novo Motor de Áudio Nativo (`cpp/`)
- Pipeline **DSP** com Osciladores Senoidais e Gerador de Ruído.
- Filtros High-Shelf integrados para compensação de perda auditiva (Regra de Meio Ganho).

### 2. Fluxo de Reabilitação Elite
- **Nível 3 & 4**: Bloqueados por Paywall (Stripe) para usuários 'free'.
- **Gatekeeper**: Serviço de verificação de assinatura integrado ao Supabase.
- **Relatórios**: Geração de PDF com gráfico de evolução de 7 dias.

### 📝 Comandos de Rotina:
1. `flutter pub get`
2. `flutter run --release` (Recomendado para teste fonoaudiológico)
