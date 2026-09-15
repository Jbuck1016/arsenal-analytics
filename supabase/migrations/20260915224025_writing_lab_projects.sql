begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.writing_lab_projects (
  id uuid primary key default gen_random_uuid(),
  owner_key_hash text not null,
  whoscored_url text not null,
  game_id text,
  competition text not null default 'ENG-League Cup',
  season text not null default '2627',
  home_team text,
  away_team text,
  home_score integer,
  away_score integer,
  match_date date,
  scrape_status text not null default 'queued'
    check (scrape_status in ('queued','scraping','ready','error')),
  workflow_status text not null default 'working'
    check (workflow_status in ('working','draft_complete','published','archived')),
  scrape_error text,
  editorial_brief text not null default '',
  article_draft text not null default '',
  workspace_notes text not null default '',
  evidence_notes jsonb not null default '{}'::jsonb,
  selected_evidence jsonb not null default '[]'::jsonb,
  article_url text,
  published_at timestamptz,
  ingested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists writing_lab_projects_owner_updated_idx
  on public.writing_lab_projects (owner_key_hash, updated_at desc);
create index if not exists writing_lab_projects_queue_idx
  on public.writing_lab_projects (scrape_status, created_at)
  where scrape_status in ('queued','scraping');

alter table public.writing_lab_projects enable row level security;

revoke all on table public.writing_lab_projects from public, anon, authenticated;
grant select, insert, update on table public.writing_lab_projects to anon, authenticated;

drop policy if exists "writing lab browser reads own workspaces" on public.writing_lab_projects;
create policy "writing lab browser reads own workspaces"
on public.writing_lab_projects for select
to anon, authenticated
using (
  length(coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
);

drop policy if exists "writing lab browser creates own workspaces" on public.writing_lab_projects;
create policy "writing lab browser creates own workspaces"
on public.writing_lab_projects for insert
to anon, authenticated
with check (
  length(coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
  and whoscored_url ~* '^https://(www\.)?whoscored\.com/matches/[0-9]+'
);

drop policy if exists "writing lab browser updates own workspaces" on public.writing_lab_projects;
create policy "writing lab browser updates own workspaces"
on public.writing_lab_projects for update
to anon, authenticated
using (
  length(coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
)
with check (
  length(coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
);

comment on table public.writing_lab_projects is
  'Private editorial workspaces. Browser access is scoped by an unguessable local workspace key; the service-role ingestion worker processes queued WhoScored URLs.';

commit;
