# BOSYN — Plano de Produto e Clínico

> Documento-norte do projeto. Define **quem ajudamos**, **o que tratamos**,
> **como medimos sucesso** e **em que ordem construímos**. Toda decisão de
> código deve poder ser justificada por algo escrito aqui. Se algo neste
> documento estiver errado, corrigimos o documento *antes* de mexer no código.

Última revisão: 2026-06-03

---

## 1. O problema que resolvemos

Pessoas com perda auditiva de longa data — geralmente perda de **sons agudos**
(presbiacusia, exposição a ruído) — vivem a mesma queixa:

> **"Eu ouço que estão falando, mas não entendo as palavras."**

Por quê? A fala é feita de duas partes:

- **Vogais** (a, e, i, o, u): graves, fortes. A pessoa **ouve**.
- **Consoantes** (s, f, x, ch, t, k, p): agudas, fracas. A pessoa **perde**.

As consoantes carregam a maior parte da *clareza* da fala. Sem elas, "fala" e
"sala", "cabo" e "cano" soam iguais. O cérebro, anos sem receber esses sons,
**desaprende** a distingui-los — mesmo quando um aparelho auditivo os reamplifica.

**Nosso usuário típico:** 55–75 anos, perda auditiva há anos, frustrado por não
acompanhar conversas (família, TV, telefone, mesa de restaurante). **Não** é um
gamer. **Não** é técnico. Quer uma resposta simples: *"isso vai me ajudar a
entender melhor as pessoas?"*

---

## 2. O que o app é (e o que NÃO é)

**É:** uma ferramenta de **treino auditivo** (reabilitação auditiva). Reeduca o
cérebro a distinguir os sons que a pessoa confunde, usando repetição dirigida —
um complemento ao aparelho auditivo e ao acompanhamento profissional.

**NÃO é:** cura, diagnóstico médico, nem substituto de fonoaudiólogo,
otorrinolaringologista ou aparelho auditivo. **Nunca prometemos isso.** Um app de
saúde honesto vale mais que um que exagera.

> Princípio inegociável: **honestidade clínica.** Nada de número inventado, gráfico
> decorativo ou "índice" que não mede nada. Se mostramos um progresso, ele é real.

---

## 3. Como medimos sucesso (métricas reais, não XP)

Estas são as únicas medidas que importam. Tudo no app deve servir a elas:

| Métrica | O que é | Por que importa |
|---|---|---|
| **Acerto por contraste** | % de acerto em cada par de sons (ex.: S×F), ao longo do tempo | É o coração: mostra se a pessoa está aprendendo a distinguir cada som |
| **Limiar de fala no ruído (SRT)** | O nível de ruído em que a pessoa ainda acerta ~50% | Medida audiológica real; mede a melhora no "efeito coquetel" |
| **Audiograma** | Mapa da perda por frequência (já existe) | Base para personalizar o treino. Não muda com treino — é referência |
| **Adesão** | Sessões feitas, regularidade | Treino auditivo só funciona com prática frequente e curta |
| **Autopercepção** | "Quão bem você acompanhou conversas esta semana?" (1–5) | Liga o treino à vida real, que é o que o usuário valoriza |

O que **não** é métrica de sucesso: XP, "nível de acuidade", badges. Podem existir
como motivação leve, mas nunca disfarçados de medida clínica.

---

## 4. Estado atual — o que é real e o que é teatro

Auditoria do código em 2026-06-03. Honestidade total para sabermos o que aproveitar.

### Funciona e é clinicamente válido (manter)
- ✅ **Teste de audição / audiometria** (`threshold_test_screen.dart`): protocolo
  clássico, frequências padrão (250–8000 Hz), gera audiograma real.
- ✅ **Pares mínimos** (`phoneme_map.dart`): conceito legítimo; pares reais em
  português dirigidos a faixas de frequência (ex.: `Saca`/`Faca` em 7 kHz).
