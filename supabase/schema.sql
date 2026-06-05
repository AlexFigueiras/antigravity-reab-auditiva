-- ============================================================================
-- BOSYN — Schema do banco (Supabase / PostgreSQL)
-- ============================================================================
-- Cria todas as tabelas que o app espera, com Row Level Security (RLS) por
-- user_id — exatamente como o código Dart assume (ver SupabaseService).
--
-- COMO APLICAR:
--   1. Abra o painel do Supabase do projeto.
--   2. Vá em "SQL Editor" -> "New query".
--   3. Cole TODO este arquivo e clique em "Run".
-- É idempotente: pode rodar de novo sem quebrar (usa IF NOT EXISTS / OR REPLACE).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- profiles: 1 linha por usuário. Guarda assinatura e respostas do onboarding.
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  user_id              uuid primary key references auth.users (id) on delete cascade,
  subscription_status  text        not null default 'free',
  onboarding_completed boolean     not null default false,
  age_range            text,
  main_difficulty      text,
  uses_hearing_aid     boolean,
  created_at           timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- audiograms: resultado do teste de audição. left_ear/right_ear são arrays de
-- pontos {frequency, threshold, conduction, masked} em JSONB.
-- ----------------------------------------------------------------------------
create table if not exists public.audiograms (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  patient_id  text        not null default 'local',
  left_ear    jsonb       not null default '[]'::jsonb,
  right_ear   jsonb       not null default '[]'::jsonb,
  notes       text,
  created_at  timestamptz not null default now()
);
create index if not exists audiograms_user_created_idx
  on public.audiograms (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- rehab_sessions: uma linha por sessão de treino concluída.
-- ----------------------------------------------------------------------------
create table if not exists public.rehab_sessions (
  id                   uuid        primary key default gen_random_uuid(),
  user_id              uuid        not null references auth.users (id) on delete cascade,
  patient_id           text        not null default 'local',
  date                 timestamptz not null default now(),
  level                int         not null,
  total_trials         int         not null default 0,
  correct_answers      int         not null default 0,
  avg_response_time_ms double precision not null default 0,
  accuracy             double precision not null default 0,
  metadata             jsonb,
  created_at           timestamptz not null default now()
);
create index if not exists rehab_sessions_user_date_idx
  on public.rehab_sessions (user_id, date asc);

-- ----------------------------------------------------------------------------
-- stimulus_results: telemetria granular por estímulo (resposta a resposta).
-- ----------------------------------------------------------------------------
create table if not exists public.stimulus_results (
  id                    uuid        primary key default gen_random_uuid(),
  user_id               uuid        not null references auth.users (id) on delete cascade,
  session_id            text        not null,
  phoneme               text,
  target_panning        double precision,
  selected_panning      double precision,
  angular_error         double precision,
  is_correct            boolean,
  reaction_time_ms      double precision,
  hardware_timestamp_ns bigint,
  output_hardware       text,
  device_name           text,
  created_at            timestamptz not null default now()
);
create index if not exists stimulus_results_user_created_idx
  on public.stimulus_results (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- self_perception: autopercepção semanal (escala 1-5).
-- ----------------------------------------------------------------------------
create table if not exists public.self_perception (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users (id) on delete cascade,
  score      int         not null check (score between 1 and 5),
  created_at timestamptz not null default now()
);
create index if not exists self_perception_user_created_idx
  on public.self_perception (user_id, created_at desc);

-- ============================================================================
-- Row Level Security: cada usuário só enxerga e altera as próprias linhas.
-- ============================================================================
alter table public.profiles         enable row level security;
alter table public.audiograms       enable row level security;
alter table public.rehab_sessions   enable row level security;
alter table public.stimulus_results enable row level security;
alter table public.self_perception  enable row level security;

-- profiles: o usuário lê/edita/cria a própria linha. NÃO pode mudar a própria
-- assinatura por aqui (isso fica para o webhook do Stripe com service_role,
-- que ignora RLS) — mas para simplificar o MVP, permitimos update do próprio
-- registro; a coluna subscription_status nasce 'free'.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Macro para as demais tabelas: select/insert/update/delete só do dono.
-- (Repetido explicitamente por tabela — Postgres não tem template de policy.)

-- audiograms
drop policy if exists "audiograms_all_own" on public.audiograms;
create policy "audiograms_all_own" on public.audiograms
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- rehab_sessions
drop policy if exists "rehab_sessions_all_own" on public.rehab_sessions;
create policy "rehab_sessions_all_own" on public.rehab_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- stimulus_results
drop policy if exists "stimulus_results_all_own" on public.stimulus_results;
create policy "stimulus_results_all_own" on public.stimulus_results
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- self_perception
drop policy if exists "self_perception_all_own" on public.self_perception;
create policy "self_perception_all_own" on public.self_perception
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
-- Trigger: cria automaticamente a linha em profiles quando um usuário se
-- registra. Rede de segurança caso o app não crie o profile no signup.
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (user_id, subscription_status, created_at)
  values (new.id, 'free', now())
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- outcome_tests: resultado do teste de desfecho independente (Matrix)
-- ----------------------------------------------------------------------------
create table if not exists public.outcome_tests (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  date            timestamptz not null default now(),
  srt_db          double precision not null,
  total_trials    int         not null default 0,
  correct_answers int         not null default 0,
  metadata        jsonb,
  created_at      timestamptz not null default now()
);
create index if not exists outcome_tests_user_created_idx
  on public.outcome_tests (user_id, created_at desc);

alter table public.outcome_tests enable row level security;

drop policy if exists "outcome_tests_all_own" on public.outcome_tests;
create policy "outcome_tests_all_own" on public.outcome_tests
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
