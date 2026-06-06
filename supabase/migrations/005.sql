-- BOSYN: MIGRATION 005 - Medida de Desfecho Independente (Matrix Test)
-- ------------------------------------------------------------------
-- Fase 0.2 do PRODUTO.md:
--   Mede o SRT de frases held-out (Matrix) pré e pós treino para provar transferência.

CREATE TABLE IF NOT EXISTS outcome_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    srt_db DOUBLE PRECISION NOT NULL,
    total_trials INT NOT NULL DEFAULT 0,
    correct_answers INT NOT NULL DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

ALTER TABLE outcome_tests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "outcome_tests_all_own" ON outcome_tests;
CREATE POLICY "outcome_tests_all_own"
ON outcome_tests FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Índice para consultas por usuário em ordem temporal (gráfico de evolução).
CREATE INDEX IF NOT EXISTS idx_outcome_tests_user_date
ON outcome_tests (user_id, created_at DESC);