- ✅ **Ganho compensatório de meia-perda** (`audio_engine.dart`,
  `getCompensatoryGain`): regra audiológica reconhecida (ganho = perda ÷ 2).
- ✅ **Ruído adaptativo no N4** (`speech_in_noise_screen.dart`): o SNR sobe/desce
  conforme acerto/erro — base correta para estimar o SRT.

### Teatro ou quebrado (corrigir ou remover)
- ❌ **Personalização desligada (bug crítico):** `getSmartPhoneme()` deveria
  escolher palavras com os sons que *este* usuário não ouve, lendo o audiograma.
  Mas é chamada com lista vazia (`getSmartPhoneme([])` em `training_dashboard.dart`),
  então a escolha é **sempre aleatória**. **A promessa central do app não acontece.**
- ❌ **Gráfico de "evolução" falso** (`home_screen.dart`, `_buildEvolutionChart`):
  pontos fixos, decorativos. Mostra progresso que não existe.
- ❌ **"Fadiga Neural" / repouso de 4h** (`gamification_controller.dart`): punição
  de videogame. Travar um idoso por 4h após 5 erros é contraproducente. Remover.
- ❌ **"Índice de Acuidade (IAB)"**: é só o XP renomeado (`INITIAL/MODERATE/ADVANCED`
  por faixa de XP). Não mede acuidade nenhuma.
- ❌ **Nível 1 (Tone Isolation):** existe no enum, mas **sem tela**. Placeholder.
- ⚠️ **Onboarding não coleta nada** (`onboarding_screen.dart`): nem idade, nem a
  queixa da pessoa, nem se usa aparelho. Perde a chance de personalizar e acolher.

### Estética
- ⚠️ **Tema "cockpit militar"** (verde fosfórico, "telemetria", "radar",
  "protocolo"): bonito, mas **intimida** exatamente quem mais precisa do app.

---

## 5. Como o app deveria ser — princípios de produto

1. **Linguagem humana.** Falamos com uma pessoa, não com um piloto de caça.
   Ver tabela de tradução na seção 7.
2. **Sempre dizer o porquê.** Antes de cada treino: *"Vamos treinar o som do **S** —
   ele aparece em 'sapato', 'casa'. É um dos que você mais confunde."*
3. **Personalização de verdade.** O treino é montado a partir do audiograma da
   pessoa. Treinamos os sons que **ela** perde, não sons aleatórios.
4. **Progresso real e honesto.** "Acertos por som, ao longo das semanas." Mesmo
   que suba devagar, é verdadeiro — e verdade motiva mais que pontos inflados.
5. **Sem punição.** Sessões curtas (3–5 min), tom gentil, sempre pode voltar.
   Descanso é sugestão acolhedora, nunca bloqueio.
6. **Acessível.** Fontes grandes, alto contraste, toques amplos, funciona com
   aparelho auditivo e fones. Pensado para 60+.
7. **Conexão com a vida.** O objetivo final é entender conversas reais — então
   caminhamos de sons → palavras → frases → situações do dia a dia.

---

## 6. Os módulos de treino ("skills")

Cada exercício é um **módulo independente**, com **um** objetivo clínico claro,
métrica própria e testável sozinho. Conjunto enxuto e bem-feito > muitos pela metade.

| # | Módulo | O que treina | Métrica | Estado |
|---|---|---|---|---|
| 0 | **Teste de audição** | Mapeia a perda (audiograma) | Limiar por frequência | ✅ existe, bom |
| 1 | **Distinguir sons** | Pares mínimos personalizados pelo audiograma | Acerto por contraste | ⚠️ existe, mas personalização quebrada |
| 2 | **Entender no barulho** | Fala + ruído adaptativo | SRT (nível de ruído tolerado) | ⚠️ existe, falta medir/mostrar o SRT |
| 3 | **Localizar o som** | Direção (esquerda/centro/direita) | Acerto de localização | ⚠️ existe |
| 4 | **Frases reais** *(futuro)* | Entender frases, não só palavras | Acerto de frase no ruído | 🔲 não existe — maior aproximação da vida real |

