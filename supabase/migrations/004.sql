-- BOSYN: MIGRATION 004 - Perfil de acolhimento + autopercepção semanal
-- --------------------------------------------------------
-- Fase 2/3 do PRODUTO.md:
--   1) O onboarding agora coleta idade, principal dificuldade e uso de
--      aparelho auditivo. Estas colunas precisam existir em `profiles`.
--   2) Autopercepção semanal (1-5): liga o treino à vida real.
--      Tabela própria, isolada por user_id via RLS.

-- 1) Colunas de acolhimento no perfil ------------------------------------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS age_range TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS main_difficulty TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS uses_hearing_aid BOOLEAN;

-- 2) Autopercepção semanal ------------------------------------------------
CREATE TABLE IF NOT EXISTS self_perception (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    -- Resposta de 1 (muito difícil) a 5 (muito bem) à pergunta:
    -- "Quão bem você acompanhou as conversas esta semana?"
    score INT NOT NULL CHECK (score BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE self_perception ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_perception_select_own"
ON self_perception FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "self_perception_insert_own"
ON self_perception FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Índice para consultas por usuário em ordem temporal (gráfico de evolução).
CREATE INDEX IF NOT EXISTS idx_self_perception_user_date
ON self_perception (user_id, created_at DESC);
