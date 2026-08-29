-- ============================================================
-- Manual DF · Sistema de usuarios (Supabase)
--
-- Pegar TODO este archivo en el SQL Editor de tu proyecto de
-- Supabase (Project > SQL Editor > New query) y ejecutarlo una
-- sola vez. Es seguro correrlo de nuevo (usa "if not exists").
--
-- Diseño genérico por "manual_area" a propósito: hoy solo existe
-- 'fotografia', pero el día que sumes Dirección y Guión no hace
-- falta tocar el esquema, solo empiezan a aparecer filas nuevas
-- con otro valor en esa columna.
-- ============================================================

-- Progreso de lectura: qué capítulos abrió cada usuario.
create table if not exists public.reading_progress (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  manual_area text not null default 'fotografia',
  chapter_id text not null,
  read_at timestamptz not null default now(),
  unique (user_id, manual_area, chapter_id)
);

-- Historial de charlas con LauChat AI, por usuario (para que se
-- sincronice entre dispositivos en vez de vivir solo en localStorage).
create table if not exists public.chat_messages (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  manual_area text not null default 'fotografia',
  question text not null,
  answer text not null,
  created_at timestamptz not null default now()
);

-- Feedback (👍/👎) ligado a qué usuario lo dejó, además del log
-- anónimo que ya se guarda en Cloudflare KV.
create table if not exists public.chat_feedback (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  manual_area text not null default 'fotografia',
  question text not null,
  answer text not null,
  rating text not null check (rating in ('up','down')),
  created_at timestamptz not null default now()
);

-- Row Level Security: cada usuario solo puede leer y escribir SUS
-- propias filas. Esto se cumple a nivel de base de datos, no depende
-- de que el JS del front nunca tenga un bug.
alter table public.reading_progress enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_feedback enable row level security;

create policy "select own reading_progress" on public.reading_progress
  for select using (auth.uid() = user_id);
create policy "insert own reading_progress" on public.reading_progress
  for insert with check (auth.uid() = user_id);
create policy "update own reading_progress" on public.reading_progress
  for update using (auth.uid() = user_id);
create policy "delete own reading_progress" on public.reading_progress
  for delete using (auth.uid() = user_id);

create policy "select own chat_messages" on public.chat_messages
  for select using (auth.uid() = user_id);
create policy "insert own chat_messages" on public.chat_messages
  for insert with check (auth.uid() = user_id);

create policy "select own chat_feedback" on public.chat_feedback
  for select using (auth.uid() = user_id);
create policy "insert own chat_feedback" on public.chat_feedback
  for insert with check (auth.uid() = user_id);

-- Índices para las consultas de analítica que vas a querer hacer
-- vos mismo más adelante (retención, usuarios habituales, etc.)
create index if not exists idx_reading_progress_user on public.reading_progress(user_id);
create index if not exists idx_chat_messages_user on public.chat_messages(user_id);
create index if not exists idx_chat_messages_created on public.chat_messages(created_at);
create index if not exists idx_chat_feedback_user on public.chat_feedback(user_id);

-- ============================================================
-- user_notes — notas ancladas a un fragmento de texto exacto (estilo
-- "resaltar y anotar"). El anclaje se guarda como el texto citado
-- (quote), no como un rango del DOM: así una nota sigue siendo válida
-- aunque el capítulo se edite después, mientras esa frase exacta no
-- se borre. Si en el futuro el texto cambia y la cita ya no aparece,
-- el front simplemente no la resalta (pero la nota no se pierde).
-- ============================================================
create table if not exists public.user_notes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  manual_area text not null default 'fotografia',
  chapter_id text not null,
  quote text not null,
  note text not null,
  created_at timestamptz not null default now()
);

alter table public.user_notes enable row level security;

create policy "select own user_notes" on public.user_notes
  for select using (auth.uid() = user_id);
create policy "insert own user_notes" on public.user_notes
  for insert with check (auth.uid() = user_id);
create policy "update own user_notes" on public.user_notes
  for update using (auth.uid() = user_id);
create policy "delete own user_notes" on public.user_notes
  for delete using (auth.uid() = user_id);

create index if not exists idx_user_notes_user on public.user_notes(user_id);
create index if not exists idx_user_notes_chapter on public.user_notes(user_id, manual_area, chapter_id);
