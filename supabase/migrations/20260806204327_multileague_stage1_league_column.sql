
-- STAGE 1 of the multi-league retrofit: additive only.
-- Adds a league dimension everywhere, defaulted to USA-MLS, so nothing behaves
-- differently today. Partitioning of the percentile layers comes in stage 2.

alter table public.events     add column if not exists league text not null default 'USA-MLS';
alter table public.matches     add column if not exists league text not null default 'USA-MLS';
alter table public.lineups     add column if not exists league text not null default 'USA-MLS';
alter table public.players     add column if not exists league text;
alter table public.sequences    add column if not exists league text not null default 'USA-MLS';
alter table public.team_names   add column if not exists league text not null default 'USA-MLS';
alter table public.player_chain_roles add column if not exists league text not null default 'USA-MLS';

-- matches already carries `competition`; keep them consistent for existing rows
update public.matches set league = coalesce(competition, 'USA-MLS') where league = 'USA-MLS';

create index if not exists events_league_idx    on public.events (league);
create index if not exists matches_league_idx   on public.matches (league);
create index if not exists sequences_league_idx on public.sequences (league);
create index if not exists lineups_league_idx   on public.lineups (league);
create index if not exists pcr_league_idx       on public.player_chain_roles (league);

-- team_names is the contamination guard; a team is unique WITHIN a league, not globally
create unique index if not exists team_names_league_event_uidx
  on public.team_names (league, event_name);

-- registry of leagues carried by the platform
create table if not exists public.leagues (
  league text primary key,
  display_name text not null,
  country text,
  tier int default 1,
  ws_name text,
  season text,
  is_active boolean default true,
  added_at timestamptz default now()
);
insert into public.leagues (league, display_name, country, tier, ws_name, season)
values ('USA-MLS','Major League Soccer','USA',1,'USA - Major League Soccer','2627')
on conflict (league) do nothing;
alter table public.leagues enable row level security;
drop policy if exists public_read on public.leagues;
create policy public_read on public.leagues for select using (true);
grant select on public.leagues to anon, authenticated;
