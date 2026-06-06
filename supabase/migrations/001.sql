-- BOSYN: MIGRATION 001 - Camada de Persistência Industrial
-- --------------------------------------------------------

-- 1. Tabela de Perfis de Usuário (Gestão de Status Clínico)
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id),
    display_name TEXT,
    acuity_level TEXT DEFAULT 'INITIAL', -- INITIAL, MODERATE, ADVANCED
    total_xp BIGINT DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    neural_energy INTEGER DEFAULT 5,
    last_training_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Tabela de Progresso de Longo Prazo (Analytics Detalhado)
CREATE TABLE IF NOT EXISTS rehab_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    phoneme TEXT NOT NULL,
    accuracy NUMERIC(5,2) NOT NULL,
    frequency_hz INTEGER,
    session_id UUID REFERENCES rehab_sessions(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Habilitar RLS [SEGURANÇA/INFRA]
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE rehab_progress ENABLE ROW LEVEL SECURITY;

-- 4. Políticas RLS de Isolamento por Usuário
-- Políticas para user_profiles
CREATE POLICY "Usuários acessam seu próprio perfil" 
ON user_profiles FOR ALL 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Políticas para rehab_progress
CREATE POLICY "Usuários acessam seu próprio progresso" 
ON rehab_progress FOR ALL 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. Função de Reset de Energia Diário (Opcional por agora, mas delineada)
-- TODO: Implementar via Cron no Supabase se possível ou via Apps Logic.
