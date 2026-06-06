-- BOSYN: MIGRATION 002 - Telemetria de Estímulos e Resiliência
-- --------------------------------------------------------

-- 1. Tabela Granular de Respostas por Estímulo [BATTERY TELEMETRY]
CREATE TABLE IF NOT EXISTS stimulus_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    session_id UUID REFERENCES rehab_sessions(id),
    phoneme TEXT NOT NULL,
    target_panning NUMERIC,
    selected_panning NUMERIC,
    angular_error NUMERIC,
    is_correct BOOLEAN NOT NULL,
    reaction_time_ms INTEGER NOT NULL,
    hardware_timestamp_ns BIGINT,
    output_hardware TEXT, -- wired_headset, bluetooth, internal_speaker
    device_name TEXT,     -- Nome do hardware (ex: Sony WH-1000XM4)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Habilitar Row Level Security e Políticas de Proteção Constritiva
ALTER TABLE stimulus_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acesso restrito do próprio paciente em telemetria granular" 
ON stimulus_results FOR ALL 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 3. Índices de performance para Analytics e Consultas ML (Futuro)
CREATE INDEX IF NOT EXISTS idx_stimulus_results_session ON stimulus_results(session_id);
CREATE INDEX IF NOT EXISTS idx_stimulus_results_phoneme ON stimulus_results(phoneme);

-- 4. Otimização das buscas agregadas do Dashboard [SENIOR-DBA]
CREATE INDEX IF NOT EXISTS idx_stimulus_results_user ON stimulus_results(user_id);
CREATE INDEX IF NOT EXISTS idx_stimulus_results_created ON stimulus_results(created_at DESC);
