# Plano Diretor de Desenvolvimento (PRD) - App de Reabilitação Auditiva
**Role Ativa:** [ORQUESTRADOR]

## 1. Visão Geral do Produto
Aplicativo mobile nativo focado em Reabilitação Auditiva Baseada em Plasticidade Neural, com ênfase no treinamento para perda de frequências agudas e dificuldade de processamento fonêmico ("efeito coquetel").

## 2. Arquitetura de Roles & Integração MCP
Toda a integração com os audiogramas dos usuários é regrada pela atuação conjunta de duas capabilities da plataforma Antigravity:
*   **[ESPECIALISTA/DOMÍNIO]:** Atua como o "Audiologista Digital". Consome os dados do audiograma (Hz/dB por orelha) fornecidos via MCP para modular os parâmetros do motor de áudio. É responsável por mapear os limiares de audição (ex: perda em 4kHz, 8kHz) e aplicar filtros Equalizadores (EQ) paramétricos em tempo real antes da emissão do estímulo ao paciente.
*   **[SEGURANÇA/INFRA]:** Valida, antes de qualquer execução de processamento via MCP, o escopo da identidade. Obrigatoriamente aplica RLS (Row Level Security) via tenantId e userId ao banco (Supabase) (`.eq('user_id', auth.uid())`). Garante a conformidade LGPD/GDPR no tráfego das Curvas Audiométricas e metadados sensíveis do paciente. Nenhuma query avança sem este isolamento (Zero-Trust Data Isolation).

## 3. Plano de Gamificação: Níveis de Processamento Auditivo
Progressão terapêutica contínua guiando o cérebro do silêncio ao caos controlado:
*   **Nível 1 (Isolamento Tonal):** Sons puros e sweep de frequências agudas calibradas exatamente na borda do limiar de detecção (Near-Threshold) do paciente. Gamificação baseada em acerto de detecção (Sim/Não).
*   **Nível 2 (Discriminação Fonêmica no Silêncio):** Apresentação de pares mínimos difíceis para perda aguda (ex: /f/ vs /s/, /p/ vs /t/). O motor realça (boost) a frequência deficitária e reduz a amplitude de graves para evitar mascaramento ascendente.
*   **Nível 3 (Áudio Espacial / Atenção Auditiva):** Introdução de estímulos lateralizados. O paciente precisa identificar a origem do som (Direita/Esquerda/Centro). Utiliza plugins de áudio binaural do Flutter/Motor Nativo.
*   **Nível 4 (O Efeito Coquetel - Speech in Noise):** Introdução dinâmica de ruído de fundo (Babble Noise, White Noise, ruído de restaurante). A Relação Sinal-Ruído (SNR - Signal to Noise Ratio) é ajustada algoritmicamente: inicia com o sinal-alvo +15dB acima do ruído e reduz gradativamente até 0dB ou negativo, conforme a curva de aprendizagem e plasticidade do paciente.

### Detalhamento Técnico: Nível 2 (Discriminação Fonêmica)
*   **Lógica de Randomização:** O sistema executará o sorteio de pares mínimos difíceis (ex: pares f/s, p/t) de uma fonte estruturada. A cada rodada, o motor selecionará um áudio Alvo e organizará opções em tela cujo posicionamento será embaralhado clinicamente (via `List.shuffle()`) para evitar adaptação por viés de posição visual.
*   **Filtros de Áudio em Tempo Real:** Conforme a Global Rule, o `AudioRehabEngine` orquestrará filtros clínicos (High-Pass/Equalizador), aplicando ganho (*boost*) estritamente nas frequências deficitárias identificadas pelo audiograma, reduzindo graves para evitar mascaramento ascendente. O normalizador de ganho atuará logo antes da saída para mitigar distorções e preservar a integridade coclear do paciente.
*   **Telemetria e Supabase (SSOT):** Os Acertos, Erros e Tempos de Reação serão consolidados. Ao concluir o nível ou sob *checkpoint*, o agregador fará a persistência no Supabase em tabela designada (ex: `rehab_sessions`). A inserção é submetida rigorosamente sob a política RLS passando o `user_id` atrelado ao Auth token, garantindo que o prontuário seja impenetrável transversalmente (LGPD/HIPAA).

