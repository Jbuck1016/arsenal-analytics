
-- Leagues Cup lives in its own tables so no existing MLS analytic can see it.
-- Schema mirrors the MLS tables exactly, so the sequence/chain-role functions
-- can be pointed at these later with no structural work.

create table if not exists public.matches_cup (
  game_id text primary key, season text, competition text, date date,
  home_team text, away_team text, home_score integer, away_score integer,
  matchday integer, venue text, stage text
);

create table if not exists public.lineups_cup (
  id bigint generated always as identity primary key,
  game_id text, player_id text, team text, is_starter boolean, position text, shirt_number integer
);
create index if not exists lineups_cup_game_idx on public.lineups_cup (game_id);

create table if not exists public.events_cup (
  id bigint generated always as identity primary key,
  game_id text, ws_id bigint, event_id bigint, period integer, minute integer, second integer,
  expanded_minute integer, team_id text, team text, player_id text, player text,
  type text, outcome_type text, x double precision, y double precision,
  end_x double precision, end_y double precision,
  is_touch boolean default false, is_shot boolean default false, is_goal boolean default false,
  card_type text, qualifiers jsonb, is_open_play boolean not null default true,
  unique (game_id, ws_id)
);
create index if not exists events_cup_game_idx on public.events_cup (game_id);
create index if not exists events_cup_team_idx on public.events_cup (team);

-- cup club whitelist: 18 MLS + 18 Liga MX, same reconciliation shape as team_names
create table if not exists public.team_names_cup (
  event_name text, match_name text, display_name text, league text
);

alter table public.matches_cup     enable row level security;
alter table public.lineups_cup     enable row level security;
alter table public.events_cup      enable row level security;
alter table public.team_names_cup  enable row level security;
do $$ declare t text;
begin
  foreach t in array array['matches_cup','lineups_cup','events_cup','team_names_cup'] loop
    execute format('drop policy if exists public_read on public.%I', t);
    execute format('create policy public_read on public.%I for select using (true)', t);
  end loop;
end $$;

grant select on public.matches_cup, public.lineups_cup, public.events_cup, public.team_names_cup
  to anon, authenticated;
