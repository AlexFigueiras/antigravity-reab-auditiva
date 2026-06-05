# Memória de Projeto — Claims Clínicas vs. Implementação Real

Este documento registra as divergências encontradas entre o que a interface/marketing do app BOSYN alega clinicamente e o que estava de fato operando no motor de áudio e lógica antes e depois da implementação das correções de reabilitação auditiva.

## 1. Tabela de Claims Clínicas vs. Implementação

| Claim Clínica / Produto | Estado Inicial (Auditado) | Estado Atual (Corrigido) | Impacto Clínico / Notas |
| :--- | :--- | :--- | :--- |
| **Ganho Compensatório por Audiograma** | **FALSO (Teatro)**. O motor calculava `clinicalGainDb` e apenas imprimia no log. O áudio do TTS tocava a 100% de volume linear de forma flat. | **REAL**. O EQ multibanda nativo (5 bandas: 1k/2k/4k/6k/8k Hz) calcula e aplica o ganho compensatório de meia-perda individualizado para cada ouvido. | Restaura a personalização do áudio nativo para a perda auditiva do usuário (apenas no modo sem aparelho). |
| **Frequências Críticas dos Estímulos** | **FALSO (Sequenciais/Teatro)**. As `freq_band` de `phoneme_map.dart` eram valores fictícios sequenciais não correlacionados a espectros reais. | **REAL**. Atualizado para centroides reais baseados na fonética (sibilantes em 6k-8k, plosivas em 1k-4k, etc.), combinando com as bandas do teste. | A personalização agora escolhe contrastes relevantes às frequências de real perda auditiva do paciente. |
| **Teste de Audição Calibrado** | **FRÁGIL**. Passos de 10 dB, sem fase de familiarização, sem controle de falsos positivos (catch-trials). Arbitrário e impreciso. | **MELHORADO (Triagem Relativa)**. Implementado Hughson-Westlake (passos de 5 dB), familiarização antes de cada frequência e catch-trials de silêncio (20%). Rótulo honesto na UI. | Agora funciona como uma triagem relativa com controle de ansiedade/falsos positivos, sem prometer um diagnóstico clínico. |
| **Staircase Adaptativo de SNR (N4)** | **QUEBRADO**. A lógica reduzia o SNR a cada acerto, mas nunca subia no erro, travando o idoso no nível mais difícil (piso). | **REAL**. Implementado staircase 2-down/1-up real através da classe `AdaptiveStaircase`, estimando o SRT real com reversões. | O teste e treino no ruído convergem para o limiar real do usuário de forma dinâmica e justa. |
| **Dificuldade Progressiva no N2** | **NULA**. Escolha de pares fonéticos puramente aleatória, independentemente da taxa de acerto do usuário. | **REAL**. Dificuldade adaptativa de 1 a 5 baseada no tipo de contraste, integrada a um staircase de progressão para manter ~75% de acertos. | Evita a frustração ao manter o desafio no ponto psicofísico ideal (zona de desenvolvimento proximal). |
| **Narrativa de Reabilitação Coclear** | **IMPRECISA**. A interface implicava "estimular cílios cocleares" e "recuperar audição". | **CORRIGIDA**. Toda a cópia e o `PRODUTO.md` explicam que a reabilitação treina a plasticidade do córtex auditivo central (cérebro). | Alinhamento com a neuroaudiologia científica e honestidade total com o usuário. |
| **Zona Morta Coclear (CDR)** | **NULA**. O motor amplificava agudos cegamente independente do limiar extremo. | **REAL**. Detecta perda >= 70 dB HL nas frequências agudas, limita o ganho a 10 dB para evitar recrutamento e aplica transposição (Frequency Lowering) em Dart. | Protege contra recrutamento e distorção na cóclea, resgatando pistas perdidas de fonemas agudos. |

## 2. Auditoria e Rastreabilidade

- **Auditoria de Linha de Base:** 2026-06-03
- **Implementação do Plano:** 2026-06-05
- **Garantia de Não-Regressão:** Execução contínua do `dart analyze` nas telas e serviços modificados para garantir 0 avisos estruturais.