## 4. Stack Técnica & Conectores Antigravity
*   **Frontend:** Flutter/Dart (Mobile Nativo - iOS/Android).
    *   *Libs Base:* `audio_session` (gerência de foco de áudio OS), `just_audio` / `soloud` ou FFI direto para DSP.
    *   *UX/UI:* Skill `[frontend-design]`, alta legibilidade, contraste AAA, touch-targets grandes, acessibilidade sênior.
*   **Backend & DSP (Digital Signal Processing):** Conectores de alta performance da Antigravity, orquestrando Cloud Functions / Edge Functions. O áudio do paciente pode ser processado localmente no device (usando FFI - C++/Rust hookado no Flutter) para processamento em tempo real (Latência < 20ms) sem ida ao servidor, garantindo segurança e fluidez.
*   **Banco de Dados/Auth:** Supabase (PostgreSQL). JWT associado ao Auth com políticas rígidas de tenant.
*   **Monetização:** Skill `[stripe-integration]` nativa para in-app purchases ou SaaS account (assinaturas recorrentes mensais/anuais).

## 5. Gestão de Skills e Bibliotecas Externas
De acordo com as diretrizes globais do projeto:
*   A consulta de novas habilidades deve ser feita **estritamente via arquivo `skills-library/catalog.md`**.
*   Os arquivos de implementação de skills estão localizados em `skills-library/archives/` para otimização de contexto. O agente deve ignorar recursivamente qualquer conteúdo dentro desta pasta.
*   **Atenção:** Não tentar ler ou indexar nada dentro de `archives/` por conta própria. A implementação específica será solicitada pelo usuário com o caminho exato do arquivo, caso seja necessária a sua utilização.

## 6. Avisos Legais e Termos Médicos
> **Aviso de Suporte à Decisão Clínica:** Este aplicativo fornece sugestão de suporte à decisão e treinamento auditivo baseado em algoritmos. Não substitui o diagnóstico, acompanhamento ou adaptação de próteses auditivas realizadas por um fonoaudiólogo/médico otorrinolaringologista. O julgamento final e a responsabilidade clínica são do profissional responsável que acompanha o paciente.

---
**Status Atual:** 
- [x] Ambiente Flutter configurado (PATH SDK).
- [x] Modelo Clínico de Audiograma implementado (refinado JSON).
- [x] Motor de Áudio (AudioRehabEngine) com síntese de Tom Puro (Nível 1) e Mixagem SNR (Nível 4).
- [x] Dashboard Industrial Utilitarian com fl_chart.
- [x] Tela de Calibração/Audiometria in-app funcional.
- [x] Persistência: Supabase integrado (serviços e infraestrutura).
- [x] Segurança [SEGURANÇA/INFRA]: Script SQL com RLS (Zero-Trust) gerado.

**Próximos Passos:** 
1. **Configuração .env:** Preencher URL/Key do Supabase no arquivo `.env`.
2. **Setup DB:** Executar `supabase_setup.sql` no painel do Supabase.
3. **Nível 2 (Discriminação Fonêmica):** Colocar listas de palavras (wav/mp3) em `assets/audio/` e implementar UI de treino.
4. **UX/UI:** Melhorar o feedback visual durante o teste de limiar (micro-animações de onda).


5. Gestão Proativa de Skills
Para maximizar a eficiência e evitar reencapsulamento de código:

Consulta Obrigatória: Antes de qualquer implementação, o agente deve escanear o skills-library/catalog.md.

Gatilho de Ação (Proatividade): Se uma skill relevante for encontrada, o agente deve interromper o raciocínio e dizer: "Identifiquei que a skill [NOME-DA-SKILL] resolve esta tarefa. Por favor, forneça o conteúdo do arquivo archives/nome_da_skill.dart para que eu possa aplicar a lógica (X-Copy)."

Manutenção: Ao criar uma solução inédita e robusta, o agente deve sugerir ao [ORQUESTRADOR] a criação de uma nova entrada no catálogo.