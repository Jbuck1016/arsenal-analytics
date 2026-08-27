
-- ============ CORE TABLES ============

create table public.matches (
  game_id     text primary key,
  season      text,
  competition text,
  date        date,
  home_team   text,
  away_team   text,
  home_score  integer,
  away_score  integer,
  matchday    integer,
  venue       text
);

create table public.players (
  player_id   text primary key,
  player_name text,
  team        text
);

-- lineups: loader clears + reinserts per game_id (no natural unique key)
create table public.lineups (
  id           bigint generated always as identity primary key,
  game_id      text,
  player_id    text,
  team         text,
  is_starter   boolean,
  position     text,
  shirt_number integer
);

-- events: loader upserts on_conflict (game_id, ws_id)
create table public.events (
  id              bigint generated always as identity primary key,
  game_id         text,
  ws_id           bigint,
  event_id        bigint,
  period          integer,
  minute          integer,
  second          integer,
  expanded_minute integer,
  team_id         text,
  team            text,
  player_id       text,
  player          text,
  type            text,
  outcome_type    text,
  x               double precision,
  y               double precision,
  end_x           double precision,
  end_y           double precision,
  is_touch        boolean default false,
  is_shot         boolean default false,
  is_goal         boolean default false,
  card_type       text,
  qualifiers      jsonb,
  constraint events_game_wsid_key unique (game_id, ws_id)
);

-- ============ INDEXES (match frontend query patterns) ============
create index idx_matches_home_team   on public.matches (home_team);
create index idx_matches_away_team   on public.matches (away_team);
create index idx_matches_competition on public.matches (competition);
create index idx_lineups_game_id     on public.lineups (game_id);
create index idx_events_game_id      on public.events (game_id);
create index idx_events_type         on public.events (type);
create index idx_events_team         on public.events (team);

-- ============ RLS: public read-only ============
-- Writes happen via the service_role key in the pipeline, which bypasses RLS.
-- The frontend uses the anon key, which is limited to SELECT only.
alter table public.matches enable row level security;
alter table public.players enable row level security;
alter table public.lineups enable row level security;
alter table public.events  enable row level security;

create policy "public read matches" on public.matches for select to anon, authenticated using (true);
create policy "public read players" on public.players for select to anon, authenticated using (true);
create policy "public read lineups" on public.lineups for select to anon, authenticated using (true);
create policy "public read events"  on public.events  for select to anon, authenticated using (true);
