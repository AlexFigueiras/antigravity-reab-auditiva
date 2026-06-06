-- BOSYN: MIGRATION 003 - Tabela `profiles` (onboarding + assinatura)
-- --------------------------------------------------------
-- O aplicativo (main.dart, auth_screen.dart, onboarding_screen.dart,
-- gatekeeper_service.dart) lê/escreve a tabela `profiles`, que nao era
-- criada por nenhuma migration anterior. Isto causava erro 500 em toda
-- consulta de perfil no launch. Esta migration cria a tabela e protege
-- a coluna de assinatura contra auto-promocao pelo cliente.

CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_status TEXT NOT NULL DEFAULT 'free', -- 'free' | 'pro'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Usuario pode ler o proprio perfil.
CREATE POLICY "profiles_select_own"
ON profiles FOR SELECT
USING (auth.uid() = user_id);

-- Usuario pode criar o proprio perfil.
CREATE POLICY "profiles_insert_own"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Usuario pode atualizar o proprio perfil (ex.: onboarding_completed).
CREATE POLICY "profiles_update_own"
ON profiles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- SEGURANCA DE RECEITA: impede que o cliente altere subscription_status.
-- Apenas o service_role (backend / webhook Stripe) pode promover para 'pro'.
-- Um UPDATE vindo do app com novo subscription_status e silenciosamente
-- revertido ao valor anterior.
CREATE OR REPLACE FUNCTION protect_subscription_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.subscription_status IS DISTINCT FROM OLD.subscription_status THEN
        IF current_setting('request.jwt.claim.role', true) <> 'service_role' THEN
            NEW.subscription_status := OLD.subscription_status;
        END IF;
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_subscription ON profiles;
CREATE TRIGGER trg_protect_subscription
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION protect_subscription_status();

-- Cria automaticamente uma linha em `profiles` quando um usuario se registra,
-- evitando o estado "sem perfil" que quebrava o FutureBuilder do launch.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (user_id) VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();
