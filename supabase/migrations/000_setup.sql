-- SQL para configuração do Supabase (Executar no SQL Editor)
-- --------------------------------------------------------

-- 1. Tabela de Audiogramas
CREATE TABLE IF NOT EXISTS audiograms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    left_ear JSONB NOT NULL,
    right_ear JSONB NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Habilitar Row Level Security [SEGURANÇA/INFRA]
ALTER TABLE audiograms ENABLE ROW LEVEL SECURITY;

-- 3. Políticas RLS (Zero-Trust Data Isolation)
-- Os profissionais só podem ver audiogramas que eles mesmos criaram ou que foram associados a eles.
-- Por agora, isolamos por user_id (quem criou o registro).

CREATE POLICY "Usuários podem ver apenas seus próprios registros" 
ON audiograms FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem inserir seus próprios registros" 
ON audiograms FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem deletar apenas seus próprios registros" 
ON audiograms FOR DELETE 
USING (auth.uid() = user_id);

-- 4. Tabela de Sessões de Reabilitação [TREINO/TELEMETRIA]
CREATE TABLE IF NOT EXISTS rehab_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    patient_id TEXT NOT NULL,
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    level INTEGER NOT NULL,
    total_trials INTEGER NOT NULL,
    correct_answers INTEGER NOT NULL,
    accuracy NUMERIC(5,2),
    avg_response_time_ms NUMERIC,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Row Level Security para Sessões
ALTER TABLE rehab_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acesso isolado a sessões por usuário" 
ON rehab_sessions FOR ALL 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