**Lógica de personalização (módulo 1 — a corrigir):** ler o audiograma →
identificar frequências com perda > 25 dB HL → priorizar os pares mínimos cujo som
distintivo vive nessas faixas. (Essa é a lógica que já existe em `getSmartPhoneme`,
hoje desligada por ser chamada vazia.)

---

## 7. Tradução: jargão → linguagem humana

Regra: se um usuário de 65 anos não entende a palavra na primeira leitura, ela sai.

| Hoje (assusta/confunde) | Vira (acolhe/explica) |
|---|---|
| INICIAR PROTOCOLO N2 | Começar o treino de hoje |
| SYSTEM TELEMETRY / RADAR EM STANDBY | (remover) |
| FADIGA NEURAL DETECTADA — REPOUSO 4h | Bom trabalho hoje! Que tal voltar amanhã? |
| DISCRIMINAÇÃO FONÊMICA | Distinguir sons parecidos |
| ATENÇÃO ESPACIAL | De que lado vem o som |
| EFEITO COQUETEL | Entender no meio do barulho |
| SNR / SIGNAL-TO-NOISE RATIO | Quanto barulho de fundo (de calmo a difícil) |
| ÍNDICE DE ACUIDADE (IAB) | Sua evolução |
| MODO COCKPIT | (remover) |
| OFFSET / CALIBRAÇÃO DE SINCRONIA | Ajuste do seu fone (uma vez só) |

---

## 8. Roteiro de construção (em fases)

Regra de ouro: **uma funcionalidade real e honesta de cada vez**, sempre testável
no celular. Nada de painel falso. Cada fase deixa o app melhor de verdade.

### Fase 0 — Fundação *(este documento)*
Definir quem ajudamos, o que tratamos e como medimos. ✅ feito ao ler isto.

### Fase 1 — Tornar honesto e humano *(maior impacto, menor risco)*
- [ ] **Ligar audiograma → treino** (consertar `getSmartPhoneme`): treinar os sons
      que a pessoa realmente perde. *Maior ganho clínico do projeto.*
- [ ] **Reescrever a linguagem** da interface (tabela da seção 7).
- [ ] **Substituir o gráfico falso** por progresso real (acerto por som no tempo).
- [ ] **Remover a "fadiga neural"** / bloqueio de 4h.

### Fase 2 — Acolher e medir
- [ ] **Onboarding que escuta:** perguntar idade, principal dificuldade, se usa
      aparelho — e usar isso para acolher e ajustar.
- [ ] **Calcular e mostrar o SRT** no módulo "Entender no barulho".
- [ ] **Tela de progresso** clara e honesta, por som e por semana.

### Fase 3 — Transferência para a vida real
- [ ] **Módulo de frases** no ruído (não só palavras isoladas).
- [ ] **Autopercepção semanal** (1–5) e correlação com o treino.
- [ ] Polir acessibilidade (fonte, contraste, voz, compatibilidade com aparelho).

### Pendências técnicas herdadas (de auditorias anteriores)
- [ ] Integração real do pagamento (Stripe) — hoje o paywall não concede acesso
      (correto), mas falta o fluxo verdadeiro via webhook no backend.
- [ ] Suporte a iOS (hoje o motor nativo é focado em Android/Oboe).
- [ ] Implementação real do `pffft` (hoje é stub) se a performance de FFT exigir.

---

## 9. Decisões em aberto (a definir com o time clínico)
- Frequência e duração ideais de sessão (evidência sugere curto e diário).
- Quantos contrastes treinar por sessão.
- Critério de "alta" / quando a pessoa atingiu o platô de melhora.
- Necessidade de validação por um(a) fonoaudiólogo(a) antes de uso amplo.

---

*Este documento é vivo. Atualize-o sempre que uma decisão de produto ou clínica mudar.*
