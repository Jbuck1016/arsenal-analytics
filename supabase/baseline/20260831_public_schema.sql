-- === preamble ===
-- Canonical production-schema baseline, generated from PostgreSQL catalogs.
begin;
do $roles$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
  if not exists(select 1 from pg_roles where rolname='supabase_admin') then create role supabase_admin nologin; end if;
end $roles$;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm;
create extension if not exists unaccent;
do $optional_extensions$ begin
  if exists(select 1 from pg_available_extensions where name='pg_cron') then
    execute 'create extension if not exists pg_cron with schema extensions';
  end if;
end $optional_extensions$;

-- === tables ===
create table public._ml_baseline (
  src text,
  k1 text,
  k2 text,
  val numeric
);
create table public._replay_log (
  ver text,
  stmt_no integer,
  sqlstate text,
  msg text,
  ts timestamp with time zone default now()
);
create table public.analytics_publication_probe (
  singleton boolean default true not null,
  value bigint default 0 not null
);

-- === rls ===
alter table public.analytics_publication_probe enable row level security;

-- === tables ===
create table public.analytics_rebuild_runs (
  run_id uuid not null,
  status text not null,
  requested_league text,
  current_step text,
  messages jsonb default '[]'::jsonb not null,
  error_message text,
  created_at timestamp with time zone default now() not null,
  started_at timestamp with time zone,
  finished_at timestamp with time zone
);

-- === rls ===
alter table public.analytics_rebuild_runs enable row level security;

-- === tables ===
create table public.detector_priority (
  detector text not null,
  band integer not null,
  note text
);
create table public.detector_requirements (
  detector text not null,
  min_matches integer default 6 not null,
  requirement text not null,
  rationale text,
  min_denominator integer,
  denominator_label text
);
create table public.events (
  id bigint generated always as identity not null,
  game_id text,
  ws_id bigint,
  event_id bigint,
  period integer,
  minute integer,
  second integer,
  expanded_minute integer,
  team_id text,
  team text,
  player_id text,
  player text,
  type text,
  outcome_type text,
  x double precision,
  y double precision,
  end_x double precision,
  end_y double precision,
  is_touch boolean default false,
  is_shot boolean default false,
  is_goal boolean default false,
  card_type text,
  qualifiers jsonb,
  is_open_play boolean default true not null,
  league text default 'USA-MLS'::text not null
);

-- === rls ===
alter table public.events enable row level security;

-- === tables ===
create table public.events_cup (
  id bigint generated always as identity not null,
  game_id text,
  ws_id bigint,
  event_id bigint,
  period integer,
  minute integer,
  second integer,
  expanded_minute integer,
  team_id text,
  team text,
  player_id text,
  player text,
  type text,
  outcome_type text,
  x double precision,
  y double precision,
  end_x double precision,
  end_y double precision,
  is_touch boolean default false,
  is_shot boolean default false,
  is_goal boolean default false,
  card_type text,
  qualifiers jsonb,
  is_open_play boolean default true not null
);

-- === rls ===
alter table public.events_cup enable row level security;

-- === tables ===
create table public.insights (
  id bigint generated always as identity not null,
  lens text not null,
  category text not null,
  scope text not null,
  subject text not null,
  subject_label text,
  team text,
  detector text not null,
  headline text not null,
  detail text,
  metrics jsonb,
  evidence jsonb,
  score numeric,
  confidence text,
  generated_at timestamp with time zone default now(),
  note text
);
create table public.invariants (
  name text not null,
  description text not null,
  check_sql text not null,
  severity text default 'error'::text not null,
  enabled boolean default true not null
);
create table public.lafc_events (
  id uuid default gen_random_uuid() not null,
  kind text not null,
  title text not null,
  starts_at timestamp with time zone not null,
  ends_at timestamp with time zone,
  all_day boolean default false not null,
  location text default ''::text,
  link text default ''::text,
  competition text default ''::text,
  home boolean,
  source_id text,
  synced_at timestamp with time zone default now() not null
);

-- === rls ===
alter table public.lafc_events enable row level security;

-- === tables ===
create table public.lafc_links (
  id uuid default gen_random_uuid() not null,
  label text not null,
  url text default ''::text,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- === rls ===
alter table public.lafc_links enable row level security;

-- === tables ===
create table public.lafc_projects (
  id uuid default gen_random_uuid() not null,
  name text not null,
  status text default 'In progress'::text not null,
  priority text default 'Medium'::text not null,
  next_action text default ''::text,
  notes text default ''::text,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  due_date date,
  category text default ''::text not null,
  subtasks jsonb default '[]'::jsonb not null
);

-- === rls ===
alter table public.lafc_projects enable row level security;

-- === tables ===
create table public.lafc_todos (
  id uuid default gen_random_uuid() not null,
  text text not null,
  done boolean default false not null,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  completed_at timestamp with time zone
);

-- === rls ===
alter table public.lafc_todos enable row level security;

-- === tables ===
create table public.lafc_tracker_config (
  id integer default 1 not null,
  secret_hash text not null
);

-- === rls ===
alter table public.lafc_tracker_config enable row level security;

-- === tables ===
create table public.league_mart_entry_objects (
  object_name text not null,
  note text
);
create table public.leagues (
  league text not null,
  display_name text not null,
  country text,
  tier integer default 1,
  ws_name text,
  season text,
  is_active boolean default true,
  added_at timestamp with time zone default now(),
  expected_teams integer,
  competition_type text default 'league'::text not null
);

-- === rls ===
alter table public.leagues enable row level security;

-- === tables ===
create table public.lineups (
  id bigint generated always as identity not null,
  game_id text,
  player_id text,
  team text,
  is_starter boolean,
  "position" text,
  shirt_number integer,
  league text default 'USA-MLS'::text not null
);

-- === rls ===
alter table public.lineups enable row level security;

-- === tables ===
create table public.lineups_cup (
  id bigint generated always as identity not null,
  game_id text,
  player_id text,
  team text,
  is_starter boolean,
  "position" text,
  shirt_number integer
);

-- === rls ===
alter table public.lineups_cup enable row level security;

-- === tables ===
create table public.matches (
  game_id text not null,
  season text,
  competition text,
  date date,
  home_team text,
  away_team text,
  home_score integer,
  away_score integer,
  matchday integer,
  venue text,
  league text default 'USA-MLS'::text not null
);

-- === rls ===
alter table public.matches enable row level security;

-- === tables ===
create table public.matches_cup (
  game_id text not null,
  season text,
  competition text,
  date date,
  home_team text,
  away_team text,
  home_score integer,
  away_score integer,
  matchday integer,
  venue text,
  stage text
);

-- === rls ===
alter table public.matches_cup enable row level security;

-- === tables ===
create table public.metric_catalog (
  metric text not null,
  label text not null,
  grp text not null,
  higher_better boolean default true not null,
  unit text
);
create table public.metric_defs (
  key text not null,
  label text not null,
  grp text not null,
  unit text,
  higher_is_better boolean default true not null,
  definition text,
  sort_order integer,
  grp_order integer,
  calc text
);
create table public.metric_synonyms (
  phrase text not null,
  metric text,
  grp text,
  weight integer default 1,
  rank_metric text
);
create table public.pillar_defs (
  pillar text not null,
  metric text not null,
  weight numeric default 1 not null,
  ord integer,
  kind text default 'quality'::text not null
);
create table public.player_bio (
  player_id text not null,
  age_seen integer,
  age_seen_date date,
  height_cm integer,
  weight_kg integer,
  nationality text,
  foot text,
  updated_at timestamp with time zone default now()
);

-- === rls ===
alter table public.player_bio enable row level security;

-- === tables ===
create table public.player_chain_roles (
  player_id text not null,
  player text,
  team text,
  pos text,
  inv integer,
  player_xt numeric,
  hold_secs numeric,
  initiator numeric,
  bridge numeric,
  progressor numeric,
  carrier numeric,
  vertical numeric,
  support_angle numeric,
  individual numeric,
  creator numeric,
  box_threat numeric,
  finisher numeric,
  league text default 'USA-MLS'::text not null
);
create table public.players (
  player_id text not null,
  player_name text,
  team text,
  league text
);

-- === rls ===
alter table public.players enable row level security;

-- === tables ===
create table public.pool_metric_relevance (
  pool text not null,
  grp text not null
);
create table public.role_pillar_weights (
  pool text not null,
  pillar text not null,
  weight numeric default 0 not null
);
create table public.sequences (
  seq_uid text not null,
  game_id text not null,
  seq_no integer not null,
  team_id text,
  team text,
  period integer,
  start_min integer,
  start_sec integer,
  dur_s integer,
  n_events integer,
  n_pass integer,
  n_players integer,
  start_x double precision,
  start_y double precision,
  end_x double precision,
  end_y double precision,
  start_third text,
  end_third text,
  ended_in_box boolean,
  ended_shot boolean,
  ended_goal boolean,
  started_setpiece boolean,
  is_open_play boolean,
  xt_sum numeric,
  mean_pass_len numeric,
  low_build boolean,
  high_build boolean,
  structured boolean,
  has_switch boolean,
  wide_triangles boolean,
  hold_up boolean,
  very_short boolean,
  long_ball boolean,
  ends_opp_half boolean,
  end_around_box boolean,
  finds_central boolean,
  finds_wide boolean,
  n_wide_pass integer,
  n_prog integer,
  n_prog_central integer,
  n_prog_wide integer,
  path jsonb,
  cx numeric,
  cy numeric,
  minx numeric,
  maxx numeric,
  miny numeric,
  maxy numeric,
  att_share numeric,
  league text default 'USA-MLS'::text not null
);
create table public.team_metric_defs (
  key text not null,
  label text not null,
  grp text not null,
  unit text,
  higher_is_better boolean default true not null,
  definition text,
  grp_order integer,
  sort_order integer
);
create table public.team_names (
  event_name text not null,
  match_name text not null,
  display_name text not null,
  league text default 'USA-MLS'::text not null
);
create table public.team_names_cup (
  event_name text,
  match_name text,
  display_name text,
  league text
);

-- === rls ===
alter table public.team_names_cup enable row level security;

-- === tables ===
create table public.xt_grid (
  x_bin integer not null,
  y_bin integer not null,
  v numeric not null
);

-- === constraints ===
alter table analytics_publication_probe add constraint analytics_publication_probe_pkey PRIMARY KEY (singleton);
alter table analytics_publication_probe add constraint analytics_publication_probe_singleton_check CHECK (singleton);
alter table analytics_rebuild_runs add constraint analytics_rebuild_runs_pkey PRIMARY KEY (run_id);
alter table analytics_rebuild_runs add constraint analytics_rebuild_runs_status_check CHECK (status = ANY (ARRAY['pending'::text, 'running'::text, 'complete'::text, 'failed'::text]));
alter table detector_priority add constraint detector_priority_pkey PRIMARY KEY (detector);
alter table detector_requirements add constraint detector_requirements_pkey PRIMARY KEY (detector);
alter table events add constraint events_game_wsid_key UNIQUE (game_id, ws_id);
alter table events add constraint events_pkey PRIMARY KEY (id);
alter table events_cup add constraint events_cup_game_id_ws_id_key UNIQUE (game_id, ws_id);
alter table events_cup add constraint events_cup_pkey PRIMARY KEY (id);
alter table insights add constraint insights_pkey PRIMARY KEY (id);
alter table invariants add constraint invariants_pkey PRIMARY KEY (name);
alter table invariants add constraint invariants_severity_check CHECK (severity = ANY (ARRAY['error'::text, 'warn'::text]));
alter table lafc_events add constraint lafc_events_kind_check CHECK (kind = ANY (ARRAY['fixture'::text, 'meeting'::text]));
alter table lafc_events add constraint lafc_events_pkey PRIMARY KEY (id);
alter table lafc_links add constraint lafc_links_pkey PRIMARY KEY (id);
alter table lafc_projects add constraint lafc_projects_pkey PRIMARY KEY (id);
alter table lafc_todos add constraint lafc_todos_pkey PRIMARY KEY (id);
alter table lafc_tracker_config add constraint lafc_tracker_config_pkey PRIMARY KEY (id);
alter table lafc_tracker_config add constraint one_row CHECK (id = 1);
alter table league_mart_entry_objects add constraint league_mart_entry_objects_pkey PRIMARY KEY (object_name);
alter table leagues add constraint leagues_competition_type_chk CHECK (competition_type = ANY (ARRAY['league'::text, 'domestic_cup'::text, 'continental'::text]));
alter table leagues add constraint leagues_pkey PRIMARY KEY (league);
alter table lineups add constraint lineups_pkey PRIMARY KEY (id);
alter table lineups_cup add constraint lineups_cup_pkey PRIMARY KEY (id);
alter table matches add constraint matches_pkey PRIMARY KEY (game_id);
alter table matches_cup add constraint matches_cup_pkey PRIMARY KEY (game_id);
alter table metric_catalog add constraint metric_defs_pkey PRIMARY KEY (metric);
alter table metric_defs add constraint metric_defs_pkey1 PRIMARY KEY (key);
alter table metric_synonyms add constraint metric_synonyms_pkey PRIMARY KEY (phrase);
alter table pillar_defs add constraint pillar_defs_pkey PRIMARY KEY (pillar, metric);
alter table player_bio add constraint player_bio_pkey PRIMARY KEY (player_id);
alter table player_chain_roles add constraint player_chain_roles_pkey PRIMARY KEY (player_id);
alter table players add constraint players_pkey PRIMARY KEY (player_id);
alter table pool_metric_relevance add constraint pool_metric_relevance_pkey PRIMARY KEY (pool, grp);
alter table role_pillar_weights add constraint role_pillar_weights_pkey PRIMARY KEY (pool, pillar);
alter table sequences add constraint sequences_pkey PRIMARY KEY (seq_uid);
alter table team_metric_defs add constraint team_metric_defs_pkey PRIMARY KEY (key);
alter table team_names add constraint team_names_pkey PRIMARY KEY (league, event_name);
alter table xt_grid add constraint xt_grid_pkey PRIMARY KEY (x_bin, y_bin);

-- === function_stubs ===
create function public.analytics_rebuild_run_status(p_run_id uuid) returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.build_insights() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.build_insights_extra() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.build_insights_players() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.build_player_chain_roles() returns void language plpgsql as $stub$ begin return; end $stub$;
create function public.build_press_insights() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.build_reactivity_insights() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.build_sequences() returns void language plpgsql as $stub$ begin return; end $stub$;
create function public.build_team_profile_insights() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.comparison_scopes() returns TABLE(league text, display_name text, players integer) language plpgsql as $stub$ begin return; end $stub$;
create function public.create_analytics_rebuild_run(p_run_id uuid, p_league text DEFAULT NULL::text) returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.detector_min_denominator(p_detector text) returns integer language plpgsql as $stub$ begin return null; end $stub$;
create function public.detector_min_matches(p_detector text) returns integer language plpgsql as $stub$ begin return null; end $stub$;
create function public.get_starter_names(p_game_id text) returns TABLE(player_name text, player_pos text) language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_events_list(p_secret text) returns SETOF lafc_events language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_links_delete(p_secret text, p_id uuid) returns void language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_links_list(p_secret text) returns SETOF lafc_links language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_links_save(p_secret text, p_id uuid, p_label text, p_url text, p_sort integer) returns lafc_links language plpgsql as $stub$ begin return null; end $stub$;
create function public.lafc_projects_delete(p_secret text, p_id uuid) returns void language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_projects_list(p_secret text) returns SETOF lafc_projects language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_projects_save(p_secret text, p_id uuid, p_name text, p_status text, p_priority text, p_next_action text, p_notes text, p_sort_order integer, p_due_date date, p_category text, p_subtasks jsonb) returns lafc_projects language plpgsql as $stub$ begin return null; end $stub$;
create function public.lafc_projects_touch() returns trigger language plpgsql as $stub$ begin return new; end $stub$;
create function public.lafc_todos_clear_done(p_secret text) returns void language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_todos_delete(p_secret text, p_id uuid) returns void language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_todos_list(p_secret text) returns SETOF lafc_todos language plpgsql as $stub$ begin return; end $stub$;
create function public.lafc_todos_save(p_secret text, p_id uuid, p_text text, p_done boolean, p_sort integer) returns lafc_todos language plpgsql as $stub$ begin return null; end $stub$;
create function public.lafc_tracker_auth(p_secret text) returns boolean language plpgsql as $stub$ begin return null; end $stub$;
create function public.nl_query(q text, p_limit integer DEFAULT 10) returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.player_card(p_id text) returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.player_card_scoped(p_id text, p_leagues text[] DEFAULT NULL::text[]) returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.player_metric_events(p_id text, p_metric text, p_limit integer DEFAULT 800) returns TABLE(kind text, x double precision, y double precision, end_x double precision, end_y double precision, value numeric, outcome text, game_id text) language plpgsql as $stub$ begin return; end $stub$;
create function public.player_pct_scoped(p_id text, p_leagues text[] DEFAULT NULL::text[], p_metrics text[] DEFAULT NULL::text[]) returns TABLE(metric text, label text, grp text, unit text, raw numeric, pct integer, higher_better boolean, pool text, n_in_scope integer, scope text) language plpgsql as $stub$ begin return; end $stub$;
create function public.player_xt_map(p_id text, p_kind text DEFAULT 'all'::text, p_positive_only boolean DEFAULT false, p_limit integer DEFAULT 500) returns TABLE(kind text, x double precision, y double precision, end_x double precision, end_y double precision, xt numeric, game_id text, minute integer) language plpgsql as $stub$ begin return; end $stub$;
create function public.polish_insights() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.preflight_league(p_league text DEFAULT NULL::text) returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.pretty_metric(p text) returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.process_analytics_rebuild_queue() returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.rebuild_all() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.rebuild_all_verified(p_run_id uuid, p_league text DEFAULT NULL::text, p_fail_after_step text DEFAULT NULL::text) returns jsonb language plpgsql as $stub$ begin return null; end $stub$;
create function public.rebuild_step(p_step text, p_league text DEFAULT NULL::text) returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.rebuild_team_names(p_league text) returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.refresh_analytics() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.refresh_analytics_batch(p_batch integer) returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.refresh_site_summaries() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.resolve_player(p_name text) returns TABLE(player_id text, player text, team text, pos text, score real) language plpgsql as $stub$ begin return; end $stub$;
create function public.run_invariants() returns TABLE(name text, severity text, violations bigint, description text, note text) language plpgsql as $stub$ begin return; end $stub$;
create function public.similar_players_chain(p_id text, p_n integer DEFAULT 12) returns TABLE(rank integer, player_id text, player text, team text, pos text, inv integer, player_xt numeric, sim_pct numeric, initiator numeric, hold_secs numeric, bridge numeric, progressor numeric, carrier numeric, vertical numeric, support_angle numeric) language plpgsql as $stub$ begin return; end $stub$;
create function public.similar_players_full(p_id text, p_n integer DEFAULT 8, p_metrics text[] DEFAULT NULL::text[]) returns TABLE(rank integer, player_id text, player text, team text, pos text, sim_pct numeric, shared_metrics integer) language plpgsql as $stub$ begin return; end $stub$;
create function public.similar_sequences(p_seq text, p_n integer DEFAULT 10) returns TABLE(rank integer, seq_uid text, team text, game_id text, n_pass integer, xt_sum numeric, ended_shot boolean, dist numeric) language plpgsql as $stub$ begin return; end $stub$;
create function public.similar_teams(p_team text, p_n integer DEFAULT 5) returns TABLE(rank integer, team text, dist numeric) language plpgsql as $stub$ begin return; end $stub$;
create function public.stamp_sequence_leagues() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.state_weight(p_margin numeric) returns numeric language plpgsql as $stub$ begin return null; end $stub$;
create function public.suppress_low_sample_insights() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.top_sequences_by_type(p_tag text, p_n integer DEFAULT 10) returns SETOF sequences language plpgsql as $stub$ begin return; end $stub$;
create function public.verify_rebuild() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.write_insight_notes() returns text language plpgsql as $stub$ begin return null; end $stub$;
create function public.xt_at(px double precision, py double precision) returns numeric language plpgsql as $stub$ begin return null; end $stub$;
create function public.xt_val(px double precision, py double precision) returns numeric language plpgsql as $stub$ begin return null; end $stub$;

-- === relations ===
create materialized view public.mv_invariant_status as  SELECT name,
    severity,
    violations,
    description,
    now() AS refreshed_at
   FROM run_invariants() run_invariants(name, severity, violations, description, note) with no data;
create view public.v_league_competitions as  SELECT league,
    display_name,
    country,
    tier,
    season,
    is_active,
    expected_teams
   FROM leagues
  WHERE competition_type = 'league'::text;

-- === relation_options ===
alter view public.v_league_competitions set (security_invoker=true);

-- === relations ===
create view public.v_match_season_scope as  SELECT m.game_id,
    m.season,
    m.competition,
    m.date,
    m.home_team,
    m.away_team,
    m.home_score,
    m.away_score,
    m.matchday,
    m.venue,
    m.league,
    l.season AS registered_season,
    l.competition_type,
    l.competition_type = 'league'::text AND m.season = l.season AS is_live_scope
   FROM matches m
     LEFT JOIN leagues l ON l.league = m.league;

-- === relation_options ===
alter view public.v_match_season_scope set (security_invoker=true);

-- === relations ===
create view public.v_league_events as  SELECT e.id,
    e.game_id,
    e.ws_id,
    e.event_id,
    e.period,
    e.minute,
    e.second,
    e.expanded_minute,
    e.team_id,
    e.team,
    e.player_id,
    e.player,
    e.type,
    e.outcome_type,
    e.x,
    e.y,
    e.end_x,
    e.end_y,
    e.is_touch,
    e.is_shot,
    e.is_goal,
    e.card_type,
    e.qualifiers,
    e.is_open_play,
    e.league
   FROM events e
     JOIN v_match_season_scope m ON m.game_id = e.game_id AND m.league = e.league AND m.is_live_scope;

-- === relation_options ===
alter view public.v_league_events set (security_invoker=true);

-- === relations ===
create view public.v_league_lineups as  SELECT li.id,
    li.game_id,
    li.player_id,
    li.team,
    li.is_starter,
    li."position",
    li.shirt_number,
    li.league
   FROM lineups li
     JOIN v_match_season_scope m ON m.game_id = li.game_id AND m.league = li.league AND m.is_live_scope;

-- === relation_options ===
alter view public.v_league_lineups set (security_invoker=true);

-- === relations ===
create view public.v_league_matches as  SELECT game_id,
    season,
    competition,
    date,
    home_team,
    away_team,
    home_score,
    away_score,
    matchday,
    venue,
    league
   FROM v_match_season_scope m
  WHERE is_live_scope;

-- === relation_options ===
alter view public.v_league_matches set (security_invoker=true);

-- === relations ===
create view public.v_league_sequences as  SELECT s.seq_uid,
    s.game_id,
    s.seq_no,
    s.team_id,
    s.team,
    s.period,
    s.start_min,
    s.start_sec,
    s.dur_s,
    s.n_events,
    s.n_pass,
    s.n_players,
    s.start_x,
    s.start_y,
    s.end_x,
    s.end_y,
    s.start_third,
    s.end_third,
    s.ended_in_box,
    s.ended_shot,
    s.ended_goal,
    s.started_setpiece,
    s.is_open_play,
    s.xt_sum,
    s.mean_pass_len,
    s.low_build,
    s.high_build,
    s.structured,
    s.has_switch,
    s.wide_triangles,
    s.hold_up,
    s.very_short,
    s.long_ball,
    s.ends_opp_half,
    s.end_around_box,
    s.finds_central,
    s.finds_wide,
    s.n_wide_pass,
    s.n_prog,
    s.n_prog_central,
    s.n_prog_wide,
    s.path,
    s.cx,
    s.cy,
    s.minx,
    s.maxx,
    s.miny,
    s.maxy,
    s.att_share,
    s.league
   FROM sequences s
     JOIN v_match_season_scope m ON m.game_id = s.game_id AND m.league = s.league AND m.is_live_scope;

-- === relation_options ===
alter view public.v_league_sequences set (security_invoker=true);

-- === relations ===
create materialized view public.mv_event_phase as  WITH seq AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.minute * 60 + events.second AS abs_sec,
                CASE
                    WHEN NOT events.is_open_play AND events.type = 'Pass'::text THEN events.minute * 60 + events.second
                    ELSE NULL::integer
                END AS delivery_sec
           FROM v_league_events events
        ), carried AS (
         SELECT seq.game_id,
            seq.ws_id,
            seq.abs_sec,
            max(seq.delivery_sec) OVER (PARTITION BY seq.game_id, seq.team ORDER BY seq.ws_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS last_delivery
           FROM seq
        )
 SELECT game_id,
    ws_id,
    last_delivery IS NOT NULL AND (abs_sec - last_delivery) >= 0 AND (abs_sec - last_delivery) <= 10 AS set_piece_phase
   FROM carried with no data;
create materialized view public.mv_game_goals as  WITH gteams AS (
         SELECT events.game_id,
            array_agg(DISTINCT events.team) AS tms
           FROM v_league_events events
          WHERE events.team IS NOT NULL
          GROUP BY events.game_id
        ), g AS (
         SELECT e.game_id,
            e.expanded_minute,
            e.second,
            e.team,
                CASE
                    WHEN e.qualifiers IS NULL THEN false
                    ELSE (EXISTS ( SELECT 1
                       FROM jsonb_array_elements(e.qualifiers) q(value)
                      WHERE ((q.value -> 'type'::text) ->> 'displayName'::text) ~~* '%own%'::text))
                END AS is_og
           FROM v_league_events e
          WHERE e.is_goal AND e.period IS DISTINCT FROM 5
        )
 SELECT g.game_id,
    g.expanded_minute,
    g.second,
        CASE
            WHEN g.is_og THEN ( SELECT t.t
               FROM unnest(gt.tms) t(t)
              WHERE t.t <> g.team
             LIMIT 1)
            ELSE g.team
        END AS scoring_team,
    g.is_og
   FROM g
     JOIN gteams gt USING (game_id)
  WHERE NOT g.is_og OR (( SELECT count(*) AS count
           FROM unnest(gt.tms) t(t)
          WHERE t.t <> g.team)) = 1 with no data;
create materialized view public.mv_match_length as  SELECT game_id,
    max(expanded_minute) AS length_min
   FROM v_league_events events
  GROUP BY game_id with no data;
create materialized view public.mv_pass_traj as  WITH p AS (
         SELECT e.id,
            e.game_id,
            e.player_id,
            e.player,
            e.team,
            e.x,
            e.y,
            e.end_x,
            e.end_y,
            e.outcome_type,
            z.aerial,
            z.thru
           FROM v_league_events e
             LEFT JOIN LATERAL ( SELECT COALESCE(bool_or(qq.dn = ANY (ARRAY['Chipped'::text, 'Longball'::text])), false) AS aerial,
                    COALESCE(bool_or(qq.dn = 'Throughball'::text), false) AS thru
                   FROM ( SELECT (q.value -> 'type'::text) ->> 'displayName'::text AS dn
                           FROM jsonb_array_elements(e.qualifiers) q(value)) qq) z ON true
          WHERE e.type = 'Pass'::text AND e.end_x IS NOT NULL AND e.x IS NOT NULL AND (e.end_x - e.x) >= 5::double precision
        )
 SELECT id,
    game_id,
    player_id,
    player,
    team,
    outcome_type = 'Successful'::text AS completed,
        CASE
            WHEN aerial THEN 'over'::text
            WHEN thru OR ((y + end_y) / 2.0::double precision) >= 33.3::double precision AND ((y + end_y) / 2.0::double precision) <= 66.7::double precision AND (end_x - x) >= 12::double precision THEN 'through'::text
            ELSE 'around'::text
        END AS trajectory,
        CASE
            WHEN end_x >= 78::double precision THEN 'in_behind'::text
            WHEN end_y < 21.1::double precision OR end_y > 78.9::double precision THEN 'outside'::text
            ELSE 'inside'::text
        END AS destination
   FROM p with no data;
create materialized view public.mv_player_chains as  WITH seq AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.player_id,
            events.type,
            events.outcome_type,
            events.x,
            events.y,
            events.end_x,
            events.end_y,
            events.minute * 60 + events.second AS abs_sec,
            lead(events.team) OVER w AS n_team,
            lead(events.player_id) OVER w AS n_player,
            lead(events.type) OVER w AS n_type,
            lead(events.outcome_type) OVER w AS n_outcome,
            lead(events.x) OVER w AS n_x,
            lead(events.end_x) OVER w AS n_end_x,
            lead(events.minute * 60 + events.second) OVER w AS n_sec
           FROM v_league_events events
          WHERE events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text])
          WINDOW w AS (PARTITION BY events.game_id ORDER BY events.ws_id)
        ), aer AS (
         SELECT seq.player_id,
            count(*) AS aerials_won,
            count(*) FILTER (WHERE seq.n_player = seq.player_id) AS aq_self,
            count(*) FILTER (WHERE seq.n_team = seq.team AND seq.n_player <> seq.player_id) AS aq_mate,
            count(*) FILTER (WHERE seq.n_team <> seq.team) AS aq_opp
           FROM seq
          WHERE seq.type = 'Aerial'::text AND seq.outcome_type = 'Successful'::text AND seq.n_team IS NOT NULL
          GROUP BY seq.player_id
        ), rec AS (
         SELECT seq.player_id,
            count(*) AS recoveries,
            count(*) FILTER (WHERE seq.n_player = seq.player_id AND seq.n_type = 'Pass'::text AND seq.n_outcome = 'Successful'::text) AS recov_pass_ok,
            count(*) FILTER (WHERE seq.n_player = seq.player_id AND seq.n_type = 'Pass'::text) AS recov_pass_att,
            count(*) FILTER (WHERE seq.n_player = seq.player_id AND seq.n_type = 'Pass'::text AND seq.n_outcome = 'Successful'::text AND seq.n_end_x IS NOT NULL AND seq.n_x IS NOT NULL AND (seq.n_x < 50::double precision AND seq.n_end_x < 50::double precision AND (seq.n_end_x - seq.n_x) >= 30::double precision OR seq.n_x < 50::double precision AND seq.n_end_x >= 50::double precision AND (seq.n_end_x - seq.n_x) >= 15::double precision OR seq.n_x >= 50::double precision AND seq.n_end_x >= 50::double precision AND (seq.n_end_x - seq.n_x) >= 10::double precision)) AS recov_prog_pass
           FROM seq
          WHERE seq.type = 'BallRecovery'::text AND (seq.n_sec - seq.abs_sec) >= 0 AND (seq.n_sec - seq.abs_sec) <= 10
          GROUP BY seq.player_id
        )
 SELECT COALESCE(a.player_id, r.player_id) AS player_id,
    a.aerials_won,
    a.aq_self,
    a.aq_mate,
    a.aq_opp,
        CASE
            WHEN a.aerials_won > 0 THEN round((2.0 * a.aq_self::numeric + a.aq_mate::numeric - a.aq_opp::numeric) / a.aerials_won::numeric, 2)
            ELSE NULL::numeric
        END AS aq_per_duel,
        CASE
            WHEN a.aerials_won >= 10 THEN round(100.0 * (a.aq_self + a.aq_mate)::numeric / a.aerials_won::numeric, 1)
            ELSE NULL::numeric
        END AS duel_quality,
    r.recoveries,
    r.recov_pass_att,
    r.recov_pass_ok,
    r.recov_prog_pass,
        CASE
            WHEN r.recov_pass_att >= 10 THEN round(100.0 * r.recov_pass_ok::numeric / r.recov_pass_att::numeric, 1)
            ELSE NULL::numeric
        END AS recov_retention
   FROM aer a
     FULL JOIN rec r ON r.player_id = a.player_id with no data;
create materialized view public.mv_player_counterpress as  WITH seq AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.player_id,
            events.type,
            events.minute * 60 + events.second AS abs_sec,
            lag(events.team) OVER w AS prev_team,
            lag(events.minute * 60 + events.second) OVER w AS prev_sec,
            lag(events.type) OVER w AS prev_type
           FROM v_league_events events
          WHERE events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text])
          WINDOW w AS (PARTITION BY events.game_id ORDER BY events.ws_id)
        )
 SELECT player_id,
    count(*) AS counterpress
   FROM seq
  WHERE (type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'Challenge'::text, 'BlockedPass'::text])) AND prev_team <> team AND (abs_sec - prev_sec) >= 0 AND (abs_sec - prev_sec) <= 5
  GROUP BY player_id with no data;
create materialized view public.mv_player_defload as  SELECT player_id,
    round(100.0 * count(*) FILTER (WHERE type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'Clearance'::text, 'BlockedPass'::text, 'Challenge'::text, 'Aerial'::text]))::numeric / NULLIF(count(*), 0)::numeric, 2) AS pct_def_actions
   FROM v_league_events events
  WHERE is_open_play AND player_id IS NOT NULL
  GROUP BY player_id with no data;
create materialized view public.mv_player_foot as  WITH f AS (
         SELECT e.player_id,
            count(*) FILTER (WHERE q.dn = 'LeftFoot'::text) AS left_ct,
            count(*) FILTER (WHERE q.dn = 'RightFoot'::text) AS right_ct
           FROM v_league_events e
             CROSS JOIN LATERAL ( SELECT (qq.value -> 'type'::text) ->> 'displayName'::text AS dn
                   FROM jsonb_array_elements(e.qualifiers) qq(value)) q
          WHERE e.player_id IS NOT NULL AND (q.dn = ANY (ARRAY['LeftFoot'::text, 'RightFoot'::text]))
          GROUP BY e.player_id
        )
 SELECT player_id,
    left_ct,
    right_ct,
    left_ct + right_ct AS foot_events,
    round(100.0 * left_ct::numeric / NULLIF(left_ct + right_ct, 0)::numeric, 1) AS left_share,
        CASE
            WHEN (left_ct + right_ct) < 8 THEN NULL::text
            WHEN (left_ct::numeric / (left_ct + right_ct)::numeric) >= 0.65 THEN 'left'::text
            WHEN (left_ct::numeric / (left_ct + right_ct)::numeric) <= 0.35 THEN 'right'::text
            ELSE 'either'::text
        END AS foot,
        CASE
            WHEN (left_ct + right_ct) >= 25 THEN 'high'::text
            WHEN (left_ct + right_ct) >= 8 THEN 'medium'::text
            ELSE 'low'::text
        END AS foot_confidence
   FROM f with no data;
create materialized view public.mv_player_league as  SELECT player_id,
    league,
    ev
   FROM ( SELECT events.player_id,
            events.league,
            count(*) AS ev,
            row_number() OVER (PARTITION BY events.player_id ORDER BY (count(*)) DESC) AS rk
           FROM v_league_events events
          WHERE events.player_id IS NOT NULL
          GROUP BY events.player_id, events.league) z
  WHERE rk = 1 with no data;
create materialized view public.mv_player_sca as  WITH seq AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.player_id,
            events.type,
            events.is_shot,
            lag(events.player_id, 1) OVER w AS p1,
            lag(events.team, 1) OVER w AS t1,
            lag(events.type, 1) OVER w AS ty1,
            lag(events.player_id, 2) OVER w AS p2,
            lag(events.team, 2) OVER w AS t2,
            lag(events.type, 2) OVER w AS ty2
           FROM v_league_events events
          WHERE events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text])
          WINDOW w AS (PARTITION BY events.game_id ORDER BY events.ws_id)
        ), sh AS (
         SELECT seq.game_id,
            seq.ws_id,
            seq.team,
            seq.player_id,
            seq.type,
            seq.is_shot,
            seq.p1,
            seq.t1,
            seq.ty1,
            seq.p2,
            seq.t2,
            seq.ty2
           FROM seq
          WHERE seq.is_shot
        ), credits AS (
         SELECT sh.p1 AS player_id
           FROM sh
          WHERE sh.t1 = sh.team AND sh.p1 IS NOT NULL AND (sh.ty1 = ANY (ARRAY['Pass'::text, 'TakeOn'::text, 'BallTouch'::text, 'BallRecovery'::text]))
        UNION ALL
         SELECT sh.p2
           FROM sh
          WHERE sh.t2 = sh.team AND sh.p2 IS NOT NULL AND sh.p2 <> COALESCE(sh.p1, ''::text) AND (sh.ty2 = ANY (ARRAY['Pass'::text, 'TakeOn'::text, 'BallTouch'::text, 'BallRecovery'::text]))
        )
 SELECT player_id,
    count(*) AS sca
   FROM credits
  GROUP BY player_id with no data;
create materialized view public.mv_player_stints as  WITH mlen AS (
         SELECT events.game_id,
            max(events.expanded_minute) + 1 AS end_min
           FROM v_league_events events
          GROUP BY events.game_id
        ), appear AS (
         SELECT DISTINCT l.game_id,
            l.player_id,
            l.team
           FROM v_league_lineups l
          WHERE l.player_id IS NOT NULL
        ), subs AS (
         SELECT events.game_id,
            events.player_id,
            min(events.expanded_minute) FILTER (WHERE events.type = 'SubstitutionOn'::text) AS on_min,
            min(events.expanded_minute) FILTER (WHERE events.type = 'SubstitutionOff'::text) AS off_min
           FROM v_league_events events
          WHERE (events.type = ANY (ARRAY['SubstitutionOn'::text, 'SubstitutionOff'::text])) AND events.player_id IS NOT NULL
          GROUP BY events.game_id, events.player_id
        ), touched AS (
         SELECT DISTINCT events.game_id,
            events.player_id
           FROM v_league_events events
          WHERE events.player_id IS NOT NULL
        )
 SELECT a.game_id,
    a.player_id,
    a.team,
    s.on_min IS NULL AS is_starter,
    COALESCE(s.on_min, 0) AS start_min,
    COALESCE(s.off_min, m.end_min) AS end_min,
    GREATEST(0, COALESCE(s.off_min, m.end_min) - COALESCE(s.on_min, 0)) AS minutes,
    m.end_min AS match_len
   FROM appear a
     JOIN mlen m ON m.game_id = a.game_id
     LEFT JOIN subs s ON s.game_id = a.game_id AND s.player_id = a.player_id
  WHERE (EXISTS ( SELECT 1
           FROM touched t
          WHERE t.game_id = a.game_id AND t.player_id = a.player_id)) with no data;
create materialized view public.mv_player_territory as  SELECT player_id,
    count(*) AS touches,
    round(avg(x)::numeric, 2) AS avg_x,
    round(stddev_pop(x)::numeric, 2) AS sd_x,
    round(avg(abs(y - 50::double precision))::numeric, 2) AS centrality,
    round(stddev_pop(y)::numeric, 2) AS sd_y,
    round(100.0 * count(*) FILTER (WHERE x < 33.3::double precision)::numeric / count(*)::numeric, 2) AS pct_def_third,
    round(100.0 * count(*) FILTER (WHERE x >= 66.7::double precision)::numeric / count(*)::numeric, 2) AS pct_att_third,
    round(100.0 * count(*) FILTER (WHERE x >= 83::double precision AND y >= 21::double precision AND y <= 79::double precision)::numeric / count(*)::numeric, 2) AS pct_box,
    round(100.0 * count(*) FILTER (WHERE y < 21::double precision OR y > 79::double precision)::numeric / count(*)::numeric, 2) AS pct_wide_lane
   FROM v_league_events e
  WHERE is_touch AND is_open_play AND x IS NOT NULL AND y IS NOT NULL
  GROUP BY player_id with no data;
create materialized view public.mv_player_zones as  WITH e AS (
         SELECT events.player_id,
            events.type,
            events.x,
            events.y,
            events.end_x,
            events.end_y,
            events.is_shot,
            events.is_open_play,
            events.outcome_type = 'Successful'::text AS ok,
            events.y >= 21.1::double precision AND events.y <= 36.8::double precision OR events.y >= 63.2::double precision AND events.y <= 78.9::double precision AS hs,
            events.y < 21.1::double precision OR events.y > 78.9::double precision AS flank,
            events.type = 'Pass'::text AND events.x IS NOT NULL AND events.end_x IS NOT NULL AND (events.x < 50::double precision AND events.end_x < 50::double precision AND (events.end_x - events.x) >= 30::double precision OR events.x < 50::double precision AND events.end_x >= 50::double precision AND (events.end_x - events.x) >= 15::double precision OR events.x >= 50::double precision AND events.end_x >= 50::double precision AND (events.end_x - events.x) >= 10::double precision) AS prog,
            events.qualifiers @> '[{"type": {"displayName": "KeyPass"}}]'::jsonb AS q_kp
           FROM v_league_events events
          WHERE events.player_id IS NOT NULL AND events.x IS NOT NULL AND events.y IS NOT NULL
        )
 SELECT player_id,
    count(*) FILTER (WHERE hs AND x >= 50::double precision AND type = 'Pass'::text AND is_open_play) AS hs_passes,
    count(*) FILTER (WHERE hs AND x >= 50::double precision AND type = 'Pass'::text AND is_open_play AND prog AND ok) AS hs_prog_passes,
    count(*) FILTER (WHERE hs AND x >= 50::double precision AND type = 'Pass'::text AND q_kp) AS hs_key_passes,
    count(*) FILTER (WHERE hs AND x >= 50::double precision AND is_shot AND is_open_play) AS hs_shots,
    count(*) FILTER (WHERE hs AND x >= 50::double precision AND type = 'TakeOn'::text) AS hs_takeons,
    count(*) FILTER (WHERE x < 17::double precision AND y >= 21.1::double precision AND y <= 78.9::double precision AND (type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BlockedPass'::text, 'Aerial'::text]))) AS box_def_actions,
    count(*) FILTER (WHERE x < 50::double precision AND hs AND (type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BlockedPass'::text, 'BallRecovery'::text]))) AS channel_def_actions,
    count(*) FILTER (WHERE x < 50::double precision AND flank AND (type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BlockedPass'::text, 'BallRecovery'::text]))) AS flank_def_actions,
    count(*) FILTER (WHERE x < 17::double precision AND y >= 21.1::double precision AND y <= 78.9::double precision AND type = 'Clearance'::text) AS box_clearances,
    count(*) FILTER (WHERE x < 17::double precision AND y >= 21.1::double precision AND y <= 78.9::double precision AND type = 'Aerial'::text AND ok) AS box_aerials_won
   FROM e
  GROUP BY player_id with no data;
create materialized view public.mv_press_vs_buildup as  WITH gteams AS (
         SELECT sequences.game_id,
            array_agg(DISTINCT sequences.team) AS tms
           FROM v_league_sequences sequences
          GROUP BY sequences.game_id
        ), opp AS (
         SELECT s.seq_uid,
            s.game_id,
            s.team AS attacking_team,
            ( SELECT t.t
                   FROM unnest(gt.tms) t(t)
                  WHERE t.t <> s.team
                 LIMIT 1) AS defending_team,
            s.league,
                CASE
                    WHEN s.long_ball THEN 'direct'::text
                    WHEN s.start_x < 33.3::double precision THEN 'short_build'::text
                    WHEN s.start_x >= 50::double precision THEN 'high_start'::text
                    ELSE 'mid_start'::text
                END AS buildup_type,
            s.end_x,
            s.end_third,
            s.ended_shot,
            s.ended_in_box,
            s.n_pass,
            s.dur_s
           FROM v_league_sequences s
             JOIN gteams gt USING (game_id)
          WHERE s.is_open_play
        )
 SELECT defending_team,
    league,
    buildup_type,
    count(*) AS n,
    round(100.0 * avg((end_x < 66.7::double precision AND NOT ended_shot)::integer), 1) AS contained_pct,
    round(100.0 * avg((end_third = 'def'::text)::integer), 1) AS died_in_their_third_pct,
    round(100.0 * avg(ended_shot::integer), 1) AS conceded_shot_pct,
    round(100.0 * avg(ended_in_box::integer), 1) AS conceded_box_pct,
    round(avg(n_pass), 2) AS opp_passes_per_seq,
    round(avg(dur_s), 1) AS opp_secs_per_seq
   FROM opp
  WHERE defending_team IS NOT NULL
  GROUP BY defending_team, league, buildup_type with no data;
create materialized view public.mv_receipt_events as  WITH seq AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.player_id,
            events.player,
            events.type,
            events.x,
            events.y,
            events.end_x,
            events.end_y,
            events.minute * 60 + events.second AS abs_sec,
            lag(events.team) OVER w AS prev_team,
            lag(COALESCE(events.end_x, events.x)) OVER w AS rx,
            lag(COALESCE(events.end_y, events.y)) OVER w AS ry,
            lag(events.minute * 60 + events.second) OVER w AS prev_sec
           FROM v_league_events events
          WHERE events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text])
          WINDOW w AS (PARTITION BY events.game_id ORDER BY events.ws_id)
        ), c AS (
         SELECT seq.game_id,
            seq.ws_id,
            seq.team,
            seq.player_id,
            seq.player,
            seq.type AS release_type,
            seq.rx,
            seq.ry,
            seq.x AS ax,
            seq.y AS ay,
            seq.abs_sec - seq.prev_sec AS ttr,
            sqrt(power((seq.x - seq.rx) * 1.05::double precision, 2::double precision) + power((seq.y - seq.ry) * 0.68::double precision, 2::double precision)) AS carry_m,
            sqrt(power((100::double precision - seq.rx) * 1.05::double precision, 2::double precision) + power((50::double precision - seq.ry) * 0.68::double precision, 2::double precision)) AS d0,
            sqrt(power((100::double precision - seq.x) * 1.05::double precision, 2::double precision) + power((50::double precision - seq.y) * 0.68::double precision, 2::double precision)) AS d1
           FROM seq
          WHERE seq.prev_team = seq.team AND seq.player_id IS NOT NULL AND seq.x IS NOT NULL AND seq.y IS NOT NULL AND seq.rx IS NOT NULL AND seq.ry IS NOT NULL AND (seq.abs_sec - seq.prev_sec) >= 0 AND (seq.abs_sec - seq.prev_sec) <= 20
        )
 SELECT game_id,
    ws_id,
    team,
    player_id,
    player,
    release_type,
    round(rx::numeric, 1) AS start_x,
    round(ry::numeric, 1) AS start_y,
    round(ax::numeric, 1) AS end_x,
    round(ay::numeric, 1) AS end_y,
    ttr,
    round(carry_m::numeric, 2) AS carry_m,
    carry_m >= 3::double precision AS is_carry,
    carry_m >= 3::double precision AND d1 < (0.85::double precision * d0) AS is_progressive,
    carry_m >= 3::double precision AND ax >= 83::double precision AND ay >= 21::double precision AND ay <= 79::double precision AND NOT (rx >= 83::double precision AND ry >= 21::double precision AND ry <= 79::double precision) AS into_box,
    round((d0 - d1)::numeric, 2) AS goal_dist_gained
   FROM c with no data;
create materialized view public.mv_seq_events as  WITH base AS (
         SELECT events.game_id,
            events.period,
            events.expanded_minute,
            events.second,
            events.event_id,
            events.team,
            events.player,
            events.player_id,
            events.type,
            events.is_shot,
            events.is_goal,
                CASE
                    WHEN jsonb_typeof(events.qualifiers) = 'array'::text THEN (EXISTS ( SELECT 1
                       FROM jsonb_array_elements(events.qualifiers) q(value)
                      WHERE ((q.value -> 'type'::text) ->> 'displayName'::text) = ANY (ARRAY['ThrowIn'::text, 'CornerTaken'::text, 'FreekickTaken'::text, 'GoalKick'::text, 'KickOff'::text, 'Penalty'::text])))
                    ELSE false
                END AS is_setpiece,
                CASE
                    WHEN events.type = ANY (ARRAY['Pass'::text, 'TakeOn'::text, 'BallTouch'::text, 'MissedShots'::text, 'SavedShot'::text, 'ShotOnPost'::text, 'Goal'::text, 'KeeperPickup'::text, 'Claim'::text]) THEN events.team
                    ELSE NULL::text
                END AS ctrl_team,
                CASE
                    WHEN (events.type = ANY (ARRAY['Foul'::text, 'Card'::text, 'OffsideGiven'::text, 'OffsidePass'::text, 'CornerAwarded'::text, 'End'::text])) OR events.is_goal THEN 1
                    ELSE 0
                END AS stop_flag
           FROM v_league_events events
        ), cum AS (
         SELECT base.game_id,
            base.period,
            base.expanded_minute,
            base.second,
            base.event_id,
            base.team,
            base.player,
            base.player_id,
            base.type,
            base.is_shot,
            base.is_goal,
            base.is_setpiece,
            base.ctrl_team,
            base.stop_flag,
            sum(base.stop_flag) OVER (PARTITION BY base.game_id ORDER BY base.period, base.expanded_minute, base.second, base.event_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS stop_cum
           FROM base
        ), ctrl AS (
         SELECT cum.game_id,
            cum.period,
            cum.expanded_minute,
            cum.second,
            cum.event_id,
            cum.team,
            cum.player,
            cum.player_id,
            cum.type,
            cum.is_shot,
            cum.is_goal,
            cum.is_setpiece,
            cum.ctrl_team,
            cum.stop_flag,
            cum.stop_cum,
            lag(cum.ctrl_team) OVER w AS prev_ctrl_team,
            lag(cum.stop_cum) OVER w AS prev_stop_cum,
            lag(cum.period) OVER w AS prev_period
           FROM cum
          WHERE cum.ctrl_team IS NOT NULL
          WINDOW w AS (PARTITION BY cum.game_id ORDER BY cum.period, cum.expanded_minute, cum.second, cum.event_id)
        ), bounded AS (
         SELECT ctrl.game_id,
            ctrl.period,
            ctrl.expanded_minute,
            ctrl.second,
            ctrl.event_id,
            ctrl.team,
            ctrl.player,
            ctrl.player_id,
            ctrl.type,
            ctrl.is_shot,
            ctrl.is_goal,
            ctrl.is_setpiece,
            ctrl.ctrl_team,
            ctrl.stop_flag,
            ctrl.stop_cum,
            ctrl.prev_ctrl_team,
            ctrl.prev_stop_cum,
            ctrl.prev_period,
                CASE
                    WHEN ctrl.prev_ctrl_team IS NULL OR ctrl.period <> ctrl.prev_period OR ctrl.ctrl_team <> ctrl.prev_ctrl_team OR ctrl.is_setpiece OR ctrl.stop_cum > COALESCE(ctrl.prev_stop_cum, '-1'::integer::bigint) THEN 1
                    ELSE 0
                END AS is_break
           FROM ctrl
        ), seqd AS (
         SELECT bounded.game_id,
            bounded.period,
            bounded.expanded_minute,
            bounded.second,
            bounded.event_id,
            bounded.team,
            bounded.player,
            bounded.player_id,
            bounded.type,
            bounded.is_shot,
            bounded.is_goal,
            bounded.is_setpiece,
            bounded.ctrl_team,
            bounded.stop_flag,
            bounded.stop_cum,
            bounded.prev_ctrl_team,
            bounded.prev_stop_cum,
            bounded.prev_period,
            bounded.is_break,
            sum(bounded.is_break) OVER (PARTITION BY bounded.game_id ORDER BY bounded.period, bounded.expanded_minute, bounded.second, bounded.event_id) AS seq_no
           FROM bounded
        )
 SELECT (game_id || '-'::text) || seq_no AS seq_uid,
    game_id,
    seq_no,
    player_id,
    player,
    team,
    type,
    is_shot,
    row_number() OVER (PARTITION BY game_id, seq_no ORDER BY period, expanded_minute, second, event_id) AS ord_a,
    count(*) OVER (PARTITION BY game_id, seq_no) AS chain_len,
    bool_or(is_break = 1 AND is_setpiece) OVER (PARTITION BY game_id, seq_no) AS seq_setpiece
   FROM seqd with no data;
create materialized view public.mv_shot_features as  SELECT game_id,
    ws_id,
    player_id,
    player,
    team,
    is_goal,
    is_open_play,
    type,
    x,
    y,
    sqrt(power((100::double precision - x) * 1.05::double precision, 2::double precision) + power((50::double precision - y) * 0.68::double precision, 2::double precision)) AS dist_m,
    degrees(
        CASE
            WHEN (power((100::double precision - x) * 1.05::double precision, 2::double precision) + power((y - 50::double precision) * 0.68::double precision, 2::double precision) - power(3.66, 2::numeric)::double precision) <= 0::double precision THEN pi()
            ELSE atan(7.32::double precision * ((100::double precision - x) * 1.05::double precision) / (power((100::double precision - x) * 1.05::double precision, 2::double precision) + power((y - 50::double precision) * 0.68::double precision, 2::double precision) - power(3.66, 2::numeric)::double precision))
        END) AS angle_deg,
    qualifiers @> '[{"type": {"displayName": "Head"}}]'::jsonb AS is_header,
    qualifiers @> '[{"type": {"displayName": "BigChance"}}]'::jsonb AS is_bigchance,
    qualifiers @> '[{"type": {"displayName": "Penalty"}}]'::jsonb AS is_pen,
    qualifiers @> '[{"type": {"displayName": "Blocked"}}]'::jsonb AS is_blocked,
        CASE
            WHEN is_goal THEN 'goal'::text
            WHEN qualifiers @> '[{"type": {"displayName": "Blocked"}}]'::jsonb THEN 'blocked'::text
            WHEN type = 'SavedShot'::text THEN 'saved'::text
            WHEN type = 'ShotOnPost'::text THEN 'post'::text
            ELSE 'off'::text
        END AS outcome
   FROM v_league_events e
  WHERE is_shot AND x IS NOT NULL AND y IS NOT NULL AND NOT qualifiers @> '[{"type": {"displayName": "OwnGoal"}}]'::jsonb with no data;
create materialized view public.mv_team_lanes as  WITH a AS (
         SELECT events.team,
                CASE
                    WHEN events.y < 33.3::double precision THEN 'R'::text
                    WHEN events.y < 66.7::double precision THEN 'C'::text
                    ELSE 'L'::text
                END AS lane,
            events.x >= 66.7::double precision AS final_third,
            events.type = 'Pass'::text AND events.end_x >= 83::double precision AND events.end_y >= 21::double precision AND events.end_y <= 79::double precision AS into_box,
            events.is_shot
           FROM v_league_events events
          WHERE events.team IS NOT NULL AND events.x IS NOT NULL AND events.y IS NOT NULL AND (events.is_open_play AND (events.type = ANY (ARRAY['Pass'::text, 'TakeOn'::text, 'BallTouch'::text, 'Dispossessed'::text])) OR events.is_shot)
        )
 SELECT team,
    lane,
    count(*) AS touches,
    count(*) FILTER (WHERE final_third) AS final_third_touches,
    count(*) FILTER (WHERE into_box) AS box_entries,
    count(*) FILTER (WHERE is_shot) AS shots,
    round(100.0 * count(*) FILTER (WHERE final_third)::numeric / NULLIF(sum(count(*) FILTER (WHERE final_third)) OVER (PARTITION BY team), 0::numeric), 1) AS pct_of_final_third
   FROM a
  GROUP BY team, lane with no data;
create materialized view public.mv_team_league as  SELECT team,
    league,
    events
   FROM ( SELECT e.team,
            e.league,
            count(*) AS events,
            row_number() OVER (PARTITION BY e.team ORDER BY (count(*)) DESC, e.league) AS rk
           FROM v_league_events e
          WHERE e.team IS NOT NULL
          GROUP BY e.team, e.league) ranked
  WHERE rk = 1 with no data;
create materialized view public.mv_team_match as  WITH ev AS (
         SELECT e.game_id,
            e.team,
            e.type,
            e.x,
            e.y,
            e.end_x,
            e.end_y,
            e.is_shot,
            e.is_open_play,
            e.outcome_type = 'Successful'::text AS ok,
            e.type = 'Pass'::text AND e.x IS NOT NULL AND e.end_x IS NOT NULL AND (e.x < 50::double precision AND e.end_x < 50::double precision AND (e.end_x - e.x) >= 30::double precision OR e.x < 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 15::double precision OR e.x >= 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 10::double precision) AS prog,
            e.qualifiers @> '[{"type": {"displayName": "Cross"}}]'::jsonb AS q_cross,
            e.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb AS q_long
           FROM v_league_events e
          WHERE e.team IS NOT NULL
        ), t AS (
         SELECT z.game_id,
            z.team,
            count(*) FILTER (WHERE z.type = 'Pass'::text) AS passes,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.ok) AS passes_cmp,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.is_open_play AND z.q_long) AS long_balls,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.prog AND z.ok) AS prog_passes,
            COALESCE(sum(GREATEST(0::double precision, z.end_x - z.x) * 1.05::double precision) FILTER (WHERE z.type = 'Pass'::text AND z.ok), 0::double precision) AS territory,
            count(*) FILTER (WHERE z.is_touch_proxy AND z.x >= 66.7::double precision) AS ft_touches,
            count(*) FILTER (WHERE z.is_touch_proxy) AS touches,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.x < 33.3::double precision) AS passes_from_def_third,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.is_open_play AND z.ok AND z.end_x >= 83::double precision AND z.end_y >= 21::double precision AND z.end_y <= 79::double precision) AS box_entries_pass,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.is_open_play AND z.q_cross) AS crosses,
            count(*) FILTER (WHERE z.is_shot) AS shots,
            count(*) FILTER (WHERE z.is_shot AND z.is_open_play) AS shots_open,
            count(*) FILTER (WHERE z.type = 'Goal'::text) AS goals,
            count(*) FILTER (WHERE z.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text])) AS def_actions,
            count(*) FILTER (WHERE (z.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text])) AND z.x > 40::double precision) AS def_actions_high,
            count(*) FILTER (WHERE z.type = 'Pass'::text AND z.x < 60::double precision) AS passes_own60,
            round(avg(z.x) FILTER (WHERE z.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text]))::numeric, 2) AS def_height,
            round(avg(z.x) FILTER (WHERE z.is_touch_proxy)::numeric, 2) AS avg_touch_x
           FROM ( SELECT ev.game_id,
                    ev.team,
                    ev.type,
                    ev.x,
                    ev.y,
                    ev.end_x,
                    ev.end_y,
                    ev.is_shot,
                    ev.is_open_play,
                    ev.ok,
                    ev.prog,
                    ev.q_cross,
                    ev.q_long,
                    (ev.type <> ALL (ARRAY['SubstitutionOn'::text, 'SubstitutionOff'::text, 'Card'::text, 'FormationChange'::text, 'FormationSet'::text, 'Start'::text, 'End'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text])) AND ev.x IS NOT NULL AS is_touch_proxy
                   FROM ev) z
          GROUP BY z.game_id, z.team
        ), paired AS (
         SELECT a.game_id,
            a.team,
            a.passes,
            a.passes_cmp,
            a.long_balls,
            a.prog_passes,
            a.territory,
            a.ft_touches,
            a.touches,
            a.passes_from_def_third,
            a.box_entries_pass,
            a.crosses,
            a.shots,
            a.shots_open,
            a.goals,
            a.def_actions,
            a.def_actions_high,
            a.passes_own60,
            a.def_height,
            a.avg_touch_x,
            b.team AS opp,
            b.passes AS opp_passes,
            b.passes_own60 AS opp_passes_own60,
            b.ft_touches AS opp_ft_touches,
            b.touches AS opp_touches,
            b.shots AS opp_shots,
            b.goals AS opp_goals
           FROM t a
             JOIN t b ON b.game_id = a.game_id AND b.team <> a.team
        )
 SELECT game_id,
    team,
    opp,
    passes,
    passes_cmp,
    shots,
    shots_open,
    goals,
    opp_shots,
    opp_goals,
    round(100.0 * passes::numeric / NULLIF(passes + opp_passes, 0)::numeric, 1) AS possession_pct,
    round(100.0 * ft_touches::numeric / NULLIF(ft_touches + opp_ft_touches, 0)::numeric, 1) AS field_tilt,
    round(opp_passes_own60::numeric / NULLIF(def_actions_high, 0)::numeric, 2) AS ppda,
    def_height,
    avg_touch_x,
    round(100.0 * long_balls::numeric / NULLIF(passes, 0)::numeric, 1) AS long_ball_pct,
    round(100.0 * passes_from_def_third::numeric / NULLIF(passes, 0)::numeric, 1) AS build_from_back_pct,
    round(territory::numeric / NULLIF(passes_cmp, 0)::numeric, 2) AS directness,
    prog_passes,
    box_entries_pass,
    crosses,
    def_actions,
    round(100.0 * shots_open::numeric / NULLIF(shots, 0)::numeric, 1) AS open_play_shot_pct
   FROM paired with no data;
create materialized view public.mv_team_sequences as  WITH base AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.type,
            events.x,
            events.y,
            events.end_x,
            events.is_shot,
            events.period,
            events.minute * 60 + events.second AS sec,
            lag(events.team) OVER w AS prev_team,
            lag(events.period) OVER w AS prev_period,
            events.minute * 60 + events.second - lag(events.minute * 60 + events.second) OVER w AS gap
           FROM v_league_events events
          WHERE events.team IS NOT NULL AND events.x IS NOT NULL AND (events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'OffsideProvoked'::text, 'CornerAwarded'::text]))
          WINDOW w AS (PARTITION BY events.game_id ORDER BY events.ws_id)
        ), flagged AS (
         SELECT base.game_id,
            base.ws_id,
            base.team,
            base.type,
            base.x,
            base.y,
            base.end_x,
            base.is_shot,
            base.period,
            base.sec,
            base.prev_team,
            base.prev_period,
            base.gap,
                CASE
                    WHEN base.prev_team IS DISTINCT FROM base.team OR base.prev_period IS DISTINCT FROM base.period OR COALESCE(base.gap, 99) > 8 THEN 1
                    ELSE 0
                END AS newseq
           FROM base
        ), numbered AS (
         SELECT flagged.game_id,
            flagged.ws_id,
            flagged.team,
            flagged.type,
            flagged.x,
            flagged.y,
            flagged.end_x,
            flagged.is_shot,
            flagged.period,
            flagged.sec,
            flagged.prev_team,
            flagged.prev_period,
            flagged.gap,
            flagged.newseq,
            sum(flagged.newseq) OVER (PARTITION BY flagged.game_id ORDER BY flagged.ws_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS seq_id
           FROM flagged
        )
 SELECT game_id,
    seq_id,
    team,
    count(*) AS actions,
    count(*) FILTER (WHERE type = 'Pass'::text) AS passes,
    GREATEST(max(sec) - min(sec), 0) AS duration_s,
    min(x) AS start_x,
    max(COALESCE(end_x, x)) AS max_x,
    bool_or(is_shot) AS ended_in_shot
   FROM numbered
  GROUP BY game_id, seq_id, team
 HAVING count(*) >= 2 with no data;
create materialized view public.seq_fz as  WITH f AS (
         SELECT sequences.seq_uid,
            sequences.team,
            sequences.game_id,
            sequences.league,
            sequences.xt_sum,
            sequences.n_pass,
            sequences.ended_shot,
            sequences.end_third,
            sequences.ended_in_box,
            sequences.start_x::numeric AS sx,
            sequences.start_y::numeric AS sy,
            sequences.end_x::numeric AS ex,
            sequences.end_y::numeric AS ey,
            sequences.cx,
            sequences.cy,
            sequences.maxx - sequences.minx AS vs,
            sequences.maxy - sequences.miny AS ls,
            sequences.end_x - sequences.start_x AS ndx,
            sequences.end_y - sequences.start_y AS ndy,
            COALESCE(sequences.mean_pass_len, 0::numeric) * sequences.n_pass::numeric AS pl,
            sequences.att_share AS az
           FROM v_league_sequences sequences
          WHERE sequences.is_open_play
        )
 SELECT seq_uid,
    team,
    game_id,
    xt_sum,
    n_pass,
    ended_shot,
    end_third,
    ended_in_box,
    (sx - avg(sx) OVER w) / NULLIF(stddev_samp(sx) OVER w, 0::numeric) AS z_sx,
    (sy - avg(sy) OVER w) / NULLIF(stddev_samp(sy) OVER w, 0::numeric) AS z_sy,
    (ex - avg(ex) OVER w) / NULLIF(stddev_samp(ex) OVER w, 0::numeric) AS z_ex,
    (ey - avg(ey) OVER w) / NULLIF(stddev_samp(ey) OVER w, 0::numeric) AS z_ey,
    (cx - avg(cx) OVER w) / NULLIF(stddev_samp(cx) OVER w, 0::numeric) AS z_cx,
    (cy - avg(cy) OVER w) / NULLIF(stddev_samp(cy) OVER w, 0::numeric) AS z_cy,
    (vs - avg(vs) OVER w) / NULLIF(stddev_samp(vs) OVER w, 0::numeric) AS z_vs,
    (ls - avg(ls) OVER w) / NULLIF(stddev_samp(ls) OVER w, 0::numeric) AS z_ls,
    (ndx - avg(ndx) OVER w) / NULLIF(stddev_samp(ndx) OVER w, 0::double precision) AS z_ndx,
    (ndy - avg(ndy) OVER w) / NULLIF(stddev_samp(ndy) OVER w, 0::double precision) AS z_ndy,
    (pl - avg(pl) OVER w) / NULLIF(stddev_samp(pl) OVER w, 0::numeric) AS z_pl,
    (n_pass::numeric - avg(n_pass) OVER w) / NULLIF(stddev_samp(n_pass) OVER w, 0::numeric) AS z_np,
    (xt_sum - avg(xt_sum) OVER w) / NULLIF(stddev_samp(xt_sum) OVER w, 0::numeric) AS z_xt,
    (az - avg(az) OVER w) / NULLIF(stddev_samp(az) OVER w, 0::numeric) AS z_as,
    league
   FROM f
  WINDOW w AS (PARTITION BY league) with no data;
create view public.team_sequence_agg as  SELECT team,
    team_id,
    count(DISTINCT game_id) AS matches,
    round(count(*)::numeric / NULLIF(count(DISTINCT game_id), 0)::numeric, 1) AS seqs_per_match,
    round(avg(n_pass), 2) AS passes_seq,
    round(avg(dur_s), 1) AS seconds_seq,
    round(avg(n_players), 2) AS players_seq,
    round(avg(xt_sum), 4) AS xt_seq,
    round(100.0 * avg(low_build::integer), 1) AS low_build_pct,
    round(100.0 * avg(high_build::integer), 1) AS high_build_pct,
    round(100.0 * avg(structured::integer), 1) AS structured_pct,
    round(100.0 * avg(very_short::integer), 1) AS very_short_pct,
    round(100.0 * avg(long_ball::integer), 1) AS long_pct,
    round(100.0 * avg(has_switch::integer), 1) AS switches_pct,
    round(100.0 * avg(wide_triangles::integer), 1) AS wide_tri_pct,
    round(100.0 * avg(hold_up::integer), 1) AS hold_up_pct,
    round(100.0 * avg(ends_opp_half::integer), 1) AS ends_opp_half_pct,
    round(100.0 * avg((end_third = 'def'::text)::integer), 1) AS ends_def_third_pct,
    round(100.0 * avg((end_third = 'att'::text)::integer), 1) AS end_att_third_pct,
    round(100.0 * avg(ended_in_box::integer), 1) AS end_in_box_pct,
    round(100.0 * avg(end_around_box::integer), 1) AS end_around_box_pct,
    round(100.0 * avg(finds_central::integer), 1) AS finds_central_pct,
    round(100.0 * avg(finds_wide::integer), 1) AS finds_wide_pct,
    round(100.0 * avg(ended_shot::integer), 1) AS ends_in_shot_pct,
    round(100.0 * sum(n_prog_central)::numeric / NULLIF(sum(n_prog), 0)::numeric, 1) AS central_prog_share,
    round(100.0 * sum(n_wide_pass)::numeric / NULLIF(sum(n_pass), 0)::numeric, 1) AS wide_pass_pct
   FROM v_league_sequences sequences
  WHERE is_open_play
  GROUP BY team, team_id;

-- === relation_options ===
alter view public.team_sequence_agg set (security_invoker=true);

-- === relations ===
create view public.v_goal_fix as  SELECT player_id,
    count(*) AS own_goals
   FROM v_league_events events
  WHERE type = 'Goal'::text AND qualifiers @> '[{"type": {"displayName": "OwnGoal"}}]'::jsonb
  GROUP BY player_id;

-- === relation_options ===
alter view public.v_goal_fix set (security_invoker=true);

-- === relations ===
create view public.v_loaded_games as  SELECT DISTINCT game_id
   FROM v_league_events events;

-- === relation_options ===
alter view public.v_loaded_games set (security_invoker=true);

-- === relations ===
create view public.v_season_stats as  WITH ev AS (
         SELECT e.game_id,
            e.team,
            e.type = 'Pass'::text AND e.end_x IS NOT NULL AND e.end_x >= 66::double precision AS ft,
            e.type = 'Pass'::text AND e.end_x IS NOT NULL AND e.end_x >= 66::double precision AND e.end_x <= 83::double precision AND e.end_y >= 21::double precision AND e.end_y <= 79::double precision AS z14,
            e.type = 'Pass'::text AND e.end_x IS NOT NULL AND e.end_x >= 83::double precision AND e.end_y >= 21::double precision AND e.end_y <= 79::double precision AS box,
            e.type = 'Pass'::text AND e.x IS NOT NULL AND e.end_x IS NOT NULL AND (e.x < 50::double precision AND e.end_x < 50::double precision AND (e.end_x - e.x) >= 30::double precision OR e.x < 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 15::double precision OR e.x >= 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 10::double precision) AS prog,
            e.type = 'Pass'::text AND e.end_x IS NOT NULL AND e.end_x > (e.x + 3::double precision) AS fwd,
            e.type = 'Pass'::text AND e.end_x IS NOT NULL AND abs(e.end_x - e.x) <= 3::double precision AS lat,
            e.type = 'Pass'::text AND e.end_x IS NOT NULL AND e.end_x < (e.x - 3::double precision) AS bwd,
            e.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Aerial'::text, 'Challenge'::text]) AS defa,
            (e.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Aerial'::text, 'Challenge'::text])) AND e.outcome_type = 'Successful'::text AS defw,
            e.is_shot AS shot,
            e.is_shot AND (e.outcome_type = 'Saved'::text OR e.is_goal) AS sot
           FROM v_league_events e
        ), agg AS (
         SELECT ev.game_id,
            ev.team,
            count(*) FILTER (WHERE ev.ft) AS final_third_passes,
            count(*) FILTER (WHERE ev.z14) AS zone14_passes,
            count(*) FILTER (WHERE ev.prog) AS progressive_passes,
            count(*) FILTER (WHERE ev.box) AS passes_into_box,
            count(*) FILTER (WHERE ev.defa) AS defensive_actions,
            count(*) FILTER (WHERE ev.defw) AS defensive_actions_won,
            count(*) FILTER (WHERE ev.shot) AS shots,
            count(*) FILTER (WHERE ev.sot) AS shots_on_target,
            count(*) FILTER (WHERE ev.fwd) AS fwd_passes,
            count(*) FILTER (WHERE ev.lat) AS lat_passes,
            count(*) FILTER (WHERE ev.bwd) AS bwd_passes
           FROM ev
          GROUP BY ev.game_id, ev.team
        )
 SELECT a.game_id,
    a.team,
        CASE
            WHEN a.team = m.home_team THEN m.away_team
            ELSE m.home_team
        END AS opponent,
        CASE
            WHEN a.team = m.home_team THEN 'H'::text
            ELSE 'A'::text
        END AS ha,
        CASE
            WHEN a.team = m.home_team THEN m.home_score
            ELSE m.away_score
        END AS team_score,
        CASE
            WHEN a.team = m.home_team THEN m.away_score
            ELSE m.home_score
        END AS opp_score,
    a.final_third_passes,
    a.zone14_passes,
    a.progressive_passes,
    a.passes_into_box,
    a.defensive_actions,
    a.defensive_actions_won,
    a.shots,
    a.shots_on_target,
    a.fwd_passes,
    a.lat_passes,
    a.bwd_passes
   FROM agg a
     JOIN v_league_matches m ON m.game_id = a.game_id;

-- === relation_options ===
alter view public.v_season_stats set (security_invoker=true);

-- === relations ===
create view public.v_team_actions as  SELECT team,
    type,
    x,
    y,
    end_x,
    end_y,
    outcome_type = 'Successful'::text AS ok,
    is_shot,
    type = 'Pass'::text AND x IS NOT NULL AND end_x IS NOT NULL AND (x < 50::double precision AND end_x < 50::double precision AND (end_x - x) >= 30::double precision OR x < 50::double precision AND end_x >= 50::double precision AND (end_x - x) >= 15::double precision OR x >= 50::double precision AND end_x >= 50::double precision AND (end_x - x) >= 10::double precision) AS prog,
    type = 'Pass'::text AND end_x >= 83::double precision AND end_y >= 21::double precision AND end_y <= 79::double precision AS into_box
   FROM v_league_events e
  WHERE team IS NOT NULL AND x IS NOT NULL AND y IS NOT NULL AND is_open_play AND (type = ANY (ARRAY['Pass'::text, 'Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'Clearance'::text, 'BlockedPass'::text, 'Challenge'::text, 'TakeOn'::text, 'Aerial'::text]));

-- === relation_options ===
alter view public.v_team_actions set (security_invoker=true);

-- === relations ===
create view public.v_xt_model_status as  SELECT (( SELECT count(*) AS count
           FROM xt_grid))::integer AS grid_cells,
    ( SELECT min(xt_grid.v) AS min
           FROM xt_grid) AS grid_min,
    ( SELECT max(xt_grid.v) AS max
           FROM xt_grid) AS grid_max,
    true AS borrowed_grid,
    false AS fitted_on_platform_competitions,
    false AS externally_validated,
    round(avg(xt_sum) FILTER (WHERE ended_shot), 4) AS shot_ending_mean_xt,
    round(avg(xt_sum) FILTER (WHERE NOT ended_shot), 4) AS other_mean_xt,
    round(avg(xt_sum) FILTER (WHERE ended_shot) / NULLIF(avg(xt_sum) FILTER (WHERE NOT ended_shot), 0::numeric), 2) AS internal_directional_ratio
   FROM v_league_sequences s;

-- === relation_options ===
alter view public.v_xt_model_status set (security_invoker=true);

-- === relations ===
create materialized view public.mv_player_carry as  SELECT player_id,
    count(*) FILTER (WHERE is_carry) AS carries,
    count(*) FILTER (WHERE is_progressive) AS prog_carries,
    count(*) FILTER (WHERE into_box) AS carries_into_box,
    round(avg(carry_m) FILTER (WHERE is_carry), 2) AS mean_carry_m,
    round(sum(GREATEST(goal_dist_gained, 0::numeric)) FILTER (WHERE is_progressive), 0) AS carry_penetration,
    count(*) AS receipts,
    percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (ttr::double precision)) AS median_ttr,
    count(*) FILTER (WHERE release_type = 'Pass'::text AND ttr < 2) AS quick_release,
    count(*) FILTER (WHERE release_type = 'Pass'::text AND ttr < 1) AS one_touch,
    count(*) FILTER (WHERE release_type = 'Pass'::text) AS pass_releases
   FROM mv_receipt_events
  GROUP BY player_id with no data;
create materialized view public.mv_player_holdup as  WITH h AS (
         SELECT r.player_id,
            r.game_id,
            r.ws_id,
            r.ttr,
            r.release_type,
            r.is_progressive,
            r.end_x >= 66.7 AS final_third
           FROM mv_receipt_events r
          WHERE r.ttr >= 5 AND r.end_x >= 66.7
        ), nxt AS (
         SELECT h.player_id,
            h.ttr,
            h.release_type,
            h.is_progressive,
            e2.type AS next_type,
            e2.team AS next_team,
            e1.team AS own_team
           FROM h
             JOIN v_league_events e1 ON e1.game_id = h.game_id AND e1.ws_id = h.ws_id
             LEFT JOIN LATERAL ( SELECT e.type,
                    e.team
                   FROM v_league_events e
                  WHERE e.game_id = h.game_id AND e.ws_id > h.ws_id
                  ORDER BY e.ws_id
                 LIMIT 1) e2 ON true
        )
 SELECT player_id,
    count(*) AS holds,
    count(*) FILTER (WHERE next_team = own_team) AS holds_retained,
    count(*) FILTER (WHERE is_progressive) AS holds_prog_carry,
    count(*) FILTER (WHERE release_type = 'Pass'::text) AS holds_passed,
    count(*) FILTER (WHERE release_type = ANY (ARRAY['SavedShot'::text, 'MissedShots'::text, 'Goal'::text, 'ShotOnPost'::text])) AS holds_shot
   FROM nxt
  GROUP BY player_id with no data;
create materialized view public.mv_player_minutes as  WITH subs AS (
         SELECT events.game_id,
            events.player_id,
            min(events.expanded_minute) FILTER (WHERE events.type = 'SubstitutionOn'::text) AS on_min,
            max(events.expanded_minute) FILTER (WHERE events.type = 'SubstitutionOff'::text) AS off_min
           FROM v_league_events events
          WHERE events.type = ANY (ARRAY['SubstitutionOn'::text, 'SubstitutionOff'::text])
          GROUP BY events.game_id, events.player_id
        ), raw AS (
         SELECT l.game_id,
            l.player_id,
            l.team,
            l."position",
            l.is_starter,
            ml.length_min,
            GREATEST(0, COALESCE(s.off_min, ml.length_min) -
                CASE
                    WHEN l.is_starter THEN 0
                    ELSE s.on_min
                END)::numeric AS raw_minutes
           FROM v_league_lineups l
             JOIN mv_match_length ml ON ml.game_id = l.game_id
             LEFT JOIN subs s ON s.game_id = l.game_id AND s.player_id = l.player_id
          WHERE l.is_starter OR s.on_min IS NOT NULL
        )
 SELECT game_id,
    player_id,
    team,
    "position",
    is_starter,
    raw_minutes,
    round(raw_minutes * 90.0 / NULLIF(length_min, 0)::numeric, 2) AS minutes
   FROM raw with no data;
create materialized view public.mv_player_pass_traj as  SELECT player_id,
    max(player) AS player,
    max(team) AS team,
    count(*) AS fwd_passes,
    round(100.0 * avg((trajectory = 'over'::text)::integer), 1) AS pct_over,
    round(100.0 * avg((trajectory = 'around'::text)::integer), 1) AS pct_around,
    round(100.0 * avg((trajectory = 'through'::text)::integer), 1) AS pct_through,
    round(100.0 * avg((destination = 'inside'::text)::integer), 1) AS pct_inside,
    round(100.0 * avg((destination = 'in_behind'::text)::integer), 1) AS pct_in_behind,
    round(100.0 * avg((destination = 'outside'::text)::integer), 1) AS pct_outside,
    round(100.0 * avg((trajectory = 'over'::text AND destination = 'inside'::text)::integer), 1) AS over_inside,
    round(100.0 * avg((trajectory = 'over'::text AND destination = 'in_behind'::text)::integer), 1) AS over_in_behind,
    round(100.0 * avg((trajectory = 'over'::text AND destination = 'outside'::text)::integer), 1) AS over_outside,
    round(100.0 * avg((trajectory = 'around'::text AND destination = 'inside'::text)::integer), 1) AS around_inside,
    round(100.0 * avg((trajectory = 'around'::text AND destination = 'in_behind'::text)::integer), 1) AS around_in_behind,
    round(100.0 * avg((trajectory = 'around'::text AND destination = 'outside'::text)::integer), 1) AS around_outside,
    round(100.0 * avg((trajectory = 'through'::text AND destination = 'inside'::text)::integer), 1) AS through_inside,
    round(100.0 * avg((trajectory = 'through'::text AND destination = 'in_behind'::text)::integer), 1) AS through_in_behind,
    round(100.0 * avg((trajectory = 'through'::text AND destination = 'outside'::text)::integer), 1) AS through_outside,
    round(100.0 * avg(completed::integer), 1) AS fwd_completion,
    round(100.0 * avg(completed::integer) FILTER (WHERE trajectory = 'over'::text), 1) AS comp_over,
    round(100.0 * avg(completed::integer) FILTER (WHERE trajectory = 'around'::text), 1) AS comp_around,
    round(100.0 * avg(completed::integer) FILTER (WHERE trajectory = 'through'::text), 1) AS comp_through
   FROM mv_pass_traj t
  GROUP BY player_id
 HAVING count(*) >= 60 with no data;
create materialized view public.mv_player_xt as  WITH pass_xt AS (
         SELECT events.player_id,
            sum(xt_at(events.end_x, events.end_y) - xt_at(events.x, events.y)) AS xt_pass,
            sum(GREATEST(xt_at(events.end_x, events.end_y) - xt_at(events.x, events.y), 0::numeric)) AS xt_pass_pos
           FROM v_league_events events
          WHERE events.type = 'Pass'::text AND events.outcome_type = 'Successful'::text AND events.is_open_play AND events.x IS NOT NULL AND events.y IS NOT NULL AND events.end_x IS NOT NULL AND events.end_y IS NOT NULL
          GROUP BY events.player_id
        ), carry_xt AS (
         SELECT mv_receipt_events.player_id,
            sum(xt_at(mv_receipt_events.end_x::double precision, mv_receipt_events.end_y::double precision) - xt_at(mv_receipt_events.start_x::double precision, mv_receipt_events.start_y::double precision)) AS xt_carry,
            sum(GREATEST(xt_at(mv_receipt_events.end_x::double precision, mv_receipt_events.end_y::double precision) - xt_at(mv_receipt_events.start_x::double precision, mv_receipt_events.start_y::double precision), 0::numeric)) AS xt_carry_pos
           FROM mv_receipt_events
          WHERE mv_receipt_events.is_carry
          GROUP BY mv_receipt_events.player_id
        )
 SELECT COALESCE(p.player_id, c.player_id) AS player_id,
    COALESCE(p.xt_pass, 0::numeric) AS xt_pass,
    COALESCE(c.xt_carry, 0::numeric) AS xt_carry,
    COALESCE(p.xt_pass, 0::numeric) + COALESCE(c.xt_carry, 0::numeric) AS xt_total,
    COALESCE(p.xt_pass_pos, 0::numeric) + COALESCE(c.xt_carry_pos, 0::numeric) AS xt_positive
   FROM pass_xt p
     FULL JOIN carry_xt c ON c.player_id = p.player_id with no data;
create materialized view public.mv_seq_state as  SELECT s.seq_uid,
    s.game_id,
    s.team,
    s.start_min,
    count(*) FILTER (WHERE gg.scoring_team = s.team) AS goals_for,
    count(*) FILTER (WHERE gg.scoring_team IS NOT NULL AND gg.scoring_team <> s.team) AS goals_against,
    count(*) FILTER (WHERE gg.scoring_team = s.team) - count(*) FILTER (WHERE gg.scoring_team IS NOT NULL AND gg.scoring_team <> s.team) AS margin,
        CASE
            WHEN count(*) FILTER (WHERE gg.scoring_team = s.team) > count(*) FILTER (WHERE gg.scoring_team IS NOT NULL AND gg.scoring_team <> s.team) THEN 'winning'::text
            WHEN count(*) FILTER (WHERE gg.scoring_team = s.team) < count(*) FILTER (WHERE gg.scoring_team IS NOT NULL AND gg.scoring_team <> s.team) THEN 'losing'::text
            ELSE 'drawing'::text
        END AS state,
    abs(count(*) FILTER (WHERE gg.scoring_team = s.team) - count(*) FILTER (WHERE gg.scoring_team IS NOT NULL AND gg.scoring_team <> s.team)) <= 1 AS is_close
   FROM v_league_sequences s
     LEFT JOIN mv_game_goals gg ON gg.game_id = s.game_id AND (gg.expanded_minute < s.start_min OR gg.expanded_minute = s.start_min AND gg.second <= COALESCE(s.start_sec, 0))
  GROUP BY s.seq_uid, s.game_id, s.team, s.start_min with no data;
create materialized view public.mv_state_segments as  WITH mlen AS (
         SELECT events.game_id,
            max(events.expanded_minute) + 1 AS end_min
           FROM v_league_events events
          GROUP BY events.game_id
        ), tg AS (
         SELECT DISTINCT events.game_id,
            events.team
           FROM v_league_events events
          WHERE events.team IS NOT NULL
        ), ev AS (
         SELECT tg.game_id,
            tg.team,
            g.expanded_minute AS t,
                CASE
                    WHEN g.scoring_team = tg.team THEN 1
                    ELSE '-1'::integer
                END AS d
           FROM tg
             JOIN mv_game_goals g ON g.game_id = tg.game_id
        ), run AS (
         SELECT ev.game_id,
            ev.team,
            ev.t,
            sum(ev.d) OVER (PARTITION BY ev.game_id, ev.team ORDER BY ev.t ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS margin
           FROM ev
        ), after_goals AS (
         SELECT r.game_id,
            r.team,
            r.t AS seg_start,
            COALESCE(lead(r.t) OVER (PARTITION BY r.game_id, r.team ORDER BY r.t), m.end_min) AS seg_end,
            r.margin
           FROM run r
             JOIN mlen m ON m.game_id = r.game_id
        ), before_first AS (
         SELECT tg.game_id,
            tg.team,
            0 AS seg_start,
            COALESCE(( SELECT min(e.t) AS min
                   FROM ev e
                  WHERE e.game_id = tg.game_id AND e.team = tg.team), m.end_min) AS seg_end,
            0 AS margin
           FROM tg
             JOIN mlen m ON m.game_id = tg.game_id
        )
 SELECT after_goals.game_id,
    after_goals.team,
    after_goals.seg_start,
    after_goals.seg_end,
    after_goals.margin
   FROM after_goals
UNION ALL
 SELECT before_first.game_id,
    before_first.team,
    before_first.seg_start,
    before_first.seg_end,
    before_first.margin
   FROM before_first with no data;
create materialized view public.mv_team_attackphase as  WITH m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        ), att AS (
         SELECT e.team,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.x >= 50::double precision AND e.outcome_type = 'Successful'::text) AS att_passes,
            COALESCE(sum(GREATEST(0::double precision, e.end_x - e.x) * 1.05::double precision) FILTER (WHERE e.type = 'Pass'::text AND e.x >= 50::double precision AND e.outcome_type = 'Successful'::text), 0::double precision) AS att_territory,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND e.x < 66.7::double precision AND e.end_x >= 66.7::double precision) AS ft_entries,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND e.end_x >= 83::double precision AND e.end_y >= 21::double precision AND e.end_y <= 79::double precision) AS box_entries,
            count(*) FILTER (WHERE e.is_shot) AS shots,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text) AS all_ok_passes
           FROM v_league_events e
          WHERE e.team IS NOT NULL AND e.x IS NOT NULL
          GROUP BY e.team
        ), tempo AS (
         SELECT mv_receipt_events.team,
            percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (mv_receipt_events.ttr::double precision)) FILTER (WHERE mv_receipt_events.end_x >= 66.7) AS ft_ttr,
            percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (mv_receipt_events.ttr::double precision)) FILTER (WHERE mv_receipt_events.end_x >= 33.3 AND mv_receipt_events.end_x < 66.7) AS mid_ttr
           FROM mv_receipt_events
          GROUP BY mv_receipt_events.team
        ), carries AS (
         SELECT mv_receipt_events.team,
            count(*) FILTER (WHERE mv_receipt_events.start_x < 66.7 AND mv_receipt_events.end_x >= 66.7) AS carry_entries
           FROM mv_receipt_events
          WHERE mv_receipt_events.is_carry
          GROUP BY mv_receipt_events.team
        ), seq AS (
         SELECT mv_team_sequences.team,
            count(*) FILTER (WHERE mv_team_sequences.max_x >= 66.7::double precision) AS reached_final,
            count(*) FILTER (WHERE mv_team_sequences.max_x >= 66.7::double precision AND mv_team_sequences.ended_in_shot) AS final_to_shot
           FROM mv_team_sequences
          GROUP BY mv_team_sequences.team
        )
 SELECT a.team,
    round((a.att_territory / NULLIF(a.att_passes, 0)::double precision)::numeric, 2) AS att_directness,
    round(t.ft_ttr::numeric, 2) AS ft_release,
    round(t.mid_ttr::numeric, 2) AS mid_release,
    round(a.all_ok_passes::numeric / NULLIF(a.shots, 0)::numeric, 1) AS passes_per_shot,
    round((a.ft_entries + COALESCE(c.carry_entries, 0::bigint))::numeric / NULLIF(m.matches, 0)::numeric, 1) AS ft_entries_pg,
    round(a.box_entries::numeric / NULLIF(m.matches, 0)::numeric, 1) AS box_entries_pg2,
    round(100.0 * a.box_entries::numeric / NULLIF(a.ft_entries + COALESCE(c.carry_entries, 0::bigint), 0)::numeric, 1) AS box_per_entry,
    round(100.0 * s.final_to_shot::numeric / NULLIF(s.reached_final, 0)::numeric, 1) AS final_to_shot_pct
   FROM att a
     JOIN m ON m.team = a.team
     LEFT JOIN tempo t ON t.team = a.team
     LEFT JOIN carries c ON c.team = a.team
     LEFT JOIN seq s ON s.team = a.team with no data;
create materialized view public.mv_team_breakdown as  WITH routes AS (
         SELECT s.team,
            tl.league,
            r.route,
            r.used,
            s.ended_shot,
            s.ended_in_box,
            s.xt_sum
           FROM v_league_sequences s
             JOIN mv_team_league tl ON tl.team = s.team
             CROSS JOIN LATERAL ( VALUES ('Through the middle'::text,s.finds_central), ('Around the outside'::text,s.finds_wide), ('Switch of play'::text,s.has_switch), ('Over the top'::text,s.long_ball), ('Wide combinations'::text,s.wide_triangles), ('Hold-up and lay'::text,s.hold_up), ('Patient build'::text,s.structured), ('From deep'::text,s.low_build), ('High regain'::text,s.high_build)) r(route, used)
          WHERE s.is_open_play
        ), agg AS (
         SELECT routes.team,
            routes.league,
            routes.route,
            count(*) FILTER (WHERE routes.used) AS seqs,
            round(100.0 * avg(routes.used::integer), 1) AS share_pct,
            round(100.0 * avg(routes.ended_shot::integer) FILTER (WHERE routes.used), 1) AS shot_pct,
            round(100.0 * avg(routes.ended_in_box::integer) FILTER (WHERE routes.used), 1) AS box_pct,
            round(avg(routes.xt_sum) FILTER (WHERE routes.used), 4) AS xt_per_seq
           FROM routes
          GROUP BY routes.team, routes.league, routes.route
        ), lg AS (
         SELECT agg.league,
            agg.route,
            avg(agg.shot_pct) AS lg_shot,
            stddev_samp(agg.shot_pct) AS sd_shot,
            avg(agg.share_pct) AS lg_share,
            stddev_samp(agg.share_pct) AS sd_share
           FROM agg
          GROUP BY agg.league, agg.route
        )
 SELECT a.team,
    a.league,
    a.route,
    a.seqs,
    a.share_pct,
    a.shot_pct,
    a.box_pct,
    a.xt_per_seq,
    rank() OVER (PARTITION BY a.league, a.route ORDER BY a.share_pct DESC) AS share_rank,
    rank() OVER (PARTITION BY a.league, a.route ORDER BY a.shot_pct DESC) AS productivity_rank,
    round((a.share_pct - lg.lg_share) / NULLIF(lg.sd_share, 0::numeric), 2) AS z_share,
    round((a.shot_pct - lg.lg_shot) / NULLIF(lg.sd_shot, 0::numeric), 2) AS z_productivity
   FROM agg a
     JOIN lg ON lg.league = a.league AND lg.route = a.route with no data;
create materialized view public.mv_team_buildup as  WITH s AS (
         SELECT mv_team_sequences.game_id,
            mv_team_sequences.seq_id,
            mv_team_sequences.team,
            mv_team_sequences.actions,
            mv_team_sequences.passes,
            mv_team_sequences.duration_s,
            mv_team_sequences.start_x,
            mv_team_sequences.max_x,
            mv_team_sequences.ended_in_shot
           FROM mv_team_sequences
        ), m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        )
 SELECT s.team,
    count(*) AS sequences,
    round(count(*)::numeric / NULLIF(m.matches, 0)::numeric, 1) AS sequences_pg,
    round(avg(s.passes), 2) AS passes_per_seq,
    round(avg(s.duration_s), 1) AS secs_per_seq,
    round(100.0 * count(*) FILTER (WHERE s.ended_in_shot)::numeric / count(*)::numeric, 1) AS pct_ending_in_shot,
    round(100.0 * count(*) FILTER (WHERE s.start_x < 50::double precision AND s.ended_in_shot AND s.duration_s <= 15)::numeric / NULLIF(count(*) FILTER (WHERE s.start_x < 50::double precision), 0)::numeric, 2) AS direct_attack_pct,
    round(100.0 * count(*) FILTER (WHERE s.passes >= 6)::numeric / count(*)::numeric, 1) AS long_sequence_pct,
    round(avg(s.max_x - s.start_x)::numeric, 1) AS ground_gained,
    round(avg(s.passes) FILTER (WHERE s.ended_in_shot), 2) AS passes_before_shot,
    round(avg(s.duration_s) FILTER (WHERE s.ended_in_shot), 1) AS secs_before_shot
   FROM s
     JOIN m ON m.team = s.team
  GROUP BY s.team, m.matches with no data;
create materialized view public.mv_team_carry_zones as  WITH c AS (
         SELECT r.team,
            LEAST(11, GREATEST(0, floor(r.start_x / 100::numeric * 12::numeric)::integer)) AS zx,
            LEAST(7, GREATEST(0, floor(r.start_y / 100::numeric * 8::numeric)::integer)) AS zy,
            r.is_progressive,
            r.into_box,
            r.carry_m
           FROM mv_receipt_events r
          WHERE r.is_carry
        ), m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        )
 SELECT c.team,
    c.zx,
    c.zy,
    count(*) AS carries,
    count(*) FILTER (WHERE c.is_progressive) AS prog_carries,
    count(*) FILTER (WHERE c.into_box) AS carries_into_box,
    round(avg(c.carry_m), 1) AS mean_m,
    round(count(*)::numeric / NULLIF(m.matches, 0)::numeric, 2) AS carries_pg
   FROM c
     JOIN m ON m.team = c.team
  GROUP BY c.team, c.zx, c.zy, m.matches with no data;
create materialized view public.mv_team_season as  SELECT team,
    count(*) AS matches,
    round(avg(possession_pct), 1) AS possession_pct,
    round(avg(field_tilt), 1) AS field_tilt,
    round(avg(ppda), 2) AS ppda,
    round(avg(def_height), 1) AS def_height,
    round(avg(avg_touch_x), 1) AS avg_touch_x,
    round(avg(long_ball_pct), 1) AS long_ball_pct,
    round(avg(build_from_back_pct), 1) AS build_from_back_pct,
    round(avg(directness), 2) AS directness,
    round(avg(prog_passes), 1) AS prog_passes_pg,
    round(avg(box_entries_pass), 1) AS box_entries_pg,
    round(avg(crosses), 1) AS crosses_pg,
    round(avg(shots), 1) AS shots_pg,
    round(avg(opp_shots), 1) AS shots_against_pg,
    round(avg(goals), 2) AS goals_pg,
    round(avg(opp_goals), 2) AS goals_against_pg,
    round(avg(open_play_shot_pct), 1) AS open_play_shot_pct
   FROM mv_team_match
  GROUP BY team with no data;
create materialized view public.mv_team_stat_ranks as  WITH per AS (
         SELECT s.team,
            count(*) AS matches,
            avg(s.final_third_passes) AS final_third_passes,
            avg(s.zone14_passes) AS zone14_passes,
            avg(s.progressive_passes) AS progressive_passes,
            avg(s.passes_into_box) AS passes_into_box,
            avg(s.defensive_actions) AS defensive_actions,
            avg(s.defensive_actions_won) AS defensive_actions_won,
            avg(s.shots) AS shots,
            avg(s.shots_on_target) AS shots_on_target,
            avg(s.fwd_passes) AS fwd_passes,
            avg(s.lat_passes) AS lat_passes,
            avg(s.bwd_passes) AS bwd_passes
           FROM v_season_stats s
          GROUP BY s.team
        ), long AS (
         SELECT per.team,
            tl.league,
            v.metric,
            v.value
           FROM per
             JOIN mv_team_league tl ON tl.team = per.team
             CROSS JOIN LATERAL ( VALUES ('final_third_passes'::text,per.final_third_passes), ('zone14_passes'::text,per.zone14_passes), ('progressive_passes'::text,per.progressive_passes), ('passes_into_box'::text,per.passes_into_box), ('defensive_actions'::text,per.defensive_actions), ('defensive_actions_won'::text,per.defensive_actions_won), ('shots'::text,per.shots), ('shots_on_target'::text,per.shots_on_target), ('fwd_passes'::text,per.fwd_passes), ('lat_passes'::text,per.lat_passes), ('bwd_passes'::text,per.bwd_passes)) v(metric, value)
        )
 SELECT team,
    metric,
    round(value, 2) AS per_game,
    rank() OVER (PARTITION BY league, metric ORDER BY value DESC) AS league_rank,
    count(*) OVER (PARTITION BY league, metric) AS of_teams,
    league
   FROM long with no data;
create materialized view public.mv_team_zones as  WITH e AS (
         SELECT events.team,
            LEAST(11, GREATEST(0, floor(events.x / 100::double precision * 12::double precision)::integer)) AS zx,
            LEAST(7, GREATEST(0, floor(events.y / 100::double precision * 8::double precision)::integer)) AS zy,
            events.type,
            events.is_shot,
            events.is_open_play,
            events.outcome_type = 'Successful'::text AS ok,
            events.type = 'Pass'::text AND events.x IS NOT NULL AND events.end_x IS NOT NULL AND (events.x < 50::double precision AND events.end_x < 50::double precision AND (events.end_x - events.x) >= 30::double precision OR events.x < 50::double precision AND events.end_x >= 50::double precision AND (events.end_x - events.x) >= 15::double precision OR events.x >= 50::double precision AND events.end_x >= 50::double precision AND (events.end_x - events.x) >= 10::double precision) AS prog
           FROM v_league_events events
          WHERE events.team IS NOT NULL AND events.x IS NOT NULL AND events.y IS NOT NULL AND (events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideProvoked'::text]))
        ), m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        )
 SELECT e.team,
    e.zx,
    e.zy,
    count(*) AS touches,
    count(*) FILTER (WHERE e.type = 'Pass'::text AND e.ok) AS passes,
    count(*) FILTER (WHERE e.prog AND e.ok) AS prog_passes,
    count(*) FILTER (WHERE e.is_shot) AS shots,
    count(*) FILTER (WHERE e.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Clearance'::text, 'Challenge'::text])) AS def_actions,
    round(count(*)::numeric / NULLIF(m.matches, 0)::numeric, 2) AS touches_pg
   FROM e
     JOIN m ON m.team = e.team
  GROUP BY e.team, e.zx, e.zy, m.matches with no data;
create materialized view public.mv_xg_bins as  WITH s AS (
         SELECT mv_shot_features.game_id,
            mv_shot_features.ws_id,
            mv_shot_features.player_id,
            mv_shot_features.player,
            mv_shot_features.team,
            mv_shot_features.is_goal,
            mv_shot_features.is_open_play,
            mv_shot_features.type,
            mv_shot_features.x,
            mv_shot_features.y,
            mv_shot_features.dist_m,
            mv_shot_features.angle_deg,
            mv_shot_features.is_header,
            mv_shot_features.is_bigchance,
            mv_shot_features.is_pen,
            mv_shot_features.is_blocked,
            mv_shot_features.outcome,
                CASE
                    WHEN mv_shot_features.dist_m < 6::double precision THEN 1
                    WHEN mv_shot_features.dist_m < 11::double precision THEN 2
                    WHEN mv_shot_features.dist_m < 16::double precision THEN 3
                    WHEN mv_shot_features.dist_m < 22::double precision THEN 4
                    WHEN mv_shot_features.dist_m < 30::double precision THEN 5
                    ELSE 6
                END AS d_bin,
                CASE
                    WHEN mv_shot_features.angle_deg < 12::double precision THEN 1
                    WHEN mv_shot_features.angle_deg < 25::double precision THEN 2
                    ELSE 3
                END AS a_bin
           FROM mv_shot_features
          WHERE NOT mv_shot_features.is_pen
        ), g AS (
         SELECT avg(
                CASE
                    WHEN s_1.is_goal THEN 1.0
                    ELSE 0::numeric
                END) AS base
           FROM s s_1
        )
 SELECT s.d_bin,
    s.a_bin,
    s.is_header,
    s.is_bigchance,
    count(*) AS n,
    sum(
        CASE
            WHEN s.is_goal THEN 1
            ELSE 0
        END) AS goals,
    round((sum(
        CASE
            WHEN s.is_goal THEN 1
            ELSE 0
        END)::numeric + 20::numeric * g.base) / (count(*) + 20)::numeric, 4) AS xg
   FROM s
     CROSS JOIN g
  GROUP BY s.d_bin, s.a_bin, s.is_header, s.is_bigchance, g.base with no data;
create view public.team_sequence_style as  WITH u AS (
         SELECT a.team,
            m.metric,
            m.raw
           FROM team_sequence_agg a
             CROSS JOIN LATERAL ( VALUES ('seqs_per_match'::text,a.seqs_per_match), ('passes_seq'::text,a.passes_seq), ('seconds_seq'::text,a.seconds_seq), ('players_seq'::text,a.players_seq), ('xt_seq'::text,a.xt_seq), ('low_build_pct'::text,a.low_build_pct), ('high_build_pct'::text,a.high_build_pct), ('structured_pct'::text,a.structured_pct), ('very_short_pct'::text,a.very_short_pct), ('long_pct'::text,a.long_pct), ('switches_pct'::text,a.switches_pct), ('wide_tri_pct'::text,a.wide_tri_pct), ('hold_up_pct'::text,a.hold_up_pct), ('ends_opp_half_pct'::text,a.ends_opp_half_pct), ('ends_def_third_pct'::text,a.ends_def_third_pct), ('end_att_third_pct'::text,a.end_att_third_pct), ('end_in_box_pct'::text,a.end_in_box_pct), ('end_around_box_pct'::text,a.end_around_box_pct), ('finds_central_pct'::text,a.finds_central_pct), ('finds_wide_pct'::text,a.finds_wide_pct), ('ends_in_shot_pct'::text,a.ends_in_shot_pct), ('central_prog_share'::text,a.central_prog_share), ('wide_pass_pct'::text,a.wide_pass_pct)) m(metric, raw)
        )
 SELECT team,
    metric,
    raw,
    round((raw - avg(raw) OVER (PARTITION BY metric)) / NULLIF(stddev_samp(raw) OVER (PARTITION BY metric), 0::numeric), 2) AS z
   FROM u;

-- === relation_options ===
alter view public.team_sequence_style set (security_invoker=true);

-- === relations ===
create view public.v_player_carries as  SELECT player_id,
    game_id,
    start_x,
    start_y,
    end_x,
    end_y,
    carry_m,
    is_progressive,
    into_box,
    ttr,
    release_type
   FROM mv_receipt_events
  WHERE is_carry;

-- === relation_options ===
alter view public.v_player_carries set (security_invoker=true);

-- === relations ===
create view public.v_player_receipts as  SELECT player_id,
    game_id,
    start_x,
    start_y,
    end_x,
    end_y,
    ttr,
    release_type,
    is_carry
   FROM mv_receipt_events;

-- === relation_options ===
alter view public.v_player_receipts set (security_invoker=true);

-- === relations ===
create view public.v_player_xt_actions as  SELECT e.player_id,
    e.game_id,
    'pass'::text AS kind,
    e.x,
    e.y,
    e.end_x,
    e.end_y,
    round(xt_at(e.end_x, e.end_y) - xt_at(e.x, e.y), 4) AS xt,
    e.expanded_minute AS minute
   FROM v_league_events e
  WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND e.is_open_play AND e.x IS NOT NULL AND e.y IS NOT NULL AND e.end_x IS NOT NULL AND e.end_y IS NOT NULL AND e.player_id IS NOT NULL
UNION ALL
 SELECT r.player_id,
    r.game_id,
    'carry'::text AS kind,
    r.start_x AS x,
    r.start_y AS y,
    r.end_x,
    r.end_y,
    round(xt_at(r.end_x::double precision, r.end_y::double precision) - xt_at(r.start_x::double precision, r.start_y::double precision), 4) AS xt,
    NULL::integer AS minute
   FROM mv_receipt_events r
  WHERE r.is_carry AND r.player_id IS NOT NULL AND r.start_x IS NOT NULL AND r.end_x IS NOT NULL;

-- === relation_options ===
alter view public.v_player_xt_actions set (security_invoker=true);

-- === relations ===
create view public.v_press_profile as  WITH lg AS (
         SELECT mv_press_vs_buildup.league,
            mv_press_vs_buildup.buildup_type,
            avg(mv_press_vs_buildup.contained_pct) AS lg_contained,
            stddev_samp(mv_press_vs_buildup.contained_pct) AS sd_contained,
            avg(mv_press_vs_buildup.conceded_shot_pct) AS lg_shot,
            stddev_samp(mv_press_vs_buildup.conceded_shot_pct) AS sd_shot
           FROM mv_press_vs_buildup
          GROUP BY mv_press_vs_buildup.league, mv_press_vs_buildup.buildup_type
        ), z AS (
         SELECT p.defending_team AS team,
            p.league,
            p.buildup_type,
            p.n,
            p.contained_pct,
            p.conceded_shot_pct,
            round((p.contained_pct - lg.lg_contained) / NULLIF(lg.sd_contained, 0::numeric), 2) AS z_contained,
            round((lg.lg_shot - p.conceded_shot_pct) / NULLIF(lg.sd_shot, 0::numeric), 2) AS z_shot_prevention
           FROM mv_press_vs_buildup p
             JOIN lg ON lg.league = p.league AND lg.buildup_type = p.buildup_type
        )
 SELECT team,
    max(z_contained) FILTER (WHERE buildup_type = 'short_build'::text) AS z_vs_short_build,
    max(z_contained) FILTER (WHERE buildup_type = 'direct'::text) AS z_vs_direct,
    max(z_contained) FILTER (WHERE buildup_type = 'high_start'::text) AS z_vs_high_start,
    max(z_shot_prevention) FILTER (WHERE buildup_type = 'short_build'::text) AS z_shotprev_vs_short,
    max(z_shot_prevention) FILTER (WHERE buildup_type = 'direct'::text) AS z_shotprev_vs_direct,
    round(max(z_contained) FILTER (WHERE buildup_type = 'short_build'::text) - max(z_contained) FILTER (WHERE buildup_type = 'direct'::text), 2) AS short_vs_direct_tilt,
    max(contained_pct) FILTER (WHERE buildup_type = 'short_build'::text) AS raw_vs_short_build,
    max(contained_pct) FILTER (WHERE buildup_type = 'direct'::text) AS raw_vs_direct,
    min(league) AS league
   FROM z
  GROUP BY team;

-- === relation_options ===
alter view public.v_press_profile set (security_invoker=true);

-- === relations ===
create view public.v_team_carries as  SELECT team,
    start_x,
    start_y,
    end_x,
    end_y,
    carry_m,
    is_progressive,
    into_box
   FROM mv_receipt_events
  WHERE is_carry;

-- === relation_options ===
alter view public.v_team_carries set (security_invoker=true);

-- === relations ===
create view public.v_xg_temporal_holdout as  WITH ordered_matches AS (
         SELECT m.game_id,
            m.date,
            row_number() OVER (ORDER BY m.date, m.game_id) AS match_no,
            count(*) OVER () AS match_count
           FROM v_league_matches m
          WHERE (EXISTS ( SELECT 1
                   FROM mv_shot_features f
                  WHERE f.game_id = m.game_id))
        ), shots AS (
         SELECT f.game_id,
            f.ws_id,
            f.player_id,
            f.player,
            f.team,
            f.is_goal,
            f.is_open_play,
            f.type,
            f.x,
            f.y,
            f.dist_m,
            f.angle_deg,
            f.is_header,
            f.is_bigchance,
            f.is_pen,
            f.is_blocked,
            f.outcome,
            om.date,
            om.match_no::numeric <= GREATEST(1::numeric, floor(om.match_count::numeric * 0.8)) AS is_training,
                CASE
                    WHEN f.dist_m < 6::double precision THEN 1
                    WHEN f.dist_m < 11::double precision THEN 2
                    WHEN f.dist_m < 16::double precision THEN 3
                    WHEN f.dist_m < 22::double precision THEN 4
                    WHEN f.dist_m < 30::double precision THEN 5
                    ELSE 6
                END AS d_bin,
                CASE
                    WHEN f.angle_deg < 12::double precision THEN 1
                    WHEN f.angle_deg < 25::double precision THEN 2
                    ELSE 3
                END AS a_bin
           FROM mv_shot_features f
             JOIN ordered_matches om ON om.game_id = f.game_id
          WHERE NOT f.is_pen
        ), training_base AS (
         SELECT avg(shots.is_goal::integer) AS rate
           FROM shots
          WHERE shots.is_training
        ), shape_rates AS (
         SELECT s.is_header,
            s.is_bigchance,
            count(*) AS n,
            sum(s.is_goal::integer) AS goals,
            (sum(s.is_goal::integer)::numeric + 50::numeric * b.rate) / (count(*) + 50)::numeric AS rate
           FROM shots s
             CROSS JOIN training_base b
          WHERE s.is_training
          GROUP BY s.is_header, s.is_bigchance, b.rate
        ), cell_rates AS (
         SELECT s.d_bin,
            s.a_bin,
            s.is_header,
            s.is_bigchance,
            count(*) AS n,
            sum(s.is_goal::integer) AS goals,
            (sum(s.is_goal::integer)::numeric + 20::numeric * sr.rate) / (count(*) + 20)::numeric AS rate
           FROM shots s
             JOIN shape_rates sr USING (is_header, is_bigchance)
          WHERE s.is_training
          GROUP BY s.d_bin, s.a_bin, s.is_header, s.is_bigchance, sr.rate
        ), scored AS (
         SELECT s.game_id,
            s.ws_id,
            s.player_id,
            s.player,
            s.team,
            s.is_goal,
            s.is_open_play,
            s.type,
            s.x,
            s.y,
            s.dist_m,
            s.angle_deg,
            s.is_header,
            s.is_bigchance,
            s.is_pen,
            s.is_blocked,
            s.outcome,
            s.date,
            s.is_training,
            s.d_bin,
            s.a_bin,
            LEAST(0.999, GREATEST(0.001, COALESCE(cr.rate, sr.rate, b.rate))) AS predicted_xg
           FROM shots s
             CROSS JOIN training_base b
             LEFT JOIN shape_rates sr USING (is_header, is_bigchance)
             LEFT JOIN cell_rates cr USING (d_bin, a_bin, is_header, is_bigchance)
          WHERE NOT s.is_training
        )
 SELECT (( SELECT count(*) AS count
           FROM shots
          WHERE shots.is_training))::integer AS training_shots,
    count(*)::integer AS validation_shots,
    min(date) AS validation_from,
    max(date) AS validation_through,
    round(avg(power(predicted_xg - is_goal::integer::numeric, 2::numeric)), 5) AS brier_score,
    round(avg(- (is_goal::integer::numeric * ln(predicted_xg) + (1 - is_goal::integer)::numeric * ln(1::numeric - predicted_xg))), 5) AS log_loss,
    round(sum(predicted_xg), 2) AS predicted_goals,
    sum(is_goal::integer)::integer AS actual_goals,
    round(100::numeric * (sum(predicted_xg) - sum(is_goal::integer)::numeric) / NULLIF(sum(is_goal::integer), 0)::numeric, 1) AS goal_error_pct,
    round(max(predicted_xg), 4) AS maximum_prediction,
    true AS temporal_holdout,
    true AS out_of_sample_tested
   FROM scored;

-- === relation_options ===
alter view public.v_xg_temporal_holdout set (security_invoker=true);

-- === relations ===
create materialized view public.mv_player_leverage as  SELECT pm.player_id,
    pm.team,
    sum(pm.minutes) AS minutes_total,
    round(100.0 * sum(GREATEST(0, LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start))) FILTER (WHERE abs(sg.margin) <= 1)::numeric / NULLIF(sum(GREATEST(0, LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start))), 0)::numeric, 1) AS leverage_pct
   FROM mv_player_stints pm
     JOIN mv_state_segments sg ON sg.game_id = pm.game_id AND sg.team = pm.team AND sg.seg_start < pm.end_min AND sg.seg_end > pm.start_min
  GROUP BY pm.player_id, pm.team with no data;
create materialized view public.mv_player_pool as  WITH mins_by_pos AS (
         SELECT mv_player_minutes.player_id,
            mv_player_minutes."position",
            sum(mv_player_minutes.minutes) AS mins
           FROM mv_player_minutes
          WHERE mv_player_minutes.is_starter AND mv_player_minutes."position" <> 'Sub'::text
          GROUP BY mv_player_minutes.player_id, mv_player_minutes."position"
        ), modal AS (
         SELECT DISTINCT ON (mins_by_pos.player_id) mins_by_pos.player_id,
            mins_by_pos."position" AS modal_position
           FROM mins_by_pos
          ORDER BY mins_by_pos.player_id, mins_by_pos.mins DESC, mins_by_pos."position"
        )
 SELECT player_id,
    modal_position,
        CASE modal_position
            WHEN 'GK'::text THEN 'GK'::text
            WHEN 'DC'::text THEN 'CB'::text
            WHEN 'DR'::text THEN 'FB'::text
            WHEN 'DL'::text THEN 'FB'::text
            WHEN 'DML'::text THEN 'FB'::text
            WHEN 'DMR'::text THEN 'FB'::text
            WHEN 'DMC'::text THEN 'CM'::text
            WHEN 'MC'::text THEN 'CM'::text
            WHEN 'AMC'::text THEN 'AM'::text
            WHEN 'ML'::text THEN 'W'::text
            WHEN 'MR'::text THEN 'W'::text
            WHEN 'AML'::text THEN 'W'::text
            WHEN 'AMR'::text THEN 'W'::text
            WHEN 'FWL'::text THEN 'W'::text
            WHEN 'FWR'::text THEN 'W'::text
            WHEN 'FW'::text THEN 'ST'::text
            ELSE NULL::text
        END AS listed_pool,
        CASE
            WHEN modal_position = ANY (ARRAY['DL'::text, 'ML'::text, 'AML'::text, 'FWL'::text, 'DML'::text]) THEN 'L'::text
            WHEN modal_position = ANY (ARRAY['DR'::text, 'MR'::text, 'AMR'::text, 'FWR'::text, 'DMR'::text]) THEN 'R'::text
            ELSE 'C'::text
        END AS nominal_side
   FROM modal with no data;
create materialized view public.mv_player_season as  SELECT m.player_id,
    p.player_name,
    mode() WITHIN GROUP (ORDER BY m.team) AS team,
    count(*) AS apps,
    count(*) FILTER (WHERE m.is_starter) AS starts,
    round(sum(m.minutes), 0) AS minutes,
    round(sum(m.minutes) / 90.0, 2) AS nineties
   FROM mv_player_minutes m
     JOIN mv_player_league pl ON pl.player_id = m.player_id
     JOIN v_league_matches lm ON lm.game_id = m.game_id AND lm.league = pl.league
     JOIN players p ON p.player_id = m.player_id
  GROUP BY m.player_id, p.player_name with no data;
create materialized view public.mv_player_team_poss as  SELECT m.player_id,
    round(sum(t.possession_pct * m.minutes) / NULLIF(sum(m.minutes), 0::numeric), 2) AS team_possession
   FROM mv_player_minutes m
     JOIN mv_team_match t ON t.game_id = m.game_id AND t.team = m.team
  GROUP BY m.player_id with no data;
create materialized view public.mv_shot_xg as  SELECT f.game_id,
    f.ws_id,
    f.player_id,
    f.player,
    f.team,
    f.is_goal,
    f.is_open_play,
    f.is_pen,
    f.is_blocked,
    f.outcome,
    round(f.dist_m::numeric, 1) AS dist_m,
    round(f.angle_deg::numeric, 1) AS angle_deg,
    f.is_header,
    f.is_bigchance,
        CASE
            WHEN f.is_pen THEN 0.76
            ELSE COALESCE(b.xg, 0.05)
        END AS xg
   FROM mv_shot_features f
     LEFT JOIN mv_xg_bins b ON b.d_bin =
        CASE
            WHEN f.dist_m < 6::double precision THEN 1
            WHEN f.dist_m < 11::double precision THEN 2
            WHEN f.dist_m < 16::double precision THEN 3
            WHEN f.dist_m < 22::double precision THEN 4
            WHEN f.dist_m < 30::double precision THEN 5
            ELSE 6
        END AND b.a_bin =
        CASE
            WHEN f.angle_deg < 12::double precision THEN 1
            WHEN f.angle_deg < 25::double precision THEN 2
            ELSE 3
        END AND b.is_header = f.is_header AND b.is_bigchance = f.is_bigchance with no data;
create view public.v_seq_directness as  SELECT s.seq_uid,
    s.game_id,
    s.team,
    s.n_pass,
    s.dur_s,
    GREATEST('-1.0'::numeric, LEAST(1.0, (s.end_x - s.start_x)::numeric / NULLIF(s.mean_pass_len * s.n_pass::numeric, 0::numeric))) AS directness,
    st.state,
    st.margin,
    st.is_close
   FROM v_league_sequences s
     JOIN mv_seq_state st USING (seq_uid)
  WHERE s.is_open_play AND s.n_pass >= 2 AND COALESCE(s.mean_pass_len, 0::numeric) > 0::numeric;

-- === relation_options ===
alter view public.v_seq_directness set (security_invoker=true);

-- === relations ===
create view public.v_team_sample as  SELECT s.team,
    min(s.league) AS league,
    count(DISTINCT s.game_id) AS matches,
    count(*) FILTER (WHERE s.is_open_play) AS open_play_seqs,
    count(*) FILTER (WHERE s.is_open_play AND s.start_x < 33.3::double precision) AS deep_start_seqs,
    count(*) FILTER (WHERE s.is_open_play AND st.state = 'winning'::text) AS seqs_winning,
    count(*) FILTER (WHERE s.is_open_play AND st.state = 'losing'::text) AS seqs_losing,
    count(DISTINCT s.game_id) >= 6 AS meets_min_matches
   FROM v_league_sequences s
     LEFT JOIN mv_seq_state st ON st.seq_uid = s.seq_uid
  GROUP BY s.team;

-- === relation_options ===
alter view public.v_team_sample set (security_invoker=true);

-- === relations ===
create view public.v_team_signature as  SELECT DISTINCT ON (team) team,
    route AS signature_route,
    share_pct,
    z_share,
    shot_pct,
    z_productivity,
        CASE
            WHEN z_productivity >= 0.5 THEN 'effective'::text
            WHEN z_productivity <= '-0.5'::numeric THEN 'unproductive'::text
            ELSE 'league average'::text
        END AS signature_verdict,
    league
   FROM mv_team_breakdown
  ORDER BY team, z_share DESC;

-- === relation_options ===
alter view public.v_team_signature set (security_invoker=true);

-- === relations ===
create materialized view public.mv_gk_match as  WITH gk AS (
         SELECT DISTINCT ON (m.game_id, m.team) m.game_id,
            m.team,
            m.player_id,
            m.minutes
           FROM mv_player_minutes m
             JOIN mv_player_pool p ON p.player_id = m.player_id
          WHERE p.modal_position = 'GK'::text
          ORDER BY m.game_id, m.team, m.minutes DESC
        ), faced AS (
         SELECT g.game_id,
            g.team,
            g.player_id,
            g.minutes,
            count(*) FILTER (WHERE x.game_id IS NOT NULL) AS shots_faced,
            count(*) FILTER (WHERE x.is_goal) AS goals_conceded,
            round(sum(x.xg) FILTER (WHERE x.outcome = ANY (ARRAY['saved'::text, 'goal'::text])), 3) AS xg_on_target_faced
           FROM gk g
             LEFT JOIN mv_shot_xg x ON x.game_id = g.game_id AND x.team <> g.team
          GROUP BY g.game_id, g.team, g.player_id, g.minutes
        )
 SELECT game_id,
    team,
    player_id,
    minutes,
    shots_faced,
    goals_conceded,
    xg_on_target_faced
   FROM faced with no data;
create materialized view public.mv_league_availability as  WITH ev AS (
         SELECT events.league,
            count(DISTINCT events.game_id) AS matches
           FROM v_league_events events
          GROUP BY events.league
        ), ts AS (
         SELECT v_team_sample.league,
            count(*) FILTER (WHERE v_team_sample.meets_min_matches) AS qualifying,
            count(*) AS total
           FROM v_team_sample
          GROUP BY v_team_sample.league
        ), ins AS (
         SELECT tl.league,
            count(*) AS n
           FROM insights i
             JOIN mv_team_league tl ON tl.team = i.team
          GROUP BY tl.league
        )
 SELECT l.league,
    l.display_name,
    COALESCE(ev.matches, 0::bigint) AS matches,
    COALESCE(ts.qualifying, 0::bigint) AS clubs_at_threshold,
    COALESCE(ts.total, 0::bigint) AS clubs,
    COALESCE(ins.n, 0::bigint) AS insights,
    ( SELECT detector_requirements.min_matches
           FROM detector_requirements
          WHERE detector_requirements.detector = 'team_profile'::text) AS min_matches_required,
        CASE
            WHEN COALESCE(ts.qualifying, 0::bigint) > 0 THEN 'available'::text
            WHEN COALESCE(ev.matches, 0::bigint) = 0 THEN 'no data yet'::text
            ELSE 'below sample threshold'::text
        END AS insight_status
   FROM leagues l
     LEFT JOIN ev ON ev.league = l.league
     LEFT JOIN ts ON ts.league = l.league
     LEFT JOIN ins ON ins.league = l.league
  WHERE l.is_active with no data;
create materialized view public.mv_player_metrics_raw as  WITH ev AS (
         SELECT e.player_id,
            e.type,
            e.is_shot,
            e.is_open_play,
            e.x,
            e.y,
            e.end_x,
            e.end_y,
            e.outcome_type = 'Successful'::text AS ok,
            e.type = 'Pass'::text AND e.x IS NOT NULL AND e.end_x IS NOT NULL AND (e.x < 50::double precision AND e.end_x < 50::double precision AND (e.end_x - e.x) >= 30::double precision OR e.x < 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 15::double precision OR e.x >= 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 10::double precision) AS prog,
            e.qualifiers @> '[{"type": {"displayName": "Cross"}}]'::jsonb AS q_cross,
            e.qualifiers @> '[{"type": {"displayName": "Throughball"}}]'::jsonb AS q_through,
            e.qualifiers @> '[{"type": {"displayName": "KeyPass"}}]'::jsonb AS q_keypass,
            e.qualifiers @> '[{"type": {"displayName": "IntentionalGoalAssist"}}]'::jsonb AS q_assist,
            e.qualifiers @> '[{"type": {"displayName": "BigChanceCreated"}}]'::jsonb AS q_bcc,
            e.qualifiers @> '[{"type": {"displayName": "BigChance"}}]'::jsonb AS q_bigchance,
            e.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb AS q_long,
            e.qualifiers @> '[{"type": {"displayName": "Head"}}]'::jsonb AS q_head,
            e.qualifiers @> '[{"type": {"displayName": "RightFoot"}}]'::jsonb AS q_rf,
            e.qualifiers @> '[{"type": {"displayName": "LeftFoot"}}]'::jsonb AS q_lf
           FROM v_league_events e
          WHERE e.player_id IS NOT NULL
        ), agg AS (
         SELECT ev.player_id,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play) AS pass_att,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.ok) AS pass_cmp,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.prog) AS prog_att,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.prog AND ev.ok) AS prog_cmp,
            COALESCE(sum(GREATEST(0::double precision, ev.end_x - ev.x) * 1.05::double precision) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.ok), 0::double precision) AS territory_gained,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.ok AND ev.end_x >= 83::double precision AND ev.end_y >= 21::double precision AND ev.end_y <= 79::double precision) AS into_box,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.ok AND ev.end_x >= 66.7::double precision) AS final_third_passes,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.q_cross) AS cross_att,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.q_cross AND ev.ok) AS cross_cmp,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.q_through) AS through_balls,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.q_keypass) AS key_passes,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.q_assist) AS assists,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.q_bcc) AS big_chances_created,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.q_long) AS long_att,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.q_long AND ev.ok) AS long_cmp,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.ok AND ev.end_x > (ev.x + 3::double precision)) AS fwd_passes,
            count(*) FILTER (WHERE ev.type = 'Pass'::text AND ev.is_open_play AND ev.ok AND ev.end_x < (ev.x - 3::double precision)) AS bwd_passes,
            count(*) FILTER (WHERE ev.is_shot AND ev.is_open_play) AS shots,
            count(*) FILTER (WHERE ev.is_open_play AND (ev.type = ANY (ARRAY['SavedShot'::text, 'Goal'::text]))) AS sot,
            count(*) FILTER (WHERE ev.is_open_play AND ev.type = 'Goal'::text) AS goals,
            count(*) FILTER (WHERE ev.is_shot AND ev.is_open_play AND ev.x >= 83::double precision AND ev.y >= 21::double precision AND ev.y <= 79::double precision) AS shots_in_box,
            count(*) FILTER (WHERE ev.is_shot AND ev.is_open_play AND ev.q_bigchance) AS big_chance_shots,
            count(*) FILTER (WHERE ev.is_shot AND ev.is_open_play AND ev.q_head) AS headed_shots,
            count(*) FILTER (WHERE ev.is_shot AND ev.is_open_play AND ev.q_rf) AS rf_shots,
            count(*) FILTER (WHERE ev.is_shot AND ev.is_open_play AND ev.q_lf) AS lf_shots,
            COALESCE(sum(sqrt(power((100::double precision - ev.x) * 1.05::double precision, 2::double precision) + power((50::double precision - ev.y) * 0.68::double precision, 2::double precision))) FILTER (WHERE ev.is_shot AND ev.is_open_play), 0::double precision) AS shot_dist_sum,
            count(*) FILTER (WHERE ev.type = 'Tackle'::text) AS tackle_att,
            count(*) FILTER (WHERE ev.type = 'Tackle'::text AND ev.ok) AS tackle_won,
            count(*) FILTER (WHERE ev.type = 'Interception'::text) AS interceptions,
            count(*) FILTER (WHERE ev.type = 'Clearance'::text) AS clearances,
            count(*) FILTER (WHERE ev.type = 'BlockedPass'::text) AS blocks,
            count(*) FILTER (WHERE ev.type = 'BallRecovery'::text) AS recoveries,
            count(*) FILTER (WHERE ev.type = 'Aerial'::text) AS aerial_att,
            count(*) FILTER (WHERE ev.type = 'Aerial'::text AND ev.ok) AS aerial_won,
            count(*) FILTER (WHERE ev.type = 'Challenge'::text) AS challenges_lost,
            count(*) FILTER (WHERE ev.type = 'Foul'::text AND NOT ev.ok) AS fouls_committed,
            count(*) FILTER (WHERE ev.type = 'Foul'::text AND ev.ok) AS fouls_won,
            count(*) FILTER (WHERE ev.type = 'Error'::text) AS errors,
            count(*) FILTER (WHERE ev.type = 'TakeOn'::text) AS takeon_att,
            count(*) FILTER (WHERE ev.type = 'TakeOn'::text AND ev.ok) AS takeon_won,
            count(*) FILTER (WHERE ev.type = 'Dispossessed'::text) AS dispossessed,
            count(*) FILTER (WHERE ev.type = 'BallTouch'::text AND NOT ev.ok) AS bad_touches,
            round(avg(ev.x) FILTER (WHERE ev.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text]))::numeric, 2) AS def_action_x
           FROM ev
          GROUP BY ev.player_id
        )
 SELECT a.player_id,
    a.pass_att,
    a.pass_cmp,
    a.prog_att,
    a.prog_cmp,
    a.territory_gained,
    a.into_box,
    a.final_third_passes,
    a.cross_att,
    a.cross_cmp,
    a.through_balls,
    a.key_passes,
    a.assists,
    a.big_chances_created,
    a.long_att,
    a.long_cmp,
    a.fwd_passes,
    a.bwd_passes,
    a.shots,
    a.sot,
    a.goals,
    a.shots_in_box,
    a.big_chance_shots,
    a.headed_shots,
    a.rf_shots,
    a.lf_shots,
    a.shot_dist_sum,
    a.tackle_att,
    a.tackle_won,
    a.interceptions,
    a.clearances,
    a.blocks,
    a.recoveries,
    a.aerial_att,
    a.aerial_won,
    a.challenges_lost,
    a.fouls_committed,
    a.fouls_won,
    a.errors,
    a.takeon_att,
    a.takeon_won,
    a.dispossessed,
    a.bad_touches,
    a.def_action_x,
    s.player_name,
    s.team,
    s.nineties,
    s.minutes,
    s.apps,
    s.starts
   FROM agg a
     JOIN mv_player_season s ON s.player_id = a.player_id with no data;
create materialized view public.mv_player_role as  WITH elig AS (
         SELECT p.player_id,
            p.modal_position,
            p.listed_pool,
            p.nominal_side,
            s.nineties,
            t.touches,
            t.avg_x,
            t.centrality,
            t.pct_box,
            t.pct_def_third,
            d.pct_def_actions,
            s.nineties >= 6::numeric AND t.touches >= 200 AND p.listed_pool <> 'GK'::text AS classifiable
           FROM mv_player_pool p
             JOIN mv_player_season s USING (player_id)
             LEFT JOIN mv_player_territory t USING (player_id)
             LEFT JOIN mv_player_defload d USING (player_id)
        ), pop AS (
         SELECT elig.player_id,
            elig.modal_position,
            elig.listed_pool,
            elig.nominal_side,
            elig.nineties,
            elig.touches,
            elig.avg_x,
            elig.centrality,
            elig.pct_box,
            elig.pct_def_third,
            elig.pct_def_actions,
            elig.classifiable
           FROM elig
          WHERE elig.classifiable
        ), st AS (
         SELECT avg(pop.avg_x) AS ax,
            stddev_pop(pop.avg_x) AS sx,
            avg(pop.centrality) AS ac,
            stddev_pop(pop.centrality) AS sc,
            avg(pop.pct_box) AS ab,
            stddev_pop(pop.pct_box) AS sb,
            avg(pop.pct_def_third) AS ad,
            stddev_pop(pop.pct_def_third) AS sd,
            avg(pop.pct_def_actions) AS af,
            stddev_pop(pop.pct_def_actions) AS sf
           FROM pop
        ), z AS (
         SELECT p.player_id,
            p.modal_position,
            p.listed_pool,
            p.nominal_side,
            p.nineties,
            p.touches,
            p.avg_x,
            p.centrality,
            p.pct_box,
            p.pct_def_third,
            p.pct_def_actions,
            p.classifiable,
            (p.avg_x - st.ax) / NULLIF(st.sx, 0::numeric) AS zx,
            (p.centrality - st.ac) / NULLIF(st.sc, 0::numeric) AS zc,
            (p.pct_box - st.ab) / NULLIF(st.sb, 0::numeric) AS zb,
            (p.pct_def_third - st.ad) / NULLIF(st.sd, 0::numeric) AS zd,
            (p.pct_def_actions - st.af) / NULLIF(st.sf, 0::numeric) AS zf
           FROM pop p
             CROSS JOIN st
        ), cent AS (
         SELECT z.listed_pool AS pool,
            avg(z.zx) AS cx,
            avg(z.zc) AS cc,
            avg(z.zb) AS cb,
            avg(z.zd) AS cd,
            avg(z.zf) AS cf
           FROM z
          GROUP BY z.listed_pool
        ), dist AS (
         SELECT z.player_id,
            c.pool AS cand,
            sqrt(power(z.zx - c.cx, 2::numeric) + power(z.zc - c.cc, 2::numeric) + power(z.zb - c.cb, 2::numeric) + power(z.zd - c.cd, 2::numeric) + power(z.zf - c.cf, 2::numeric)) AS d
           FROM z
             CROSS JOIN cent c
        ), ranked AS (
         SELECT dist.player_id,
            dist.cand,
            dist.d,
            row_number() OVER (PARTITION BY dist.player_id ORDER BY dist.d) AS rn
           FROM dist
        ), assigned AS (
         SELECT a_1.player_id,
            a_1.cand AS territory_pool,
            round(a_1.d, 3) AS dist_best,
            round(b.d, 3) AS dist_next,
            round(b.d - a_1.d, 3) AS margin
           FROM ranked a_1
             JOIN ranked b ON b.player_id = a_1.player_id AND b.rn = 2
          WHERE a_1.rn = 1
        )
 SELECT e.player_id,
    e.modal_position,
    e.listed_pool,
    e.nominal_side,
    e.nineties,
    e.touches,
    e.classifiable,
    COALESCE(a.territory_pool, e.listed_pool) AS pool,
    a.dist_best,
    a.dist_next,
    a.margin,
    a.territory_pool IS NOT NULL AND a.territory_pool <> e.listed_pool AS reassigned,
        CASE
            WHEN NOT e.classifiable THEN 'low_sample'::text
            WHEN a.margin >= 0.75 THEN 'high'::text
            WHEN a.margin >= 0.35 THEN 'medium'::text
            ELSE 'low'::text
        END AS confidence
   FROM elig e
     LEFT JOIN assigned a USING (player_id) with no data;
create materialized view public.mv_player_setpiece as  SELECT e.player_id,
    count(*) FILTER (WHERE e.is_shot AND p.set_piece_phase) AS sp_shots,
    round(sum(x.xg) FILTER (WHERE p.set_piece_phase AND NOT x.is_pen), 3) AS sp_xg,
    count(*) FILTER (WHERE e.is_shot AND p.set_piece_phase AND e.is_goal) AS sp_goals,
    count(*) FILTER (WHERE e.type = 'Pass'::text AND NOT e.is_open_play AND e.qualifiers @> '[{"type": {"displayName": "KeyPass"}}]'::jsonb) AS sp_key_passes,
    count(*) FILTER (WHERE e.type = 'Aerial'::text AND p.set_piece_phase AND e.outcome_type = 'Successful'::text) AS sp_aerials_won
   FROM v_league_events e
     JOIN mv_event_phase p ON p.game_id = e.game_id AND p.ws_id = e.ws_id
     LEFT JOIN mv_shot_xg x ON x.game_id = e.game_id AND x.ws_id = e.ws_id
  WHERE e.player_id IS NOT NULL
  GROUP BY e.player_id with no data;
create materialized view public.mv_player_state_output as  WITH ev_state AS (
         SELECT e.game_id,
            e.team,
            e.player_id,
            e.ws_id,
            e.type,
            e.x,
            e.y,
            e.end_x,
            e.end_y,
            e.outcome_type,
            sg.margin::numeric AS margin
           FROM v_league_events e
             JOIN mv_state_segments sg ON sg.game_id = e.game_id AND sg.team = e.team AND e.expanded_minute >= sg.seg_start AND e.expanded_minute < sg.seg_end
          WHERE e.player_id IS NOT NULL
        ), shots AS (
         SELECT s_1.player_id,
            s_1.xg,
            state_weight(es.margin) AS w
           FROM mv_shot_xg s_1
             JOIN ev_state es ON es.game_id = s_1.game_id AND es.ws_id = s_1.ws_id
          WHERE s_1.is_pen = false
        ), xt AS (
         SELECT es.player_id,
            COALESCE(xt_val(es.end_x, es.end_y), 0::numeric) - COALESCE(xt_val(es.x, es.y), 0::numeric) AS xt_delta,
            state_weight(es.margin) AS w
           FROM ev_state es
          WHERE es.type = 'Pass'::text AND es.outcome_type = 'Successful'::text AND es.end_x IS NOT NULL
        ), wmin AS (
         SELECT pm.player_id,
            sum(GREATEST(0, LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start))) AS raw_min,
            sum(GREATEST(0, LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start))::numeric * state_weight(sg.margin::numeric)) AS weighted_min
           FROM mv_player_stints pm
             JOIN mv_state_segments sg ON sg.game_id = pm.game_id AND sg.team = pm.team AND sg.seg_start < pm.end_min AND sg.seg_end > pm.start_min
          GROUP BY pm.player_id
        ), sh_agg AS (
         SELECT shots.player_id,
            sum(shots.xg) AS raw_xg,
            sum(shots.xg * shots.w) AS live_xg
           FROM shots
          GROUP BY shots.player_id
        ), xt_agg AS (
         SELECT xt.player_id,
            sum(xt.xt_delta) AS raw_xt,
            sum(xt.xt_delta * xt.w) AS live_xt
           FROM xt
          GROUP BY xt.player_id
        )
 SELECT w.player_id,
    pcr.player,
    pcr.team,
    pcr.pos,
    round(w.raw_min::numeric / 90.0, 2) AS nineties_raw,
    round(w.weighted_min / 90.0, 2) AS nineties_live,
    round(100.0 * w.weighted_min / NULLIF(w.raw_min, 0)::numeric, 1) AS live_minute_pct,
    round(COALESCE(s.raw_xg, 0::numeric) / NULLIF(w.raw_min::numeric / 90.0, 0::numeric), 3) AS xg_90_raw,
    round(COALESCE(s.live_xg, 0::numeric) / NULLIF(w.weighted_min / 90.0, 0::numeric), 3) AS xg_90_live,
    round(COALESCE(s.live_xg, 0::numeric) / NULLIF(w.weighted_min / 90.0, 0::numeric) - COALESCE(s.raw_xg, 0::numeric) / NULLIF(w.raw_min::numeric / 90.0, 0::numeric), 3) AS xg_90_delta,
    round(COALESCE(x.raw_xt, 0::numeric) / NULLIF(w.raw_min::numeric / 90.0, 0::numeric), 3) AS xt_90_raw,
    round(COALESCE(x.live_xt, 0::numeric) / NULLIF(w.weighted_min / 90.0, 0::numeric), 3) AS xt_90_live,
    round(COALESCE(x.live_xt, 0::numeric) / NULLIF(w.weighted_min / 90.0, 0::numeric) - COALESCE(x.raw_xt, 0::numeric) / NULLIF(w.raw_min::numeric / 90.0, 0::numeric), 3) AS xt_90_delta
   FROM wmin w
     JOIN player_chain_roles pcr ON pcr.player_id = w.player_id
     LEFT JOIN sh_agg s ON s.player_id = w.player_id
     LEFT JOIN xt_agg x ON x.player_id = w.player_id
  WHERE w.raw_min >= 540 with no data;
create materialized view public.mv_player_xa as  SELECT p.player_id,
    count(*) AS chances_created,
    round(sum(x.xg), 3) AS xa
   FROM mv_shot_xg x
     JOIN v_league_events shot ON shot.game_id = x.game_id AND shot.ws_id = x.ws_id AND shot.is_shot
     JOIN LATERAL ( SELECT e.player_id,
            e.team,
            e.type,
            e.qualifiers @> '[{"type": {"displayName": "KeyPass"}}]'::jsonb AS keypass,
            e.qualifiers @> '[{"type": {"displayName": "ShotAssist"}}]'::jsonb AS shotassist
           FROM v_league_events e
          WHERE e.game_id = shot.game_id AND e.ws_id < shot.ws_id AND (e.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text]))
          ORDER BY e.ws_id DESC
         LIMIT 1) p ON true
  WHERE p.team = shot.team AND p.type = 'Pass'::text AND (p.keypass OR p.shotassist) AND p.player_id IS NOT NULL
  GROUP BY p.player_id with no data;
create materialized view public.mv_squad_role as  WITH team_games AS MATERIALIZED (
         SELECT ps.game_id,
            ps.team,
            m.league,
            m.date,
            max(ps.match_len) AS end_min
           FROM mv_player_stints ps
             JOIN v_league_matches m ON m.game_id = ps.game_id
          WHERE ps.team IS NOT NULL AND m.date IS NOT NULL
          GROUP BY ps.game_id, ps.team, m.league, m.date
        ), player_team AS MATERIALIZED (
         SELECT ps.player_id,
            ps.team,
            min(g.league) AS league,
            min(g.date) AS first_date,
            max(g.date) AS last_date,
            sum(ps.minutes) AS minutes_played,
            count(*) AS appearances,
            count(*) FILTER (WHERE ps.is_starter) AS starts
           FROM mv_player_stints ps
             JOIN team_games g ON g.game_id = ps.game_id AND g.team = ps.team
          GROUP BY ps.player_id, ps.team
        ), team_last AS (
         SELECT team_games.team,
            max(team_games.date) AS last_team_date
           FROM team_games
          GROUP BY team_games.team
        ), bounds AS (
         SELECT p.player_id,
            p.team,
            p.league,
            p.first_date,
            p.last_date,
            p.minutes_played,
            p.appearances,
            p.starts,
                CASE
                    WHEN max(p.last_date) OVER (PARTITION BY p.player_id) > p.last_date THEN p.last_date
                    ELSE tl.last_team_date
                END AS window_end
           FROM player_team p
             JOIN team_last tl ON tl.team = p.team
        ), avail AS (
         SELECT b.player_id,
            b.team,
            b.league,
            b.first_date,
            b.last_date,
            b.window_end,
            b.minutes_played,
            b.appearances,
            b.starts,
            count(g.game_id) AS games_available,
            COALESCE(sum(g.end_min), 0::bigint) AS minutes_available
           FROM bounds b
             LEFT JOIN team_games g ON g.team = b.team AND g.date >= b.first_date AND g.date <= b.window_end
          GROUP BY b.player_id, b.team, b.league, b.first_date, b.last_date, b.window_end, b.minutes_played, b.appearances, b.starts
        ), scored AS (
         SELECT a.player_id,
            a.team,
            a.league,
            a.first_date,
            a.last_date,
            a.window_end,
            a.minutes_played,
            a.appearances,
            a.starts,
            a.games_available,
            a.minutes_available,
            lv.leverage_pct,
            round(100.0 * a.minutes_played::numeric / NULLIF(a.minutes_available, 0)::numeric, 1) AS selection_pct,
            round(100.0 * a.starts::numeric / NULLIF(a.games_available, 0)::numeric, 1) AS start_pct
           FROM avail a
             LEFT JOIN mv_player_leverage lv ON lv.player_id = a.player_id AND lv.team = a.team
        ), ranked AS (
         SELECT s.player_id,
            s.team,
            s.league,
            s.first_date,
            s.last_date,
            s.window_end,
            s.minutes_played,
            s.appearances,
            s.starts,
            s.games_available,
            s.minutes_available,
            s.leverage_pct,
            s.selection_pct,
            s.start_pct,
            rank() OVER (PARTITION BY s.team ORDER BY s.selection_pct DESC NULLS LAST) AS squad_rank,
            round((s.leverage_pct - avg(s.leverage_pct) OVER (PARTITION BY s.team)) / NULLIF(stddev_samp(s.leverage_pct) OVER (PARTITION BY s.team), 0::numeric), 2) AS leverage_z_in_squad
           FROM scored s
        )
 SELECT r.player_id,
    r.team,
    r.league,
    r.first_date,
    r.last_date,
    r.window_end,
    r.minutes_played,
    r.appearances,
    r.starts,
    r.games_available,
    r.minutes_available,
    r.leverage_pct,
    r.selection_pct,
    r.start_pct,
    r.squad_rank,
    r.leverage_z_in_squad,
    pcr.player,
    pcr.pos,
        CASE
            WHEN r.selection_pct >= 70::numeric THEN 'Key player'::text
            WHEN r.selection_pct >= 45::numeric THEN 'Starter'::text
            WHEN r.selection_pct >= 20::numeric THEN 'Rotation'::text
            ELSE 'Fringe'::text
        END AS squad_role
   FROM ranked r
     JOIN player_chain_roles pcr ON pcr.player_id = r.player_id
  WHERE r.games_available >= 6 with no data;
create materialized view public.mv_team_directness_state as  WITH base AS (
         SELECT d.team,
            tl.league,
            d.state,
            round(avg(d.directness), 4) AS directness,
            count(*) AS n
           FROM v_seq_directness d
             JOIN mv_team_league tl ON tl.team = d.team
          GROUP BY d.team, tl.league, d.state
        ), piv AS (
         SELECT base.team,
            base.league,
            max(base.directness) FILTER (WHERE base.state = 'winning'::text) AS dir_winning,
            max(base.directness) FILTER (WHERE base.state = 'drawing'::text) AS dir_drawing,
            max(base.directness) FILTER (WHERE base.state = 'losing'::text) AS dir_losing,
            sum(base.n) FILTER (WHERE base.state = 'winning'::text) AS n_winning,
            sum(base.n) FILTER (WHERE base.state = 'drawing'::text) AS n_drawing,
            sum(base.n) FILTER (WHERE base.state = 'losing'::text) AS n_losing,
            round(avg(base.directness), 4) AS dir_overall
           FROM base
          GROUP BY base.team, base.league
        )
 SELECT team,
    league,
    dir_winning,
    dir_drawing,
    dir_losing,
    n_winning,
    n_drawing,
    n_losing,
    dir_overall,
    round(dir_losing - dir_winning, 4) AS swing_l_minus_w,
    rank() OVER (PARTITION BY league ORDER BY (dir_losing - dir_winning) DESC) AS swing_rank
   FROM piv with no data;
create view public.v_match_events as  SELECT e.id,
    e.game_id,
    e.ws_id,
    e.event_id,
    e.period,
    e.minute,
    e.second,
    e.expanded_minute,
    e.team_id,
    e.team,
    e.player_id,
    e.player,
    e.type,
    e.outcome_type,
    e.x,
    e.y,
    e.end_x,
    e.end_y,
    e.is_touch,
    e.is_shot,
    e.is_goal,
    e.card_type,
    e.qualifiers,
    e.is_open_play,
    e.league,
    x.xg,
    x.dist_m AS shot_dist_m,
    x.angle_deg AS shot_angle_deg
   FROM v_league_events e
     LEFT JOIN mv_shot_xg x ON x.game_id = e.game_id AND x.ws_id = e.ws_id;

-- === relation_options ===
alter view public.v_match_events set (security_invoker=true);

-- === relations ===
create view public.v_player_actions as  SELECT e.player_id,
    e.game_id,
    e.type,
    e.x,
    e.y,
    e.end_x,
    e.end_y,
    e.outcome_type = 'Successful'::text AS ok,
    e.is_shot,
    e.is_goal,
    e.is_open_play,
    COALESCE(ph.set_piece_phase, false) AS sp_phase,
    e.type = 'Pass'::text AND e.x IS NOT NULL AND e.end_x IS NOT NULL AND (e.x < 50::double precision AND e.end_x < 50::double precision AND (e.end_x - e.x) >= 30::double precision OR e.x < 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 15::double precision OR e.x >= 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 10::double precision) AS prog,
    e.type = 'Pass'::text AND e.end_x >= 83::double precision AND e.end_y >= 21::double precision AND e.end_y <= 79::double precision AS into_box,
    e.qualifiers @> '[{"type": {"displayName": "Cross"}}]'::jsonb AS cross_,
    e.qualifiers @> '[{"type": {"displayName": "KeyPass"}}]'::jsonb AS keypass,
    e.qualifiers @> '[{"type": {"displayName": "IntentionalGoalAssist"}}]'::jsonb AS assist,
    e.qualifiers @> '[{"type": {"displayName": "Throughball"}}]'::jsonb AS through,
    e.qualifiers @> '[{"type": {"displayName": "Head"}}]'::jsonb AS head,
    e.qualifiers @> '[{"type": {"displayName": "BigChance"}}]'::jsonb AS bigchance,
    x.xg,
    x.outcome AS shot_outcome
   FROM v_league_events e
     LEFT JOIN mv_event_phase ph ON ph.game_id = e.game_id AND ph.ws_id = e.ws_id
     LEFT JOIN mv_shot_xg x ON x.game_id = e.game_id AND x.ws_id = e.ws_id
  WHERE e.player_id IS NOT NULL AND e.x IS NOT NULL AND e.y IS NOT NULL AND (e.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'OffsideProvoked'::text]));

-- === relation_options ===
alter view public.v_player_actions set (security_invoker=true);

-- === relations ===
create view public.v_player_sot_fix as  SELECT player_id,
    count(*) FILTER (WHERE is_open_play AND (outcome = ANY (ARRAY['saved'::text, 'goal'::text]))) AS sot_true,
    count(*) FILTER (WHERE is_open_play AND outcome = 'blocked'::text) AS blocked
   FROM mv_shot_xg
  GROUP BY player_id;

-- === relation_options ===
alter view public.v_player_sot_fix set (security_invoker=true);

-- === relations ===
create view public.v_team_shots as  SELECT x.team,
    x.game_id,
    x.player,
    x.is_goal,
    x.is_open_play,
    x.is_pen,
    x.xg,
    x.is_header,
    x.is_bigchance,
    x.is_blocked,
    x.outcome,
    f.x,
    f.y,
    round(f.dist_m::numeric, 1) AS dist_m
   FROM mv_shot_xg x
     JOIN mv_shot_features f ON f.game_id = x.game_id AND f.ws_id = x.ws_id;

-- === relation_options ===
alter view public.v_team_shots set (security_invoker=true);

-- === relations ===
create view public.v_xg_model_support as  SELECT (( SELECT sum(mv_xg_bins.n) AS sum
           FROM mv_xg_bins))::integer AS training_shots,
    (( SELECT count(*) AS count
           FROM mv_xg_bins))::integer AS lookup_bins,
    (( SELECT count(DISTINCT mv_shot_xg.xg) AS count
           FROM mv_shot_xg
          WHERE NOT mv_shot_xg.is_pen AND mv_shot_xg.xg IS NOT NULL))::integer AS distinct_values,
    ( SELECT min(mv_shot_xg.xg) AS min
           FROM mv_shot_xg
          WHERE NOT mv_shot_xg.is_pen AND mv_shot_xg.xg IS NOT NULL) AS xg_min,
    ( SELECT max(mv_shot_xg.xg) AS max
           FROM mv_shot_xg
          WHERE NOT mv_shot_xg.is_pen AND mv_shot_xg.xg IS NOT NULL) AS xg_max,
    20 AS sparse_threshold,
    (( SELECT count(*) AS count
           FROM mv_xg_bins
          WHERE mv_xg_bins.n < 20))::integer AS sparse_bins,
    ( SELECT round(100.0 * sum(mv_xg_bins.n) FILTER (WHERE mv_xg_bins.n < 20) / NULLIF(sum(mv_xg_bins.n), 0::numeric), 2) AS round
           FROM mv_xg_bins) AS sparse_shot_share_pct,
    false AS holdout_run,
    false AS out_of_sample_tested;

-- === relation_options ===
alter view public.v_xg_model_support set (security_invoker=true);

-- === relations ===
create materialized view public.mv_player_gk as  WITH keepers AS (
         SELECT mv_player_pool.player_id
           FROM mv_player_pool
          WHERE mv_player_pool.modal_position = 'GK'::text
        ), acts AS (
         SELECT e.player_id,
            count(*) FILTER (WHERE e.type = 'Save'::text) AS saves,
            count(*) FILTER (WHERE e.type = 'Claim'::text) AS claims,
            count(*) FILTER (WHERE e.type = 'KeeperSweeper'::text) AS sweeps,
            count(*) FILTER (WHERE e.type = 'Punch'::text) AS punches,
            round(avg(e.x) FILTER (WHERE e.type = 'KeeperSweeper'::text)::numeric, 1) AS sweep_x
           FROM v_league_events e
             JOIN keepers k ON k.player_id = e.player_id
          WHERE e.type = ANY (ARRAY['Save'::text, 'Claim'::text, 'KeeperSweeper'::text, 'Punch'::text, 'KeeperPickup'::text])
          GROUP BY e.player_id
        ), m AS (
         SELECT g.player_id,
            sum(g.goals_conceded) AS goals_conceded,
            sum(g.xg_on_target_faced) AS xg_faced
           FROM mv_gk_match g
             JOIN keepers k ON k.player_id = g.player_id
          GROUP BY g.player_id
        )
 SELECT COALESCE(a.player_id, m.player_id) AS player_id,
    a.saves,
    a.claims,
    a.sweeps,
    a.punches,
    a.sweep_x,
    m.goals_conceded,
    m.xg_faced,
        CASE
            WHEN (COALESCE(a.saves, 0::bigint)::numeric + COALESCE(m.goals_conceded, 0::numeric)) >= 15::numeric THEN round(100.0 * a.saves::numeric / (a.saves::numeric + m.goals_conceded), 1)
            ELSE NULL::numeric
        END AS save_pct,
    round(COALESCE(m.xg_faced, 0::numeric) - COALESCE(m.goals_conceded, 0::numeric), 2) AS goals_prevented
   FROM acts a
     FULL JOIN m ON m.player_id = a.player_id with no data;
create materialized view public.mv_team_buildphase as  WITH m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        ), gk AS (
         SELECT e_1.team,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text) AS gk_passes,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text AND e_1.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb) AS gk_long
           FROM v_league_events e_1
             JOIN mv_player_pool p ON p.player_id = e_1.player_id AND p.modal_position = 'GK'::text
          GROUP BY e_1.team
        ), deep AS (
         SELECT e_1.team,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text AND e_1.x < 33.3::double precision) AS d3_passes,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text AND e_1.x < 33.3::double precision AND e_1.outcome_type = 'Successful'::text) AS d3_ok,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text AND e_1.x < 33.3::double precision AND e_1.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb) AS d3_long,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text AND e_1.x < 33.3::double precision AND e_1.end_x < 33.3::double precision AND e_1.outcome_type = 'Successful'::text) AS d3_circulate,
            count(*) FILTER (WHERE e_1.type = 'Pass'::text) AS all_passes,
            count(*) FILTER (WHERE e_1.is_touch AND e_1.x < 33.3::double precision) AS d3_touches,
            count(*) FILTER (WHERE e_1.is_touch) AS all_touches
           FROM v_league_events e_1
          WHERE e_1.team IS NOT NULL AND e_1.x IS NOT NULL
          GROUP BY e_1.team
        ), cb AS (
         SELECT e_1.team,
            count(*) FILTER (WHERE e_1.outcome_type = 'Successful'::text AND (e_1.x < 50::double precision AND e_1.end_x < 50::double precision AND (e_1.end_x - e_1.x) >= 30::double precision OR e_1.x < 50::double precision AND e_1.end_x >= 50::double precision AND (e_1.end_x - e_1.x) >= 15::double precision OR e_1.x >= 50::double precision AND e_1.end_x >= 50::double precision AND (e_1.end_x - e_1.x) >= 10::double precision)) AS cb_prog
           FROM v_league_events e_1
             JOIN mv_player_role r ON r.player_id = e_1.player_id AND r.pool = 'CB'::text
          WHERE e_1.type = 'Pass'::text
          GROUP BY e_1.team
        ), exits AS (
         SELECT mv_team_sequences.team,
            count(*) FILTER (WHERE mv_team_sequences.start_x < 33.3::double precision) AS deep_starts,
            count(*) FILTER (WHERE mv_team_sequences.start_x < 33.3::double precision AND mv_team_sequences.max_x >= 66.7::double precision) AS deep_to_final,
            count(*) FILTER (WHERE mv_team_sequences.start_x < 33.3::double precision AND mv_team_sequences.max_x >= 50::double precision) AS deep_to_half
           FROM mv_team_sequences
          GROUP BY mv_team_sequences.team
        )
 SELECT d.team,
    round(100.0 * g.gk_long::numeric / NULLIF(g.gk_passes, 0)::numeric, 1) AS gk_long_pct,
    round(d.d3_passes::numeric / NULLIF(m.matches, 0)::numeric, 1) AS d3_passes_pg,
    round(100.0 * d.d3_passes::numeric / NULLIF(d.all_passes, 0)::numeric, 1) AS d3_pass_share,
    round(100.0 * d.d3_ok::numeric / NULLIF(d.d3_passes, 0)::numeric, 1) AS d3_accuracy,
    round(100.0 * d.d3_long::numeric / NULLIF(d.d3_passes, 0)::numeric, 1) AS d3_long_pct,
    round(d.d3_circulate::numeric / NULLIF(m.matches, 0)::numeric, 1) AS deep_circulation_pg,
    round(100.0 * d.d3_touches::numeric / NULLIF(d.all_touches, 0)::numeric, 1) AS d3_touch_share,
    round(c.cb_prog::numeric / NULLIF(m.matches, 0)::numeric, 1) AS cb_prog_pg,
    round(100.0 * e.deep_to_half::numeric / NULLIF(e.deep_starts, 0)::numeric, 1) AS escape_pct,
    round(100.0 * e.deep_to_final::numeric / NULLIF(e.deep_starts, 0)::numeric, 1) AS deep_to_final_pct
   FROM deep d
     JOIN m ON m.team = d.team
     LEFT JOIN gk g ON g.team = d.team
     LEFT JOIN cb c ON c.team = d.team
     LEFT JOIN exits e ON e.team = d.team with no data;
create view public.pcr_z as  WITH p AS (
         SELECT c.player_id,
            c.player,
            c.team,
            c.pos,
            c.inv,
            c.player_xt,
            c.hold_secs,
            c.initiator,
            c.bridge,
            c.progressor,
            c.carrier,
            c.vertical,
            c.support_angle,
            c.individual,
            c.creator,
            c.box_threat,
            c.finisher,
            COALESCE(r.pool, c.pos) AS pool,
            COALESCE(pl.league, 'USA-MLS'::text) AS league
           FROM player_chain_roles c
             LEFT JOIN mv_player_role r ON r.player_id = c.player_id
             LEFT JOIN mv_player_league pl ON pl.player_id = c.player_id
        )
 SELECT player_id,
    player,
    team,
    pos,
    pool,
    inv,
    player_xt,
    hold_secs,
    (initiator - avg(initiator) OVER w) / NULLIF(stddev_samp(initiator) OVER w, 0::numeric) AS z_init,
    (bridge - avg(bridge) OVER w) / NULLIF(stddev_samp(bridge) OVER w, 0::numeric) AS z_bridge,
    (progressor - avg(progressor) OVER w) / NULLIF(stddev_samp(progressor) OVER w, 0::numeric) AS z_prog,
    (carrier - avg(carrier) OVER w) / NULLIF(stddev_samp(carrier) OVER w, 0::numeric) AS z_carry,
    (vertical - avg(vertical) OVER w) / NULLIF(stddev_samp(vertical) OVER w, 0::numeric) AS z_vert,
    (support_angle - avg(support_angle) OVER w) / NULLIF(stddev_samp(support_angle) OVER w, 0::numeric) AS z_supp,
    (individual - avg(individual) OVER w) / NULLIF(stddev_samp(individual) OVER w, 0::numeric) AS z_indiv,
    (creator - avg(creator) OVER w) / NULLIF(stddev_samp(creator) OVER w, 0::numeric) AS z_creator,
    (box_threat - avg(box_threat) OVER w) / NULLIF(stddev_samp(box_threat) OVER w, 0::numeric) AS z_box,
    (finisher - avg(finisher) OVER w) / NULLIF(stddev_samp(finisher) OVER w, 0::numeric) AS z_finish,
    (hold_secs - avg(hold_secs) OVER w) / NULLIF(stddev_samp(hold_secs) OVER w, 0::numeric) AS z_ctrl,
    league
   FROM p
  WINDOW w AS (PARTITION BY league, pool);

-- === relation_options ===
alter view public.pcr_z set (security_invoker=true);

-- === relations ===
create view public.player_chain_pct as  WITH p AS (
         SELECT c.player_id,
            c.player,
            c.team,
            c.pos,
            c.inv,
            c.player_xt,
            c.hold_secs,
            c.initiator,
            c.bridge,
            c.progressor,
            c.carrier,
            c.vertical,
            c.support_angle,
            c.individual,
            c.creator,
            c.box_threat,
            c.finisher,
            COALESCE(r.pool, c.pos) AS pool,
            COALESCE(pl.league, 'USA-MLS'::text) AS league
           FROM player_chain_roles c
             LEFT JOIN mv_player_role r ON r.player_id = c.player_id
             LEFT JOIN mv_player_league pl ON pl.player_id = c.player_id
        )
 SELECT p.player_id,
    p.player,
    p.pos,
    p.pool,
    m.role,
    m.raw,
    round(100::double precision * percent_rank() OVER (PARTITION BY p.league, p.pool, m.role ORDER BY m.raw))::integer AS pct,
    p.league
   FROM p
     CROSS JOIN LATERAL ( VALUES ('initiator'::text,p.initiator), ('controller'::text,p.hold_secs), ('bridge'::text,p.bridge), ('progressor'::text,p.progressor), ('carrier'::text,p.carrier), ('vertical'::text,p.vertical), ('support_angle'::text,p.support_angle), ('individual'::text,p.individual), ('creator'::text,p.creator), ('box_threat'::text,p.box_threat), ('finisher'::text,p.finisher)) m(role, raw);

-- === relation_options ===
alter view public.player_chain_pct set (security_invoker=true);

-- === relations ===
create view public.v_league_availability as  SELECT league,
    display_name,
    matches,
    clubs_at_threshold,
    clubs,
    insights,
    min_matches_required,
    insight_status
   FROM mv_league_availability;

-- === relation_options ===
alter view public.v_league_availability set (security_invoker=true);

-- === relations ===
create view public.v_squad_role as  WITH lg AS (
         SELECT mv_squad_role.league,
            percentile_cont(0.25::double precision) WITHIN GROUP (ORDER BY (mv_squad_role.leverage_pct::double precision)) AS p25,
            percentile_cont(0.50::double precision) WITHIN GROUP (ORDER BY (mv_squad_role.leverage_pct::double precision)) AS p50
           FROM mv_squad_role
          WHERE mv_squad_role.leverage_pct IS NOT NULL
          GROUP BY mv_squad_role.league
        )
 SELECT r.player_id,
    r.player,
    r.team,
    r.pos,
    r.squad_role,
    r.squad_rank,
    r.selection_pct,
    r.start_pct,
    r.leverage_pct,
    r.leverage_z_in_squad,
    r.minutes_played,
    r.minutes_available,
    r.appearances,
    r.starts,
    r.games_available,
    round(100.0::double precision * percent_rank() OVER (PARTITION BY r.league ORDER BY r.leverage_pct))::integer AS leverage_pct_rank,
    r.selection_pct >= 40::numeric AND r.leverage_pct::double precision < lg.p25 AS minutes_inflated,
    r.league
   FROM mv_squad_role r
     JOIN lg ON lg.league = r.league;

-- === relation_options ===
alter view public.v_squad_role set (security_invoker=true);

-- === relations ===
create materialized view public.mv_player_archetype as  WITH names(role, label) AS (
         VALUES ('progressor'::text,'Progressor'::text), ('initiator'::text,'Deep Initiator'::text), ('creator'::text,'Creator'::text), ('box_threat'::text,'Box Threat'::text), ('finisher'::text,'Finisher'::text), ('carrier'::text,'Carrier'::text), ('vertical'::text,'Vertical Passer'::text), ('support_angle'::text,'Link Player'::text), ('bridge'::text,'Third-Man Bridge'::text), ('individual'::text,'Dribbler'::text), ('controller'::text,'Tempo Setter'::text)
        ), r AS (
         SELECT p.player_id,
            p.player,
            p.pool,
            p.role,
            p.pct,
            row_number() OVER (PARTITION BY p.player_id ORDER BY p.pct DESC, p.role) AS rk
           FROM player_chain_pct p
        ), top2 AS (
         SELECT r.player_id,
            max(r.player) AS player,
            max(r.pool) AS pool,
            max(r.role) FILTER (WHERE r.rk = 1) AS primary_role,
            max(r.pct) FILTER (WHERE r.rk = 1) AS primary_pct,
            max(r.role) FILTER (WHERE r.rk = 2) AS secondary_role,
            max(r.pct) FILTER (WHERE r.rk = 2) AS secondary_pct
           FROM r
          WHERE r.rk <= 2
          GROUP BY r.player_id
        )
 SELECT t.player_id,
    t.player,
    t.pool,
    t.primary_role,
    t.primary_pct,
    t.secondary_role,
    t.secondary_pct,
    n1.label AS primary_label,
    n2.label AS secondary_label,
    (n1.label || ' / '::text) || n2.label AS archetype,
    (t.pool || ' · '::text) || n1.label AS pool_archetype
   FROM top2 t
     LEFT JOIN names n1 ON n1.role = t.primary_role
     LEFT JOIN names n2 ON n2.role = t.secondary_role with no data;
create materialized view public.mv_player_metrics as  SELECT r.player_id,
    r.player_name,
    r.team,
    r.nineties,
    round(r.pass_cmp::numeric / r.nineties, 2) AS pass_cmp_90,
    round(100.0 * r.pass_cmp::numeric / NULLIF(r.pass_att, 0)::numeric, 1) AS pass_pct,
    round(r.prog_cmp::numeric / r.nineties, 2) AS prog_cmp_90,
        CASE
            WHEN r.prog_att >= 25 THEN round(100.0 * r.prog_cmp::numeric / r.prog_att::numeric, 1)
            ELSE NULL::numeric
        END AS prog_pct,
    round((r.territory_gained / r.nineties::double precision)::numeric, 1) AS territory_90,
    round(r.into_box::numeric / r.nineties, 2) AS into_box_90,
    round(r.final_third_passes::numeric / r.nineties, 2) AS final_third_90,
    round(r.through_balls::numeric / r.nineties, 3) AS through_90,
    round(r.cross_att::numeric / r.nineties, 2) AS cross_90,
        CASE
            WHEN r.cross_att >= 20 THEN round(100.0 * r.cross_cmp::numeric / r.cross_att::numeric, 1)
            ELSE NULL::numeric
        END AS cross_pct,
    round(r.key_passes::numeric / r.nineties, 2) AS key_pass_90,
    round(r.assists::numeric / r.nineties, 3) AS assist_90,
    round(r.big_chances_created::numeric / r.nineties, 3) AS bcc_90,
    round(r.long_att::numeric / r.nineties, 2) AS long_90,
        CASE
            WHEN r.long_att >= 25 THEN round(100.0 * r.long_cmp::numeric / r.long_att::numeric, 1)
            ELSE NULL::numeric
        END AS long_pct,
    round(r.shots::numeric / r.nineties, 2) AS shots_90,
    round(COALESCE(sf.sot_true, 0::bigint)::numeric / r.nineties, 2) AS sot_90,
    round(COALESCE(sf.blocked, 0::bigint)::numeric / r.nineties, 2) AS blocked_90,
    round(GREATEST(r.goals - COALESCE(og.own_goals, 0::bigint), 0::bigint)::numeric / r.nineties, 3) AS goals_90,
        CASE
            WHEN r.shots >= 10 THEN round(100.0 * r.shots_in_box::numeric / r.shots::numeric, 1)
            ELSE NULL::numeric
        END AS box_share,
        CASE
            WHEN r.shots >= 10 THEN round((r.shot_dist_sum / r.shots::double precision)::numeric, 1)
            ELSE NULL::numeric
        END AS shot_dist,
        CASE
            WHEN r.shots >= 12 THEN round(100.0 * GREATEST(r.goals - COALESCE(og.own_goals, 0::bigint), 0::bigint)::numeric / r.shots::numeric, 1)
            ELSE NULL::numeric
        END AS conversion,
        CASE
            WHEN r.shots >= 10 THEN round(100.0 * COALESCE(sf.sot_true, 0::bigint)::numeric / r.shots::numeric, 1)
            ELSE NULL::numeric
        END AS shot_acc,
    round(r.big_chance_shots::numeric / r.nineties, 3) AS bigchance_90,
        CASE
            WHEN (r.rf_shots + r.lf_shots) >= 10 THEN round(100.0 * LEAST(r.rf_shots, r.lf_shots)::numeric / (r.rf_shots + r.lf_shots)::numeric, 1)
            ELSE NULL::numeric
        END AS weak_foot_share,
    round(r.tackle_att::numeric / r.nineties, 2) AS tackle_90,
        CASE
            WHEN r.tackle_att >= 15 THEN round(100.0 * r.tackle_won::numeric / r.tackle_att::numeric, 1)
            ELSE NULL::numeric
        END AS tackle_pct,
    round(r.interceptions::numeric / r.nineties, 2) AS int_90,
    round(r.clearances::numeric / r.nineties, 2) AS clear_90,
    round(r.blocks::numeric / r.nineties, 2) AS block_90,
    round(r.recoveries::numeric / r.nineties, 2) AS recov_90,
    round(r.aerial_att::numeric / r.nineties, 2) AS aerial_90,
        CASE
            WHEN r.aerial_att >= 20 THEN round(100.0 * r.aerial_won::numeric / r.aerial_att::numeric, 1)
            ELSE NULL::numeric
        END AS aerial_pct,
    round((r.tackle_att + r.interceptions + r.clearances + r.blocks + r.recoveries)::numeric / r.nineties, 2) AS def_action_90,
    r.def_action_x AS def_height,
    round(r.takeon_att::numeric / r.nineties, 2) AS takeon_90,
        CASE
            WHEN r.takeon_att >= 15 THEN round(100.0 * r.takeon_won::numeric / r.takeon_att::numeric, 1)
            ELSE NULL::numeric
        END AS takeon_pct,
    round(r.dispossessed::numeric / r.nineties, 2) AS disp_90,
    round(r.bad_touches::numeric / r.nineties, 2) AS badtouch_90,
    round(r.fouls_committed::numeric / r.nineties, 2) AS foul_com_90,
    round(r.fouls_won::numeric / r.nineties, 2) AS foul_won_90,
    round(r.errors::numeric / r.nineties, 3) AS error_90,
    round(c.carries::numeric / r.nineties, 2) AS carries_90,
    round(c.prog_carries::numeric / r.nineties, 2) AS prog_carries_90,
    round(c.carries_into_box::numeric / r.nineties, 2) AS carry_box_90,
    c.mean_carry_m,
    round(c.carry_penetration / r.nineties, 1) AS carry_pen_90,
    round(c.median_ttr::numeric, 2) AS median_ttr,
        CASE
            WHEN c.pass_releases >= 50 THEN round(100.0 * c.quick_release::numeric / c.pass_releases::numeric, 1)
            ELSE NULL::numeric
        END AS quick_pct,
        CASE
            WHEN c.pass_releases >= 50 THEN round(100.0 * c.one_touch::numeric / c.pass_releases::numeric, 1)
            ELSE NULL::numeric
        END AS one_touch_pct,
    ch.aq_per_duel,
    ch.duel_quality,
    ch.recov_retention,
    round(ch.recov_prog_pass::numeric / r.nineties, 2) AS recov_prog_90,
    round(COALESCE(sx.xg, 0::numeric) / r.nineties, 3) AS xg_90,
        CASE
            WHEN r.shots >= 10 THEN round(COALESCE(sx.xg, 0::numeric) / NULLIF(sx.shots, 0)::numeric, 3)
            ELSE NULL::numeric
        END AS xg_per_shot,
    round((GREATEST(r.goals - COALESCE(og.own_goals, 0::bigint), 0::bigint)::numeric - COALESCE(sx.xg, 0::numeric)) / r.nineties, 3) AS finishing,
    round(COALESCE(xa.xa, 0::numeric) / r.nineties, 3) AS xa_90,
    round(COALESCE(xt.xt_total, 0::numeric) / r.nineties, 3) AS xt_90,
    round(COALESCE(xt.xt_pass, 0::numeric) / r.nineties, 3) AS xt_pass_90,
    round(COALESCE(xt.xt_carry, 0::numeric) / r.nineties, 3) AS xt_carry_90,
    gk.save_pct,
    round(COALESCE(gk.goals_prevented, 0::numeric) / r.nineties, 3) AS goals_prevented_90,
    round(gk.saves::numeric / r.nineties, 2) AS saves_90,
    round(gk.claims::numeric / r.nineties, 2) AS claims_90,
    round(gk.sweeps::numeric / r.nineties, 2) AS sweeps_90,
    gk.sweep_x
   FROM mv_player_metrics_raw r
     LEFT JOIN mv_player_carry c ON c.player_id = r.player_id
     LEFT JOIN mv_player_chains ch ON ch.player_id = r.player_id
     LEFT JOIN mv_player_xa xa ON xa.player_id = r.player_id
     LEFT JOIN mv_player_xt xt ON xt.player_id = r.player_id
     LEFT JOIN mv_player_gk gk ON gk.player_id = r.player_id
     LEFT JOIN v_goal_fix og ON og.player_id = r.player_id
     LEFT JOIN v_player_sot_fix sf ON sf.player_id = r.player_id
     LEFT JOIN ( SELECT mv_shot_xg.player_id,
            sum(mv_shot_xg.xg) AS xg,
            count(*) AS shots
           FROM mv_shot_xg
          GROUP BY mv_shot_xg.player_id) sx ON sx.player_id = r.player_id
  WHERE r.nineties > 0::numeric with no data;
create materialized view public.mv_team_all as  SELECT s.team,
    s.matches,
    s.possession_pct,
    s.field_tilt,
    s.ppda,
    s.def_height,
    s.avg_touch_x,
    s.long_ball_pct,
    s.build_from_back_pct,
    s.directness,
    s.prog_passes_pg,
    s.box_entries_pg,
    s.crosses_pg,
    s.shots_pg,
    s.shots_against_pg,
    s.goals_pg,
    s.goals_against_pg,
    s.open_play_shot_pct,
    b2.passes_per_seq,
    b2.secs_per_seq,
    b2.long_sequence_pct,
    b2.pct_ending_in_shot,
    b2.ground_gained,
    b2.sequences_pg,
    bp.gk_long_pct,
    bp.d3_pass_share,
    bp.d3_accuracy,
    bp.d3_long_pct,
    bp.deep_circulation_pg,
    bp.cb_prog_pg,
    bp.escape_pct,
    bp.deep_to_final_pct,
    bp.d3_touch_share,
    ap.att_directness,
    ap.mid_release,
    ap.ft_release,
    ap.passes_per_shot,
    ap.ft_entries_pg,
    ap.box_per_entry,
    ap.final_to_shot_pct,
    COALESCE(l.pct_left, 0::numeric) AS pct_left,
    COALESCE(l.pct_centre, 0::numeric) AS pct_centre,
    COALESCE(l.pct_right, 0::numeric) AS pct_right
   FROM mv_team_season s
     LEFT JOIN mv_team_buildup b2 ON b2.team = s.team
     LEFT JOIN mv_team_buildphase bp ON bp.team = s.team
     LEFT JOIN mv_team_attackphase ap ON ap.team = s.team
     LEFT JOIN ( SELECT mv_team_lanes.team,
            max(mv_team_lanes.pct_of_final_third) FILTER (WHERE mv_team_lanes.lane = 'L'::text) AS pct_left,
            max(mv_team_lanes.pct_of_final_third) FILTER (WHERE mv_team_lanes.lane = 'C'::text) AS pct_centre,
            max(mv_team_lanes.pct_of_final_third) FILTER (WHERE mv_team_lanes.lane = 'R'::text) AS pct_right
           FROM mv_team_lanes
          GROUP BY mv_team_lanes.team) l ON l.team = s.team with no data;
create materialized view public.mv_team_percentiles as  WITH long AS (
         SELECT t.team,
            tl.league,
            v.metric,
            v.value
           FROM mv_team_all t
             JOIN mv_team_league tl ON tl.team = t.team
             CROSS JOIN LATERAL ( VALUES ('possession_pct'::text,t.possession_pct), ('field_tilt'::text,t.field_tilt), ('avg_touch_x'::text,t.avg_touch_x), ('directness'::text,t.directness), ('long_ball_pct'::text,t.long_ball_pct), ('build_from_back_pct'::text,t.build_from_back_pct), ('ppda'::text,t.ppda), ('def_height'::text,t.def_height), ('prog_passes_pg'::text,t.prog_passes_pg), ('box_entries_pg'::text,t.box_entries_pg), ('crosses_pg'::text,t.crosses_pg), ('shots_pg'::text,t.shots_pg), ('goals_pg'::text,t.goals_pg), ('open_play_shot_pct'::text,t.open_play_shot_pct), ('shots_against_pg'::text,t.shots_against_pg), ('goals_against_pg'::text,t.goals_against_pg), ('passes_per_seq'::text,t.passes_per_seq), ('secs_per_seq'::text,t.secs_per_seq), ('long_sequence_pct'::text,t.long_sequence_pct), ('pct_ending_in_shot'::text,t.pct_ending_in_shot), ('ground_gained'::text,t.ground_gained), ('sequences_pg'::text,t.sequences_pg), ('gk_long_pct'::text,t.gk_long_pct), ('d3_pass_share'::text,t.d3_pass_share), ('d3_accuracy'::text,t.d3_accuracy), ('d3_long_pct'::text,t.d3_long_pct), ('deep_circulation_pg'::text,t.deep_circulation_pg), ('cb_prog_pg'::text,t.cb_prog_pg), ('escape_pct'::text,t.escape_pct), ('deep_to_final_pct'::text,t.deep_to_final_pct), ('d3_touch_share'::text,t.d3_touch_share), ('att_directness'::text,t.att_directness), ('mid_release'::text,t.mid_release), ('ft_release'::text,t.ft_release), ('passes_per_shot'::text,t.passes_per_shot), ('ft_entries_pg'::text,t.ft_entries_pg), ('box_per_entry'::text,t.box_per_entry), ('final_to_shot_pct'::text,t.final_to_shot_pct), ('pct_left'::text,t.pct_left), ('pct_centre'::text,t.pct_centre), ('pct_right'::text,t.pct_right)) v(metric, value)
        ), r AS (
         SELECT l.team,
            l.league,
            l.metric,
            l.value,
            d.higher_is_better,
            percent_rank() OVER (PARTITION BY l.league, l.metric ORDER BY l.value) AS pr
           FROM long l
             JOIN team_metric_defs d ON d.key = l.metric
          WHERE l.value IS NOT NULL
        )
 SELECT team,
    metric,
    value,
    round((100::double precision *
        CASE
            WHEN higher_is_better THEN pr
            ELSE 1::double precision - pr
        END)::numeric, 0) AS pct,
    league
   FROM r with no data;
create view public.v_player_metrics_ext as  SELECT m.player_id,
    m.player_name,
    m.team,
    m.nineties,
    m.pass_cmp_90,
    m.pass_pct,
    m.prog_cmp_90,
    m.prog_pct,
    m.territory_90,
    m.into_box_90,
    m.final_third_90,
    m.through_90,
    m.cross_90,
    m.cross_pct,
    m.key_pass_90,
    m.assist_90,
    m.bcc_90,
    m.long_90,
    m.long_pct,
    m.shots_90,
    m.sot_90,
    m.blocked_90,
    m.goals_90,
    m.box_share,
    m.shot_dist,
    m.conversion,
    m.shot_acc,
    m.bigchance_90,
    m.weak_foot_share,
    m.tackle_90,
    m.tackle_pct,
    m.int_90,
    m.clear_90,
    m.block_90,
    m.recov_90,
    m.aerial_90,
    m.aerial_pct,
    m.def_action_90,
    m.def_height,
    m.takeon_90,
    m.takeon_pct,
    m.disp_90,
    m.badtouch_90,
    m.foul_com_90,
    m.foul_won_90,
    m.error_90,
    m.carries_90,
    m.prog_carries_90,
    m.carry_box_90,
    m.mean_carry_m,
    m.carry_pen_90,
    m.median_ttr,
    m.quick_pct,
    m.one_touch_pct,
    m.aq_per_duel,
    m.duel_quality,
    m.recov_retention,
    m.recov_prog_90,
    m.xg_90,
    m.xg_per_shot,
    m.finishing,
    m.xa_90,
    m.xt_90,
    m.xt_pass_90,
    m.xt_carry_90,
    m.save_pct,
    m.goals_prevented_90,
    m.saves_90,
    m.claims_90,
    m.sweeps_90,
    m.sweep_x,
    round(z.hs_passes::numeric / m.nineties, 2) AS hs_passes_90,
    round(z.hs_prog_passes::numeric / m.nineties, 2) AS hs_prog_90,
    round(z.hs_key_passes::numeric / m.nineties, 2) AS hs_key_90,
    round(z.hs_shots::numeric / m.nineties, 2) AS hs_shots_90,
    round(z.hs_takeons::numeric / m.nineties, 2) AS hs_takeons_90,
    round(z.box_def_actions::numeric / m.nineties, 2) AS box_def_90,
    round(z.channel_def_actions::numeric / m.nineties, 2) AS channel_def_90,
    round(z.flank_def_actions::numeric / m.nineties, 2) AS flank_def_90,
    round(cp.counterpress::numeric / m.nineties, 2) AS counterpress_90,
    round(sca.sca::numeric / m.nineties, 2) AS sca_90,
    round(hu.holds::numeric / m.nineties, 2) AS holds_90,
        CASE
            WHEN hu.holds >= 10 THEN round(100.0 * hu.holds_retained::numeric / hu.holds::numeric, 1)
            ELSE NULL::numeric
        END AS hold_retention,
        CASE
            WHEN hu.holds >= 10 THEN round(100.0 * hu.holds_prog_carry::numeric / hu.holds::numeric, 1)
            ELSE NULL::numeric
        END AS hold_prog_pct,
        CASE
            WHEN hu.holds >= 10 THEN round(100.0 * hu.holds_shot::numeric / hu.holds::numeric, 1)
            ELSE NULL::numeric
        END AS hold_shot_pct,
    round(COALESCE(sp.sp_xg, 0::numeric) / m.nineties, 3) AS sp_xg_90,
    round(sp.sp_shots::numeric / m.nineties, 2) AS sp_shots_90,
    round(sp.sp_aerials_won::numeric / m.nineties, 2) AS sp_aerials_90,
    round(sp.sp_key_passes::numeric / m.nineties, 2) AS sp_key_90
   FROM mv_player_metrics m
     LEFT JOIN mv_player_zones z ON z.player_id = m.player_id
     LEFT JOIN mv_player_counterpress cp ON cp.player_id = m.player_id
     LEFT JOIN mv_player_sca sca ON sca.player_id = m.player_id
     LEFT JOIN mv_player_holdup hu ON hu.player_id = m.player_id
     LEFT JOIN mv_player_setpiece sp ON sp.player_id = m.player_id;

-- === relation_options ===
alter view public.v_player_metrics_ext set (security_invoker=true);

-- === relations ===
create view public.v_team_directory as  SELECT t.team,
    tl.league,
    COALESCE(l.display_name, 'Major League Soccer'::text) AS league_name,
    l.country,
    count(*) OVER (PARTITION BY tl.league) AS teams_in_league,
    ( SELECT count(*) AS count
           FROM v_league_matches m
          WHERE m.league = tl.league AND m.home_score IS NOT NULL AND (m.home_team = t.team OR m.away_team = t.team)) AS matches_played
   FROM mv_team_all t
     JOIN mv_team_league tl ON tl.team = t.team
     LEFT JOIN leagues l ON l.league = tl.league;

-- === relation_options ===
alter view public.v_team_directory set (security_invoker=true);

-- === relations ===
create materialized view public.mv_player_chain_value as  WITH inv AS (
         SELECT se.player_id,
            se.player,
            se.team,
            se.ord_a,
            se.chain_len,
            se.chain_len - se.ord_a AS steps_from_end,
            s.ended_shot,
            s.ended_goal,
            s.xt_sum,
            s.n_pass
           FROM mv_seq_events se
             JOIN v_league_sequences s USING (seq_uid)
          WHERE se.seq_setpiece = false AND s.is_open_play AND se.player_id IS NOT NULL
        ), agg AS (
         SELECT inv.player_id,
            max(inv.player) AS player,
            max(inv.team) AS team,
            count(*) AS involvements,
            count(*) FILTER (WHERE inv.ended_shot) AS shot_chain_inv,
            count(*) FILTER (WHERE inv.ended_shot AND inv.steps_from_end >= 3) AS early_shot_inv,
            count(*) FILTER (WHERE inv.ended_goal AND inv.steps_from_end >= 3) AS early_goal_inv,
            round(avg(inv.steps_from_end), 2) AS mean_steps_from_end,
            round(avg(inv.xt_sum), 4) AS mean_chain_xt
           FROM inv
          GROUP BY inv.player_id
        )
 SELECT a.player_id,
    a.player,
    a.team,
    a.involvements,
    a.shot_chain_inv,
    a.early_shot_inv,
    a.early_goal_inv,
    a.mean_steps_from_end,
    a.mean_chain_xt,
    m.nineties,
    round(100.0 * a.shot_chain_inv::numeric / NULLIF(a.involvements, 0)::numeric, 2) AS shot_chain_pct,
    round(100.0 * a.early_shot_inv::numeric / NULLIF(a.involvements, 0)::numeric, 2) AS early_shot_pct,
    round(a.early_shot_inv::numeric / NULLIF(m.nineties, 0::numeric), 2) AS early_shot_inv_90,
    round(a.shot_chain_inv::numeric / NULLIF(m.nineties, 0::numeric), 2) AS shot_chain_inv_90,
    round(a.early_goal_inv::numeric / NULLIF(m.nineties, 0::numeric), 3) AS early_goal_inv_90
   FROM agg a
     JOIN player_chain_roles pcr ON pcr.player_id = a.player_id
     LEFT JOIN v_player_metrics_ext m ON m.player_id = a.player_id
  WHERE a.involvements >= 120 with no data;
create materialized view public.mv_player_percentiles as  WITH base AS (
         SELECT m.player_id,
            m.player_name,
            m.team,
            m.nineties,
            m.pass_cmp_90,
            m.pass_pct,
            m.prog_cmp_90,
            m.prog_pct,
            m.territory_90,
            m.into_box_90,
            m.final_third_90,
            m.through_90,
            m.cross_90,
            m.cross_pct,
            m.key_pass_90,
            m.assist_90,
            m.bcc_90,
            m.long_90,
            m.long_pct,
            m.shots_90,
            m.sot_90,
            m.blocked_90,
            m.goals_90,
            m.box_share,
            m.shot_dist,
            m.conversion,
            m.shot_acc,
            m.bigchance_90,
            m.weak_foot_share,
            m.tackle_90,
            m.tackle_pct,
            m.int_90,
            m.clear_90,
            m.block_90,
            m.recov_90,
            m.aerial_90,
            m.aerial_pct,
            m.def_action_90,
            m.def_height,
            m.takeon_90,
            m.takeon_pct,
            m.disp_90,
            m.badtouch_90,
            m.foul_com_90,
            m.foul_won_90,
            m.error_90,
            m.carries_90,
            m.prog_carries_90,
            m.carry_box_90,
            m.mean_carry_m,
            m.carry_pen_90,
            m.median_ttr,
            m.quick_pct,
            m.one_touch_pct,
            m.aq_per_duel,
            m.duel_quality,
            m.recov_retention,
            m.recov_prog_90,
            m.xg_90,
            m.xg_per_shot,
            m.finishing,
            m.xa_90,
            m.xt_90,
            m.xt_pass_90,
            m.xt_carry_90,
            m.save_pct,
            m.goals_prevented_90,
            m.saves_90,
            m.claims_90,
            m.sweeps_90,
            m.sweep_x,
            m.hs_passes_90,
            m.hs_prog_90,
            m.hs_key_90,
            m.hs_shots_90,
            m.hs_takeons_90,
            m.box_def_90,
            m.channel_def_90,
            m.flank_def_90,
            m.counterpress_90,
            m.sca_90,
            m.holds_90,
            m.hold_retention,
            m.hold_prog_pct,
            m.hold_shot_pct,
            m.sp_xg_90,
            m.sp_shots_90,
            m.sp_aerials_90,
            m.sp_key_90,
            p.team_possession,
            50.0 / NULLIF(100::numeric - p.team_possession, 0::numeric) AS padj
           FROM v_player_metrics_ext m
             LEFT JOIN mv_player_team_poss p USING (player_id)
        ), long AS (
         SELECT b.player_id,
            r.pool,
            b.nineties,
            pl.league,
            v.metric,
            v.value
           FROM base b
             JOIN mv_player_role r USING (player_id)
             LEFT JOIN mv_player_league pl ON pl.player_id = b.player_id
             CROSS JOIN LATERAL ( VALUES ('pass_cmp_90'::text,b.pass_cmp_90), ('pass_pct'::text,b.pass_pct), ('prog_cmp_90'::text,b.prog_cmp_90), ('prog_pct'::text,b.prog_pct), ('territory_90'::text,b.territory_90), ('into_box_90'::text,b.into_box_90), ('final_third_90'::text,b.final_third_90), ('through_90'::text,b.through_90), ('cross_90'::text,b.cross_90), ('cross_pct'::text,b.cross_pct), ('key_pass_90'::text,b.key_pass_90), ('assist_90'::text,b.assist_90), ('bcc_90'::text,b.bcc_90), ('xa_90'::text,b.xa_90), ('xt_90'::text,b.xt_90), ('xt_pass_90'::text,b.xt_pass_90), ('xt_carry_90'::text,b.xt_carry_90), ('sca_90'::text,b.sca_90), ('long_90'::text,b.long_90), ('long_pct'::text,b.long_pct), ('shots_90'::text,b.shots_90), ('sot_90'::text,b.sot_90), ('goals_90'::text,b.goals_90), ('blocked_90'::text,b.blocked_90), ('xg_90'::text,b.xg_90), ('xg_per_shot'::text,b.xg_per_shot), ('finishing'::text,b.finishing), ('box_share'::text,b.box_share), ('shot_dist'::text,b.shot_dist), ('conversion'::text,b.conversion), ('shot_acc'::text,b.shot_acc), ('bigchance_90'::text,b.bigchance_90), ('weak_foot_share'::text,b.weak_foot_share), ('tackle_90'::text,b.tackle_90), ('tackle_pct'::text,b.tackle_pct), ('int_90'::text,b.int_90), ('clear_90'::text,b.clear_90), ('block_90'::text,b.block_90), ('recov_90'::text,b.recov_90), ('aerial_90'::text,b.aerial_90), ('aerial_pct'::text,b.aerial_pct), ('def_action_90'::text,b.def_action_90), ('def_height'::text,b.def_height), ('box_def_90'::text,b.box_def_90), ('channel_def_90'::text,b.channel_def_90), ('flank_def_90'::text,b.flank_def_90), ('counterpress_90'::text,b.counterpress_90), ('takeon_90'::text,b.takeon_90), ('takeon_pct'::text,b.takeon_pct), ('disp_90'::text,b.disp_90), ('badtouch_90'::text,b.badtouch_90), ('foul_com_90'::text,b.foul_com_90), ('foul_won_90'::text,b.foul_won_90), ('error_90'::text,b.error_90), ('carries_90'::text,b.carries_90), ('prog_carries_90'::text,b.prog_carries_90), ('carry_box_90'::text,b.carry_box_90), ('mean_carry_m'::text,b.mean_carry_m), ('carry_pen_90'::text,b.carry_pen_90), ('median_ttr'::text,b.median_ttr), ('quick_pct'::text,b.quick_pct), ('one_touch_pct'::text,b.one_touch_pct), ('aq_per_duel'::text,b.aq_per_duel), ('duel_quality'::text,b.duel_quality), ('recov_retention'::text,b.recov_retention), ('recov_prog_90'::text,b.recov_prog_90), ('save_pct'::text,b.save_pct), ('goals_prevented_90'::text,b.goals_prevented_90), ('saves_90'::text,b.saves_90), ('claims_90'::text,b.claims_90), ('sweeps_90'::text,b.sweeps_90), ('sweep_x'::text,b.sweep_x), ('hs_passes_90'::text,b.hs_passes_90), ('hs_prog_90'::text,b.hs_prog_90), ('hs_key_90'::text,b.hs_key_90), ('hs_shots_90'::text,b.hs_shots_90), ('hs_takeons_90'::text,b.hs_takeons_90), ('holds_90'::text,b.holds_90), ('hold_retention'::text,b.hold_retention), ('hold_prog_pct'::text,b.hold_prog_pct), ('hold_shot_pct'::text,b.hold_shot_pct), ('sp_xg_90'::text,b.sp_xg_90), ('sp_shots_90'::text,b.sp_shots_90), ('sp_aerials_90'::text,b.sp_aerials_90), ('sp_key_90'::text,b.sp_key_90), ('padj_tackle_90'::text,round(b.tackle_90 * b.padj, 2)), ('padj_int_90'::text,round(b.int_90 * b.padj, 2)), ('padj_def_90'::text,round(b.def_action_90 * b.padj, 2)), ('padj_recov_90'::text,round(b.recov_90 * b.padj, 2))) v(metric, value)
        ), ranked AS (
         SELECT l.player_id,
            l.pool,
            l.nineties,
            l.league,
            l.metric,
            l.value,
            d.higher_is_better,
            percent_rank() OVER (PARTITION BY l.league, l.pool, l.metric ORDER BY l.value) AS pr
           FROM long l
             JOIN metric_defs d ON d.key = l.metric
          WHERE l.nineties >= 6::numeric AND l.value IS NOT NULL
        )
 SELECT player_id,
    pool,
    metric,
    value,
    round((100::double precision *
        CASE
            WHEN higher_is_better THEN pr
            ELSE 1::double precision - pr
        END)::numeric, 0) AS pct,
    league
   FROM ranked with no data;
create materialized view public.mv_player_progression as  WITH pa AS (
         SELECT e.player_id,
            count(*) FILTER (WHERE e.type = 'Pass'::text) AS passes_att,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.end_x IS NOT NULL AND (e.end_x - e.x) >= 10::double precision) AS prog_att,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND e.end_x IS NOT NULL AND (e.end_x - e.x) >= 10::double precision) AS prog_cmp,
            count(*) FILTER (WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND e.end_x IS NOT NULL AND (e.end_x - e.x) >= 10::double precision AND e.end_x >= 66.7::double precision) AS prog_into_final
           FROM v_league_events e
          WHERE e.player_id IS NOT NULL
          GROUP BY e.player_id
        )
 SELECT pa.player_id,
    pcr.player,
    pcr.team,
    pcr.pos,
    m.nineties,
    pa.passes_att,
    pa.prog_att,
    pa.prog_cmp,
    round(pa.prog_att::numeric / NULLIF(m.nineties, 0::numeric), 2) AS prog_att_90,
    round(pa.prog_cmp::numeric / NULLIF(m.nineties, 0::numeric), 2) AS prog_cmp_90_own,
    round(pa.prog_into_final::numeric / NULLIF(m.nineties, 0::numeric), 2) AS prog_into_final_90,
    round(100.0 * pa.prog_cmp::numeric / NULLIF(pa.prog_att, 0)::numeric, 1) AS prog_completion,
    round(100.0 * pa.prog_att::numeric / NULLIF(pa.passes_att, 0)::numeric, 1) AS prog_tendency_pct
   FROM pa
     JOIN player_chain_roles pcr ON pcr.player_id = pa.player_id
     LEFT JOIN v_player_metrics_ext m ON m.player_id = pa.player_id with no data;
create materialized view public.mv_metric_examples as  WITH q AS (
         SELECT p.metric,
            p.pool,
            p.player_id,
            p.value,
            p.pct,
            p.league,
            s.player_name,
            s.team,
            s.nineties
           FROM mv_player_percentiles p
             JOIN mv_player_season s USING (player_id)
          WHERE s.nineties >= 8::numeric
        ), stat AS (
         SELECT q.metric,
            q.league,
            count(*) AS n,
            round(min(q.value), 3) AS min_v,
            round(percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (q.value::double precision))::numeric, 3) AS med_v,
            round(max(q.value), 3) AS max_v
           FROM q
          GROUP BY q.metric, q.league
        ), hi AS (
         SELECT DISTINCT ON (q.metric, q.league) q.metric,
            q.league,
            q.player_id,
            q.player_name,
            q.team,
            q.pool,
            q.value,
            q.nineties
           FROM q
          ORDER BY q.metric, q.league, q.value DESC
        ), lo AS (
         SELECT DISTINCT ON (q.metric, q.league) q.metric,
            q.league,
            q.player_id,
            q.player_name,
            q.team,
            q.pool,
            q.value,
            q.nineties
           FROM q
          ORDER BY q.metric, q.league, q.value
        )
 SELECT st.metric,
    st.n,
    st.min_v,
    st.med_v,
    st.max_v,
    hi.player_name AS hi_name,
    hi.team AS hi_team,
    hi.pool AS hi_pool,
    round(hi.value, 3) AS hi_value,
    hi.player_id AS hi_id,
    lo.player_name AS lo_name,
    lo.team AS lo_team,
    lo.pool AS lo_pool,
    round(lo.value, 3) AS lo_value,
    lo.player_id AS lo_id,
    st.league
   FROM stat st
     LEFT JOIN hi ON hi.metric = st.metric AND hi.league = st.league
     LEFT JOIN lo ON lo.metric = st.metric AND lo.league = st.league with no data;
create materialized view public.mv_player_pillars as  SELECT p.player_id,
    p.pool,
    d.pillar,
    min(d.ord) AS ord,
    round(sum(p.pct * d.weight) / NULLIF(sum(d.weight), 0::numeric), 1) AS score,
    count(*) AS markers_used,
    p.league
   FROM mv_player_percentiles p
     JOIN pillar_defs d ON d.metric = p.metric
  WHERE p.pool <> 'GK'::text
  GROUP BY p.player_id, p.pool, d.pillar, p.league with no data;
create materialized view public.player_search as  SELECT pcr.player_id,
    pcr.player,
    pcr.team,
    pcr.pos,
        CASE "right"(pcr.pos, 1)
            WHEN 'R'::text THEN 'R'::text
            WHEN 'L'::text THEN 'L'::text
            ELSE 'C'::text
        END AS side,
    z.pool,
    m.nineties,
    pcr.inv,
    b.age_seen,
    b.age_seen_date,
    b.height_cm,
    b.weight_kg,
    b.nationality,
    ft.foot,
    ft.left_share,
    ft.foot_confidence,
    ar.primary_label AS archetype_primary,
    ar.secondary_label AS archetype_secondary,
    ar.archetype,
    ar.pool_archetype,
    pcr.initiator,
    pcr.bridge,
    pcr.progressor,
    pcr.carrier,
    pcr.vertical,
    pcr.support_angle,
    pcr.individual,
    pcr.creator,
    pcr.box_threat,
    pcr.finisher,
    pcr.hold_secs,
    pcr.player_xt,
    pr.prog_att_90,
    pr.prog_completion,
    pr.prog_tendency_pct,
    pr.prog_into_final_90,
    tj.pct_over,
    tj.pct_around,
    tj.pct_through,
    tj.pct_inside,
    tj.pct_in_behind,
    tj.pct_outside,
    tj.comp_over,
    tj.comp_around,
    tj.comp_through,
    tj.fwd_passes,
    cv.early_shot_inv_90,
    cv.shot_chain_pct,
    cv.early_shot_pct,
    cv.mean_chain_xt,
    cv.mean_steps_from_end,
    m.pass_cmp_90,
    m.pass_pct,
    m.prog_cmp_90,
    m.prog_pct,
    m.into_box_90,
    m.final_third_90,
    m.through_90,
    m.cross_90,
    m.cross_pct,
    m.key_pass_90,
    m.assist_90,
    m.bcc_90,
    m.long_90,
    m.long_pct,
    m.carries_90,
    m.prog_carries_90,
    m.carry_box_90,
    m.mean_carry_m,
    m.carry_pen_90,
    m.takeon_90,
    m.takeon_pct,
    m.disp_90,
    m.shots_90,
    m.sot_90,
    m.goals_90,
    m.xg_90,
    m.xg_per_shot,
    m.conversion,
    m.bigchance_90,
    m.finishing,
    m.xt_90,
    m.xt_pass_90,
    m.xt_carry_90,
    m.xa_90,
    m.sca_90,
    m.tackle_90,
    m.tackle_pct,
    m.int_90,
    m.recov_90,
    m.aerial_90,
    m.aerial_pct,
    m.counterpress_90,
    m.def_action_90,
    m.box_def_90,
    m.channel_def_90,
    m.flank_def_90,
    COALESCE(pl.league, 'USA-MLS'::text) AS league
   FROM player_chain_roles pcr
     JOIN pcr_z z ON z.player_id = pcr.player_id
     LEFT JOIN v_player_metrics_ext m ON m.player_id = pcr.player_id
     LEFT JOIN player_bio b ON b.player_id = pcr.player_id
     LEFT JOIN mv_player_foot ft ON ft.player_id = pcr.player_id
     LEFT JOIN mv_player_archetype ar ON ar.player_id = pcr.player_id
     LEFT JOIN mv_player_progression pr ON pr.player_id = pcr.player_id
     LEFT JOIN mv_player_pass_traj tj ON tj.player_id = pcr.player_id
     LEFT JOIN mv_player_chain_value cv ON cv.player_id = pcr.player_id
     LEFT JOIN mv_player_league pl ON pl.player_id = pcr.player_id with no data;
create materialized view public.mv_league_summary as  WITH ev AS (
         SELECT events.league,
            count(DISTINCT events.game_id) AS matches,
            count(DISTINCT events.team) AS teams
           FROM v_league_events events
          GROUP BY events.league
        ), seq AS (
         SELECT sequences.league,
            count(*) AS sequences
           FROM v_league_sequences sequences
          GROUP BY sequences.league
        ), pl AS (
         SELECT player_search.league,
            count(*) AS players_profiled
           FROM player_search
          GROUP BY player_search.league
        ), ins AS (
         SELECT tl.league,
            count(*) AS insights
           FROM insights i
             JOIN mv_team_league tl ON tl.team = i.team
          GROUP BY tl.league
        )
 SELECT l.league,
    l.display_name,
    l.country,
    l.season,
    COALESCE(ev.matches, 0::bigint) AS matches,
    COALESCE(ev.teams, 0::bigint) AS teams,
    COALESCE(pl.players_profiled, 0::bigint) AS players_profiled,
    COALESCE(seq.sequences, 0::bigint) AS sequences,
    COALESCE(ins.insights, 0::bigint) AS insights
   FROM leagues l
     LEFT JOIN ev ON ev.league = l.league
     LEFT JOIN seq ON seq.league = l.league
     LEFT JOIN pl ON pl.league = l.league
     LEFT JOIN ins ON ins.league = l.league
  WHERE l.is_active with no data;
create materialized view public.mv_player_dna as  WITH w AS (
         SELECT p.player_id,
            p.pool,
            p.pillar,
            p.score,
            p.league,
            COALESCE(rw.weight, 0::numeric) AS weight
           FROM mv_player_pillars p
             LEFT JOIN role_pillar_weights rw ON rw.pool = p.pool AND rw.pillar = p.pillar
        ), ranked AS (
         SELECT w.player_id,
            w.pool,
            w.pillar,
            w.score,
            w.league,
            w.weight,
            row_number() OVER (PARTITION BY w.player_id ORDER BY w.score DESC) AS rk_all,
            row_number() OVER (PARTITION BY w.player_id ORDER BY (w.score * w.weight) DESC) AS rk_rel
           FROM w
        ), raw AS (
         SELECT ranked.player_id,
            ranked.pool,
            min(ranked.league) AS league,
            round(exp(sum(ranked.weight * ln(GREATEST(ranked.score, 1::numeric))) FILTER (WHERE ranked.weight > 0::numeric) / NULLIF(sum(ranked.weight) FILTER (WHERE ranked.weight > 0::numeric), 0::numeric)), 1) AS completeness_raw,
            round(avg(ranked.score) FILTER (WHERE ranked.weight > 0::numeric AND ranked.rk_rel <= 2), 1) AS impact_raw,
            round(avg(ranked.score) FILTER (WHERE ranked.weight > 0::numeric), 1) AS mean_relevant,
            round(stddev_pop(ranked.score) FILTER (WHERE ranked.weight > 0::numeric), 1) AS spread,
            max(
                CASE
                    WHEN ranked.rk_all = 1 THEN ranked.pillar
                    ELSE NULL::text
                END) AS top_pillar,
            max(
                CASE
                    WHEN ranked.rk_all = 2 THEN ranked.pillar
                    ELSE NULL::text
                END) AS second_pillar
           FROM ranked
          GROUP BY ranked.player_id, ranked.pool
        ), weak AS (
         SELECT DISTINCT ON (ranked.player_id) ranked.player_id,
            ranked.pillar AS weakest_pillar,
            ranked.score AS weakest_score
           FROM ranked
          WHERE ranked.weight > 0::numeric
          ORDER BY ranked.player_id, ranked.score
        )
 SELECT r.player_id,
    r.pool,
    r.mean_relevant,
    r.spread,
    r.top_pillar,
    r.second_pillar,
    w2.weakest_pillar,
    w2.weakest_score,
    r.completeness_raw,
    r.impact_raw,
    round(100::double precision * percent_rank() OVER (PARTITION BY r.league, r.pool ORDER BY r.completeness_raw)) AS completeness,
    round(100::double precision * percent_rank() OVER (PARTITION BY r.league, r.pool ORDER BY r.impact_raw)) AS impact,
    r.league
   FROM raw r
     JOIN weak w2 USING (player_id) with no data;
create materialized view public.mv_player_pct as  WITH u AS (
         SELECT ps.player_id,
            ps.player,
            ps.pool,
            ps.archetype_primary,
            ps.league,
            m.metric,
            m.raw
           FROM player_search ps
             CROSS JOIN LATERAL ( VALUES ('xt_90'::text,ps.xt_90), ('xt_pass_90'::text,ps.xt_pass_90), ('xt_carry_90'::text,ps.xt_carry_90), ('player_xt'::text,ps.player_xt), ('prog_att_90'::text,ps.prog_att_90), ('prog_cmp_90'::text,ps.prog_cmp_90), ('prog_completion'::text,ps.prog_completion), ('prog_tendency_pct'::text,ps.prog_tendency_pct), ('prog_into_final_90'::text,ps.prog_into_final_90), ('into_box_90'::text,ps.into_box_90), ('final_third_90'::text,ps.final_third_90), ('through_90'::text,ps.through_90), ('long_90'::text,ps.long_90), ('long_pct'::text,ps.long_pct), ('pass_cmp_90'::text,ps.pass_cmp_90), ('pass_pct'::text,ps.pass_pct), ('pct_over'::text,ps.pct_over), ('pct_around'::text,ps.pct_around), ('pct_through'::text,ps.pct_through), ('pct_in_behind'::text,ps.pct_in_behind), ('pct_inside'::text,ps.pct_inside), ('pct_outside'::text,ps.pct_outside), ('comp_through'::text,ps.comp_through), ('comp_over'::text,ps.comp_over), ('carries_90'::text,ps.carries_90), ('prog_carries_90'::text,ps.prog_carries_90), ('carry_box_90'::text,ps.carry_box_90), ('carry_pen_90'::text,ps.carry_pen_90), ('mean_carry_m'::text,ps.mean_carry_m), ('takeon_90'::text,ps.takeon_90), ('takeon_pct'::text,ps.takeon_pct), ('disp_90'::text,ps.disp_90), ('xa_90'::text,ps.xa_90), ('key_pass_90'::text,ps.key_pass_90), ('sca_90'::text,ps.sca_90), ('bcc_90'::text,ps.bcc_90), ('assist_90'::text,ps.assist_90), ('cross_90'::text,ps.cross_90), ('cross_pct'::text,ps.cross_pct), ('xg_90'::text,ps.xg_90), ('goals_90'::text,ps.goals_90), ('shots_90'::text,ps.shots_90), ('sot_90'::text,ps.sot_90), ('xg_per_shot'::text,ps.xg_per_shot), ('conversion'::text,ps.conversion), ('finishing'::text,ps.finishing), ('bigchance_90'::text,ps.bigchance_90), ('early_shot_inv_90'::text,ps.early_shot_inv_90), ('shot_chain_pct'::text,ps.shot_chain_pct), ('early_shot_pct'::text,ps.early_shot_pct), ('mean_chain_xt'::text,ps.mean_chain_xt), ('def_action_90'::text,ps.def_action_90), ('tackle_90'::text,ps.tackle_90), ('tackle_pct'::text,ps.tackle_pct), ('int_90'::text,ps.int_90), ('recov_90'::text,ps.recov_90), ('aerial_90'::text,ps.aerial_90), ('aerial_pct'::text,ps.aerial_pct), ('counterpress_90'::text,ps.counterpress_90), ('box_def_90'::text,ps.box_def_90), ('channel_def_90'::text,ps.channel_def_90), ('flank_def_90'::text,ps.flank_def_90)) m(metric, raw)
          WHERE ps.nineties >= 3::numeric
        ), ranked AS (
         SELECT u.player_id,
            u.player,
            u.pool,
            u.archetype_primary,
            u.league,
            u.metric,
            u.raw,
            d.higher_better,
            percent_rank() OVER (PARTITION BY u.league, u.pool, u.metric ORDER BY u.raw) AS pr_pool,
            percent_rank() OVER (PARTITION BY u.league, u.archetype_primary, u.metric ORDER BY u.raw) AS pr_arch,
            count(*) OVER (PARTITION BY u.league, u.archetype_primary, u.metric) AS arch_n
           FROM u
             JOIN metric_catalog d ON d.metric = u.metric
          WHERE u.raw IS NOT NULL
        )
 SELECT player_id,
    player,
    pool,
    archetype_primary,
    metric,
    raw,
    higher_better,
    round(100::double precision *
        CASE
            WHEN higher_better THEN pr_pool
            ELSE 1::double precision - pr_pool
        END)::integer AS pct_pool,
        CASE
            WHEN arch_n >= 15 THEN round(100::double precision *
            CASE
                WHEN higher_better THEN pr_arch
                ELSE 1::double precision - pr_arch
            END)::integer
            ELSE NULL::integer
        END AS pct_archetype,
    arch_n AS archetype_cohort,
    league
   FROM ranked with no data;
create materialized view public.mv_site_summary as  SELECT ( SELECT max(m.date) AS max
           FROM v_league_matches m
          WHERE m.home_score IS NOT NULL AND (EXISTS ( SELECT 1
                   FROM v_league_events e
                  WHERE e.game_id = m.game_id))) AS as_of_match_date,
    ( SELECT count(DISTINCT events.game_id) AS count
           FROM v_league_events events) AS matches_analysed,
    ( SELECT count(*) AS count
           FROM v_league_events events) AS events,
    ( SELECT count(*) AS count
           FROM v_league_sequences sequences) AS sequences,
    ( SELECT count(*) AS count
           FROM leagues
          WHERE leagues.is_active) AS leagues_active,
    ( SELECT count(DISTINCT events.league) AS count
           FROM v_league_events events) AS leagues_with_data,
    ( SELECT count(DISTINCT events.team) AS count
           FROM v_league_events events) AS clubs,
    ( SELECT count(DISTINCT events.player_id) AS count
           FROM v_league_events events
          WHERE events.player_id IS NOT NULL) AS players_touched_ball,
    ( SELECT count(DISTINCT mv_player_season.player_id) AS count
           FROM mv_player_season) AS players_in_matchday_squads,
    ( SELECT count(*) AS count
           FROM ( SELECT mv_player_season.player_id
                   FROM mv_player_season
                EXCEPT
                 SELECT events.player_id
                   FROM v_league_events events
                  WHERE events.player_id IS NOT NULL) z) AS players_named_never_involved,
    ( SELECT count(*) AS count
           FROM player_search) AS players_profiled_outfield,
    ( SELECT count(*) AS count
           FROM insights) AS insights,
    ( SELECT count(DISTINCT insights.team) AS count
           FROM insights) AS clubs_with_insights,
    ( SELECT count(*) AS count
           FROM metric_defs) AS metrics_player,
    ( SELECT count(*) AS count
           FROM team_metric_defs) AS metrics_team,
    ( SELECT count(*) AS count
           FROM mv_shot_xg
          WHERE mv_shot_xg.is_pen = false) AS shots_non_pen,
    ( SELECT round(sum(mv_shot_xg.xg), 1) AS round
           FROM mv_shot_xg
          WHERE mv_shot_xg.is_pen = false) AS xg_predicted,
    ( SELECT count(*) AS count
           FROM mv_shot_xg
          WHERE mv_shot_xg.is_pen = false AND mv_shot_xg.is_goal) AS goals_actual,
    ( SELECT count(*) AS count
           FROM invariants
          WHERE invariants.enabled AND invariants.severity = 'error'::text) AS checks_error,
    ( SELECT count(*) AS count
           FROM invariants
          WHERE invariants.enabled AND invariants.severity = 'warn'::text) AS checks_warn,
    now() AS refreshed_at with no data;
create view public.v_league_summary as  SELECT league,
    display_name,
    country,
    season,
    matches,
    teams,
    players_profiled,
    sequences,
    insights
   FROM mv_league_summary;

-- === relation_options ===
alter view public.v_league_summary set (security_invoker=true);

-- === relations ===
create view public.v_player_pct_all as  SELECT mv_player_pct.player_id,
    mv_player_pct.player,
    mv_player_pct.pool,
    mv_player_pct.metric,
    mv_player_pct.pct_pool AS pct,
    mv_player_pct.league
   FROM mv_player_pct
UNION ALL
 SELECT p.player_id,
    p.player,
    p.pool,
    'role_'::text || p.role AS metric,
    p.pct,
    p.league
   FROM player_chain_pct p;

-- === relation_options ===
alter view public.v_player_pct_all set (security_invoker=true);

-- === functions ===
CREATE OR REPLACE FUNCTION public.analytics_rebuild_run_status(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select to_jsonb(r) from public.analytics_rebuild_runs r where r.run_id=p_run_id;$function$
;
CREATE OR REPLACE FUNCTION public.build_insights()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '180s'
AS $function$
declare v_ct int;
begin
  truncate table public.insights;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with pctr as (
    select p.player_id, p.player, p.pool, p.role, p.raw, p.pct,
      row_number() over (partition by p.pool, p.role order by p.raw desc) rrk,
      p.raw - lead(p.raw) over (partition by p.pool, p.role order by p.raw desc) gap2
    from public.player_chain_pct p
  ),
  firsts as (select * from pctr where rrk=1 and pct>=99),
  tops as (select distinct on (player_id) * from firsts order by player_id, gap2 desc nulls last)
  select 'sd','role_profile','player', t.player_id, t.player, pcr.team, 'standout_profile',
    format('%s tops the %s pool for %s', t.player, t.pool, lbl.friendly),
    format('The league''s most %s profile among %ss, across %s involvements, clear of the next by %s. A shortlist anchor.',
      lbl.friendly, t.pool, pcr.inv, round(t.gap2::numeric,1)),
    jsonb_build_object('pool',t.pool,'role',lbl.friendly,'percentile',t.pct,'inv',pcr.inv,'gap_to_2nd',round(t.gap2::numeric,1)),
    jsonb_build_object('player_id',t.player_id), round(coalesce(t.gap2,0)::numeric,2),
    case when pcr.inv>=300 then 'high' else 'medium' end
  from tops t
  join public.player_chain_roles pcr on pcr.player_id=t.player_id
  join lateral (values
    ('progressor','ball-progression'),('initiator','build-up initiation'),('creator','chance-creation'),
    ('box_threat','box threat'),('carrier','ball-carrying'),('vertical','vertical passing'),
    ('support_angle','diagonal support'),('bridge','third-man bridging'),('finisher','finishing'),
    ('individual','1v1 dribbling'),('controller','tempo control')) lbl(key,friendly) on lbl.key=t.role
  where pcr.inv>=150;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with pr as (
    select team, player_id, player, r.label role, (inv * r.pctval/100.0) rinv
    from public.player_chain_roles
    cross join lateral (values ('ball progression', progressor),('chance creation', creator),
      ('build-up initiation', initiator),('third-man bridging', bridge)) r(label,pctval)
  ),
  tot as (select team, role, sum(rinv) team_rinv from pr group by team, role),
  sh as (select pr.team, pr.player_id, pr.player, pr.role, pr.rinv/nullif(t.team_rinv,0) share,
      row_number() over (partition by pr.team, pr.role order by pr.rinv desc) rk
    from pr join tot t using (team, role)),
  rolep as (select role, percentile_cont(0.9) within group (order by share) p90 from sh where rk=1 group by role),
  top2 as (select team, role, max(share) filter (where rk=1) s1, max(player) filter (where rk=1) p1,
      max(player_id) filter (where rk=1) pid1, max(share) filter (where rk=2) s2
    from sh where rk<=2 group by team, role)
  select 'sd','key_man_risk','team', t.team, t.team, t.team, 'key_man',
    format('%s carries %s''s %s', t.p1, t.team, t.role),
    format('%s handles %s%% of %s''s %s work with a %s-point drop to the next man. No close deputy.',
      t.p1, round(100*t.s1), t.team, t.role, round(100*(t.s1-t.s2))),
    jsonb_build_object('role',t.role,'share_pct',round(100*t.s1,1),'gap_to_2nd_pct',round(100*(t.s1-t.s2),1),'player',t.p1),
    jsonb_build_object('player_id',t.pid1,'team',t.team), round(100*(t.s1-t.s2),1), 'medium'
  from top2 t join rolep rp using(role)
  where t.s1 >= rp.p90 and (t.s1 - t.s2) >= 0.07;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with targets(pool, role, friendly, why) as (values
    ('CB','progressor','ball-playing centre-back','building out from the back'),
    ('FB','carrier','attacking full-back','carrying the ball forward from wide'),
    ('CM','creator','creative midfielder','manufacturing chances from midfield'),
    ('CM','progressor','progressive midfielder','moving the ball forward through the middle'),
    ('AM','creator','creative number ten','unlocking a low block'),
    ('W','individual','one-v-one winger','beating a full-back in isolation'),
    ('ST','box_threat','penalty-box striker','occupying the six-yard area')
  ),
  best as (
    select pcr.team, t.pool, t.role, t.friendly, t.why,
      max(p.pct) as best_pct, (array_agg(p.player order by p.pct desc))[1] as best_player, count(*) as options
    from targets t
    join public.player_chain_pct p on p.pool = t.pool and p.role = t.role
    join public.player_chain_roles pcr on pcr.player_id = p.player_id
    group by pcr.team, t.pool, t.role, t.friendly, t.why
  )
  select 'sd','squad_gap','team', b.team, b.team, b.team, 'squad_gap',
    format('%s have no high-end %s', b.team, b.friendly),
    format('Their best option ranks in the %sth percentile of the %s pool (%s). A clear recruitment lane for %s.',
      b.best_pct, b.pool, b.best_player, b.why),
    jsonb_build_object('pool',b.pool,'role',b.role,'best_pct',b.best_pct,'best_player',b.best_player,'options',b.options),
    jsonb_build_object('team',b.team), (50 - b.best_pct), 'medium'
  from best b where b.best_pct <= 35;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'sd','usage','player', r.player_id, r.player, r.team, 'minutes_inflated',
    format('%s''s minutes come in decided games', r.player),
    format('Plays %s%% of available minutes for %s, but only %s%% of his time on the pitch is with the game within one goal, bottom quartile in the league. Per-90 numbers should be read with that in mind.',
      r.selection_pct, r.team, r.leverage_pct),
    jsonb_build_object('selection_pct',r.selection_pct,'leverage_pct',r.leverage_pct,'squad_role',r.squad_role),
    jsonb_build_object('player_id',r.player_id,'team',r.team), (100 - r.leverage_pct), 'medium'
  from public.v_squad_role r where r.minutes_inflated;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with freq as (
    select pool, primary_label, count(*) n,
      round(100.0*count(*)/sum(count(*)) over (partition by pool), 1) pct_of_pool
    from public.mv_player_archetype group by pool, primary_label
  )
  select 'sd','role_profile','player', a.player_id, a.player, pcr.team, 'misfit_profile',
    format('%s is an unusual %s', a.player, a.pool),
    format('Listed as a %s but behaves like a %s, a profile only %s%% of the %s pool shares. Either a tactical quirk worth exploiting or a player in the wrong role.',
      a.pool, a.primary_label, f.pct_of_pool, a.pool),
    jsonb_build_object('pool',a.pool,'archetype',a.archetype,'primary',a.primary_label,
      'primary_pct',a.primary_pct,'share_of_pool',f.pct_of_pool),
    jsonb_build_object('player_id',a.player_id), (100 - f.pct_of_pool), 'medium'
  from public.mv_player_archetype a
  join freq f on f.pool = a.pool and f.primary_label = a.primary_label
  join public.player_chain_roles pcr on pcr.player_id = a.player_id
  where f.pct_of_pool <= 5 and a.primary_pct >= 85 and pcr.inv >= 250;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with extremes as (
    select team, metric, z, abs(z) az, row_number() over (partition by team order by abs(z) desc) rk
    from public.team_sequence_style where z is not null
  ),
  top as (select * from extremes where rk = 1),
  sig as (select * from public.v_team_signature)
  select 'tactical','identity','team', t.team, t.team, t.team, 'team_profile',
    case when t.az >= 1.5 then format('%s are defined by their %s', t.team, replace(t.metric,'_',' '))
         when t.az >= 0.8 then format('%s lean towards %s', t.team, replace(t.metric,'_',' '))
         else format('%s have no pronounced identity', t.team) end,
    case when t.az >= 0.8 then
      format('Their most distinctive trait is %s (%s standard deviations from the league mean). They break teams down mostly %s, which is %s by league standards.',
        replace(t.metric,'_',' '), round(t.z,1), lower(s.signature_route), s.signature_verdict)
    else
      format('Nothing in their possession profile sits far from the league average, the most distinctive trait being %s at %s standard deviations. They lean %s, %s by league standards. A side without a strong stylistic fingerprint.',
        replace(t.metric,'_',' '), round(t.z,1), lower(s.signature_route), s.signature_verdict) end,
    jsonb_build_object('top_metric',t.metric,'z',round(t.z,2),
      'signature_route',s.signature_route,'route_share',s.share_pct,'route_verdict',s.signature_verdict),
    jsonb_build_object('team',t.team), t.az, 'medium'
  from top t left join sig s on s.team = t.team;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'tactical','defending','team', p.team, p.team, p.team, 'press_vulnerability',
    case when p.z_vs_direct <= -1.0 then format('%s struggle against direct play', p.team)
         else format('%s struggle against short build-up', p.team) end,
    case when p.z_vs_direct <= -1.0 then
      format('They contain long, direct possessions %s standard deviations worse than the league, while handling short build-up at %s. Opponents who go over them find joy.',
        round(abs(p.z_vs_direct),1), round(p.z_vs_short_build,1))
    else
      format('They contain patient build-up %s standard deviations worse than the league, while coping with direct play at %s. Sides that play through them find joy.',
        round(abs(p.z_vs_short_build),1), round(p.z_vs_direct,1)) end,
    jsonb_build_object('z_vs_direct',p.z_vs_direct,'z_vs_short_build',p.z_vs_short_build,
      'raw_vs_direct',p.raw_vs_direct,'raw_vs_short_build',p.raw_vs_short_build),
    jsonb_build_object('team',p.team), greatest(abs(p.z_vs_direct), abs(p.z_vs_short_build)), 'medium'
  from public.v_press_profile p
  where p.z_vs_direct <= -1.0 or p.z_vs_short_build <= -1.0;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'tactical','identity','team', d.team, d.team, d.team, 'game_state_reactivity',
    case when d.swing_l_minus_w >= 0.03 then format('%s change shape with the scoreline', d.team)
         else format('%s play the same way whatever the score', d.team) end,
    case when d.swing_l_minus_w >= 0.03 then
      format('Their possessions run %s directness when losing against %s when winning, one of the sharper swings in the league. A reactive side rather than a settled one.',
        d.dir_losing, d.dir_winning)
    else
      format('Directness barely moves between winning (%s) and losing (%s). A settled identity that does not chase the game.',
        d.dir_winning, d.dir_losing) end,
    jsonb_build_object('dir_winning',d.dir_winning,'dir_drawing',d.dir_drawing,
      'dir_losing',d.dir_losing,'swing',d.swing_l_minus_w),
    jsonb_build_object('team',d.team), abs(d.swing_l_minus_w)*100, 'medium'
  from public.mv_team_directness_state d
  where abs(d.swing_l_minus_w) >= 0.03 or d.swing_rank <= 3;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by passes_seq desc) pass_rk,
      rank() over (order by xt_seq desc) xt_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','identity','team', team, team, team, 'sterile_control',
    format('%s dominate the ball without threat', team),
    format('%s passes per sequence (%s of %s) but only %s xT per possession (%s of %s). Control without penetration.',
      passes_seq, pass_rk, nteams, xt_seq, xt_rk, nteams),
    jsonb_build_object('passes_seq',passes_seq,'passes_rank',pass_rk,'xt_seq',xt_seq,'xt_rank',xt_rk),
    jsonb_build_object('team',team), (xt_rk - pass_rk), 'medium'
  from r where pass_rk <= 8 and xt_rk >= (nteams-9);

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by finds_central_pct desc) c_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','style','team', team, team, team, 'central_funnel',
    format('%s funnel everything through the middle', team),
    format('%s%% of progression runs central (%s of %s), the heaviest reliance on interior play in the league.',
      finds_central_pct, c_rk, nteams),
    jsonb_build_object('finds_central_pct',finds_central_pct,'central_rank',c_rk),
    jsonb_build_object('team',team), (nteams-c_rk), 'medium'
  from r where c_rk<=4;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by finds_wide_pct desc) w_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','style','team', team, team, team, 'byline_team',
    format('%s attack down the outside', team),
    format('%s%% of progression goes wide (%s of %s). Built to reach the byline rather than play through the lines.',
      finds_wide_pct, w_rk, nteams),
    jsonb_build_object('finds_wide_pct',finds_wide_pct,'wide_rank',w_rk),
    jsonb_build_object('team',team), (nteams-w_rk), 'medium'
  from r where w_rk<=4;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by ends_opp_half_pct desc) opp_rk,
      rank() over (order by end_att_third_pct desc) att_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','identity','team', team, team, team, 'territorial',
    format('%s pin opponents in', team),
    format('%s%% of sequences end in the opposition half and %s%% in the final third (%s and %s of %s). A front-foot territorial identity.',
      ends_opp_half_pct, end_att_third_pct, opp_rk, att_rk, nteams),
    jsonb_build_object('ends_opp_half_pct',ends_opp_half_pct,'end_att_third_pct',end_att_third_pct),
    jsonb_build_object('team',team), (nteams-opp_rk)+(nteams-att_rk), 'medium'
  from r where opp_rk<=6 and att_rk<=6;

  select count(*) into v_ct from public.insights;
  return format('built %s insights at %s', v_ct, now()::timestamptz(0));
end $function$
;
CREATE OR REPLACE FUNCTION public.build_insights_extra()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '180s'
AS $function$
declare v_ct int;
begin
  delete from public.insights where detector in
    ('counter_attack','low_block','team_strength','team_weakness','player_elite','player_weakness');

  -- 1) counter-attacking identity.
  -- The rank-based version fired for the top four in every league, so in a competition
  -- where every side had zero counter-attacks it announced six teams as breaking at speed
  -- from deep on 0.00%. Now requires a non-zero rate AND a real denominator.
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with c as (
    select s.team, s.league,
      round(100.0*avg((s.start_x < 33.3 and s.ended_shot and s.dur_s <= 15)::int), 2) counter_pct,
      count(*) filter (where s.start_x < 33.3) deep_n,
      round(avg(s.dur_s),1) secs
    from v_league_sequences as s where s.is_open_play group by s.team, s.league
  ),
  r as (
    select c.*, m.possession_pct, m.ppda, m.directness, ts.matches,
      rank() over (partition by c.league order by c.counter_pct desc) ck,
      count(*) over (partition by c.league) n
    from c
    join public.mv_team_all m on m.team = c.team
    join public.v_team_sample ts on ts.team = c.team
    where ts.meets_min_matches and c.counter_pct > 0 and c.deep_n >= 120
  )
  select 'tactical','identity','team', team, team, team, 'counter_attack',
    format('%s break at speed from deep', team),
    format('%s%% of their possessions start in their own third and reach a shot inside 15 seconds, ranked %s of %s, measured across %s deep starts in %s matches. They do it with only %s%% of the ball and a passive press (PPDA %s), which is the shape of a side that invites pressure and punishes the turnover.',
      counter_pct, ck, n, deep_n, matches, possession_pct, ppda),
    jsonb_build_object('counter_pct',counter_pct,'counter_rank',ck,'deep_starts',deep_n,
      'matches',matches,'possession_pct',possession_pct,'ppda',ppda),
    jsonb_build_object('team',team), (n-ck)+10, 'medium',
    'A counter-attacking profile is a choice, not a shortfall, but it does make a side dependent on the opponent committing bodies forward. Against a team that also sits deep, the same numbers tend to collapse.'
  from r where ck <= 4;

  -- 2) low block
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select m.team, m.ppda, m.def_height, m.possession_pct, ts.matches,
      rank() over (order by m.ppda desc) pk, count(*) over () n
    from public.mv_team_all m
    join public.v_team_sample ts on ts.team = m.team
    where ts.meets_min_matches
  )
  select 'tactical','defending','team', team, team, team, 'low_block',
    format('%s defend deep and let you have it', team),
    format('PPDA of %s (%s of %s, higher means less pressing) with a defensive line at %s and only %s%% of the ball, across %s matches. They concede territory deliberately rather than contesting it.',
      ppda, pk, n, def_height, possession_pct, matches),
    jsonb_build_object('ppda',ppda,'ppda_rank',pk,'def_height',def_height,
      'possession_pct',possession_pct,'matches',matches),
    jsonb_build_object('team',team), (n-pk)+5, 'medium',
    'Read this with the counter-attack number. A deep block that breaks well is a plan; a deep block that does not is a side under pressure.'
  from r where pk <= 5 and def_height < 45;

  -- 3) strength and weakness, gated on sample
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.team, p.metric, p.value, p.pct, d.label, p.league, ts.matches,
      row_number() over (partition by p.team order by p.pct desc) best,
      rank() over (partition by p.league, p.metric order by p.pct desc) lr,
      count(*) over (partition by p.league, p.metric) n
    from public.mv_team_percentiles p
    join public.team_metric_defs d on d.key = p.metric
    join public.v_team_sample ts on ts.team = p.team
    where p.pct is not null and ts.meets_min_matches
  )
  select 'tactical','identity','team', team, team, team, 'team_strength',
    format('%s: best in the squad at %s', team, lower(label)),
    format('%s, which puts them %s of %s in the league and in the %sth percentile across %s matches.',
      value, lr, n, pct, matches),
    jsonb_build_object('metric',metric,'label',label,'value',value,'pct',pct,'rank',lr,'matches',matches),
    jsonb_build_object('team',team), pct, 'medium',
    'A team''s strongest percentile is relative to the league, not an absolute strength. If the whole division is poor at something, leading it means less than it reads.'
  from r where best = 1;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.team, p.metric, p.value, p.pct, d.label, p.league, ts.matches,
      row_number() over (partition by p.team order by p.pct asc) worst,
      rank() over (partition by p.league, p.metric order by p.pct asc) lr,
      count(*) over (partition by p.league, p.metric) n
    from public.mv_team_percentiles p
    join public.team_metric_defs d on d.key = p.metric
    join public.v_team_sample ts on ts.team = p.team
    where p.pct is not null and ts.meets_min_matches
  )
  select 'tactical','identity','team', team, team, team, 'team_weakness',
    format('%s: weakest at %s', team, lower(label)),
    format('%s, which is %s of %s in the league and the %sth percentile across %s matches.',
      value, lr, n, pct, matches),
    jsonb_build_object('metric',metric,'label',label,'value',value,'pct',pct,'rank',lr,'matches',matches),
    jsonb_build_object('team',team), (100-pct), 'medium',
    'Before treating this as a problem, ask whether it is a by-product of how they choose to play. A counter-attacking side will always look poor for possession, and that is deliberate.'
  from r where worst = 1;

  -- 4/5) player detectors are unchanged here; build_insights_players rebuilds them
  select count(*) into v_ct from public.insights;
  return format('extra detectors rebuilt, %s insights', v_ct);
end $function$
;
CREATE OR REPLACE FUNCTION public.build_insights_players()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '180s'
AS $function$
declare v_ct int;
begin
  delete from public.insights where detector in ('player_elite','player_weakness');

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.player_id, p.player, p.pool, p.metric, p.raw, p.pct_pool, d.label, d.unit, d.grp,
      d.higher_better, ps.team, ps.nineties,
      rank() over (partition by p.pool, p.metric order by p.pct_pool desc, ps.nineties desc) rk,
      count(*) over (partition by p.pool, p.metric) n
    from public.mv_player_pct p
    join public.player_search ps on ps.player_id = p.player_id
    join public.metric_catalog d on d.metric = p.metric
    join public.pool_metric_relevance rel on rel.pool = p.pool and rel.grp = d.grp
    where ps.nineties >= 8
      -- an inverted metric at zero is an absence, not an achievement worth a headline
      and not (d.higher_better = false and p.raw = 0)
      and not (d.higher_better = true and p.raw = 0)
  ),
  best as (select distinct on (player_id) * from r where rk <= 5 order by player_id, rk, n desc)
  select 'sd','player_rank','player', player_id, player, team, 'player_elite',
    case when higher_better
      then format('%s is %s in the league for %s among %ss', player,
             case rk when 1 then 'first' when 2 then 'second' when 3 then 'third'
                     when 4 then 'fourth' else 'fifth' end, lower(label), pool)
      else format('%s concedes the fewest %s among %ss (%s in the league)', player,
             lower(label), pool,
             case rk when 1 then 'first' when 2 then 'second' when 3 then 'third'
                     when 4 then 'fourth' else 'fifth' end)
    end,
    format('%s%s across %s full matches, ranked %s of %s %ss%s.',
      raw, case when unit is null then '' else ' '||unit end, round(nineties,1), rk, n, pool,
      case when higher_better then '' else ' (lower is better for this metric)' end),
    jsonb_build_object('metric',metric,'label',label,'value',raw,'pct',pct_pool,
      'rank',rk,'pool',pool,'group',grp,'higher_better',higher_better),
    jsonb_build_object('player_id',player_id), (100 - rk*3), 'medium',
    'A league-leading rate is worth checking against volume and game state. A player at a dominant side accumulates more of most things, and output banked in decided games is worth less than the same output in tight ones.'
  from best;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.player_id, p.player, p.pool, p.metric, p.raw, p.pct_pool, d.label, d.unit,
      ps.team, ps.nineties,
      row_number() over (partition by p.player_id order by p.pct_pool asc) w,
      max(p.pct_pool) over (partition by p.player_id) best_pct
    from public.mv_player_pct p
    join public.player_search ps on ps.player_id = p.player_id
    join public.metric_catalog d on d.metric = p.metric
    join public.pool_metric_relevance rel on rel.pool = p.pool and rel.grp = d.grp
    where ps.nineties >= 10
  )
  select 'sd','player_rank','player', player_id, player, team, 'player_weakness',
    format('%s struggles with %s', player, lower(label)),
    format('%s%s puts him in the %sth percentile of %ss across %s full matches, his clearest weakness in an area the role asks for. He reaches the %sth percentile at his best.',
      raw, case when unit is null then '' else ' '||unit end, pct_pool, pool, round(nineties,1), best_pct),
    jsonb_build_object('metric',metric,'label',label,'value',raw,'pct',pct_pool,
      'pool',pool,'best_pct',best_pct,'nineties',round(nineties,1)),
    jsonb_build_object('player_id',player_id), (best_pct - pct_pool), 'medium',
    'A low percentile is not automatically a flaw. It may be something his side never asks of him, and the honest test is whether the team loses anything because of it.'
  from r where w = 1 and pct_pool <= 8 and best_pct >= 70;

  update public.insights i set score =
    coalesce(dp.band, 5) * 1000 + least(999, greatest(0, round(coalesce(i.score, 0))))
  from public.detector_priority dp where dp.detector = i.detector;
  update public.insights set score = 5000 + least(999, greatest(0, round(coalesce(score,0))))
  where detector not in (select detector from public.detector_priority);

  select count(*) into v_ct from public.insights;
  return format('%s insights, re-ranked by detector priority', v_ct);
end $function$
;
CREATE OR REPLACE FUNCTION public.build_player_chain_roles()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  truncate table public.player_chain_roles;
  insert into public.player_chain_roles
    (player_id, player, team, pos, inv, player_xt, hold_secs,
     initiator, bridge, progressor, carrier, vertical, support_angle, individual, creator, box_threat, finisher)
  with base as (
    select game_id, period, expanded_minute, second, event_id, team, player, player_id, type, outcome_type,
      x, y, end_x, end_y, is_shot,
      case when type='Pass' and outcome_type='Successful' and end_x is not null
        then coalesce(public.xt_val(end_x,end_y),0)-coalesce(public.xt_val(x,y),0) else 0 end as xt_delta,
      case when jsonb_typeof(qualifiers)='array' then exists(select 1 from jsonb_array_elements(qualifiers) q
        where q->'type'->>'displayName' in ('ThrowIn','CornerTaken','FreekickTaken','GoalKick','KickOff','Penalty')) else false end as is_setpiece,
      case when type in ('Pass','TakeOn','BallTouch','MissedShots','SavedShot','ShotOnPost','Goal','KeeperPickup','Claim') then team end as ctrl_team,
      case when type in ('Foul','Card','OffsideGiven','OffsidePass','CornerAwarded','End') or is_goal then 1 else 0 end as stop_flag
    from v_league_events as events
  ),
  cum as (select *, sum(stop_flag) over (partition by game_id order by period,expanded_minute,second,event_id rows between unbounded preceding and current row) stop_cum from base),
  ctrl as (select *, lag(ctrl_team) over w prev_ctrl_team, lag(stop_cum) over w prev_stop_cum, lag(period) over w prev_period
    from cum where ctrl_team is not null window w as (partition by game_id order by period,expanded_minute,second,event_id)),
  bounded as (select *, case when prev_ctrl_team is null or period<>prev_period or ctrl_team<>prev_ctrl_team or is_setpiece or stop_cum>coalesce(prev_stop_cum,-1) then 1 else 0 end is_break from ctrl),
  seqd as (select *, sum(is_break) over (partition by game_id order by period,expanded_minute,second,event_id) seq_no from bounded),
  ordd as (select *,
    row_number() over w2 ord_a,
    count(*) over (partition by game_id,seq_no) seq_len,
    bool_or(is_break=1 and is_setpiece) over (partition by game_id,seq_no) seq_sp,
    lag(expanded_minute*60+second) over w2 prev_t,
    lag(x) over w2 prev_x, lag(y) over w2 prev_y, lag(end_x) over w2 prev_ex, lag(end_y) over w2 prev_ey,
    lead(case when is_shot then 1 else 0 end) over w2 next_shot
    from seqd window w2 as (partition by game_id,seq_no order by period,expanded_minute,second,event_id)),
  invv as (
    select player_id, player, team, xt_delta,
      (ord_a=1) f_init,
      (ord_a>1 and ord_a<seq_len and type='Pass' and outcome_type='Successful'
        and ((x<33.3 and end_x>=33.3) or (x<66.7 and end_x>=66.7))) f_bridge,
      (type='Pass' and outcome_type='Successful' and end_x-x>=10) f_prog,
      (type='Pass' and prev_ex is not null and (x-prev_ex)>=6) f_carry,
      (type='Pass' and outcome_type='Successful' and end_x-x>=8 and abs(end_y-y)<=8) f_vert,
      (( type='Pass' and outcome_type='Successful' and end_x-x>0 and degrees(atan2(abs(end_y-y),end_x-x)) between 35 and 55)
        or (prev_ex is not null and prev_ex-prev_x>0 and degrees(atan2(abs(prev_ey-prev_y),prev_ex-prev_x)) between 35 and 55)) f_support,
      (type='TakeOn') f_indiv,
      (type='Pass' and outcome_type='Successful' and next_shot=1) f_creator,
      (x>=83 and y between 21.1 and 78.9) f_box,
      is_shot f_finish,
      case when ord_a>1 then (expanded_minute*60+second)-prev_t end hold
    from ordd where seq_sp=false
  ),
  agg as (
    select player_id, max(player) player, max(team) team, count(*) inv,
      round(sum(xt_delta)::numeric,2) player_xt, round(avg(hold)::numeric,2) hold_secs,
      round(100*avg(f_init::int),1) initiator, round(100*avg(f_bridge::int),1) bridge,
      round(100*avg(f_prog::int),1) progressor, round(100*avg(f_carry::int),1) carrier,
      round(100*avg(f_vert::int),1) vertical, round(100*avg(f_support::int),1) support_angle,
      round(100*avg(f_indiv::int),1) individual, round(100*avg(f_creator::int),1) creator,
      round(100*avg(f_box::int),1) box_threat, round(100*avg(f_finish::int),1) finisher
    from invv group by player_id having count(*)>=120
  )
  select a.player_id, a.player, a.team, coalesce(r.modal_position,'?') pos, a.inv, a.player_xt, a.hold_secs,
    a.initiator, a.bridge, a.progressor, a.carrier, a.vertical, a.support_angle, a.individual, a.creator, a.box_threat, a.finisher
  from agg a left join public.mv_player_role r on r.player_id=a.player_id
  where coalesce(r.modal_position,'?') <> 'GK';
end $function$
;
CREATE OR REPLACE FUNCTION public.build_press_insights()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rows int; v_min int; v_den int;
begin
  v_min := public.detector_min_matches('press_vulnerability');
  v_den := public.detector_min_denominator('press_vulnerability');
  delete from public.insights where detector = 'press_vulnerability';
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with vol as (
    select mp.defending_team as team,
      min(mp.n) filter (where mp.buildup_type in ('short_build','direct')) as min_n,
      max(mp.n) filter (where mp.buildup_type='short_build') as n_short,
      max(mp.n) filter (where mp.buildup_type='direct') as n_direct
    from public.mv_press_vs_buildup mp group by mp.defending_team
  )
  select 'tactical','defending','team', p.team, p.team, p.team, 'press_vulnerability',
    case when p.z_vs_direct <= -1.0 then format('%s struggle against direct play', p.team)
         else format('%s struggle against short build-up', p.team) end,
    case when p.z_vs_direct <= -1.0 then
      format('They contain long, direct possessions %s standard deviations worse than the league, while handling short build-up at %s. Measured across %s direct and %s short-build possessions faced.',
        round(abs(p.z_vs_direct),1), round(p.z_vs_short_build,1), v.n_direct, v.n_short)
    else
      format('They contain patient build-up %s standard deviations worse than the league, while coping with direct play at %s. Measured across %s short-build and %s direct possessions faced.',
        round(abs(p.z_vs_short_build),1), round(p.z_vs_direct,1), v.n_short, v.n_direct) end,
    jsonb_build_object('z_vs_direct',p.z_vs_direct,'z_vs_short_build',p.z_vs_short_build,
      'n_direct',v.n_direct,'n_short',v.n_short,'min_denominator',v_den),
    jsonb_build_object('team',p.team),
    greatest(abs(p.z_vs_direct), abs(p.z_vs_short_build)), 'medium',
    'The practical use is opposition planning: attack the weakness rather than the strength, and check whether your own personnel can execute that route.'
  from public.v_press_profile p
  join public.v_team_sample ts on ts.team = p.team
  join vol v on v.team = p.team
  where ts.matches >= v_min and coalesce(v.min_n,0) >= v_den
    and (p.z_vs_direct <= -1.0 or p.z_vs_short_build <= -1.0);
  get diagnostics v_rows = row_count;
  return format('press: %s (min %s matches, %s possessions per type)', v_rows, v_min, v_den);
end $function$
;
CREATE OR REPLACE FUNCTION public.build_reactivity_insights()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rows int; v_min int; v_den int;
begin
  v_min := public.detector_min_matches('game_state_reactivity');
  v_den := public.detector_min_denominator('game_state_reactivity');
  delete from public.insights where detector = 'game_state_reactivity';
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  select 'tactical','identity','team', d.team, d.team, d.team, 'game_state_reactivity',
    case when d.swing_l_minus_w >= 0.03 then format('%s change shape with the scoreline', d.team)
         else format('%s play the same way whatever the score', d.team) end,
    case when d.swing_l_minus_w >= 0.03 then
      format('Their possessions run %s directness when losing against %s when winning, measured across %s losing and %s winning possessions. A reactive side rather than a settled one.',
        d.dir_losing, d.dir_winning, ts.seqs_losing, ts.seqs_winning)
    else
      format('Directness barely moves between winning (%s) and losing (%s), across %s winning and %s losing possessions. A settled identity that does not chase the game.',
        d.dir_winning, d.dir_losing, ts.seqs_winning, ts.seqs_losing) end,
    jsonb_build_object('dir_winning',d.dir_winning,'dir_losing',d.dir_losing,
      'swing',d.swing_l_minus_w,'seqs_winning',ts.seqs_winning,'seqs_losing',ts.seqs_losing,
      'min_denominator',v_den),
    jsonb_build_object('team',d.team), abs(d.swing_l_minus_w)*100, 'medium',
    'Game-state behaviour needs both states well sampled. A side that has rarely trailed cannot be judged on how it reacts to trailing.'
  from public.mv_team_directness_state d
  join public.v_team_sample ts on ts.team = d.team
  where ts.matches >= v_min
    and ts.seqs_winning >= v_den and ts.seqs_losing >= v_den
    and d.dir_winning is not null and d.dir_losing is not null
    and (abs(d.swing_l_minus_w) >= 0.03 or d.swing_rank <= 3);
  get diagnostics v_rows = row_count;
  return format('reactivity: %s (min %s matches, %s possessions per state)', v_rows, v_min, v_den);
end $function$
;
CREATE OR REPLACE FUNCTION public.build_sequences()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  truncate table public.sequences;
  insert into public.sequences (
    seq_uid, game_id, seq_no, team_id, team, period, start_min, start_sec, dur_s,
    n_events, n_pass, n_players, start_x, start_y, end_x, end_y, start_third, end_third,
    ended_in_box, ended_shot, ended_goal, started_setpiece, is_open_play, xt_sum,
    mean_pass_len, low_build, high_build, structured, has_switch, wide_triangles, hold_up,
    very_short, long_ball, ends_opp_half, end_around_box, finds_central, finds_wide,
    n_wide_pass, n_prog, n_prog_central, n_prog_wide,
    path, cx, cy, minx, maxx, miny, maxy, att_share
  )
  with base as (
    select
      game_id, period, expanded_minute, second, event_id,
      team_id, team, player, type, outcome_type, x, y, end_x, end_y, is_shot, is_goal,
      case when type='Pass' and outcome_type='Successful' and end_x is not null
           then coalesce(public.xt_val(end_x,end_y),0)-coalesce(public.xt_val(x,y),0) else 0 end as xt_delta,
      case when type='Pass' and outcome_type='Successful' and end_x is not null
           then sqrt(power(end_x-x,2)+power(end_y-y,2)) end as pass_len,
      (type='Pass' and outcome_type='Successful' and end_x is not null and (end_x-x)>=10) as is_prog,
      (type='Pass' and outcome_type='Successful' and end_x is not null and (end_x-x)>=10
        and ((y+end_y)/2.0) between 33.3 and 66.7) as prog_central,
      (type='Pass' and outcome_type='Successful' and end_x is not null and (end_x-x)>=10
        and ((y+end_y)/2.0) not between 33.3 and 66.7) as prog_wide,
      (type='Pass' and outcome_type='Successful' and (y<21.1 or y>78.9)) as is_wide_pass,
      (type='Pass' and outcome_type='Successful' and (y<21.1 or y>78.9) and x>=50) as is_wide_att,
      (type='Pass' and outcome_type='Successful' and end_x is not null
        and abs(end_y-y)>40 and (y-50)*(end_y-50)<0) as is_switch,
      (type='Pass' and outcome_type='Successful' and x>=66.7 and end_x < x-5) as is_holdup,
      case when jsonb_typeof(qualifiers)='array' then exists (
        select 1 from jsonb_array_elements(qualifiers) q
        where q->'type'->>'displayName' in
          ('ThrowIn','CornerTaken','FreekickTaken','GoalKick','KickOff','Penalty')
      ) else false end as is_setpiece,
      case when type in ('Pass','TakeOn','BallTouch','MissedShots','SavedShot',
                         'ShotOnPost','Goal','KeeperPickup','Claim') then team end as ctrl_team,
      case when type in ('Foul','Card','OffsideGiven','OffsidePass','CornerAwarded','End')
                or is_goal then 1 else 0 end as stop_flag
    from public.events
  ),
  cum as (select *, sum(stop_flag) over (partition by game_id
        order by period,expanded_minute,second,event_id
        rows between unbounded preceding and current row) as stop_cum from base),
  ctrl as (select *, lag(ctrl_team) over w as prev_ctrl_team, lag(stop_cum) over w as prev_stop_cum,
           lag(period) over w as prev_period from cum where ctrl_team is not null
    window w as (partition by game_id order by period,expanded_minute,second,event_id)),
  bounded as (select *, case when prev_ctrl_team is null or period<>prev_period or ctrl_team<>prev_ctrl_team
                or is_setpiece or stop_cum > coalesce(prev_stop_cum,-1) then 1 else 0 end as is_break from ctrl),
  seqd as (select *, sum(is_break) over (partition by game_id
        order by period,expanded_minute,second,event_id) as seq_no from bounded),
  ordd as (select *,
      row_number() over (partition by game_id,seq_no order by period,expanded_minute,second,event_id) as ord_a,
      row_number() over (partition by game_id,seq_no order by period desc,expanded_minute desc,second desc,event_id desc) as ord_d,
      first_value(case when coalesce(end_x,x)>=66.7 then coalesce(end_y,y) end) over (
        partition by game_id,seq_no
        order by (case when coalesce(end_x,x)>=66.7 then 0 else 1 end),period,expanded_minute,second,event_id
        rows between unbounded preceding and unbounded following) as first_att_y
    from seqd),
  agg as (
    select game_id||'-'||seq_no as seq_uid, game_id, seq_no,
      max(team_id) filter (where ord_a=1) as team_id, max(team) filter (where ord_a=1) as team,
      max(period) filter (where ord_a=1) as period,
      max(expanded_minute) filter (where ord_a=1) as start_min, max(second) filter (where ord_a=1) as start_sec,
      max(expanded_minute*60+second)-min(expanded_minute*60+second) as dur_s,
      count(*) as n_events, count(*) filter (where type='Pass') as n_pass, count(distinct player) as n_players,
      max(x) filter (where ord_a=1) as start_x, max(y) filter (where ord_a=1) as start_y,
      max(coalesce(end_x,x)) filter (where ord_d=1) as end_x, max(coalesce(end_y,y)) filter (where ord_d=1) as end_y,
      bool_or(is_shot) as ended_shot, bool_or(is_goal) as ended_goal,
      bool_or(is_break=1 and is_setpiece) as started_setpiece,
      round(sum(xt_delta)::numeric,4) as xt_sum, round(avg(pass_len)::numeric,1) as mean_pass_len,
      max(pass_len) as max_pass_len, bool_or(is_switch) as has_switch, bool_or(is_holdup) as hold_up,
      count(*) filter (where is_wide_att) as wide_att_ct, count(distinct player) filter (where is_wide_att) as wide_att_players,
      count(*) filter (where is_wide_pass) as n_wide_pass, count(*) filter (where is_prog) as n_prog,
      count(*) filter (where prog_central) as n_prog_central, count(*) filter (where prog_wide) as n_prog_wide,
      max(first_att_y) as first_att_y,
      jsonb_agg(jsonb_build_object('x',round(x::numeric,1),'y',round(y::numeric,1),
        'ex',round(end_x::numeric,1),'ey',round(end_y::numeric,1),'t',type)
        order by period,expanded_minute,second,event_id) as path,
      round(avg(x)::numeric,1) as cx, round(avg(y)::numeric,1) as cy,
      round(min(x)::numeric,1) as minx, round(max(x)::numeric,1) as maxx,
      round(min(y)::numeric,1) as miny, round(max(y)::numeric,1) as maxy,
      round(avg((x>66.7)::int)::numeric,3) as att_share
    from ordd group by game_id, seq_no)
  select seq_uid, game_id, seq_no, team_id, team, period, start_min, start_sec, dur_s,
    n_events, n_pass, n_players, start_x, start_y, end_x, end_y,
    case when start_x<33.3 then 'def' when start_x<66.7 then 'mid' else 'att' end,
    case when end_x<33.3 then 'def' when end_x<66.7 then 'mid' else 'att' end,
    (end_x>=83 and end_y between 21.1 and 78.9), ended_shot, ended_goal, started_setpiece,
    not started_setpiece, xt_sum, mean_pass_len,
    (start_x<33.3), (start_x>=50), (start_x<50 and n_pass>=5 and dur_s>=12), has_switch,
    (wide_att_ct>=3 and wide_att_players>=3), hold_up,
    (mean_pass_len is not null and mean_pass_len<15),
    (coalesce(mean_pass_len>26,false) or coalesce(max_pass_len>=40,false)),
    (end_x>=50), (end_x>=70 and not (end_x>=83 and end_y between 21.1 and 78.9)),
    (first_att_y is not null and first_att_y between 21.1 and 78.9),
    (first_att_y is not null and first_att_y not between 21.1 and 78.9),
    n_wide_pass, n_prog, n_prog_central, n_prog_wide,
    path, cx, cy, minx, maxx, miny, maxy, att_share
  from agg;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.build_team_profile_insights()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  delete from public.insights where detector = 'team_profile';

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with extremes as (
    select team, metric, z, abs(z) az, row_number() over (partition by team order by abs(z) desc) rk
    from public.team_sequence_style where z is not null
  ),
  top as (select * from extremes where rk = 1),
  sig as (select * from public.v_team_signature)
  select 'tactical','identity','team', t.team, t.team, t.team, 'team_profile',
    case
      when t.az < 0.8 then format('%s have no pronounced identity', t.team)
      when t.z > 0 and t.az >= 1.5 then format('%s are defined by %s', t.team, public.pretty_metric(t.metric))
      when t.z > 0 then format('%s lean towards %s', t.team, public.pretty_metric(t.metric))
      when t.az >= 1.5 then format('%s sit near the bottom of the league for %s', t.team, public.pretty_metric(t.metric))
      else format('%s rank low for %s', t.team, public.pretty_metric(t.metric))
    end,
    (case
      when t.az < 0.8 then
        format('Nothing in their possession profile sits far from the league average. The closest thing to a signature is %s, and even that is only %s standard deviations out. A side without a strong stylistic fingerprint.',
          public.pretty_metric(t.metric), round(t.z,1))
      when t.z > 0 then
        format('Their most distinctive trait is %s, %s standard deviations above the league mean.',
          public.pretty_metric(t.metric), round(t.z,1))
      else
        format('What separates them is the absence of it: %s sits %s standard deviations below the league mean.',
          public.pretty_metric(t.metric), round(abs(t.z),1))
     end)
    || coalesce(
       format(' Their main route in is %s, %s.', lower(s.signature_route),
         case s.signature_verdict
           when 'effective'    then 'and it pays off'
           when 'unproductive' then 'though it rarely pays off'
           else 'at a return no better or worse than the league'
         end), ''),
    jsonb_build_object('top_metric',t.metric,'top_metric_label',public.pretty_metric(t.metric),
      'z',round(t.z,2),'signature_route',s.signature_route,
      'route_share',s.share_pct,'route_verdict',s.signature_verdict),
    jsonb_build_object('team',t.team), t.az, 'medium'
  from top t left join sig s on s.team = t.team;

  get diagnostics n = row_count;
  return format('team profiles built (%s)', n);
end $function$
;
CREATE OR REPLACE FUNCTION public.comparison_scopes()
 RETURNS TABLE(league text, display_name text, players integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select l.league, l.display_name, count(distinct ps.player_id)::int
  from public.leagues l
  left join public.player_search ps on ps.league = l.league
  where l.is_active
  group by l.league, l.display_name
  order by l.display_name;
$function$
;
CREATE OR REPLACE FUNCTION public.create_analytics_rebuild_run(p_run_id uuid, p_league text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ begin insert into public.analytics_rebuild_runs(run_id,status,requested_league) values(p_run_id,'pending',p_league);return jsonb_build_object('run_id',p_run_id,'status','pending');end $function$
;
CREATE OR REPLACE FUNCTION public.detector_min_denominator(p_detector text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce((select min_denominator from public.detector_requirements where detector = p_detector), 0);
$function$
;
CREATE OR REPLACE FUNCTION public.detector_min_matches(p_detector text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce((select min_matches from public.detector_requirements where detector = p_detector), 6);
$function$
;
CREATE OR REPLACE FUNCTION public.get_starter_names(p_game_id text)
 RETURNS TABLE(player_name text, player_pos text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with subbed_on as (
    select distinct player_id from public.events
    where game_id = p_game_id and type = 'SubstitutionOn' and player_id is not null
  ),
  touched as (
    select distinct player_id from public.events
    where game_id = p_game_id and player_id is not null
  )
  select p.player_name, l.position
  from public.lineups l
  join public.players p on p.player_id = l.player_id
  join touched t on t.player_id = l.player_id
  where l.game_id = p_game_id
    and not exists (select 1 from subbed_on s where s.player_id = l.player_id);
$function$
;
CREATE OR REPLACE FUNCTION public.lafc_events_list(p_secret text)
 RETURNS SETOF lafc_events
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;
  return query select * from public.lafc_events order by starts_at asc;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.lafc_links_delete(p_secret text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  delete from public.lafc_links where id=p_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_links_list(p_secret text)
 RETURNS SETOF lafc_links
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  return query select * from public.lafc_links order by sort_order asc, created_at asc;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_links_save(p_secret text, p_id uuid, p_label text, p_url text, p_sort integer)
 RETURNS lafc_links
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare r public.lafc_links;
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  if p_label is null or length(trim(p_label))=0 then raise exception 'label required' using errcode='22000'; end if;
  if p_id is null then
    insert into public.lafc_links(label,url,sort_order) values(trim(p_label),coalesce(p_url,''),coalesce(p_sort,0)) returning * into r;
  else
    update public.lafc_links set label=trim(p_label),url=coalesce(p_url,''),sort_order=coalesce(p_sort,sort_order) where id=p_id returning * into r;
    if not found then raise exception 'not found' using errcode='P0002'; end if;
  end if;
  return r;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_projects_delete(p_secret text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;
  delete from public.lafc_projects where id = p_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.lafc_projects_list(p_secret text)
 RETURNS SETOF lafc_projects
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;
  return query
    select * from public.lafc_projects
    order by sort_order asc, updated_at desc;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.lafc_projects_save(p_secret text, p_id uuid, p_name text, p_status text, p_priority text, p_next_action text, p_notes text, p_sort_order integer, p_due_date date, p_category text, p_subtasks jsonb)
 RETURNS lafc_projects
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  r public.lafc_projects;
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'name required' using errcode = '22000';
  end if;

  if p_id is null then
    insert into public.lafc_projects
      (name, status, priority, next_action, notes, sort_order, due_date, category, subtasks)
    values
      (trim(p_name), coalesce(p_status,'In progress'), coalesce(p_priority,'Medium'),
       coalesce(p_next_action,''), coalesce(p_notes,''), coalesce(p_sort_order,0),
       p_due_date, coalesce(p_category,''), coalesce(p_subtasks,'[]'::jsonb))
    returning * into r;
  else
    update public.lafc_projects
       set name = trim(p_name),
           status = coalesce(p_status, status),
           priority = coalesce(p_priority, priority),
           next_action = coalesce(p_next_action, next_action),
           notes = coalesce(p_notes, notes),
           sort_order = coalesce(p_sort_order, sort_order),
           due_date = p_due_date,
           category = coalesce(p_category, category),
           subtasks = coalesce(p_subtasks, subtasks)
     where id = p_id
    returning * into r;
    if not found then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;

  return r;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.lafc_projects_touch()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.lafc_todos_clear_done(p_secret text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  delete from public.lafc_todos where done;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_todos_delete(p_secret text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  delete from public.lafc_todos where id=p_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_todos_list(p_secret text)
 RETURNS SETOF lafc_todos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  return query select * from public.lafc_todos order by done asc, sort_order asc, created_at asc;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_todos_save(p_secret text, p_id uuid, p_text text, p_done boolean, p_sort integer)
 RETURNS lafc_todos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare r public.lafc_todos;
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  if p_text is null or length(trim(p_text))=0 then raise exception 'text required' using errcode='22000'; end if;
  if p_id is null then
    insert into public.lafc_todos(text,done,sort_order,completed_at)
      values(trim(p_text),coalesce(p_done,false),coalesce(p_sort,0), case when coalesce(p_done,false) then now() else null end)
      returning * into r;
  else
    update public.lafc_todos
      set text=trim(p_text), done=coalesce(p_done,done), sort_order=coalesce(p_sort,sort_order),
          completed_at = case when coalesce(p_done,done) then coalesce(completed_at,now()) else null end
      where id=p_id returning * into r;
    if not found then raise exception 'not found' using errcode='P0002'; end if;
  end if;
  return r;
end;$function$
;
CREATE OR REPLACE FUNCTION public.lafc_tracker_auth(p_secret text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select exists (
    select 1 from public.lafc_tracker_config
    where id = 1 and secret_hash = extensions.crypt(p_secret, secret_hash)
  );
$function$
;
CREATE OR REPLACE FUNCTION public.nl_query(q text, p_limit integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  s text := lower(trim(coalesce(q,'')));
  s_count text;
  intent text := 'filter';
  subj_id text; subj_name text; subj_team text; subj_pos text; subj_pool text;
  name_part text;
  metrics text[] := '{}';
  best_phrase text; best_metric text; metric_label text; metric_unit text;
  dim_labels text;
  v_pool text; v_side text; v_foot text; v_age int; v_n int := p_limit;
  m text[]; res jsonb; expl text; pool_n int;
begin
  if s = '' then return jsonb_build_object('error','empty query'); end if;

  m := regexp_match(s, '(?:under|younger than|below|aged under|\mu)\s*(\d{2})');
  if m is not null then v_age := (m[1])::int; end if;
  s_count := regexp_replace(s, '(?:under|younger than|below|aged under|\mu)\s*\d{2}', ' ', 'g');

  m := regexp_match(s_count, '\m(\d{1,3})\M');
  if m is not null then v_n := least(greatest((m[1])::int,1),50); end if;
  if s ~ '\mten\M' then v_n := 10; elsif s ~ '\mfive\M' then v_n := 5;
  elsif s ~ '\mtwenty\M' then v_n := 20; elsif s ~ '\mthree\M' then v_n := 3; end if;

  if s ~ '(centre[- ]?back|center[- ]?back|\mcbs?\M)' then v_pool := 'CB';
  elsif s ~ '(full[- ]?backs?|\mfbs?\M|wing[- ]?backs?)' then v_pool := 'FB';
  elsif s ~ '(attacking midfield|\mams?\M)' then v_pool := 'AM';
  elsif s ~ '(\mmidfielders?\M|\mmidfield\M|\mcms?\M|number ?(6|8)|\mholding\M|\mregista\M)' then v_pool := 'CM';
  elsif s ~ '(\mwingers?\M|wide (players?|forwards?)|\mwide\M)' then v_pool := 'W';
  elsif s ~ '(\mstrikers?\M|centre[- ]?forwards?|number ?9|\msts?\M)' then v_pool := 'ST';
  end if;

  if s ~ '(right[- ]?sided|from the right|right wing|right side|right flank)' then v_side := 'R';
  elsif s ~ '(left[- ]?sided|from the left|left wing|left side|left flank)' then v_side := 'L';
  elsif s ~ '(\mcentral\M|\mcentrally\M|through the middle)' then v_side := 'C';
  end if;

  if s ~ 'left[- ]?footed' then v_foot := 'left';
  elsif s ~ 'right[- ]?footed' then v_foot := 'right';
  elsif s ~ '(two[- ]?footed|both feet|either foot)' then v_foot := 'either';
  end if;

  select array_agg(distinct mm) into metrics from (
    select case when ms.metric is not null then ms.metric else mc.metric end as mm
    from public.metric_synonyms ms
    left join public.metric_catalog mc on ms.metric is null and mc.grp = ms.grp
    where s like '%'||ms.phrase||'%'
  ) z where mm is not null;

  select ms.phrase, coalesce(ms.metric, ms.rank_metric)
    into best_phrase, best_metric
    from public.metric_synonyms ms
   where s like '%'||ms.phrase||'%'
   order by length(ms.phrase) desc limit 1;

  select d.label, d.unit into metric_label, metric_unit
    from public.metric_catalog d where d.metric = coalesce(best_metric,'xt_90');

  if s ~ '(similar to|comparable to|alternatives to|version of|\mlike\M)' then
    intent := 'similar';
    name_part := trim(regexp_replace(s,
      '^.*?(?:similar to|comparable to|alternatives to|version of|like)\s+', ''));
    -- a trailing qualifier ("as a shooter", "in build-up") is not part of the name
    name_part := trim(regexp_replace(name_part,
      '\s+(as|in|for|at|on|by|with|when|based on|regarding|considering)\s+.*$', ''));
    name_part := trim(regexp_replace(name_part, '[^a-z0-9áéíóúñü'' -]', '', 'g'));
    select r.player_id, r.player, r.team, r.pos
      into subj_id, subj_name, subj_team, subj_pos
      from public.resolve_player(name_part) r limit 1;
    if subj_id is null then
      return jsonb_build_object('intent','similar','error',
        format('could not find a player matching "%s"', name_part), 'query', q);
    end if;
    select pool into subj_pool from public.player_search where player_id = subj_id;
  elsif s ~ '(\mbest\M|\mtop\M|\mmost\M|\mhighest\M|\mleading\M|\mstrongest\M)' then
    intent := 'rank';
  end if;

  if intent = 'similar' then
    res := (select coalesce(jsonb_agg(to_jsonb(x) order by x.rank),'[]'::jsonb) from (
      select * from public.similar_players_full(subj_id, v_n,
        case when array_length(metrics,1) is null then null else metrics end)) x);

    select string_agg(label, ', ' order by label) into dim_labels
      from public.metric_catalog where metric = any(coalesce(metrics,'{}'));

    expl := case
      when array_length(metrics,1) is null then
        format('Style match against %s, compared across the full profile: roles, trajectory, carrying, creation, shooting and defending. Every %s is scored on the same dimensions and the closest are listed first.',
          subj_name, coalesce(subj_pool,'player'))
      else
        format('Narrowed to %s, so this is a different list from an overall style match. Compared on %s dimension%s: %s. Only %ss are considered.',
          best_phrase, array_length(metrics,1),
          case when array_length(metrics,1)=1 then '' else 's' end,
          coalesce(dim_labels, array_to_string(metrics, ', ')),
          coalesce(subj_pool,'player'))
      end;

    return jsonb_build_object('intent','similar','query',q,
      'subject', jsonb_build_object('player_id',subj_id,'player',subj_name,
                                    'team',subj_team,'pos',subj_pos,'pool',subj_pool),
      'compared_on', case when array_length(metrics,1) is null
                          then 'overall style' else coalesce(best_phrase,'selected metrics') end,
      'explain', expl, 'metrics', to_jsonb(metrics), 'results', res);
  else
    select count(*) into pool_n from public.player_search ps
      where (v_pool is null or ps.pool = v_pool)
        and (v_side is null or ps.side = v_side)
        and (v_foot is null or ps.foot = v_foot)
        and (v_age  is null or ps.age_seen <= v_age)
        and coalesce(ps.nineties,0) >= 6;

    res := (select coalesce(jsonb_agg(to_jsonb(y) order by y.rk),'[]'::jsonb) from (
      select row_number() over (order by p.pct_pool desc, ps.nineties desc) rk,
             ps.player_id, ps.player, ps.team, ps.pos, ps.pool, ps.age_seen, ps.foot,
             ps.league, round(ps.nineties,1) nineties,
             p.metric, p.raw as value, p.pct_pool as pct
      from public.mv_player_pct p
      join public.player_search ps on ps.player_id = p.player_id
      where p.metric = coalesce(best_metric,'xt_90')
        and (v_pool is null or ps.pool = v_pool)
        and (v_side is null or ps.side = v_side)
        and (v_foot is null or ps.foot = v_foot)
        and (v_age  is null or ps.age_seen <= v_age)
        and coalesce(ps.nineties,0) >= 6
      order by p.pct_pool desc, ps.nineties desc
      limit v_n) y);

    expl := format('Ranked on %s%s. %s%s%s%s Minimum 6 full matches played. %s players qualified; the top %s are shown. Percentiles are within position pool, not across the whole league.',
      coalesce(metric_label, best_metric, 'expected threat'),
      case when metric_unit is null then '' else ' ('||metric_unit||')' end,
      case when v_pool is null then 'All positions. ' else 'Position pool '||v_pool||'. ' end,
      case when v_side is null then '' else 'Side '||v_side||'. ' end,
      case when v_foot is null then '' else initcap(v_foot)||'-footed only. ' end,
      case when v_age  is null then '' else 'Aged '||v_age||' or under. ' end,
      pool_n, least(v_n, pool_n));

    return jsonb_build_object('intent', intent, 'query', q,
      'ranked_on', coalesce(best_metric,'xt_90'),
      'ranked_on_label', coalesce(metric_label, best_phrase, 'expected threat'),
      'explain', expl, 'pool_size', pool_n,
      'filters', jsonb_build_object('pool',v_pool,'side',v_side,'foot',v_foot,
                                    'max_age',v_age,'min_nineties',6),
      'results', res);
  end if;
end $function$
;
CREATE OR REPLACE FUNCTION public.player_card(p_id text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with ps as (select * from public.player_search where player_id = p_id),
  pct as (
    select p.metric, d.label, d.grp, d.unit, p.raw, p.pct_pool, p.pct_archetype,
      case when p.pct_pool >= 90 then 'Elite' when p.pct_pool >= 75 then 'Strong'
           when p.pct_pool >= 40 then 'Average' when p.pct_pool >= 20 then 'Below Par'
           else 'Limited' end as band
    from public.mv_player_pct p join public.metric_catalog d on d.metric = p.metric
    where p.player_id = p_id
  ),
  roles as (select role, raw, pct from public.player_chain_pct where player_id = p_id order by pct desc),
  usage as (select squad_role, selection_pct, leverage_pct, minutes_inflated, starts, appearances
            from public.v_squad_role where player_id = p_id limit 1),
  comps as (select * from public.similar_players_chain(p_id, 5))
  select jsonb_build_object(
    'player', to_jsonb((select row_to_json(x) from (
        select ps.player_id, ps.player, ps.team, ps.pos, ps.side, ps.pool,
               ps.age_seen, ps.height_cm, ps.weight_kg, ps.foot, ps.foot_confidence,
               ps.nineties, ps.inv, ps.archetype, ps.archetype_primary, ps.archetype_secondary
        from ps) x)),
    'usage', (select to_jsonb(u) from usage u),
    'traits', (select jsonb_agg(jsonb_build_object('metric',metric,'label',label,'group',grp,'unit',unit,
        'value',raw,'pct',pct_pool,'pct_archetype',pct_archetype,'band',band) order by pct_pool desc) from pct),
    'strengths', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct_pool,'value',raw) order by pct_pool desc)
        from (select * from pct where pct_pool >= 80 order by pct_pool desc limit 6) s),
    'weaknesses', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct_pool,'value',raw) order by pct_pool asc)
        from (select * from pct where pct_pool <= 25 order by pct_pool asc limit 4) w),
    'roles', (select jsonb_agg(jsonb_build_object('role',role,'value',raw,'pct',pct) order by pct desc) from roles),
    'similar', (select jsonb_agg(to_jsonb(c) order by c.rank) from comps c)
  );
$function$
;
CREATE OR REPLACE FUNCTION public.player_card_scoped(p_id text, p_leagues text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with ps as (select * from public.player_search where player_id = p_id),
  pct as (
    select s.metric, s.label, s.grp, s.unit, s.raw, s.pct, s.n_in_scope, s.scope,
      case when s.pct >= 90 then 'Elite' when s.pct >= 75 then 'Strong'
           when s.pct >= 40 then 'Average' when s.pct >= 20 then 'Below Par'
           else 'Limited' end as band
    from public.player_pct_scoped(p_id, p_leagues) s
  )
  select jsonb_build_object(
    'player', to_jsonb((select row_to_json(x) from (
        select ps.player_id, ps.player, ps.team, ps.pos, ps.side, ps.pool, ps.league,
               ps.age_seen, ps.height_cm, ps.foot, ps.nineties, ps.archetype
        from ps) x)),
    'scope', (select scope from pct limit 1),
    'compared_against', (select n_in_scope from pct limit 1),
    'traits', (select jsonb_agg(jsonb_build_object(
        'metric',metric,'label',label,'group',grp,'unit',unit,
        'value',raw,'pct',pct,'band',band) order by pct desc) from pct),
    'strengths', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct,'value',raw)
        order by pct desc) from (select * from pct where pct >= 80 order by pct desc limit 6) s),
    'weaknesses', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct,'value',raw)
        order by pct asc) from (select * from pct where pct <= 25 order by pct asc limit 4) w)
  );
$function$
;
CREATE OR REPLACE FUNCTION public.player_metric_events(p_id text, p_metric text, p_limit integer DEFAULT 800)
 RETURNS TABLE(kind text, x double precision, y double precision, end_x double precision, end_y double precision, value numeric, outcome text, game_id text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
begin
  if p_metric in ('xt_90','xt_pass_90','xt_carry_90','player_xt','xt_positive') then
    return query
      select a.kind, a.x::double precision, a.y::double precision,
             a.end_x::double precision, a.end_y::double precision, a.xt,
             case when a.xt > 0 then 'positive' else 'negative' end, a.game_id
      from public.v_player_xt_actions a
      where a.player_id = p_id
        and (p_metric <> 'xt_pass_90'  or a.kind = 'pass')
        and (p_metric <> 'xt_carry_90' or a.kind = 'carry')
        and (p_metric <> 'xt_positive' or a.xt > 0)
      order by abs(a.xt) desc limit p_limit;

  elsif p_metric in ('carries_90','prog_carries_90','carry_box_90','carry_pen_90','mean_carry_m') then
    return query
      select 'carry'::text, c.start_x::double precision, c.start_y::double precision,
             c.end_x::double precision, c.end_y::double precision,
             round(c.carry_m::numeric,1),
             case when c.into_box then 'into box' when c.is_progressive then 'progressive' else 'carry' end,
             c.game_id
      from public.v_player_carries c
      where c.player_id = p_id
        and (p_metric <> 'prog_carries_90' or c.is_progressive)
        and (p_metric not in ('carry_box_90','carry_pen_90') or c.into_box)
      order by c.carry_m desc limit p_limit;

  elsif p_metric in ('shots_90','sot_90','goals_90','xg_90','xg_per_shot','bigchance_90','conversion','finishing','shot_acc','shot_dist') then
    return query
      select 'shot'::text, a.x::double precision, a.y::double precision,
             a.end_x::double precision, a.end_y::double precision,
             round(coalesce(a.xg,0)::numeric,3),
             case when a.is_goal then 'goal' else coalesce(a.shot_outcome,'shot') end, a.game_id
      from public.v_player_actions a
      where a.player_id = p_id and a.is_shot
        and (p_metric <> 'goals_90' or a.is_goal)
        and (p_metric <> 'bigchance_90' or a.bigchance)
        and (p_metric <> 'sot_90' or a.is_goal or a.shot_outcome ilike '%target%' or a.shot_outcome ilike '%saved%')
      order by coalesce(a.xg,0) desc limit p_limit;

  elsif p_metric in ('tackle_90','int_90','recov_90','clear_90','block_90','aerial_90','def_action_90',
                     'padj_tackle_90','padj_int_90','padj_recov_90','padj_def_90',
                     'box_def_90','channel_def_90','flank_def_90','counterpress_90') then
    return query
      select lower(a.type), a.x::double precision, a.y::double precision,
             a.end_x::double precision, a.end_y::double precision, 1::numeric,
             case when a.ok then 'won' else 'lost' end, a.game_id
      from public.v_player_actions a
      where a.player_id = p_id
        and ((p_metric in ('tackle_90','padj_tackle_90') and a.type='Tackle')
          or (p_metric in ('int_90','padj_int_90')       and a.type='Interception')
          or (p_metric in ('recov_90','padj_recov_90')   and a.type='BallRecovery')
          or (p_metric = 'clear_90'  and a.type='Clearance')
          or (p_metric = 'block_90'  and a.type in ('BlockedPass','Block'))
          or (p_metric = 'aerial_90' and a.type='Aerial')
          or (p_metric in ('def_action_90','padj_def_90','counterpress_90','box_def_90','channel_def_90','flank_def_90')
              and a.type in ('Tackle','Interception','BallRecovery','Clearance','BlockedPass','Challenge','Aerial')))
      order by a.x desc limit p_limit;

  elsif p_metric in ('takeon_90','takeon_pct','disp_90') then
    return query
      select 'takeon'::text, a.x::double precision, a.y::double precision,
             a.end_x::double precision, a.end_y::double precision, 1::numeric,
             case when a.ok then 'beaten' else 'stopped' end, a.game_id
      from public.v_player_actions a
      where a.player_id = p_id and a.type in ('TakeOn','Dispossessed')
      order by a.x desc limit p_limit;

  else
    return query
      select 'pass'::text, a.x::double precision, a.y::double precision,
             a.end_x::double precision, a.end_y::double precision,
             round(coalesce(a.xg,0)::numeric,3),
             case when a.assist then 'assist' when a.keypass then 'key pass'
                  when a.ok then 'completed' else 'incomplete' end, a.game_id
      from public.v_player_actions a
      where a.player_id = p_id and a.type='Pass'
        and (p_metric <> 'pass_cmp_90'     or a.ok)
        and (p_metric not in ('prog_cmp_90','prog_pct','hs_prog_90') or (a.prog and a.ok))
        and (p_metric <> 'into_box_90'     or a.into_box)
        and (p_metric <> 'through_90'      or a.through)
        and (p_metric not in ('cross_90','cross_pct') or a.cross_)
        and (p_metric not in ('key_pass_90','hs_key_90') or a.keypass)
        and (p_metric <> 'assist_90'       or a.assist)
        and (p_metric <> 'final_third_90'  or (a.end_x >= 66.7 and a.ok))
      order by (case when a.assist then 3 when a.keypass then 2 else 1 end) desc, a.end_x desc
      limit p_limit;
  end if;
end $function$
;
CREATE OR REPLACE FUNCTION public.player_pct_scoped(p_id text, p_leagues text[] DEFAULT NULL::text[], p_metrics text[] DEFAULT NULL::text[])
 RETURNS TABLE(metric text, label text, grp text, unit text, raw numeric, pct integer, higher_better boolean, pool text, n_in_scope integer, scope text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with tgt as (
    select pool, league from public.mv_player_pct where player_id = p_id limit 1
  ),
  scope as (
    select case
      when p_leagues is null or array_length(p_leagues,1) is null
        then array[(select league from tgt)]
      else p_leagues end as ls
  ),
  pop as (
    select p.player_id, p.metric, p.raw, p.higher_better, p.pool
    from public.mv_player_pct p, tgt, scope
    where p.pool = tgt.pool
      and p.league = any(scope.ls)
      and (p_metrics is null or p.metric = any(p_metrics))
  ),
  ranked as (
    select player_id, metric, raw, higher_better, pool,
      percent_rank() over (partition by metric order by raw) pr,
      count(*) over (partition by metric) n
    from pop
  )
  select r.metric, d.label, d.grp, d.unit, r.raw,
    round(100*(case when r.higher_better then r.pr else 1-r.pr end))::int as pct,
    r.higher_better, r.pool, r.n::int,
    array_to_string((select ls from scope), ' + ')
  from ranked r
  join public.metric_catalog d on d.metric = r.metric
  where r.player_id = p_id
  order by pct desc;
$function$
;
CREATE OR REPLACE FUNCTION public.player_xt_map(p_id text, p_kind text DEFAULT 'all'::text, p_positive_only boolean DEFAULT false, p_limit integer DEFAULT 500)
 RETURNS TABLE(kind text, x double precision, y double precision, end_x double precision, end_y double precision, xt numeric, game_id text, minute integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select a.kind, a.x, a.y, a.end_x, a.end_y, a.xt, a.game_id, a.minute
  from public.v_player_xt_actions a
  where a.player_id = p_id
    and (p_kind = 'all' or a.kind = p_kind)
    and (not p_positive_only or a.xt > 0)
  order by a.xt desc
  limit p_limit;
$function$
;
CREATE OR REPLACE FUNCTION public.polish_insights()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a text; b text; c text; d text; e text; f text; g text;
begin
  a := public.build_team_profile_insights();
  b := public.build_insights_extra();
  c := public.build_insights_players();
  d := public.build_reactivity_insights();
  e := public.build_press_insights();
  f := public.suppress_low_sample_insights();   -- must run after every detector
  g := public.write_insight_notes();
  return concat_ws(' | ', a, b, c, d, e, f, g);
end $function$
;
CREATE OR REPLACE FUNCTION public.preflight_league(p_league text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; bad text; n_wl int; msgs text := '';
begin
  for r in select league, coalesce(expected_teams, 999) exp from public.leagues where is_active
             and (p_league is null or league = p_league) loop
    select count(distinct event_name) into n_wl from public.team_names where league = r.league;
    if n_wl < r.exp then
      msgs := msgs || format('%s: bootstrapping %s/%s clubs (guard open); ', r.league, n_wl, r.exp);
      continue;
    end if;
    select string_agg(distinct e.team, ', ') into bad
      from public.events e
      where e.league = r.league and e.team is not null
        and e.team not in (select event_name from public.team_names t where t.league = r.league);
    if bad is not null then
      raise exception 'preflight failed for % -- team(s) not in that league''s whitelist: %', r.league, bad;
    end if;
    msgs := msgs || format('%s ok (%s clubs); ', r.league, n_wl);
  end loop;
  return coalesce(nullif(msgs,''), 'no active leagues');
end $function$
;
CREATE OR REPLACE FUNCTION public.pretty_metric(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce((select l from (values
    ('seqs_per_match','possession volume'),
    ('passes_seq','long passing sequences'),
    ('seconds_seq','slow, patient possessions'),
    ('players_seq','number of players per move'),
    ('xt_seq','threat per possession'),
    ('low_build_pct','building from deep'),
    ('high_build_pct','winning the ball high'),
    ('structured_pct','patient structured build-up'),
    ('very_short_pct','short passing'),
    ('long_pct','going long'),
    ('switches_pct','switching play'),
    ('wide_tri_pct','wide combination play'),
    ('hold_up_pct','holding the ball up'),
    ('ends_opp_half_pct','finishing moves in the opposition half'),
    ('ends_def_third_pct','possessions dying in their own third'),
    ('end_att_third_pct','reaching the final third'),
    ('end_in_box_pct','getting into the box'),
    ('end_around_box_pct','working the ball to the edge of the box'),
    ('finds_central_pct','progressing centrally'),
    ('finds_wide_pct','progressing wide'),
    ('ends_in_shot_pct','turning possessions into shots'),
    ('central_prog_share','central progression'),
    ('wide_pass_pct','wide passing')
  ) t(k,l) where t.k = p), replace(p,'_',' '));
$function$
;
CREATE OR REPLACE FUNCTION public.process_analytics_rebuild_queue()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '0'
AS $function$
declare
  queued public.analytics_rebuild_runs%rowtype;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('analytics-rebuild-worker', 0)) then
    return jsonb_build_object('status','busy');
  end if;

  select * into queued
  from public.analytics_rebuild_runs
  where status = 'pending'
  order by created_at, run_id
  for update skip locked
  limit 1;

  if not found then
    return jsonb_build_object('status','idle');
  end if;

  return public.rebuild_all_verified(queued.run_id, queued.requested_league, null);
end
$function$
;
CREATE OR REPLACE FUNCTION public.rebuild_all()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '0'
AS $function$
begin
  perform public.rebuild_step('preflight', null);
  perform public.rebuild_step('metrics', null);
  perform public.rebuild_step('sequences', null);
  perform public.rebuild_step('players', null);
  perform public.rebuild_step('seqfz', null);
  perform public.rebuild_step('lookups', null);
  perform public.rebuild_step('state', null);
  perform public.rebuild_step('chains', null);
  perform public.rebuild_step('traj', null);
  perform public.rebuild_step('profiles', null);
  perform public.rebuild_step('usage', null);
  perform public.rebuild_step('teamstyle', null);
  perform public.rebuild_step('search', null);
  perform public.rebuild_step('percentiles', null);
  perform public.rebuild_step('insights', null);
  return public.rebuild_step('verify', null);
end $function$
;
CREATE OR REPLACE FUNCTION public.rebuild_all_verified(p_run_id uuid, p_league text DEFAULT NULL::text, p_fail_after_step text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '0'
AS $function$
declare steps constant text[]:=array['preflight','metrics1','metrics2','metrics3','metrics4','sequences','players','seqfz','lookups','state','chains','traj','profiles','usage','teamstyle','search','percentiles','insights','verify'];step text;result text;output jsonb:='[]'::jsonb;failure text;
begin
 update public.analytics_rebuild_runs set status='running',started_at=now(),current_step='starting',error_message=null,messages='[]'::jsonb where run_id=p_run_id and status='pending';
 if not found then raise exception 'unknown or non-pending analytics rebuild run %',p_run_id;end if;
 begin
  if p_fail_after_step is not null then update public.analytics_publication_probe set value=value+1 where singleton;end if;
  foreach step in array steps loop
   update public.analytics_rebuild_runs set current_step=step where run_id=p_run_id;
   result:=public.rebuild_step(step,p_league);
   output:=output||jsonb_build_array(jsonb_build_object('step',step,'result',result));
   if p_fail_after_step=step then raise exception 'deliberate publication-gate test failure after %',step;end if;
  end loop;
 exception when others then failure:=sqlerrm;end;
 if failure is not null then update public.analytics_rebuild_runs set status='failed',current_step=null,error_message=failure,messages=output,finished_at=now() where run_id=p_run_id;return jsonb_build_object('run_id',p_run_id,'status','failed','error',failure,'steps',output);end if;
 update public.analytics_rebuild_runs set status='complete',current_step=null,messages=output,finished_at=now() where run_id=p_run_id;
 return jsonb_build_object('run_id',p_run_id,'status','complete','steps',output);
end $function$
;
CREATE OR REPLACE FUNCTION public.rebuild_step(p_step text, p_league text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '240s'
AS $function$
declare n_srch int; n_st int; n_ce int; n_tj int; n_sq int; n_pct int; msg text;
begin
  case p_step
    when 'preflight' then return public.preflight_league(p_league);
    when 'metrics1' then return public.refresh_analytics_batch(1);
    when 'metrics2' then return public.refresh_analytics_batch(2);
    when 'metrics3' then return public.refresh_analytics_batch(3);
    when 'metrics4' then return public.refresh_analytics_batch(4);
    when 'metrics' then perform public.refresh_analytics(); return 'metrics refreshed';
    when 'sequences' then perform public.build_sequences(); msg:=public.stamp_sequence_leagues(); return 'sequences built; '||msg;
    when 'players' then perform public.build_player_chain_roles(); perform public.stamp_sequence_leagues(); return 'players built';
    when 'seqfz' then refresh materialized view public.seq_fz; return 'seq_fz refreshed';
    when 'lookups' then refresh materialized view public.mv_team_league; refresh materialized view public.mv_player_league; perform public.stamp_sequence_leagues(); return 'league lookups refreshed';
    when 'state' then refresh materialized view public.mv_game_goals; refresh materialized view public.mv_seq_state; refresh materialized view public.mv_state_segments; select count(*) into n_st from public.mv_seq_state; return format('game state built (%s possessions tagged)',n_st);
    when 'chains' then refresh materialized view public.mv_seq_events; refresh materialized view public.mv_player_chain_value; select count(*) into n_ce from public.mv_player_chain_value; return format('chain value built (%s players)',n_ce);
    when 'traj' then refresh materialized view public.mv_pass_traj; refresh materialized view public.mv_player_pass_traj; select count(*) into n_tj from public.mv_player_pass_traj; return format('pass trajectory built (%s players)',n_tj);
    when 'profiles' then refresh materialized view public.mv_player_foot; refresh materialized view public.mv_player_archetype; refresh materialized view public.mv_player_progression; return 'foot / archetype / progression refreshed';
    when 'usage' then refresh materialized view public.mv_player_stints; refresh materialized view public.mv_player_leverage; refresh materialized view public.mv_squad_role; refresh materialized view public.mv_player_state_output; select count(*) into n_sq from public.mv_squad_role; return format('squad usage + state-adjusted output built (%s rows)',n_sq);
    when 'teamstyle' then refresh materialized view public.mv_team_directness_state; refresh materialized view public.mv_press_vs_buildup; refresh materialized view public.mv_team_breakdown; return 'directness / press / breakdown refreshed';
    when 'search' then refresh materialized view public.player_search; select count(*) into n_srch from public.player_search; return format('search index refreshed (%s players)',n_srch);
    when 'percentiles' then refresh materialized view public.mv_player_pct; select count(*) into n_pct from public.mv_player_pct; return format('percentile layer refreshed (%s rows)',n_pct);
    when 'insights' then msg:=public.build_insights(); perform public.polish_insights(); return msg||'; summaries held pending verification';
    when 'verify' then msg:=public.verify_rebuild(); perform public.refresh_site_summaries(); return msg||' | verified summaries published';
    else raise exception 'unknown rebuild step: %',p_step;
  end case;
end $function$
;
CREATE OR REPLACE FUNCTION public.rebuild_team_names(p_league text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  delete from public.team_names where league = p_league;

  insert into public.team_names (event_name, match_name, display_name, league)
  with g as (
    select e.game_id, m.home_team, m.away_team, array_agg(distinct e.team) as ets
    from public.events e
    join public.matches m on m.game_id = e.game_id
    where e.league = p_league and e.team is not null
    group by e.game_id, m.home_team, m.away_team
  ),
  paired as (
    select t as event_name,
      case when similarity(unaccent(lower(t)), unaccent(lower(g.home_team)))
              >= similarity(unaccent(lower(t)), unaccent(lower(g.away_team)))
           then g.home_team else g.away_team end as match_name
    from g, unnest(g.ets) t
  ),
  -- a club can appear in several fixtures, so take the name it matched most often
  ranked as (
    select event_name, match_name, count(*) n,
      row_number() over (partition by event_name order by count(*) desc, match_name) rk
    from paired group by event_name, match_name
  )
  select event_name, match_name, match_name, p_league
  from ranked where rk = 1;

  get diagnostics n = row_count;
  return format('%s: %s clubs mapped', p_league, n);
end $function$
;
CREATE OR REPLACE FUNCTION public.refresh_analytics()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '0'
AS $function$
begin
  perform public.refresh_analytics_batch(1);
  perform public.refresh_analytics_batch(2);
  perform public.refresh_analytics_batch(3);
  perform public.refresh_analytics_batch(4);
  return 'refreshed at ' || now()::text;
end $function$
;
CREATE OR REPLACE FUNCTION public.refresh_analytics_batch(p_batch integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '240s'
AS $function$
begin
  case p_batch
    when 1 then  -- foundations: match length, minutes, pools, roles, raw metrics
      refresh materialized view mv_match_length;
      refresh materialized view mv_player_minutes;
      refresh materialized view mv_player_season;
      refresh materialized view mv_player_territory;
      refresh materialized view mv_player_defload;
      refresh materialized view mv_player_pool;
      refresh materialized view mv_player_role;
      refresh materialized view mv_player_metrics_raw;
      refresh materialized view mv_receipt_events;
      refresh materialized view mv_player_carry;
      return 'metrics 1/4: foundations';

    when 2 then  -- chains, shot model, threat, and the per-player derived layers
      refresh materialized view mv_player_chains;
      refresh materialized view mv_shot_features;
      refresh materialized view mv_xg_bins;
      refresh materialized view mv_shot_xg;
      refresh materialized view mv_event_phase;
      refresh materialized view mv_player_xa;
      refresh materialized view mv_player_xt;
      refresh materialized view mv_player_zones;
      refresh materialized view mv_player_sca;
      refresh materialized view mv_player_counterpress;
      refresh materialized view mv_player_holdup;
      refresh materialized view mv_player_setpiece;
      return 'metrics 2/4: chains, xG, xT';

    when 3 then  -- team layer
      refresh materialized view mv_team_match;
      refresh materialized view mv_team_season;
      refresh materialized view mv_team_zones;
      refresh materialized view mv_team_carry_zones;
      refresh materialized view mv_team_sequences;
      refresh materialized view mv_team_buildup;
      refresh materialized view mv_team_buildphase;
      refresh materialized view mv_team_attackphase;
      refresh materialized view mv_team_lanes;
      refresh materialized view mv_team_all;
      refresh materialized view mv_team_percentiles;
      refresh materialized view mv_team_stat_ranks;
      refresh materialized view mv_player_team_poss;
      refresh materialized view mv_gk_match;
      refresh materialized view mv_player_gk;
      return 'metrics 3/4: team layer';

    when 4 then  -- player metrics, percentiles, pillars, DNA, examples
      refresh materialized view mv_player_metrics;
      refresh materialized view mv_player_percentiles;
      refresh materialized view mv_player_pillars;
      refresh materialized view mv_player_dna;
      refresh materialized view mv_metric_examples;
      return 'metrics 4/4: percentiles and DNA';

    else raise exception 'unknown metrics batch: %', p_batch;
  end case;
end $function$
;
CREATE OR REPLACE FUNCTION public.refresh_site_summaries()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  refresh materialized view public.mv_league_summary;
  refresh materialized view public.mv_league_availability;
  refresh materialized view public.mv_invariant_status;
  refresh materialized view public.mv_site_summary;
  return 'site summaries refreshed';
end $function$
;
CREATE OR REPLACE FUNCTION public.resolve_player(p_name text)
 RETURNS TABLE(player_id text, player text, team text, pos text, score real)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select ps.player_id, ps.player, ps.team, ps.pos,
         similarity(unaccent(lower(ps.player)), unaccent(lower(p_name))) as score
  from public.player_search ps
  where unaccent(lower(ps.player)) % unaccent(lower(p_name))
     or unaccent(lower(ps.player)) like '%'||unaccent(lower(p_name))||'%'
  order by score desc, ps.nineties desc nulls last
  limit 5;
$function$
;
CREATE OR REPLACE FUNCTION public.run_invariants()
 RETURNS TABLE(name text, severity text, violations bigint, description text, note text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; v bigint; err text;
begin
  for r in select * from public.invariants where enabled order by severity, name loop
    v := null; err := null;
    begin
      execute r.check_sql into v;
    exception when others then
      err := left(sqlerrm, 200);
      v := -1;
    end;
    name := r.name; severity := r.severity; violations := coalesce(v, -1);
    description := r.description; note := err;
    return next;
  end loop;
end $function$
;
CREATE OR REPLACE FUNCTION public.similar_players_chain(p_id text, p_n integer DEFAULT 12)
 RETURNS TABLE(rank integer, player_id text, player text, team text, pos text, inv integer, player_xt numeric, sim_pct numeric, initiator numeric, hold_secs numeric, bridge numeric, progressor numeric, carrier numeric, vertical numeric, support_angle numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with q as (select * from public.pcr_z where player_id=p_id)
  select row_number() over (order by d.cos desc)::int, d.player_id, c.player, c.team, c.pos, c.inv, c.player_xt,
    round((d.cos*100)::numeric,1), c.initiator, c.hold_secs, c.bridge, c.progressor, c.carrier, c.vertical, c.support_angle
  from (
    select z.player_id,
      ( coalesce(z.z_init,0)*coalesce(q.z_init,0)+coalesce(z.z_bridge,0)*coalesce(q.z_bridge,0)
       +coalesce(z.z_prog,0)*coalesce(q.z_prog,0)+coalesce(z.z_carry,0)*coalesce(q.z_carry,0)
       +coalesce(z.z_vert,0)*coalesce(q.z_vert,0)+coalesce(z.z_supp,0)*coalesce(q.z_supp,0)
       +coalesce(z.z_indiv,0)*coalesce(q.z_indiv,0)+coalesce(z.z_creator,0)*coalesce(q.z_creator,0)
       +coalesce(z.z_box,0)*coalesce(q.z_box,0)+coalesce(z.z_finish,0)*coalesce(q.z_finish,0)
       +coalesce(z.z_ctrl,0)*coalesce(q.z_ctrl,0) )
      / nullif( sqrt(coalesce(z.z_init,0)^2+coalesce(z.z_bridge,0)^2+coalesce(z.z_prog,0)^2+coalesce(z.z_carry,0)^2
       +coalesce(z.z_vert,0)^2+coalesce(z.z_supp,0)^2+coalesce(z.z_indiv,0)^2+coalesce(z.z_creator,0)^2
       +coalesce(z.z_box,0)^2+coalesce(z.z_finish,0)^2+coalesce(z.z_ctrl,0)^2)
       * sqrt(coalesce(q.z_init,0)^2+coalesce(q.z_bridge,0)^2+coalesce(q.z_prog,0)^2+coalesce(q.z_carry,0)^2
       +coalesce(q.z_vert,0)^2+coalesce(q.z_supp,0)^2+coalesce(q.z_indiv,0)^2+coalesce(q.z_creator,0)^2
       +coalesce(q.z_box,0)^2+coalesce(q.z_finish,0)^2+coalesce(q.z_ctrl,0)^2), 0) as cos
    from public.pcr_z z, q
    where z.pool=q.pool and z.player_id<>q.player_id
  ) d
  join public.player_chain_roles c on c.player_id=d.player_id
  where d.cos is not null
  order by d.cos desc limit p_n;
$function$
;
CREATE OR REPLACE FUNCTION public.similar_players_full(p_id text, p_n integer DEFAULT 8, p_metrics text[] DEFAULT NULL::text[])
 RETURNS TABLE(rank integer, player_id text, player text, team text, pos text, sim_pct numeric, shared_metrics integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with feats as (
    select coalesce(p_metrics, array[
      'role_progressor','role_creator','role_carrier','role_box_threat','role_finisher',
      'role_initiator','role_bridge','role_vertical','role_support_angle','role_individual','role_controller',
      'pct_over','pct_around','pct_through','pct_in_behind','pct_inside','pct_outside',
      'prog_tendency_pct','prog_completion','prog_into_final_90',
      'early_shot_pct','shot_chain_pct','prog_carries_90','takeon_90','carry_box_90',
      'xa_90','key_pass_90','xg_90','xt_90','def_action_90','aerial_90','recov_90'
    ]) as m
  ),
  tgt as (select a.pool, a.metric, a.pct from public.v_player_pct_all a, feats
          where a.player_id = p_id and a.metric = any(feats.m)),
  -- 60% of what the target has, floor of 1: a single-metric query is a legitimate ask
  need as (select greatest(1, ceil(0.6 * count(*))::int) as k from tgt),
  cand as (select a.player_id, a.metric, a.pct from public.v_player_pct_all a, feats
           where a.metric = any(feats.m) and a.player_id <> p_id
             and a.pool = (select pool from tgt limit 1)),
  d as (
    select c.player_id, sqrt(sum(power(c.pct - t.pct, 2)))/sqrt(count(*)) as dist, count(*)::int as shared
    from cand c join tgt t on t.metric = c.metric
    group by c.player_id having count(*) >= (select k from need)
  )
  select row_number() over (order by d.dist)::int, d.player_id, ps.player, ps.team, ps.pos,
         round(greatest(0, 100 - d.dist)::numeric, 1), d.shared
  from d join public.player_search ps on ps.player_id = d.player_id
  order by d.dist limit p_n;
$function$
;
CREATE OR REPLACE FUNCTION public.similar_sequences(p_seq text, p_n integer DEFAULT 10)
 RETURNS TABLE(rank integer, seq_uid text, team text, game_id text, n_pass integer, xt_sum numeric, ended_shot boolean, dist numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with q as (select * from public.seq_fz where seq_uid = p_seq)
  select row_number() over (order by d.dist)::int, d.seq_uid, d.team, d.game_id,
         d.n_pass, d.xt_sum, d.ended_shot, round(d.dist::numeric,3)
  from (
    select z.seq_uid, z.team, z.game_id, z.n_pass, z.xt_sum, z.ended_shot,
      sqrt(
        power(z.z_sx-q.z_sx,2)+power(z.z_sy-q.z_sy,2)+power(z.z_ex-q.z_ex,2)+power(z.z_ey-q.z_ey,2)
       +power(z.z_cx-q.z_cx,2)+power(z.z_cy-q.z_cy,2)+power(z.z_vs-q.z_vs,2)+power(z.z_ls-q.z_ls,2)
       +power(z.z_ndx-q.z_ndx,2)+power(z.z_ndy-q.z_ndy,2)+power(z.z_pl-q.z_pl,2)+power(z.z_np-q.z_np,2)
       +power(z.z_xt-q.z_xt,2)+power(z.z_as-q.z_as,2)
      ) as dist
    from public.seq_fz z, q
    where z.seq_uid <> q.seq_uid and z.game_id <> q.game_id
  ) d
  order by d.dist limit p_n;
$function$
;
CREATE OR REPLACE FUNCTION public.similar_teams(p_team text, p_n integer DEFAULT 5)
 RETURNS TABLE(rank integer, team text, dist numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with q as (select metric, z from public.team_sequence_style where team = p_team)
  select row_number() over (order by x.d)::int, x.t, round(x.d::numeric,2)
  from (
    select s.team as t, sqrt(sum(power(coalesce(s.z,0)-coalesce(q.z,0),2))) as d
    from public.team_sequence_style s join q using(metric)
    where s.team <> p_team
    group by s.team
  ) x order by x.d limit p_n;
$function$
;
CREATE OR REPLACE FUNCTION public.stamp_sequence_leagues()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n_seq int; n_pcr int;
begin
  with gl as (select distinct game_id, league from public.events)
  update public.sequences s set league = gl.league
  from gl where gl.game_id = s.game_id and s.league is distinct from gl.league;
  get diagnostics n_seq = row_count;

  update public.player_chain_roles p set league = pl.league
  from public.mv_player_league pl
  where pl.player_id = p.player_id and p.league is distinct from pl.league;
  get diagnostics n_pcr = row_count;

  return format('league stamped on %s sequences, %s player rows', n_seq, n_pcr);
end $function$
;
CREATE OR REPLACE FUNCTION public.state_weight(p_margin numeric)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select case when abs(p_margin) <= 1 then 1.00 when abs(p_margin) = 2 then 0.60 else 0.35 end::numeric;
$function$
;
CREATE OR REPLACE FUNCTION public.suppress_low_sample_insights()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int; n_undeclared int; n_ineligible int;
begin
  delete from public.insights i
  using public.v_team_sample ts, public.detector_requirements r
  where ts.team = i.team and r.detector = i.detector and ts.matches < r.min_matches;
  get diagnostics n = row_count;

  delete from public.insights i
  where i.team is not null
    and not exists (select 1 from public.detector_requirements r where r.detector = i.detector);
  get diagnostics n_undeclared = row_count;

  -- Club must exist in the scoped evidence base AND clear the minimum
  -- declared for that specific detector. detector_requirements governs;
  -- no sample threshold is hardcoded here.
  delete from public.insights i
  where i.team is not null
    and not exists (
      select 1
      from public.v_team_sample ts
      join public.leagues l on l.league = ts.league and l.competition_type = 'league'
      join public.detector_requirements r on r.detector = i.detector
      where ts.team = i.team
        and ts.matches >= r.min_matches);
  get diagnostics n_ineligible = row_count;

  return format('%s suppressed below declared minimum, %s removed for having no declared requirement, %s removed as ineligible clubs',
                n, n_undeclared, n_ineligible);
end $function$
;
CREATE OR REPLACE FUNCTION public.top_sequences_by_type(p_tag text, p_n integer DEFAULT 10)
 RETURNS SETOF sequences
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if p_tag not in ('low_build','high_build','structured','has_switch','wide_triangles','hold_up',
       'very_short','long_ball','ends_opp_half','end_around_box','finds_central','finds_wide',
       'ended_shot','ended_goal','ended_in_box') then
    raise exception 'invalid tag: %', p_tag;
  end if;
  return query execute format(
    'select * from v_league_sequences as sequences where is_open_play and %I order by xt_sum desc limit %s',
    p_tag, p_n);
end; $function$
;
CREATE OR REPLACE FUNCTION public.verify_rebuild()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare bad text; warns text; n_seq int; seq_games int; n_pcr int; n_srch int;
begin
  select string_agg(format('%s (%s violations)', name, violations), '; ' order by name)
    into bad
  from public.run_invariants()
  where severity = 'error' and violations <> 0;

  if bad is not null then
    raise exception 'rebuild verification FAILED -- %', bad;
  end if;

  select string_agg(format('%s: %s', name, violations), '; ' order by name)
    into warns
  from public.run_invariants()
  where severity = 'warn' and violations > 0;

  select count(*), count(distinct game_id) into n_seq, seq_games from public.sequences;
  select count(*) into n_pcr from public.player_chain_roles;
  select count(*) into n_srch from public.player_search;

  return format('verified -- %s sequences over %s games, %s outfield players, %s in search index, %s league(s)%s',
    n_seq, seq_games, n_pcr, n_srch,
    (select count(*) from public.leagues where is_active),
    case when warns is null then '' else ' | notes: ' || warns end);
end $function$
;
CREATE OR REPLACE FUNCTION public.write_insight_notes()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int := 0;
begin
  -- standout profile: what the profile means and what to check next
  update public.insights i set note = format(
    'Reads as a specialist rather than an all-rounder: he tops the %s pool for %s. Before shortlisting, check whether the volume is a product of his side having the ball, and look at the pitch map to see whether the actions come in useful areas or safe ones.',
    i.metrics->>'pool', i.metrics->>'role')
  where i.detector='standout_profile' and i.note is null;

  -- key man: the risk framed as a squad-planning question
  update public.insights i set note = format(
    'The planning question is what happens without him. With %s%% of the %s load and no close deputy, an injury or sale forces either a like-for-like replacement or a change of approach. Worth checking whether the next man is young enough to grow into it.',
    round((i.metrics->>'share_pct')::numeric), i.metrics->>'role')
  where i.detector='key_man' and i.note is null;

  -- squad gap: the recruitment brief
  update public.insights i set note = format(
    'This is a recruitment lane rather than a crisis: the squad functions without one, but the ceiling is capped. If the side already struggles to progress, filling it changes more than one metric. If they progress fine by other routes, it may be a deliberate stylistic choice.')
  where i.detector='squad_gap' and i.note is null;

  -- minutes inflated: how to read his numbers
  update public.insights i set note = format(
    'Read his per-90 output with that in mind. It does not mean he is a poor player — it means a meaningful share of his production arrived when the game was already settled, and the same numbers in tighter matches would be worth more. Compare his output split by game state before valuing him.')
  where i.detector='minutes_inflated' and i.note is null;

  -- misfit: quirk or misuse
  update public.insights i set note = format(
    'Two readings. Either the coach is using him deliberately against type, which is worth understanding tactically, or he is playing a role that does not suit him. The data flags the anomaly; only watching the games separates intent from accident.')
  where i.detector='misfit_profile' and i.note is null;

  -- team profile
  update public.insights i set note = case
    when abs((i.metrics->>'z')::numeric) < 0.8 then
      'A side without a strong stylistic fingerprint is not necessarily a poor one, but it is harder to plan against and harder to recruit for. Ask whether that is deliberate flexibility or an absence of identity.'
    else format(
      'Style is not quality. This tells you how they try to play, not how well it works — the route verdict does that. A side leaning this heavily on one trait is also predictable, which is exploitable if you can take that trait away.')
    end
  where i.detector='team_profile' and i.note is null;

  -- press vulnerability
  update public.insights i set note =
    'The practical use is opposition planning: attack the weakness rather than the strength, and check whether your own personnel can execute that route before committing to it.'
  where i.detector='press_vulnerability' and i.note is null;

  -- game state reactivity
  update public.insights i set note =
    'Useful for in-game planning. A reactive side changes character once you score, so the game you prepare for is not the game you get after the first goal. A settled side gives you the same problem for ninety minutes.'
  where i.detector='game_state_reactivity' and i.note is null;

  -- sterile control
  update public.insights i set note =
    'Control without penetration is usually a final-third problem rather than a build-up one. Check the route breakdown to see where possessions die, then check whether the squad has anyone above pool average for chance creation.'
  where i.detector='sterile_control' and i.note is null;

  -- route extremes
  update public.insights i set note =
    'A pronounced route preference is both an identity and a vulnerability. Cross-reference against opponents who defend that route well to find the fixtures where they struggle.'
  where i.detector in ('central_funnel','byline_team') and i.note is null;

  update public.insights i set note =
    'Territorial dominance says where the game is played, not whether chances follow. Pair it with the share of possessions ending in a shot before treating it as a strength.'
  where i.detector='territorial' and i.note is null;

  select count(*) into n from public.insights where note is not null;
  return format('%s insight notes written', n);
end $function$
;
CREATE OR REPLACE FUNCTION public.xt_at(px double precision, py double precision)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select v from public.xt_grid
  where x_bin = least(11, greatest(0, floor(px/100*12)::int))
    and y_bin = least(7,  greatest(0, floor(py/100*8)::int));
$function$
;
CREATE OR REPLACE FUNCTION public.xt_val(px double precision, py double precision)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select v from public.xt_grid
  where x_bin = least(11, greatest(0, floor(px/100.0*12)::int))
    and y_bin = least(7, greatest(0, floor(py/100.0*8)::int));
$function$
;

-- === owners ===
alter table public._ml_baseline owner to postgres;
alter table public._replay_log owner to postgres;
alter table public.analytics_publication_probe owner to postgres;
alter table public.analytics_rebuild_runs owner to postgres;
alter table public.detector_priority owner to postgres;
alter table public.detector_requirements owner to postgres;
alter table public.events owner to postgres;
alter table public.events_cup owner to postgres;
alter sequence public.events_cup_id_seq owner to postgres;
alter sequence public.events_id_seq owner to postgres;
alter table public.insights owner to postgres;
alter sequence public.insights_id_seq owner to postgres;
alter table public.invariants owner to postgres;
alter table public.lafc_events owner to postgres;
alter table public.lafc_links owner to postgres;
alter table public.lafc_projects owner to postgres;
alter table public.lafc_todos owner to postgres;
alter table public.lafc_tracker_config owner to postgres;
alter table public.league_mart_entry_objects owner to postgres;
alter table public.leagues owner to postgres;
alter table public.lineups owner to postgres;
alter table public.lineups_cup owner to postgres;
alter sequence public.lineups_cup_id_seq owner to postgres;
alter sequence public.lineups_id_seq owner to postgres;
alter table public.matches owner to postgres;
alter table public.matches_cup owner to postgres;
alter table public.metric_catalog owner to postgres;
alter table public.metric_defs owner to postgres;
alter table public.metric_synonyms owner to postgres;
alter materialized view public.mv_event_phase owner to postgres;
alter materialized view public.mv_game_goals owner to postgres;
alter materialized view public.mv_gk_match owner to postgres;
alter materialized view public.mv_invariant_status owner to postgres;
alter materialized view public.mv_league_availability owner to postgres;
alter materialized view public.mv_league_summary owner to postgres;
alter materialized view public.mv_match_length owner to postgres;
alter materialized view public.mv_metric_examples owner to postgres;
alter materialized view public.mv_pass_traj owner to postgres;
alter materialized view public.mv_player_archetype owner to postgres;
alter materialized view public.mv_player_carry owner to postgres;
alter materialized view public.mv_player_chain_value owner to postgres;
alter materialized view public.mv_player_chains owner to postgres;
alter materialized view public.mv_player_counterpress owner to postgres;
alter materialized view public.mv_player_defload owner to postgres;
alter materialized view public.mv_player_dna owner to postgres;
alter materialized view public.mv_player_foot owner to postgres;
alter materialized view public.mv_player_gk owner to postgres;
alter materialized view public.mv_player_holdup owner to postgres;
alter materialized view public.mv_player_league owner to postgres;
alter materialized view public.mv_player_leverage owner to postgres;
alter materialized view public.mv_player_metrics owner to postgres;
alter materialized view public.mv_player_metrics_raw owner to postgres;
alter materialized view public.mv_player_minutes owner to postgres;
alter materialized view public.mv_player_pass_traj owner to postgres;
alter materialized view public.mv_player_pct owner to postgres;
alter materialized view public.mv_player_percentiles owner to postgres;
alter materialized view public.mv_player_pillars owner to postgres;
alter materialized view public.mv_player_pool owner to postgres;
alter materialized view public.mv_player_progression owner to postgres;
alter materialized view public.mv_player_role owner to postgres;
alter materialized view public.mv_player_sca owner to postgres;
alter materialized view public.mv_player_season owner to postgres;
alter materialized view public.mv_player_setpiece owner to postgres;
alter materialized view public.mv_player_state_output owner to postgres;
alter materialized view public.mv_player_stints owner to postgres;
alter materialized view public.mv_player_team_poss owner to postgres;
alter materialized view public.mv_player_territory owner to postgres;
alter materialized view public.mv_player_xa owner to postgres;
alter materialized view public.mv_player_xt owner to postgres;
alter materialized view public.mv_player_zones owner to postgres;
alter materialized view public.mv_press_vs_buildup owner to postgres;
alter materialized view public.mv_receipt_events owner to postgres;
alter materialized view public.mv_seq_events owner to postgres;
alter materialized view public.mv_seq_state owner to postgres;
alter materialized view public.mv_shot_features owner to postgres;
alter materialized view public.mv_shot_xg owner to postgres;
alter materialized view public.mv_site_summary owner to postgres;
alter materialized view public.mv_squad_role owner to postgres;
alter materialized view public.mv_state_segments owner to postgres;
alter materialized view public.mv_team_all owner to postgres;
alter materialized view public.mv_team_attackphase owner to postgres;
alter materialized view public.mv_team_breakdown owner to postgres;
alter materialized view public.mv_team_buildphase owner to postgres;
alter materialized view public.mv_team_buildup owner to postgres;
alter materialized view public.mv_team_carry_zones owner to postgres;
alter materialized view public.mv_team_directness_state owner to postgres;
alter materialized view public.mv_team_lanes owner to postgres;
alter materialized view public.mv_team_league owner to postgres;
alter materialized view public.mv_team_match owner to postgres;
alter materialized view public.mv_team_percentiles owner to postgres;
alter materialized view public.mv_team_season owner to postgres;
alter materialized view public.mv_team_sequences owner to postgres;
alter materialized view public.mv_team_stat_ranks owner to postgres;
alter materialized view public.mv_team_zones owner to postgres;
alter materialized view public.mv_xg_bins owner to postgres;
alter view public.pcr_z owner to postgres;
alter table public.pillar_defs owner to postgres;
alter table public.player_bio owner to postgres;
alter view public.player_chain_pct owner to postgres;
alter table public.player_chain_roles owner to postgres;
alter materialized view public.player_search owner to postgres;
alter table public.players owner to postgres;
alter table public.pool_metric_relevance owner to postgres;
alter table public.role_pillar_weights owner to postgres;
alter materialized view public.seq_fz owner to postgres;
alter table public.sequences owner to postgres;
alter table public.team_metric_defs owner to postgres;
alter table public.team_names owner to postgres;
alter table public.team_names_cup owner to postgres;
alter view public.team_sequence_agg owner to postgres;
alter view public.team_sequence_style owner to postgres;
alter view public.v_goal_fix owner to postgres;
alter view public.v_league_availability owner to postgres;
alter view public.v_league_competitions owner to postgres;
alter view public.v_league_events owner to postgres;
alter view public.v_league_lineups owner to postgres;
alter view public.v_league_matches owner to postgres;
alter view public.v_league_sequences owner to postgres;
alter view public.v_league_summary owner to postgres;
alter view public.v_loaded_games owner to postgres;
alter view public.v_match_events owner to postgres;
alter view public.v_match_season_scope owner to postgres;
alter view public.v_player_actions owner to postgres;
alter view public.v_player_carries owner to postgres;
alter view public.v_player_metrics_ext owner to postgres;
alter view public.v_player_pct_all owner to postgres;
alter view public.v_player_receipts owner to postgres;
alter view public.v_player_sot_fix owner to postgres;
alter view public.v_player_xt_actions owner to postgres;
alter view public.v_press_profile owner to postgres;
alter view public.v_season_stats owner to postgres;
alter view public.v_seq_directness owner to postgres;
alter view public.v_squad_role owner to postgres;
alter view public.v_team_actions owner to postgres;
alter view public.v_team_carries owner to postgres;
alter view public.v_team_directory owner to postgres;
alter view public.v_team_sample owner to postgres;
alter view public.v_team_shots owner to postgres;
alter view public.v_team_signature owner to postgres;
alter view public.v_xg_model_support owner to postgres;
alter view public.v_xg_temporal_holdout owner to postgres;
alter view public.v_xt_model_status owner to postgres;
alter table public.xt_grid owner to postgres;
alter function analytics_rebuild_run_status(uuid) owner to postgres;
alter function build_insights_extra() owner to postgres;
alter function build_insights_players() owner to postgres;
alter function build_insights() owner to postgres;
alter function build_player_chain_roles() owner to postgres;
alter function build_press_insights() owner to postgres;
alter function build_reactivity_insights() owner to postgres;
alter function build_sequences() owner to postgres;
alter function build_team_profile_insights() owner to postgres;
alter function comparison_scopes() owner to postgres;
alter function create_analytics_rebuild_run(uuid,text) owner to postgres;
alter function detector_min_denominator(text) owner to postgres;
alter function detector_min_matches(text) owner to postgres;
alter function get_starter_names(text) owner to postgres;
alter function lafc_events_list(text) owner to postgres;
alter function lafc_links_delete(text,uuid) owner to postgres;
alter function lafc_links_list(text) owner to postgres;
alter function lafc_links_save(text,uuid,text,text,integer) owner to postgres;
alter function lafc_projects_delete(text,uuid) owner to postgres;
alter function lafc_projects_list(text) owner to postgres;
alter function lafc_projects_save(text,uuid,text,text,text,text,text,integer,date,text,jsonb) owner to postgres;
alter function lafc_projects_touch() owner to postgres;
alter function lafc_todos_clear_done(text) owner to postgres;
alter function lafc_todos_delete(text,uuid) owner to postgres;
alter function lafc_todos_list(text) owner to postgres;
alter function lafc_todos_save(text,uuid,text,boolean,integer) owner to postgres;
alter function lafc_tracker_auth(text) owner to postgres;
alter function nl_query(text,integer) owner to postgres;
alter function player_card_scoped(text,text[]) owner to postgres;
alter function player_card(text) owner to postgres;
alter function player_metric_events(text,text,integer) owner to postgres;
alter function player_pct_scoped(text,text[],text[]) owner to postgres;
alter function player_xt_map(text,text,boolean,integer) owner to postgres;
alter function polish_insights() owner to postgres;
alter function preflight_league(text) owner to postgres;
alter function pretty_metric(text) owner to postgres;
alter function process_analytics_rebuild_queue() owner to postgres;
alter function rebuild_all_verified(uuid,text,text) owner to postgres;
alter function rebuild_all() owner to postgres;
alter function rebuild_step(text,text) owner to postgres;
alter function rebuild_team_names(text) owner to postgres;
alter function refresh_analytics_batch(integer) owner to postgres;
alter function refresh_analytics() owner to postgres;
alter function refresh_site_summaries() owner to postgres;
alter function resolve_player(text) owner to postgres;
alter function run_invariants() owner to postgres;
alter function similar_players_chain(text,integer) owner to postgres;
alter function similar_players_full(text,integer,text[]) owner to postgres;
alter function similar_sequences(text,integer) owner to postgres;
alter function similar_teams(text,integer) owner to postgres;
alter function stamp_sequence_leagues() owner to postgres;
alter function state_weight(numeric) owner to postgres;
alter function suppress_low_sample_insights() owner to postgres;
alter function top_sequences_by_type(text,integer) owner to postgres;
alter function verify_rebuild() owner to postgres;
alter function write_insight_notes() owner to postgres;
alter function xt_at(double precision,double precision) owner to postgres;
alter function xt_val(double precision,double precision) owner to postgres;

-- === indexes ===
CREATE INDEX _ml_baseline_idx ON public._ml_baseline USING btree (src, k1, k2);
CREATE INDEX events_league_idx ON public.events USING btree (league);
CREATE INDEX idx_events_game_id ON public.events USING btree (game_id);
CREATE INDEX idx_events_open_play ON public.events USING btree (is_open_play);
CREATE INDEX idx_events_player_id ON public.events USING btree (player_id);
CREATE INDEX idx_events_qualifiers_gin ON public.events USING gin (qualifiers jsonb_path_ops);
CREATE INDEX idx_events_team ON public.events USING btree (team);
CREATE INDEX idx_events_team_game_id ON public.events USING btree (team, game_id);
CREATE INDEX idx_events_team_type ON public.events USING btree (team, type);
CREATE INDEX idx_events_type ON public.events USING btree (type);
CREATE INDEX events_cup_game_idx ON public.events_cup USING btree (game_id);
CREATE INDEX events_cup_team_idx ON public.events_cup USING btree (team);
CREATE INDEX lafc_events_starts_idx ON public.lafc_events USING btree (starts_at);
CREATE INDEX idx_lineups_game_id ON public.lineups USING btree (game_id);
CREATE INDEX lineups_league_idx ON public.lineups USING btree (league);
CREATE INDEX lineups_cup_game_idx ON public.lineups_cup USING btree (game_id);
CREATE INDEX idx_matches_away_team ON public.matches USING btree (away_team);
CREATE INDEX idx_matches_competition ON public.matches USING btree (competition);
CREATE INDEX idx_matches_home_team ON public.matches USING btree (home_team);
CREATE INDEX matches_league_idx ON public.matches USING btree (league);
CREATE UNIQUE INDEX mv_event_phase_game_id_ws_id_idx ON public.mv_event_phase USING btree (game_id, ws_id);
CREATE INDEX mv_event_phase_set_piece_phase_idx ON public.mv_event_phase USING btree (set_piece_phase);
CREATE INDEX mv_game_goals_idx ON public.mv_game_goals USING btree (game_id, expanded_minute);
CREATE INDEX mv_gk_match_player_id_idx ON public.mv_gk_match USING btree (player_id);
CREATE UNIQUE INDEX mv_invariant_status_name_idx ON public.mv_invariant_status USING btree (name);
CREATE UNIQUE INDEX mv_league_availability_pk ON public.mv_league_availability USING btree (league);
CREATE UNIQUE INDEX mv_league_summary_pk ON public.mv_league_summary USING btree (league);
CREATE UNIQUE INDEX mv_match_length_game_id_idx ON public.mv_match_length USING btree (game_id);
CREATE INDEX mv_metric_examples_metric_idx ON public.mv_metric_examples USING btree (metric);
CREATE INDEX mv_pass_traj_player ON public.mv_pass_traj USING btree (player_id);
CREATE INDEX mv_player_archetype_cohort ON public.mv_player_archetype USING btree (pool_archetype);
CREATE UNIQUE INDEX mv_player_archetype_pk ON public.mv_player_archetype USING btree (player_id);
CREATE UNIQUE INDEX mv_player_carry_player_id_idx ON public.mv_player_carry USING btree (player_id);
CREATE UNIQUE INDEX mv_player_chain_value_pk ON public.mv_player_chain_value USING btree (player_id);
CREATE UNIQUE INDEX mv_player_chains_player_id_idx ON public.mv_player_chains USING btree (player_id);
CREATE UNIQUE INDEX mv_player_counterpress_player_id_idx ON public.mv_player_counterpress USING btree (player_id);
CREATE UNIQUE INDEX mv_player_defload_player_id_idx ON public.mv_player_defload USING btree (player_id);
CREATE UNIQUE INDEX mv_player_dna_pk ON public.mv_player_dna USING btree (player_id);
CREATE UNIQUE INDEX mv_player_foot_pk ON public.mv_player_foot USING btree (player_id);
CREATE UNIQUE INDEX mv_player_gk_player_id_idx ON public.mv_player_gk USING btree (player_id);
CREATE UNIQUE INDEX mv_player_holdup_player_id_idx ON public.mv_player_holdup USING btree (player_id);
CREATE UNIQUE INDEX mv_player_league_pk ON public.mv_player_league USING btree (player_id);
CREATE INDEX mv_player_leverage_p ON public.mv_player_leverage USING btree (player_id);
CREATE UNIQUE INDEX mv_player_metrics_player_id_idx ON public.mv_player_metrics USING btree (player_id);
CREATE UNIQUE INDEX mv_player_metrics_raw_player_id_idx ON public.mv_player_metrics_raw USING btree (player_id);
CREATE INDEX mv_player_minutes_game_id_idx ON public.mv_player_minutes USING btree (game_id);
CREATE INDEX mv_player_minutes_player_id_idx ON public.mv_player_minutes USING btree (player_id);
CREATE UNIQUE INDEX mv_player_pass_traj_pk ON public.mv_player_pass_traj USING btree (player_id);
CREATE INDEX mv_player_pct_metric ON public.mv_player_pct USING btree (metric);
CREATE INDEX mv_player_pct_player ON public.mv_player_pct USING btree (player_id);
CREATE INDEX mv_player_percentiles_metric ON public.mv_player_percentiles USING btree (metric);
CREATE INDEX mv_player_percentiles_pm ON public.mv_player_percentiles USING btree (player_id, metric);
CREATE INDEX mv_player_pillars_p ON public.mv_player_pillars USING btree (player_id);
CREATE UNIQUE INDEX mv_player_pillars_uq ON public.mv_player_pillars USING btree (player_id, pillar);
CREATE UNIQUE INDEX mv_player_pool_player_id_idx ON public.mv_player_pool USING btree (player_id);
CREATE UNIQUE INDEX mv_player_progression_pk ON public.mv_player_progression USING btree (player_id);
CREATE UNIQUE INDEX mv_player_role_player_id_idx ON public.mv_player_role USING btree (player_id);
CREATE UNIQUE INDEX mv_player_sca_player_id_idx ON public.mv_player_sca USING btree (player_id);
CREATE UNIQUE INDEX mv_player_season_player_id_idx ON public.mv_player_season USING btree (player_id);
CREATE UNIQUE INDEX mv_player_setpiece_player_id_idx ON public.mv_player_setpiece USING btree (player_id);
CREATE UNIQUE INDEX mv_player_state_output_pk ON public.mv_player_state_output USING btree (player_id);
CREATE INDEX mv_player_stints_pg ON public.mv_player_stints USING btree (player_id, game_id);
CREATE UNIQUE INDEX mv_player_team_poss_player_id_idx ON public.mv_player_team_poss USING btree (player_id);
CREATE UNIQUE INDEX mv_player_territory_player_id_idx ON public.mv_player_territory USING btree (player_id);
CREATE UNIQUE INDEX mv_player_xa_player_id_idx ON public.mv_player_xa USING btree (player_id);
CREATE UNIQUE INDEX mv_player_xt_player_id_idx ON public.mv_player_xt USING btree (player_id);
CREATE UNIQUE INDEX mv_player_zones_player_id_idx ON public.mv_player_zones USING btree (player_id);
CREATE INDEX mv_press_vs_buildup_team ON public.mv_press_vs_buildup USING btree (defending_team);
CREATE INDEX mv_receipt_events_game_id_idx ON public.mv_receipt_events USING btree (game_id);
CREATE INDEX mv_receipt_events_player_id_idx ON public.mv_receipt_events USING btree (player_id);
CREATE INDEX mv_seq_events_player ON public.mv_seq_events USING btree (player_id);
CREATE INDEX mv_seq_events_seq ON public.mv_seq_events USING btree (seq_uid);
CREATE UNIQUE INDEX mv_seq_state_pk ON public.mv_seq_state USING btree (seq_uid);
CREATE INDEX mv_seq_state_team ON public.mv_seq_state USING btree (team, state);
CREATE UNIQUE INDEX mv_shot_features_game_id_ws_id_idx ON public.mv_shot_features USING btree (game_id, ws_id);
CREATE UNIQUE INDEX mv_shot_xg_game_id_ws_id_idx ON public.mv_shot_xg USING btree (game_id, ws_id);
CREATE INDEX mv_shot_xg_player_id_idx ON public.mv_shot_xg USING btree (player_id);
CREATE INDEX mv_squad_role_player ON public.mv_squad_role USING btree (player_id);
CREATE INDEX mv_state_segments_gt ON public.mv_state_segments USING btree (game_id, team);
CREATE UNIQUE INDEX mv_team_all_team_idx ON public.mv_team_all USING btree (team);
CREATE UNIQUE INDEX mv_team_attackphase_team_idx ON public.mv_team_attackphase USING btree (team);
CREATE INDEX mv_team_breakdown_team ON public.mv_team_breakdown USING btree (team);
CREATE UNIQUE INDEX mv_team_buildphase_team_idx ON public.mv_team_buildphase USING btree (team);
CREATE UNIQUE INDEX mv_team_buildup_team_idx ON public.mv_team_buildup USING btree (team);
CREATE INDEX mv_team_carry_zones_team_idx ON public.mv_team_carry_zones USING btree (team);
CREATE UNIQUE INDEX mv_team_directness_state_pk ON public.mv_team_directness_state USING btree (team);
CREATE INDEX mv_team_lanes_team_idx ON public.mv_team_lanes USING btree (team);
CREATE UNIQUE INDEX mv_team_league_pk ON public.mv_team_league USING btree (team);
CREATE UNIQUE INDEX mv_team_match_game_id_team_idx ON public.mv_team_match USING btree (game_id, team);
CREATE INDEX mv_team_percentiles_tm ON public.mv_team_percentiles USING btree (team, metric);
CREATE UNIQUE INDEX mv_team_season_team_idx ON public.mv_team_season USING btree (team);
CREATE INDEX mv_team_sequences_team_idx ON public.mv_team_sequences USING btree (team);
CREATE INDEX mv_team_stat_ranks_tm ON public.mv_team_stat_ranks USING btree (team, metric);
CREATE INDEX mv_team_zones_team_idx ON public.mv_team_zones USING btree (team);
CREATE UNIQUE INDEX mv_xg_bins_d_bin_a_bin_is_header_is_bigchance_idx ON public.mv_xg_bins USING btree (d_bin, a_bin, is_header, is_bigchance);
CREATE INDEX pcr_league_idx ON public.player_chain_roles USING btree (league);
CREATE INDEX player_search_age ON public.player_search USING btree (age_seen);
CREATE INDEX player_search_foot ON public.player_search USING btree (foot);
CREATE INDEX player_search_league ON public.player_search USING btree (league);
CREATE INDEX player_search_name_trgm ON public.player_search USING gin (player gin_trgm_ops);
CREATE UNIQUE INDEX player_search_pk ON public.player_search USING btree (player_id);
CREATE INDEX player_search_pool ON public.player_search USING btree (pool);
CREATE INDEX player_search_pos ON public.player_search USING btree (pos);
CREATE INDEX player_search_side ON public.player_search USING btree (side);
CREATE UNIQUE INDEX seq_fz_pk ON public.seq_fz USING btree (seq_uid);
CREATE INDEX seq_fz_team ON public.seq_fz USING btree (team);
CREATE INDEX sequences_game_idx ON public.sequences USING btree (game_id);
CREATE INDEX sequences_league_idx ON public.sequences USING btree (league);
CREATE INDEX sequences_team_op_idx ON public.sequences USING btree (team, is_open_play);
CREATE UNIQUE INDEX team_names_league_event_uidx ON public.team_names USING btree (league, event_name);

-- === triggers ===
CREATE TRIGGER trg_lafc_links_touch BEFORE UPDATE ON lafc_links FOR EACH ROW EXECUTE FUNCTION lafc_projects_touch();
CREATE TRIGGER trg_lafc_projects_touch BEFORE UPDATE ON lafc_projects FOR EACH ROW EXECUTE FUNCTION lafc_projects_touch();

-- === policies ===
create policy "public read events" on public.events as permissive for select to anon,authenticated using (true);
create policy public_read on public.events_cup as permissive for select to public using (true);
create policy public_read on public.leagues as permissive for select to public using (true);
create policy "public read lineups" on public.lineups as permissive for select to anon,authenticated using (true);
create policy public_read on public.lineups_cup as permissive for select to public using (true);
create policy "public read matches" on public.matches as permissive for select to anon,authenticated using (true);
create policy public_read on public.matches_cup as permissive for select to public using (true);
create policy public_read on public.player_bio as permissive for select to public using (true);
create policy "public read players" on public.players as permissive for select to anon,authenticated using (true);
create policy public_read on public.team_names_cup as permissive for select to public using (true);

-- === comments ===
comment on view public.v_league_competitions is 'Registered league competitions only. Single source of competition membership for league-scoped analytics.';
comment on view public.v_league_events is 'Canonical current-season league event source. Excludes cups, continental fixtures and prior seasons.';
comment on view public.v_league_lineups is 'Canonical current-season league lineup source. Season resolves through matches.';
comment on view public.v_league_matches is 'Canonical current-season league match source. Raw history remains in matches.';
comment on view public.v_league_sequences is 'Canonical current-season league sequence source. Season resolves through matches.';
comment on view public.v_match_season_scope is 'Current-season match catalogue used by caller-rights public analytics. Contains only already-public match and registry fields.';
comment on view public.v_team_sample is 'Team evidence base, league competitions only via v_league_sequences. Source of truth for the six-match minimum.';
comment on function process_analytics_rebuild_queue() is 'Claims one pending analytics rebuild and executes it inside the rollback-safe database transaction. Scheduled once per minute; advisory locking prevents overlap.';
comment on function rebuild_all_verified(uuid,text,text) is 'Refreshes every analytical layer and publishes summaries in one rollback-safe transaction. p_fail_after_step is a service-role-only verification hook.';

-- === acl_reset ===

revoke all on all tables in schema public from public,anon,authenticated,service_role;
revoke all on all sequences in schema public from public,anon,authenticated,service_role;
revoke all on all functions in schema public from public,anon,authenticated,service_role;

-- === grants ===
grant DELETE on table public._ml_baseline to postgres;
grant INSERT on table public._ml_baseline to postgres;
grant MAINTAIN on table public._ml_baseline to postgres;
grant REFERENCES on table public._ml_baseline to postgres;
grant SELECT on table public._ml_baseline to postgres;
grant TRIGGER on table public._ml_baseline to postgres;
grant TRUNCATE on table public._ml_baseline to postgres;
grant UPDATE on table public._ml_baseline to postgres;
grant DELETE on table public._ml_baseline to service_role;
grant INSERT on table public._ml_baseline to service_role;
grant MAINTAIN on table public._ml_baseline to service_role;
grant REFERENCES on table public._ml_baseline to service_role;
grant SELECT on table public._ml_baseline to service_role;
grant TRIGGER on table public._ml_baseline to service_role;
grant TRUNCATE on table public._ml_baseline to service_role;
grant UPDATE on table public._ml_baseline to service_role;
grant DELETE on table public._replay_log to postgres;
grant INSERT on table public._replay_log to postgres;
grant MAINTAIN on table public._replay_log to postgres;
grant REFERENCES on table public._replay_log to postgres;
grant SELECT on table public._replay_log to postgres;
grant TRIGGER on table public._replay_log to postgres;
grant TRUNCATE on table public._replay_log to postgres;
grant UPDATE on table public._replay_log to postgres;
grant DELETE on table public._replay_log to service_role;
grant INSERT on table public._replay_log to service_role;
grant MAINTAIN on table public._replay_log to service_role;
grant REFERENCES on table public._replay_log to service_role;
grant SELECT on table public._replay_log to service_role;
grant TRIGGER on table public._replay_log to service_role;
grant TRUNCATE on table public._replay_log to service_role;
grant UPDATE on table public._replay_log to service_role;
grant DELETE on table public.analytics_publication_probe to postgres;
grant INSERT on table public.analytics_publication_probe to postgres;
grant MAINTAIN on table public.analytics_publication_probe to postgres;
grant REFERENCES on table public.analytics_publication_probe to postgres;
grant SELECT on table public.analytics_publication_probe to postgres;
grant TRIGGER on table public.analytics_publication_probe to postgres;
grant TRUNCATE on table public.analytics_publication_probe to postgres;
grant UPDATE on table public.analytics_publication_probe to postgres;
grant DELETE on table public.analytics_publication_probe to service_role;
grant INSERT on table public.analytics_publication_probe to service_role;
grant MAINTAIN on table public.analytics_publication_probe to service_role;
grant REFERENCES on table public.analytics_publication_probe to service_role;
grant SELECT on table public.analytics_publication_probe to service_role;
grant TRIGGER on table public.analytics_publication_probe to service_role;
grant TRUNCATE on table public.analytics_publication_probe to service_role;
grant UPDATE on table public.analytics_publication_probe to service_role;
grant DELETE on table public.analytics_rebuild_runs to postgres;
grant INSERT on table public.analytics_rebuild_runs to postgres;
grant MAINTAIN on table public.analytics_rebuild_runs to postgres;
grant REFERENCES on table public.analytics_rebuild_runs to postgres;
grant SELECT on table public.analytics_rebuild_runs to postgres;
grant TRIGGER on table public.analytics_rebuild_runs to postgres;
grant TRUNCATE on table public.analytics_rebuild_runs to postgres;
grant UPDATE on table public.analytics_rebuild_runs to postgres;
grant DELETE on table public.analytics_rebuild_runs to service_role;
grant INSERT on table public.analytics_rebuild_runs to service_role;
grant MAINTAIN on table public.analytics_rebuild_runs to service_role;
grant REFERENCES on table public.analytics_rebuild_runs to service_role;
grant SELECT on table public.analytics_rebuild_runs to service_role;
grant TRIGGER on table public.analytics_rebuild_runs to service_role;
grant TRUNCATE on table public.analytics_rebuild_runs to service_role;
grant UPDATE on table public.analytics_rebuild_runs to service_role;
grant SELECT on table public.detector_priority to anon;
grant SELECT on table public.detector_priority to authenticated;
grant DELETE on table public.detector_priority to postgres;
grant INSERT on table public.detector_priority to postgres;
grant MAINTAIN on table public.detector_priority to postgres;
grant REFERENCES on table public.detector_priority to postgres;
grant SELECT on table public.detector_priority to postgres;
grant TRIGGER on table public.detector_priority to postgres;
grant TRUNCATE on table public.detector_priority to postgres;
grant UPDATE on table public.detector_priority to postgres;
grant DELETE on table public.detector_priority to service_role;
grant INSERT on table public.detector_priority to service_role;
grant MAINTAIN on table public.detector_priority to service_role;
grant REFERENCES on table public.detector_priority to service_role;
grant SELECT on table public.detector_priority to service_role;
grant TRIGGER on table public.detector_priority to service_role;
grant TRUNCATE on table public.detector_priority to service_role;
grant UPDATE on table public.detector_priority to service_role;
grant SELECT on table public.detector_requirements to anon;
grant SELECT on table public.detector_requirements to authenticated;
grant DELETE on table public.detector_requirements to postgres;
grant INSERT on table public.detector_requirements to postgres;
grant MAINTAIN on table public.detector_requirements to postgres;
grant REFERENCES on table public.detector_requirements to postgres;
grant SELECT on table public.detector_requirements to postgres;
grant TRIGGER on table public.detector_requirements to postgres;
grant TRUNCATE on table public.detector_requirements to postgres;
grant UPDATE on table public.detector_requirements to postgres;
grant DELETE on table public.detector_requirements to service_role;
grant INSERT on table public.detector_requirements to service_role;
grant MAINTAIN on table public.detector_requirements to service_role;
grant REFERENCES on table public.detector_requirements to service_role;
grant SELECT on table public.detector_requirements to service_role;
grant TRIGGER on table public.detector_requirements to service_role;
grant TRUNCATE on table public.detector_requirements to service_role;
grant UPDATE on table public.detector_requirements to service_role;
grant SELECT on table public.events to anon;
grant SELECT on table public.events to authenticated;
grant DELETE on table public.events to postgres;
grant INSERT on table public.events to postgres;
grant MAINTAIN on table public.events to postgres;
grant REFERENCES on table public.events to postgres;
grant SELECT on table public.events to postgres;
grant TRIGGER on table public.events to postgres;
grant TRUNCATE on table public.events to postgres;
grant UPDATE on table public.events to postgres;
grant DELETE on table public.events to service_role;
grant INSERT on table public.events to service_role;
grant MAINTAIN on table public.events to service_role;
grant REFERENCES on table public.events to service_role;
grant SELECT on table public.events to service_role;
grant TRIGGER on table public.events to service_role;
grant TRUNCATE on table public.events to service_role;
grant UPDATE on table public.events to service_role;
grant SELECT on table public.events_cup to anon;
grant SELECT on table public.events_cup to authenticated;
grant DELETE on table public.events_cup to postgres;
grant INSERT on table public.events_cup to postgres;
grant MAINTAIN on table public.events_cup to postgres;
grant REFERENCES on table public.events_cup to postgres;
grant SELECT on table public.events_cup to postgres;
grant TRIGGER on table public.events_cup to postgres;
grant TRUNCATE on table public.events_cup to postgres;
grant UPDATE on table public.events_cup to postgres;
grant DELETE on table public.events_cup to service_role;
grant INSERT on table public.events_cup to service_role;
grant MAINTAIN on table public.events_cup to service_role;
grant REFERENCES on table public.events_cup to service_role;
grant SELECT on table public.events_cup to service_role;
grant TRIGGER on table public.events_cup to service_role;
grant TRUNCATE on table public.events_cup to service_role;
grant UPDATE on table public.events_cup to service_role;
grant SELECT on sequence public.events_cup_id_seq to anon;
grant UPDATE on sequence public.events_cup_id_seq to anon;
grant USAGE on sequence public.events_cup_id_seq to anon;
grant SELECT on sequence public.events_cup_id_seq to authenticated;
grant UPDATE on sequence public.events_cup_id_seq to authenticated;
grant USAGE on sequence public.events_cup_id_seq to authenticated;
grant SELECT on sequence public.events_cup_id_seq to postgres;
grant UPDATE on sequence public.events_cup_id_seq to postgres;
grant USAGE on sequence public.events_cup_id_seq to postgres;
grant SELECT on sequence public.events_cup_id_seq to service_role;
grant UPDATE on sequence public.events_cup_id_seq to service_role;
grant USAGE on sequence public.events_cup_id_seq to service_role;
grant SELECT on sequence public.events_id_seq to anon;
grant UPDATE on sequence public.events_id_seq to anon;
grant USAGE on sequence public.events_id_seq to anon;
grant SELECT on sequence public.events_id_seq to authenticated;
grant UPDATE on sequence public.events_id_seq to authenticated;
grant USAGE on sequence public.events_id_seq to authenticated;
grant SELECT on sequence public.events_id_seq to postgres;
grant UPDATE on sequence public.events_id_seq to postgres;
grant USAGE on sequence public.events_id_seq to postgres;
grant SELECT on sequence public.events_id_seq to service_role;
grant UPDATE on sequence public.events_id_seq to service_role;
grant USAGE on sequence public.events_id_seq to service_role;
grant SELECT on table public.insights to anon;
grant SELECT on table public.insights to authenticated;
grant DELETE on table public.insights to postgres;
grant INSERT on table public.insights to postgres;
grant MAINTAIN on table public.insights to postgres;
grant REFERENCES on table public.insights to postgres;
grant SELECT on table public.insights to postgres;
grant TRIGGER on table public.insights to postgres;
grant TRUNCATE on table public.insights to postgres;
grant UPDATE on table public.insights to postgres;
grant DELETE on table public.insights to service_role;
grant INSERT on table public.insights to service_role;
grant MAINTAIN on table public.insights to service_role;
grant REFERENCES on table public.insights to service_role;
grant SELECT on table public.insights to service_role;
grant TRIGGER on table public.insights to service_role;
grant TRUNCATE on table public.insights to service_role;
grant UPDATE on table public.insights to service_role;
grant SELECT on sequence public.insights_id_seq to anon;
grant UPDATE on sequence public.insights_id_seq to anon;
grant USAGE on sequence public.insights_id_seq to anon;
grant SELECT on sequence public.insights_id_seq to authenticated;
grant UPDATE on sequence public.insights_id_seq to authenticated;
grant USAGE on sequence public.insights_id_seq to authenticated;
grant SELECT on sequence public.insights_id_seq to postgres;
grant UPDATE on sequence public.insights_id_seq to postgres;
grant USAGE on sequence public.insights_id_seq to postgres;
grant SELECT on sequence public.insights_id_seq to service_role;
grant UPDATE on sequence public.insights_id_seq to service_role;
grant USAGE on sequence public.insights_id_seq to service_role;
grant SELECT on table public.invariants to anon;
grant SELECT on table public.invariants to authenticated;
grant DELETE on table public.invariants to postgres;
grant INSERT on table public.invariants to postgres;
grant MAINTAIN on table public.invariants to postgres;
grant REFERENCES on table public.invariants to postgres;
grant SELECT on table public.invariants to postgres;
grant TRIGGER on table public.invariants to postgres;
grant TRUNCATE on table public.invariants to postgres;
grant UPDATE on table public.invariants to postgres;
grant DELETE on table public.invariants to service_role;
grant INSERT on table public.invariants to service_role;
grant MAINTAIN on table public.invariants to service_role;
grant REFERENCES on table public.invariants to service_role;
grant SELECT on table public.invariants to service_role;
grant TRIGGER on table public.invariants to service_role;
grant TRUNCATE on table public.invariants to service_role;
grant UPDATE on table public.invariants to service_role;
grant SELECT on table public.lafc_events to anon;
grant SELECT on table public.lafc_events to authenticated;
grant DELETE on table public.lafc_events to postgres;
grant INSERT on table public.lafc_events to postgres;
grant MAINTAIN on table public.lafc_events to postgres;
grant REFERENCES on table public.lafc_events to postgres;
grant SELECT on table public.lafc_events to postgres;
grant TRIGGER on table public.lafc_events to postgres;
grant TRUNCATE on table public.lafc_events to postgres;
grant UPDATE on table public.lafc_events to postgres;
grant DELETE on table public.lafc_events to service_role;
grant INSERT on table public.lafc_events to service_role;
grant MAINTAIN on table public.lafc_events to service_role;
grant REFERENCES on table public.lafc_events to service_role;
grant SELECT on table public.lafc_events to service_role;
grant TRIGGER on table public.lafc_events to service_role;
grant TRUNCATE on table public.lafc_events to service_role;
grant UPDATE on table public.lafc_events to service_role;
grant SELECT on table public.lafc_links to anon;
grant SELECT on table public.lafc_links to authenticated;
grant DELETE on table public.lafc_links to postgres;
grant INSERT on table public.lafc_links to postgres;
grant MAINTAIN on table public.lafc_links to postgres;
grant REFERENCES on table public.lafc_links to postgres;
grant SELECT on table public.lafc_links to postgres;
grant TRIGGER on table public.lafc_links to postgres;
grant TRUNCATE on table public.lafc_links to postgres;
grant UPDATE on table public.lafc_links to postgres;
grant DELETE on table public.lafc_links to service_role;
grant INSERT on table public.lafc_links to service_role;
grant MAINTAIN on table public.lafc_links to service_role;
grant REFERENCES on table public.lafc_links to service_role;
grant SELECT on table public.lafc_links to service_role;
grant TRIGGER on table public.lafc_links to service_role;
grant TRUNCATE on table public.lafc_links to service_role;
grant UPDATE on table public.lafc_links to service_role;
grant SELECT on table public.lafc_projects to anon;
grant SELECT on table public.lafc_projects to authenticated;
grant DELETE on table public.lafc_projects to postgres;
grant INSERT on table public.lafc_projects to postgres;
grant MAINTAIN on table public.lafc_projects to postgres;
grant REFERENCES on table public.lafc_projects to postgres;
grant SELECT on table public.lafc_projects to postgres;
grant TRIGGER on table public.lafc_projects to postgres;
grant TRUNCATE on table public.lafc_projects to postgres;
grant UPDATE on table public.lafc_projects to postgres;
grant DELETE on table public.lafc_projects to service_role;
grant INSERT on table public.lafc_projects to service_role;
grant MAINTAIN on table public.lafc_projects to service_role;
grant REFERENCES on table public.lafc_projects to service_role;
grant SELECT on table public.lafc_projects to service_role;
grant TRIGGER on table public.lafc_projects to service_role;
grant TRUNCATE on table public.lafc_projects to service_role;
grant UPDATE on table public.lafc_projects to service_role;
grant DELETE on table public.lafc_todos to postgres;
grant INSERT on table public.lafc_todos to postgres;
grant MAINTAIN on table public.lafc_todos to postgres;
grant REFERENCES on table public.lafc_todos to postgres;
grant SELECT on table public.lafc_todos to postgres;
grant TRIGGER on table public.lafc_todos to postgres;
grant TRUNCATE on table public.lafc_todos to postgres;
grant UPDATE on table public.lafc_todos to postgres;
grant DELETE on table public.lafc_todos to service_role;
grant INSERT on table public.lafc_todos to service_role;
grant MAINTAIN on table public.lafc_todos to service_role;
grant REFERENCES on table public.lafc_todos to service_role;
grant SELECT on table public.lafc_todos to service_role;
grant TRIGGER on table public.lafc_todos to service_role;
grant TRUNCATE on table public.lafc_todos to service_role;
grant UPDATE on table public.lafc_todos to service_role;
grant SELECT on table public.lafc_tracker_config to anon;
grant SELECT on table public.lafc_tracker_config to authenticated;
grant DELETE on table public.lafc_tracker_config to postgres;
grant INSERT on table public.lafc_tracker_config to postgres;
grant MAINTAIN on table public.lafc_tracker_config to postgres;
grant REFERENCES on table public.lafc_tracker_config to postgres;
grant SELECT on table public.lafc_tracker_config to postgres;
grant TRIGGER on table public.lafc_tracker_config to postgres;
grant TRUNCATE on table public.lafc_tracker_config to postgres;
grant UPDATE on table public.lafc_tracker_config to postgres;
grant DELETE on table public.lafc_tracker_config to service_role;
grant INSERT on table public.lafc_tracker_config to service_role;
grant MAINTAIN on table public.lafc_tracker_config to service_role;
grant REFERENCES on table public.lafc_tracker_config to service_role;
grant SELECT on table public.lafc_tracker_config to service_role;
grant TRIGGER on table public.lafc_tracker_config to service_role;
grant TRUNCATE on table public.lafc_tracker_config to service_role;
grant UPDATE on table public.lafc_tracker_config to service_role;
grant DELETE on table public.league_mart_entry_objects to postgres;
grant INSERT on table public.league_mart_entry_objects to postgres;
grant MAINTAIN on table public.league_mart_entry_objects to postgres;
grant REFERENCES on table public.league_mart_entry_objects to postgres;
grant SELECT on table public.league_mart_entry_objects to postgres;
grant TRIGGER on table public.league_mart_entry_objects to postgres;
grant TRUNCATE on table public.league_mart_entry_objects to postgres;
grant UPDATE on table public.league_mart_entry_objects to postgres;
grant DELETE on table public.league_mart_entry_objects to service_role;
grant INSERT on table public.league_mart_entry_objects to service_role;
grant MAINTAIN on table public.league_mart_entry_objects to service_role;
grant REFERENCES on table public.league_mart_entry_objects to service_role;
grant SELECT on table public.league_mart_entry_objects to service_role;
grant TRIGGER on table public.league_mart_entry_objects to service_role;
grant TRUNCATE on table public.league_mart_entry_objects to service_role;
grant UPDATE on table public.league_mart_entry_objects to service_role;
grant SELECT on table public.leagues to anon;
grant SELECT on table public.leagues to authenticated;
grant DELETE on table public.leagues to postgres;
grant INSERT on table public.leagues to postgres;
grant MAINTAIN on table public.leagues to postgres;
grant REFERENCES on table public.leagues to postgres;
grant SELECT on table public.leagues to postgres;
grant TRIGGER on table public.leagues to postgres;
grant TRUNCATE on table public.leagues to postgres;
grant UPDATE on table public.leagues to postgres;
grant DELETE on table public.leagues to service_role;
grant INSERT on table public.leagues to service_role;
grant MAINTAIN on table public.leagues to service_role;
grant REFERENCES on table public.leagues to service_role;
grant SELECT on table public.leagues to service_role;
grant TRIGGER on table public.leagues to service_role;
grant TRUNCATE on table public.leagues to service_role;
grant UPDATE on table public.leagues to service_role;
grant SELECT on table public.lineups to anon;
grant SELECT on table public.lineups to authenticated;
grant DELETE on table public.lineups to postgres;
grant INSERT on table public.lineups to postgres;
grant MAINTAIN on table public.lineups to postgres;
grant REFERENCES on table public.lineups to postgres;
grant SELECT on table public.lineups to postgres;
grant TRIGGER on table public.lineups to postgres;
grant TRUNCATE on table public.lineups to postgres;
grant UPDATE on table public.lineups to postgres;
grant DELETE on table public.lineups to service_role;
grant INSERT on table public.lineups to service_role;
grant MAINTAIN on table public.lineups to service_role;
grant REFERENCES on table public.lineups to service_role;
grant SELECT on table public.lineups to service_role;
grant TRIGGER on table public.lineups to service_role;
grant TRUNCATE on table public.lineups to service_role;
grant UPDATE on table public.lineups to service_role;
grant SELECT on table public.lineups_cup to anon;
grant SELECT on table public.lineups_cup to authenticated;
grant DELETE on table public.lineups_cup to postgres;
grant INSERT on table public.lineups_cup to postgres;
grant MAINTAIN on table public.lineups_cup to postgres;
grant REFERENCES on table public.lineups_cup to postgres;
grant SELECT on table public.lineups_cup to postgres;
grant TRIGGER on table public.lineups_cup to postgres;
grant TRUNCATE on table public.lineups_cup to postgres;
grant UPDATE on table public.lineups_cup to postgres;
grant DELETE on table public.lineups_cup to service_role;
grant INSERT on table public.lineups_cup to service_role;
grant MAINTAIN on table public.lineups_cup to service_role;
grant REFERENCES on table public.lineups_cup to service_role;
grant SELECT on table public.lineups_cup to service_role;
grant TRIGGER on table public.lineups_cup to service_role;
grant TRUNCATE on table public.lineups_cup to service_role;
grant UPDATE on table public.lineups_cup to service_role;
grant SELECT on sequence public.lineups_cup_id_seq to anon;
grant UPDATE on sequence public.lineups_cup_id_seq to anon;
grant USAGE on sequence public.lineups_cup_id_seq to anon;
grant SELECT on sequence public.lineups_cup_id_seq to authenticated;
grant UPDATE on sequence public.lineups_cup_id_seq to authenticated;
grant USAGE on sequence public.lineups_cup_id_seq to authenticated;
grant SELECT on sequence public.lineups_cup_id_seq to postgres;
grant UPDATE on sequence public.lineups_cup_id_seq to postgres;
grant USAGE on sequence public.lineups_cup_id_seq to postgres;
grant SELECT on sequence public.lineups_cup_id_seq to service_role;
grant UPDATE on sequence public.lineups_cup_id_seq to service_role;
grant USAGE on sequence public.lineups_cup_id_seq to service_role;
grant SELECT on sequence public.lineups_id_seq to anon;
grant UPDATE on sequence public.lineups_id_seq to anon;
grant USAGE on sequence public.lineups_id_seq to anon;
grant SELECT on sequence public.lineups_id_seq to authenticated;
grant UPDATE on sequence public.lineups_id_seq to authenticated;
grant USAGE on sequence public.lineups_id_seq to authenticated;
grant SELECT on sequence public.lineups_id_seq to postgres;
grant UPDATE on sequence public.lineups_id_seq to postgres;
grant USAGE on sequence public.lineups_id_seq to postgres;
grant SELECT on sequence public.lineups_id_seq to service_role;
grant UPDATE on sequence public.lineups_id_seq to service_role;
grant USAGE on sequence public.lineups_id_seq to service_role;
grant SELECT on table public.matches to anon;
grant SELECT on table public.matches to authenticated;
grant DELETE on table public.matches to postgres;
grant INSERT on table public.matches to postgres;
grant MAINTAIN on table public.matches to postgres;
grant REFERENCES on table public.matches to postgres;
grant SELECT on table public.matches to postgres;
grant TRIGGER on table public.matches to postgres;
grant TRUNCATE on table public.matches to postgres;
grant UPDATE on table public.matches to postgres;
grant DELETE on table public.matches to service_role;
grant INSERT on table public.matches to service_role;
grant MAINTAIN on table public.matches to service_role;
grant REFERENCES on table public.matches to service_role;
grant SELECT on table public.matches to service_role;
grant TRIGGER on table public.matches to service_role;
grant TRUNCATE on table public.matches to service_role;
grant UPDATE on table public.matches to service_role;
grant SELECT on table public.matches_cup to anon;
grant SELECT on table public.matches_cup to authenticated;
grant DELETE on table public.matches_cup to postgres;
grant INSERT on table public.matches_cup to postgres;
grant MAINTAIN on table public.matches_cup to postgres;
grant REFERENCES on table public.matches_cup to postgres;
grant SELECT on table public.matches_cup to postgres;
grant TRIGGER on table public.matches_cup to postgres;
grant TRUNCATE on table public.matches_cup to postgres;
grant UPDATE on table public.matches_cup to postgres;
grant DELETE on table public.matches_cup to service_role;
grant INSERT on table public.matches_cup to service_role;
grant MAINTAIN on table public.matches_cup to service_role;
grant REFERENCES on table public.matches_cup to service_role;
grant SELECT on table public.matches_cup to service_role;
grant TRIGGER on table public.matches_cup to service_role;
grant TRUNCATE on table public.matches_cup to service_role;
grant UPDATE on table public.matches_cup to service_role;
grant SELECT on table public.metric_catalog to anon;
grant SELECT on table public.metric_catalog to authenticated;
grant DELETE on table public.metric_catalog to postgres;
grant INSERT on table public.metric_catalog to postgres;
grant MAINTAIN on table public.metric_catalog to postgres;
grant REFERENCES on table public.metric_catalog to postgres;
grant SELECT on table public.metric_catalog to postgres;
grant TRIGGER on table public.metric_catalog to postgres;
grant TRUNCATE on table public.metric_catalog to postgres;
grant UPDATE on table public.metric_catalog to postgres;
grant DELETE on table public.metric_catalog to service_role;
grant INSERT on table public.metric_catalog to service_role;
grant MAINTAIN on table public.metric_catalog to service_role;
grant REFERENCES on table public.metric_catalog to service_role;
grant SELECT on table public.metric_catalog to service_role;
grant TRIGGER on table public.metric_catalog to service_role;
grant TRUNCATE on table public.metric_catalog to service_role;
grant UPDATE on table public.metric_catalog to service_role;
grant SELECT on table public.metric_defs to anon;
grant SELECT on table public.metric_defs to authenticated;
grant DELETE on table public.metric_defs to postgres;
grant INSERT on table public.metric_defs to postgres;
grant MAINTAIN on table public.metric_defs to postgres;
grant REFERENCES on table public.metric_defs to postgres;
grant SELECT on table public.metric_defs to postgres;
grant TRIGGER on table public.metric_defs to postgres;
grant TRUNCATE on table public.metric_defs to postgres;
grant UPDATE on table public.metric_defs to postgres;
grant DELETE on table public.metric_defs to service_role;
grant INSERT on table public.metric_defs to service_role;
grant MAINTAIN on table public.metric_defs to service_role;
grant REFERENCES on table public.metric_defs to service_role;
grant SELECT on table public.metric_defs to service_role;
grant TRIGGER on table public.metric_defs to service_role;
grant TRUNCATE on table public.metric_defs to service_role;
grant UPDATE on table public.metric_defs to service_role;
grant SELECT on table public.metric_synonyms to anon;
grant SELECT on table public.metric_synonyms to authenticated;
grant DELETE on table public.metric_synonyms to postgres;
grant INSERT on table public.metric_synonyms to postgres;
grant MAINTAIN on table public.metric_synonyms to postgres;
grant REFERENCES on table public.metric_synonyms to postgres;
grant SELECT on table public.metric_synonyms to postgres;
grant TRIGGER on table public.metric_synonyms to postgres;
grant TRUNCATE on table public.metric_synonyms to postgres;
grant UPDATE on table public.metric_synonyms to postgres;
grant DELETE on table public.metric_synonyms to service_role;
grant INSERT on table public.metric_synonyms to service_role;
grant MAINTAIN on table public.metric_synonyms to service_role;
grant REFERENCES on table public.metric_synonyms to service_role;
grant SELECT on table public.metric_synonyms to service_role;
grant TRIGGER on table public.metric_synonyms to service_role;
grant TRUNCATE on table public.metric_synonyms to service_role;
grant UPDATE on table public.metric_synonyms to service_role;
grant SELECT on table public.mv_event_phase to anon;
grant SELECT on table public.mv_event_phase to authenticated;
grant DELETE on table public.mv_event_phase to postgres;
grant INSERT on table public.mv_event_phase to postgres;
grant MAINTAIN on table public.mv_event_phase to postgres;
grant REFERENCES on table public.mv_event_phase to postgres;
grant SELECT on table public.mv_event_phase to postgres;
grant TRIGGER on table public.mv_event_phase to postgres;
grant TRUNCATE on table public.mv_event_phase to postgres;
grant UPDATE on table public.mv_event_phase to postgres;
grant DELETE on table public.mv_event_phase to service_role;
grant INSERT on table public.mv_event_phase to service_role;
grant MAINTAIN on table public.mv_event_phase to service_role;
grant REFERENCES on table public.mv_event_phase to service_role;
grant SELECT on table public.mv_event_phase to service_role;
grant TRIGGER on table public.mv_event_phase to service_role;
grant TRUNCATE on table public.mv_event_phase to service_role;
grant UPDATE on table public.mv_event_phase to service_role;
grant SELECT on table public.mv_game_goals to anon;
grant SELECT on table public.mv_game_goals to authenticated;
grant DELETE on table public.mv_game_goals to postgres;
grant INSERT on table public.mv_game_goals to postgres;
grant MAINTAIN on table public.mv_game_goals to postgres;
grant REFERENCES on table public.mv_game_goals to postgres;
grant SELECT on table public.mv_game_goals to postgres;
grant TRIGGER on table public.mv_game_goals to postgres;
grant TRUNCATE on table public.mv_game_goals to postgres;
grant UPDATE on table public.mv_game_goals to postgres;
grant DELETE on table public.mv_game_goals to service_role;
grant INSERT on table public.mv_game_goals to service_role;
grant MAINTAIN on table public.mv_game_goals to service_role;
grant REFERENCES on table public.mv_game_goals to service_role;
grant SELECT on table public.mv_game_goals to service_role;
grant TRIGGER on table public.mv_game_goals to service_role;
grant TRUNCATE on table public.mv_game_goals to service_role;
grant UPDATE on table public.mv_game_goals to service_role;
grant SELECT on table public.mv_gk_match to anon;
grant SELECT on table public.mv_gk_match to authenticated;
grant DELETE on table public.mv_gk_match to postgres;
grant INSERT on table public.mv_gk_match to postgres;
grant MAINTAIN on table public.mv_gk_match to postgres;
grant REFERENCES on table public.mv_gk_match to postgres;
grant SELECT on table public.mv_gk_match to postgres;
grant TRIGGER on table public.mv_gk_match to postgres;
grant TRUNCATE on table public.mv_gk_match to postgres;
grant UPDATE on table public.mv_gk_match to postgres;
grant DELETE on table public.mv_gk_match to service_role;
grant INSERT on table public.mv_gk_match to service_role;
grant MAINTAIN on table public.mv_gk_match to service_role;
grant REFERENCES on table public.mv_gk_match to service_role;
grant SELECT on table public.mv_gk_match to service_role;
grant TRIGGER on table public.mv_gk_match to service_role;
grant TRUNCATE on table public.mv_gk_match to service_role;
grant UPDATE on table public.mv_gk_match to service_role;
grant SELECT on table public.mv_invariant_status to anon;
grant SELECT on table public.mv_invariant_status to authenticated;
grant DELETE on table public.mv_invariant_status to postgres;
grant INSERT on table public.mv_invariant_status to postgres;
grant MAINTAIN on table public.mv_invariant_status to postgres;
grant REFERENCES on table public.mv_invariant_status to postgres;
grant SELECT on table public.mv_invariant_status to postgres;
grant TRIGGER on table public.mv_invariant_status to postgres;
grant TRUNCATE on table public.mv_invariant_status to postgres;
grant UPDATE on table public.mv_invariant_status to postgres;
grant DELETE on table public.mv_invariant_status to service_role;
grant INSERT on table public.mv_invariant_status to service_role;
grant MAINTAIN on table public.mv_invariant_status to service_role;
grant REFERENCES on table public.mv_invariant_status to service_role;
grant SELECT on table public.mv_invariant_status to service_role;
grant TRIGGER on table public.mv_invariant_status to service_role;
grant TRUNCATE on table public.mv_invariant_status to service_role;
grant UPDATE on table public.mv_invariant_status to service_role;
grant SELECT on table public.mv_league_availability to anon;
grant SELECT on table public.mv_league_availability to authenticated;
grant DELETE on table public.mv_league_availability to postgres;
grant INSERT on table public.mv_league_availability to postgres;
grant MAINTAIN on table public.mv_league_availability to postgres;
grant REFERENCES on table public.mv_league_availability to postgres;
grant SELECT on table public.mv_league_availability to postgres;
grant TRIGGER on table public.mv_league_availability to postgres;
grant TRUNCATE on table public.mv_league_availability to postgres;
grant UPDATE on table public.mv_league_availability to postgres;
grant DELETE on table public.mv_league_availability to service_role;
grant INSERT on table public.mv_league_availability to service_role;
grant MAINTAIN on table public.mv_league_availability to service_role;
grant REFERENCES on table public.mv_league_availability to service_role;
grant SELECT on table public.mv_league_availability to service_role;
grant TRIGGER on table public.mv_league_availability to service_role;
grant TRUNCATE on table public.mv_league_availability to service_role;
grant UPDATE on table public.mv_league_availability to service_role;
grant SELECT on table public.mv_league_summary to anon;
grant SELECT on table public.mv_league_summary to authenticated;
grant DELETE on table public.mv_league_summary to postgres;
grant INSERT on table public.mv_league_summary to postgres;
grant MAINTAIN on table public.mv_league_summary to postgres;
grant REFERENCES on table public.mv_league_summary to postgres;
grant SELECT on table public.mv_league_summary to postgres;
grant TRIGGER on table public.mv_league_summary to postgres;
grant TRUNCATE on table public.mv_league_summary to postgres;
grant UPDATE on table public.mv_league_summary to postgres;
grant DELETE on table public.mv_league_summary to service_role;
grant INSERT on table public.mv_league_summary to service_role;
grant MAINTAIN on table public.mv_league_summary to service_role;
grant REFERENCES on table public.mv_league_summary to service_role;
grant SELECT on table public.mv_league_summary to service_role;
grant TRIGGER on table public.mv_league_summary to service_role;
grant TRUNCATE on table public.mv_league_summary to service_role;
grant UPDATE on table public.mv_league_summary to service_role;
grant SELECT on table public.mv_match_length to anon;
grant SELECT on table public.mv_match_length to authenticated;
grant DELETE on table public.mv_match_length to postgres;
grant INSERT on table public.mv_match_length to postgres;
grant MAINTAIN on table public.mv_match_length to postgres;
grant REFERENCES on table public.mv_match_length to postgres;
grant SELECT on table public.mv_match_length to postgres;
grant TRIGGER on table public.mv_match_length to postgres;
grant TRUNCATE on table public.mv_match_length to postgres;
grant UPDATE on table public.mv_match_length to postgres;
grant DELETE on table public.mv_match_length to service_role;
grant INSERT on table public.mv_match_length to service_role;
grant MAINTAIN on table public.mv_match_length to service_role;
grant REFERENCES on table public.mv_match_length to service_role;
grant SELECT on table public.mv_match_length to service_role;
grant TRIGGER on table public.mv_match_length to service_role;
grant TRUNCATE on table public.mv_match_length to service_role;
grant UPDATE on table public.mv_match_length to service_role;
grant SELECT on table public.mv_metric_examples to anon;
grant SELECT on table public.mv_metric_examples to authenticated;
grant DELETE on table public.mv_metric_examples to postgres;
grant INSERT on table public.mv_metric_examples to postgres;
grant MAINTAIN on table public.mv_metric_examples to postgres;
grant REFERENCES on table public.mv_metric_examples to postgres;
grant SELECT on table public.mv_metric_examples to postgres;
grant TRIGGER on table public.mv_metric_examples to postgres;
grant TRUNCATE on table public.mv_metric_examples to postgres;
grant UPDATE on table public.mv_metric_examples to postgres;
grant DELETE on table public.mv_metric_examples to service_role;
grant INSERT on table public.mv_metric_examples to service_role;
grant MAINTAIN on table public.mv_metric_examples to service_role;
grant REFERENCES on table public.mv_metric_examples to service_role;
grant SELECT on table public.mv_metric_examples to service_role;
grant TRIGGER on table public.mv_metric_examples to service_role;
grant TRUNCATE on table public.mv_metric_examples to service_role;
grant UPDATE on table public.mv_metric_examples to service_role;
grant SELECT on table public.mv_pass_traj to anon;
grant SELECT on table public.mv_pass_traj to authenticated;
grant DELETE on table public.mv_pass_traj to postgres;
grant INSERT on table public.mv_pass_traj to postgres;
grant MAINTAIN on table public.mv_pass_traj to postgres;
grant REFERENCES on table public.mv_pass_traj to postgres;
grant SELECT on table public.mv_pass_traj to postgres;
grant TRIGGER on table public.mv_pass_traj to postgres;
grant TRUNCATE on table public.mv_pass_traj to postgres;
grant UPDATE on table public.mv_pass_traj to postgres;
grant DELETE on table public.mv_pass_traj to service_role;
grant INSERT on table public.mv_pass_traj to service_role;
grant MAINTAIN on table public.mv_pass_traj to service_role;
grant REFERENCES on table public.mv_pass_traj to service_role;
grant SELECT on table public.mv_pass_traj to service_role;
grant TRIGGER on table public.mv_pass_traj to service_role;
grant TRUNCATE on table public.mv_pass_traj to service_role;
grant UPDATE on table public.mv_pass_traj to service_role;
grant SELECT on table public.mv_player_archetype to anon;
grant SELECT on table public.mv_player_archetype to authenticated;
grant DELETE on table public.mv_player_archetype to postgres;
grant INSERT on table public.mv_player_archetype to postgres;
grant MAINTAIN on table public.mv_player_archetype to postgres;
grant REFERENCES on table public.mv_player_archetype to postgres;
grant SELECT on table public.mv_player_archetype to postgres;
grant TRIGGER on table public.mv_player_archetype to postgres;
grant TRUNCATE on table public.mv_player_archetype to postgres;
grant UPDATE on table public.mv_player_archetype to postgres;
grant DELETE on table public.mv_player_archetype to service_role;
grant INSERT on table public.mv_player_archetype to service_role;
grant MAINTAIN on table public.mv_player_archetype to service_role;
grant REFERENCES on table public.mv_player_archetype to service_role;
grant SELECT on table public.mv_player_archetype to service_role;
grant TRIGGER on table public.mv_player_archetype to service_role;
grant TRUNCATE on table public.mv_player_archetype to service_role;
grant UPDATE on table public.mv_player_archetype to service_role;
grant SELECT on table public.mv_player_carry to anon;
grant SELECT on table public.mv_player_carry to authenticated;
grant DELETE on table public.mv_player_carry to postgres;
grant INSERT on table public.mv_player_carry to postgres;
grant MAINTAIN on table public.mv_player_carry to postgres;
grant REFERENCES on table public.mv_player_carry to postgres;
grant SELECT on table public.mv_player_carry to postgres;
grant TRIGGER on table public.mv_player_carry to postgres;
grant TRUNCATE on table public.mv_player_carry to postgres;
grant UPDATE on table public.mv_player_carry to postgres;
grant DELETE on table public.mv_player_carry to service_role;
grant INSERT on table public.mv_player_carry to service_role;
grant MAINTAIN on table public.mv_player_carry to service_role;
grant REFERENCES on table public.mv_player_carry to service_role;
grant SELECT on table public.mv_player_carry to service_role;
grant TRIGGER on table public.mv_player_carry to service_role;
grant TRUNCATE on table public.mv_player_carry to service_role;
grant UPDATE on table public.mv_player_carry to service_role;
grant SELECT on table public.mv_player_chain_value to anon;
grant SELECT on table public.mv_player_chain_value to authenticated;
grant DELETE on table public.mv_player_chain_value to postgres;
grant INSERT on table public.mv_player_chain_value to postgres;
grant MAINTAIN on table public.mv_player_chain_value to postgres;
grant REFERENCES on table public.mv_player_chain_value to postgres;
grant SELECT on table public.mv_player_chain_value to postgres;
grant TRIGGER on table public.mv_player_chain_value to postgres;
grant TRUNCATE on table public.mv_player_chain_value to postgres;
grant UPDATE on table public.mv_player_chain_value to postgres;
grant DELETE on table public.mv_player_chain_value to service_role;
grant INSERT on table public.mv_player_chain_value to service_role;
grant MAINTAIN on table public.mv_player_chain_value to service_role;
grant REFERENCES on table public.mv_player_chain_value to service_role;
grant SELECT on table public.mv_player_chain_value to service_role;
grant TRIGGER on table public.mv_player_chain_value to service_role;
grant TRUNCATE on table public.mv_player_chain_value to service_role;
grant UPDATE on table public.mv_player_chain_value to service_role;
grant SELECT on table public.mv_player_chains to anon;
grant SELECT on table public.mv_player_chains to authenticated;
grant DELETE on table public.mv_player_chains to postgres;
grant INSERT on table public.mv_player_chains to postgres;
grant MAINTAIN on table public.mv_player_chains to postgres;
grant REFERENCES on table public.mv_player_chains to postgres;
grant SELECT on table public.mv_player_chains to postgres;
grant TRIGGER on table public.mv_player_chains to postgres;
grant TRUNCATE on table public.mv_player_chains to postgres;
grant UPDATE on table public.mv_player_chains to postgres;
grant DELETE on table public.mv_player_chains to service_role;
grant INSERT on table public.mv_player_chains to service_role;
grant MAINTAIN on table public.mv_player_chains to service_role;
grant REFERENCES on table public.mv_player_chains to service_role;
grant SELECT on table public.mv_player_chains to service_role;
grant TRIGGER on table public.mv_player_chains to service_role;
grant TRUNCATE on table public.mv_player_chains to service_role;
grant UPDATE on table public.mv_player_chains to service_role;
grant SELECT on table public.mv_player_counterpress to anon;
grant SELECT on table public.mv_player_counterpress to authenticated;
grant DELETE on table public.mv_player_counterpress to postgres;
grant INSERT on table public.mv_player_counterpress to postgres;
grant MAINTAIN on table public.mv_player_counterpress to postgres;
grant REFERENCES on table public.mv_player_counterpress to postgres;
grant SELECT on table public.mv_player_counterpress to postgres;
grant TRIGGER on table public.mv_player_counterpress to postgres;
grant TRUNCATE on table public.mv_player_counterpress to postgres;
grant UPDATE on table public.mv_player_counterpress to postgres;
grant DELETE on table public.mv_player_counterpress to service_role;
grant INSERT on table public.mv_player_counterpress to service_role;
grant MAINTAIN on table public.mv_player_counterpress to service_role;
grant REFERENCES on table public.mv_player_counterpress to service_role;
grant SELECT on table public.mv_player_counterpress to service_role;
grant TRIGGER on table public.mv_player_counterpress to service_role;
grant TRUNCATE on table public.mv_player_counterpress to service_role;
grant UPDATE on table public.mv_player_counterpress to service_role;
grant SELECT on table public.mv_player_defload to anon;
grant SELECT on table public.mv_player_defload to authenticated;
grant DELETE on table public.mv_player_defload to postgres;
grant INSERT on table public.mv_player_defload to postgres;
grant MAINTAIN on table public.mv_player_defload to postgres;
grant REFERENCES on table public.mv_player_defload to postgres;
grant SELECT on table public.mv_player_defload to postgres;
grant TRIGGER on table public.mv_player_defload to postgres;
grant TRUNCATE on table public.mv_player_defload to postgres;
grant UPDATE on table public.mv_player_defload to postgres;
grant DELETE on table public.mv_player_defload to service_role;
grant INSERT on table public.mv_player_defload to service_role;
grant MAINTAIN on table public.mv_player_defload to service_role;
grant REFERENCES on table public.mv_player_defload to service_role;
grant SELECT on table public.mv_player_defload to service_role;
grant TRIGGER on table public.mv_player_defload to service_role;
grant TRUNCATE on table public.mv_player_defload to service_role;
grant UPDATE on table public.mv_player_defload to service_role;
grant SELECT on table public.mv_player_dna to anon;
grant SELECT on table public.mv_player_dna to authenticated;
grant DELETE on table public.mv_player_dna to postgres;
grant INSERT on table public.mv_player_dna to postgres;
grant MAINTAIN on table public.mv_player_dna to postgres;
grant REFERENCES on table public.mv_player_dna to postgres;
grant SELECT on table public.mv_player_dna to postgres;
grant TRIGGER on table public.mv_player_dna to postgres;
grant TRUNCATE on table public.mv_player_dna to postgres;
grant UPDATE on table public.mv_player_dna to postgres;
grant DELETE on table public.mv_player_dna to service_role;
grant INSERT on table public.mv_player_dna to service_role;
grant MAINTAIN on table public.mv_player_dna to service_role;
grant REFERENCES on table public.mv_player_dna to service_role;
grant SELECT on table public.mv_player_dna to service_role;
grant TRIGGER on table public.mv_player_dna to service_role;
grant TRUNCATE on table public.mv_player_dna to service_role;
grant UPDATE on table public.mv_player_dna to service_role;
grant SELECT on table public.mv_player_foot to anon;
grant SELECT on table public.mv_player_foot to authenticated;
grant DELETE on table public.mv_player_foot to postgres;
grant INSERT on table public.mv_player_foot to postgres;
grant MAINTAIN on table public.mv_player_foot to postgres;
grant REFERENCES on table public.mv_player_foot to postgres;
grant SELECT on table public.mv_player_foot to postgres;
grant TRIGGER on table public.mv_player_foot to postgres;
grant TRUNCATE on table public.mv_player_foot to postgres;
grant UPDATE on table public.mv_player_foot to postgres;
grant DELETE on table public.mv_player_foot to service_role;
grant INSERT on table public.mv_player_foot to service_role;
grant MAINTAIN on table public.mv_player_foot to service_role;
grant REFERENCES on table public.mv_player_foot to service_role;
grant SELECT on table public.mv_player_foot to service_role;
grant TRIGGER on table public.mv_player_foot to service_role;
grant TRUNCATE on table public.mv_player_foot to service_role;
grant UPDATE on table public.mv_player_foot to service_role;
grant SELECT on table public.mv_player_gk to anon;
grant SELECT on table public.mv_player_gk to authenticated;
grant DELETE on table public.mv_player_gk to postgres;
grant INSERT on table public.mv_player_gk to postgres;
grant MAINTAIN on table public.mv_player_gk to postgres;
grant REFERENCES on table public.mv_player_gk to postgres;
grant SELECT on table public.mv_player_gk to postgres;
grant TRIGGER on table public.mv_player_gk to postgres;
grant TRUNCATE on table public.mv_player_gk to postgres;
grant UPDATE on table public.mv_player_gk to postgres;
grant DELETE on table public.mv_player_gk to service_role;
grant INSERT on table public.mv_player_gk to service_role;
grant MAINTAIN on table public.mv_player_gk to service_role;
grant REFERENCES on table public.mv_player_gk to service_role;
grant SELECT on table public.mv_player_gk to service_role;
grant TRIGGER on table public.mv_player_gk to service_role;
grant TRUNCATE on table public.mv_player_gk to service_role;
grant UPDATE on table public.mv_player_gk to service_role;
grant SELECT on table public.mv_player_holdup to anon;
grant SELECT on table public.mv_player_holdup to authenticated;
grant DELETE on table public.mv_player_holdup to postgres;
grant INSERT on table public.mv_player_holdup to postgres;
grant MAINTAIN on table public.mv_player_holdup to postgres;
grant REFERENCES on table public.mv_player_holdup to postgres;
grant SELECT on table public.mv_player_holdup to postgres;
grant TRIGGER on table public.mv_player_holdup to postgres;
grant TRUNCATE on table public.mv_player_holdup to postgres;
grant UPDATE on table public.mv_player_holdup to postgres;
grant DELETE on table public.mv_player_holdup to service_role;
grant INSERT on table public.mv_player_holdup to service_role;
grant MAINTAIN on table public.mv_player_holdup to service_role;
grant REFERENCES on table public.mv_player_holdup to service_role;
grant SELECT on table public.mv_player_holdup to service_role;
grant TRIGGER on table public.mv_player_holdup to service_role;
grant TRUNCATE on table public.mv_player_holdup to service_role;
grant UPDATE on table public.mv_player_holdup to service_role;
grant SELECT on table public.mv_player_league to anon;
grant SELECT on table public.mv_player_league to authenticated;
grant DELETE on table public.mv_player_league to postgres;
grant INSERT on table public.mv_player_league to postgres;
grant MAINTAIN on table public.mv_player_league to postgres;
grant REFERENCES on table public.mv_player_league to postgres;
grant SELECT on table public.mv_player_league to postgres;
grant TRIGGER on table public.mv_player_league to postgres;
grant TRUNCATE on table public.mv_player_league to postgres;
grant UPDATE on table public.mv_player_league to postgres;
grant DELETE on table public.mv_player_league to service_role;
grant INSERT on table public.mv_player_league to service_role;
grant MAINTAIN on table public.mv_player_league to service_role;
grant REFERENCES on table public.mv_player_league to service_role;
grant SELECT on table public.mv_player_league to service_role;
grant TRIGGER on table public.mv_player_league to service_role;
grant TRUNCATE on table public.mv_player_league to service_role;
grant UPDATE on table public.mv_player_league to service_role;
grant SELECT on table public.mv_player_leverage to anon;
grant SELECT on table public.mv_player_leverage to authenticated;
grant DELETE on table public.mv_player_leverage to postgres;
grant INSERT on table public.mv_player_leverage to postgres;
grant MAINTAIN on table public.mv_player_leverage to postgres;
grant REFERENCES on table public.mv_player_leverage to postgres;
grant SELECT on table public.mv_player_leverage to postgres;
grant TRIGGER on table public.mv_player_leverage to postgres;
grant TRUNCATE on table public.mv_player_leverage to postgres;
grant UPDATE on table public.mv_player_leverage to postgres;
grant DELETE on table public.mv_player_leverage to service_role;
grant INSERT on table public.mv_player_leverage to service_role;
grant MAINTAIN on table public.mv_player_leverage to service_role;
grant REFERENCES on table public.mv_player_leverage to service_role;
grant SELECT on table public.mv_player_leverage to service_role;
grant TRIGGER on table public.mv_player_leverage to service_role;
grant TRUNCATE on table public.mv_player_leverage to service_role;
grant UPDATE on table public.mv_player_leverage to service_role;
grant SELECT on table public.mv_player_metrics to anon;
grant SELECT on table public.mv_player_metrics to authenticated;
grant DELETE on table public.mv_player_metrics to postgres;
grant INSERT on table public.mv_player_metrics to postgres;
grant MAINTAIN on table public.mv_player_metrics to postgres;
grant REFERENCES on table public.mv_player_metrics to postgres;
grant SELECT on table public.mv_player_metrics to postgres;
grant TRIGGER on table public.mv_player_metrics to postgres;
grant TRUNCATE on table public.mv_player_metrics to postgres;
grant UPDATE on table public.mv_player_metrics to postgres;
grant DELETE on table public.mv_player_metrics to service_role;
grant INSERT on table public.mv_player_metrics to service_role;
grant MAINTAIN on table public.mv_player_metrics to service_role;
grant REFERENCES on table public.mv_player_metrics to service_role;
grant SELECT on table public.mv_player_metrics to service_role;
grant TRIGGER on table public.mv_player_metrics to service_role;
grant TRUNCATE on table public.mv_player_metrics to service_role;
grant UPDATE on table public.mv_player_metrics to service_role;
grant SELECT on table public.mv_player_metrics_raw to anon;
grant SELECT on table public.mv_player_metrics_raw to authenticated;
grant DELETE on table public.mv_player_metrics_raw to postgres;
grant INSERT on table public.mv_player_metrics_raw to postgres;
grant MAINTAIN on table public.mv_player_metrics_raw to postgres;
grant REFERENCES on table public.mv_player_metrics_raw to postgres;
grant SELECT on table public.mv_player_metrics_raw to postgres;
grant TRIGGER on table public.mv_player_metrics_raw to postgres;
grant TRUNCATE on table public.mv_player_metrics_raw to postgres;
grant UPDATE on table public.mv_player_metrics_raw to postgres;
grant DELETE on table public.mv_player_metrics_raw to service_role;
grant INSERT on table public.mv_player_metrics_raw to service_role;
grant MAINTAIN on table public.mv_player_metrics_raw to service_role;
grant REFERENCES on table public.mv_player_metrics_raw to service_role;
grant SELECT on table public.mv_player_metrics_raw to service_role;
grant TRIGGER on table public.mv_player_metrics_raw to service_role;
grant TRUNCATE on table public.mv_player_metrics_raw to service_role;
grant UPDATE on table public.mv_player_metrics_raw to service_role;
grant SELECT on table public.mv_player_minutes to anon;
grant SELECT on table public.mv_player_minutes to authenticated;
grant DELETE on table public.mv_player_minutes to postgres;
grant INSERT on table public.mv_player_minutes to postgres;
grant MAINTAIN on table public.mv_player_minutes to postgres;
grant REFERENCES on table public.mv_player_minutes to postgres;
grant SELECT on table public.mv_player_minutes to postgres;
grant TRIGGER on table public.mv_player_minutes to postgres;
grant TRUNCATE on table public.mv_player_minutes to postgres;
grant UPDATE on table public.mv_player_minutes to postgres;
grant DELETE on table public.mv_player_minutes to service_role;
grant INSERT on table public.mv_player_minutes to service_role;
grant MAINTAIN on table public.mv_player_minutes to service_role;
grant REFERENCES on table public.mv_player_minutes to service_role;
grant SELECT on table public.mv_player_minutes to service_role;
grant TRIGGER on table public.mv_player_minutes to service_role;
grant TRUNCATE on table public.mv_player_minutes to service_role;
grant UPDATE on table public.mv_player_minutes to service_role;
grant SELECT on table public.mv_player_pass_traj to anon;
grant SELECT on table public.mv_player_pass_traj to authenticated;
grant DELETE on table public.mv_player_pass_traj to postgres;
grant INSERT on table public.mv_player_pass_traj to postgres;
grant MAINTAIN on table public.mv_player_pass_traj to postgres;
grant REFERENCES on table public.mv_player_pass_traj to postgres;
grant SELECT on table public.mv_player_pass_traj to postgres;
grant TRIGGER on table public.mv_player_pass_traj to postgres;
grant TRUNCATE on table public.mv_player_pass_traj to postgres;
grant UPDATE on table public.mv_player_pass_traj to postgres;
grant DELETE on table public.mv_player_pass_traj to service_role;
grant INSERT on table public.mv_player_pass_traj to service_role;
grant MAINTAIN on table public.mv_player_pass_traj to service_role;
grant REFERENCES on table public.mv_player_pass_traj to service_role;
grant SELECT on table public.mv_player_pass_traj to service_role;
grant TRIGGER on table public.mv_player_pass_traj to service_role;
grant TRUNCATE on table public.mv_player_pass_traj to service_role;
grant UPDATE on table public.mv_player_pass_traj to service_role;
grant SELECT on table public.mv_player_pct to anon;
grant SELECT on table public.mv_player_pct to authenticated;
grant DELETE on table public.mv_player_pct to postgres;
grant INSERT on table public.mv_player_pct to postgres;
grant MAINTAIN on table public.mv_player_pct to postgres;
grant REFERENCES on table public.mv_player_pct to postgres;
grant SELECT on table public.mv_player_pct to postgres;
grant TRIGGER on table public.mv_player_pct to postgres;
grant TRUNCATE on table public.mv_player_pct to postgres;
grant UPDATE on table public.mv_player_pct to postgres;
grant DELETE on table public.mv_player_pct to service_role;
grant INSERT on table public.mv_player_pct to service_role;
grant MAINTAIN on table public.mv_player_pct to service_role;
grant REFERENCES on table public.mv_player_pct to service_role;
grant SELECT on table public.mv_player_pct to service_role;
grant TRIGGER on table public.mv_player_pct to service_role;
grant TRUNCATE on table public.mv_player_pct to service_role;
grant UPDATE on table public.mv_player_pct to service_role;
grant SELECT on table public.mv_player_percentiles to anon;
grant SELECT on table public.mv_player_percentiles to authenticated;
grant DELETE on table public.mv_player_percentiles to postgres;
grant INSERT on table public.mv_player_percentiles to postgres;
grant MAINTAIN on table public.mv_player_percentiles to postgres;
grant REFERENCES on table public.mv_player_percentiles to postgres;
grant SELECT on table public.mv_player_percentiles to postgres;
grant TRIGGER on table public.mv_player_percentiles to postgres;
grant TRUNCATE on table public.mv_player_percentiles to postgres;
grant UPDATE on table public.mv_player_percentiles to postgres;
grant DELETE on table public.mv_player_percentiles to service_role;
grant INSERT on table public.mv_player_percentiles to service_role;
grant MAINTAIN on table public.mv_player_percentiles to service_role;
grant REFERENCES on table public.mv_player_percentiles to service_role;
grant SELECT on table public.mv_player_percentiles to service_role;
grant TRIGGER on table public.mv_player_percentiles to service_role;
grant TRUNCATE on table public.mv_player_percentiles to service_role;
grant UPDATE on table public.mv_player_percentiles to service_role;
grant SELECT on table public.mv_player_pillars to anon;
grant SELECT on table public.mv_player_pillars to authenticated;
grant DELETE on table public.mv_player_pillars to postgres;
grant INSERT on table public.mv_player_pillars to postgres;
grant MAINTAIN on table public.mv_player_pillars to postgres;
grant REFERENCES on table public.mv_player_pillars to postgres;
grant SELECT on table public.mv_player_pillars to postgres;
grant TRIGGER on table public.mv_player_pillars to postgres;
grant TRUNCATE on table public.mv_player_pillars to postgres;
grant UPDATE on table public.mv_player_pillars to postgres;
grant DELETE on table public.mv_player_pillars to service_role;
grant INSERT on table public.mv_player_pillars to service_role;
grant MAINTAIN on table public.mv_player_pillars to service_role;
grant REFERENCES on table public.mv_player_pillars to service_role;
grant SELECT on table public.mv_player_pillars to service_role;
grant TRIGGER on table public.mv_player_pillars to service_role;
grant TRUNCATE on table public.mv_player_pillars to service_role;
grant UPDATE on table public.mv_player_pillars to service_role;
grant SELECT on table public.mv_player_pool to anon;
grant SELECT on table public.mv_player_pool to authenticated;
grant DELETE on table public.mv_player_pool to postgres;
grant INSERT on table public.mv_player_pool to postgres;
grant MAINTAIN on table public.mv_player_pool to postgres;
grant REFERENCES on table public.mv_player_pool to postgres;
grant SELECT on table public.mv_player_pool to postgres;
grant TRIGGER on table public.mv_player_pool to postgres;
grant TRUNCATE on table public.mv_player_pool to postgres;
grant UPDATE on table public.mv_player_pool to postgres;
grant DELETE on table public.mv_player_pool to service_role;
grant INSERT on table public.mv_player_pool to service_role;
grant MAINTAIN on table public.mv_player_pool to service_role;
grant REFERENCES on table public.mv_player_pool to service_role;
grant SELECT on table public.mv_player_pool to service_role;
grant TRIGGER on table public.mv_player_pool to service_role;
grant TRUNCATE on table public.mv_player_pool to service_role;
grant UPDATE on table public.mv_player_pool to service_role;
grant SELECT on table public.mv_player_progression to anon;
grant SELECT on table public.mv_player_progression to authenticated;
grant DELETE on table public.mv_player_progression to postgres;
grant INSERT on table public.mv_player_progression to postgres;
grant MAINTAIN on table public.mv_player_progression to postgres;
grant REFERENCES on table public.mv_player_progression to postgres;
grant SELECT on table public.mv_player_progression to postgres;
grant TRIGGER on table public.mv_player_progression to postgres;
grant TRUNCATE on table public.mv_player_progression to postgres;
grant UPDATE on table public.mv_player_progression to postgres;
grant DELETE on table public.mv_player_progression to service_role;
grant INSERT on table public.mv_player_progression to service_role;
grant MAINTAIN on table public.mv_player_progression to service_role;
grant REFERENCES on table public.mv_player_progression to service_role;
grant SELECT on table public.mv_player_progression to service_role;
grant TRIGGER on table public.mv_player_progression to service_role;
grant TRUNCATE on table public.mv_player_progression to service_role;
grant UPDATE on table public.mv_player_progression to service_role;
grant SELECT on table public.mv_player_role to anon;
grant SELECT on table public.mv_player_role to authenticated;
grant DELETE on table public.mv_player_role to postgres;
grant INSERT on table public.mv_player_role to postgres;
grant MAINTAIN on table public.mv_player_role to postgres;
grant REFERENCES on table public.mv_player_role to postgres;
grant SELECT on table public.mv_player_role to postgres;
grant TRIGGER on table public.mv_player_role to postgres;
grant TRUNCATE on table public.mv_player_role to postgres;
grant UPDATE on table public.mv_player_role to postgres;
grant DELETE on table public.mv_player_role to service_role;
grant INSERT on table public.mv_player_role to service_role;
grant MAINTAIN on table public.mv_player_role to service_role;
grant REFERENCES on table public.mv_player_role to service_role;
grant SELECT on table public.mv_player_role to service_role;
grant TRIGGER on table public.mv_player_role to service_role;
grant TRUNCATE on table public.mv_player_role to service_role;
grant UPDATE on table public.mv_player_role to service_role;
grant SELECT on table public.mv_player_sca to anon;
grant SELECT on table public.mv_player_sca to authenticated;
grant DELETE on table public.mv_player_sca to postgres;
grant INSERT on table public.mv_player_sca to postgres;
grant MAINTAIN on table public.mv_player_sca to postgres;
grant REFERENCES on table public.mv_player_sca to postgres;
grant SELECT on table public.mv_player_sca to postgres;
grant TRIGGER on table public.mv_player_sca to postgres;
grant TRUNCATE on table public.mv_player_sca to postgres;
grant UPDATE on table public.mv_player_sca to postgres;
grant DELETE on table public.mv_player_sca to service_role;
grant INSERT on table public.mv_player_sca to service_role;
grant MAINTAIN on table public.mv_player_sca to service_role;
grant REFERENCES on table public.mv_player_sca to service_role;
grant SELECT on table public.mv_player_sca to service_role;
grant TRIGGER on table public.mv_player_sca to service_role;
grant TRUNCATE on table public.mv_player_sca to service_role;
grant UPDATE on table public.mv_player_sca to service_role;
grant SELECT on table public.mv_player_season to anon;
grant SELECT on table public.mv_player_season to authenticated;
grant DELETE on table public.mv_player_season to postgres;
grant INSERT on table public.mv_player_season to postgres;
grant MAINTAIN on table public.mv_player_season to postgres;
grant REFERENCES on table public.mv_player_season to postgres;
grant SELECT on table public.mv_player_season to postgres;
grant TRIGGER on table public.mv_player_season to postgres;
grant TRUNCATE on table public.mv_player_season to postgres;
grant UPDATE on table public.mv_player_season to postgres;
grant DELETE on table public.mv_player_season to service_role;
grant INSERT on table public.mv_player_season to service_role;
grant MAINTAIN on table public.mv_player_season to service_role;
grant REFERENCES on table public.mv_player_season to service_role;
grant SELECT on table public.mv_player_season to service_role;
grant TRIGGER on table public.mv_player_season to service_role;
grant TRUNCATE on table public.mv_player_season to service_role;
grant UPDATE on table public.mv_player_season to service_role;
grant SELECT on table public.mv_player_setpiece to anon;
grant SELECT on table public.mv_player_setpiece to authenticated;
grant DELETE on table public.mv_player_setpiece to postgres;
grant INSERT on table public.mv_player_setpiece to postgres;
grant MAINTAIN on table public.mv_player_setpiece to postgres;
grant REFERENCES on table public.mv_player_setpiece to postgres;
grant SELECT on table public.mv_player_setpiece to postgres;
grant TRIGGER on table public.mv_player_setpiece to postgres;
grant TRUNCATE on table public.mv_player_setpiece to postgres;
grant UPDATE on table public.mv_player_setpiece to postgres;
grant DELETE on table public.mv_player_setpiece to service_role;
grant INSERT on table public.mv_player_setpiece to service_role;
grant MAINTAIN on table public.mv_player_setpiece to service_role;
grant REFERENCES on table public.mv_player_setpiece to service_role;
grant SELECT on table public.mv_player_setpiece to service_role;
grant TRIGGER on table public.mv_player_setpiece to service_role;
grant TRUNCATE on table public.mv_player_setpiece to service_role;
grant UPDATE on table public.mv_player_setpiece to service_role;
grant SELECT on table public.mv_player_state_output to anon;
grant SELECT on table public.mv_player_state_output to authenticated;
grant DELETE on table public.mv_player_state_output to postgres;
grant INSERT on table public.mv_player_state_output to postgres;
grant MAINTAIN on table public.mv_player_state_output to postgres;
grant REFERENCES on table public.mv_player_state_output to postgres;
grant SELECT on table public.mv_player_state_output to postgres;
grant TRIGGER on table public.mv_player_state_output to postgres;
grant TRUNCATE on table public.mv_player_state_output to postgres;
grant UPDATE on table public.mv_player_state_output to postgres;
grant DELETE on table public.mv_player_state_output to service_role;
grant INSERT on table public.mv_player_state_output to service_role;
grant MAINTAIN on table public.mv_player_state_output to service_role;
grant REFERENCES on table public.mv_player_state_output to service_role;
grant SELECT on table public.mv_player_state_output to service_role;
grant TRIGGER on table public.mv_player_state_output to service_role;
grant TRUNCATE on table public.mv_player_state_output to service_role;
grant UPDATE on table public.mv_player_state_output to service_role;
grant SELECT on table public.mv_player_stints to anon;
grant SELECT on table public.mv_player_stints to authenticated;
grant DELETE on table public.mv_player_stints to postgres;
grant INSERT on table public.mv_player_stints to postgres;
grant MAINTAIN on table public.mv_player_stints to postgres;
grant REFERENCES on table public.mv_player_stints to postgres;
grant SELECT on table public.mv_player_stints to postgres;
grant TRIGGER on table public.mv_player_stints to postgres;
grant TRUNCATE on table public.mv_player_stints to postgres;
grant UPDATE on table public.mv_player_stints to postgres;
grant DELETE on table public.mv_player_stints to service_role;
grant INSERT on table public.mv_player_stints to service_role;
grant MAINTAIN on table public.mv_player_stints to service_role;
grant REFERENCES on table public.mv_player_stints to service_role;
grant SELECT on table public.mv_player_stints to service_role;
grant TRIGGER on table public.mv_player_stints to service_role;
grant TRUNCATE on table public.mv_player_stints to service_role;
grant UPDATE on table public.mv_player_stints to service_role;
grant SELECT on table public.mv_player_team_poss to anon;
grant SELECT on table public.mv_player_team_poss to authenticated;
grant DELETE on table public.mv_player_team_poss to postgres;
grant INSERT on table public.mv_player_team_poss to postgres;
grant MAINTAIN on table public.mv_player_team_poss to postgres;
grant REFERENCES on table public.mv_player_team_poss to postgres;
grant SELECT on table public.mv_player_team_poss to postgres;
grant TRIGGER on table public.mv_player_team_poss to postgres;
grant TRUNCATE on table public.mv_player_team_poss to postgres;
grant UPDATE on table public.mv_player_team_poss to postgres;
grant DELETE on table public.mv_player_team_poss to service_role;
grant INSERT on table public.mv_player_team_poss to service_role;
grant MAINTAIN on table public.mv_player_team_poss to service_role;
grant REFERENCES on table public.mv_player_team_poss to service_role;
grant SELECT on table public.mv_player_team_poss to service_role;
grant TRIGGER on table public.mv_player_team_poss to service_role;
grant TRUNCATE on table public.mv_player_team_poss to service_role;
grant UPDATE on table public.mv_player_team_poss to service_role;
grant SELECT on table public.mv_player_territory to anon;
grant SELECT on table public.mv_player_territory to authenticated;
grant DELETE on table public.mv_player_territory to postgres;
grant INSERT on table public.mv_player_territory to postgres;
grant MAINTAIN on table public.mv_player_territory to postgres;
grant REFERENCES on table public.mv_player_territory to postgres;
grant SELECT on table public.mv_player_territory to postgres;
grant TRIGGER on table public.mv_player_territory to postgres;
grant TRUNCATE on table public.mv_player_territory to postgres;
grant UPDATE on table public.mv_player_territory to postgres;
grant DELETE on table public.mv_player_territory to service_role;
grant INSERT on table public.mv_player_territory to service_role;
grant MAINTAIN on table public.mv_player_territory to service_role;
grant REFERENCES on table public.mv_player_territory to service_role;
grant SELECT on table public.mv_player_territory to service_role;
grant TRIGGER on table public.mv_player_territory to service_role;
grant TRUNCATE on table public.mv_player_territory to service_role;
grant UPDATE on table public.mv_player_territory to service_role;
grant SELECT on table public.mv_player_xa to anon;
grant SELECT on table public.mv_player_xa to authenticated;
grant DELETE on table public.mv_player_xa to postgres;
grant INSERT on table public.mv_player_xa to postgres;
grant MAINTAIN on table public.mv_player_xa to postgres;
grant REFERENCES on table public.mv_player_xa to postgres;
grant SELECT on table public.mv_player_xa to postgres;
grant TRIGGER on table public.mv_player_xa to postgres;
grant TRUNCATE on table public.mv_player_xa to postgres;
grant UPDATE on table public.mv_player_xa to postgres;
grant DELETE on table public.mv_player_xa to service_role;
grant INSERT on table public.mv_player_xa to service_role;
grant MAINTAIN on table public.mv_player_xa to service_role;
grant REFERENCES on table public.mv_player_xa to service_role;
grant SELECT on table public.mv_player_xa to service_role;
grant TRIGGER on table public.mv_player_xa to service_role;
grant TRUNCATE on table public.mv_player_xa to service_role;
grant UPDATE on table public.mv_player_xa to service_role;
grant SELECT on table public.mv_player_xt to anon;
grant SELECT on table public.mv_player_xt to authenticated;
grant DELETE on table public.mv_player_xt to postgres;
grant INSERT on table public.mv_player_xt to postgres;
grant MAINTAIN on table public.mv_player_xt to postgres;
grant REFERENCES on table public.mv_player_xt to postgres;
grant SELECT on table public.mv_player_xt to postgres;
grant TRIGGER on table public.mv_player_xt to postgres;
grant TRUNCATE on table public.mv_player_xt to postgres;
grant UPDATE on table public.mv_player_xt to postgres;
grant DELETE on table public.mv_player_xt to service_role;
grant INSERT on table public.mv_player_xt to service_role;
grant MAINTAIN on table public.mv_player_xt to service_role;
grant REFERENCES on table public.mv_player_xt to service_role;
grant SELECT on table public.mv_player_xt to service_role;
grant TRIGGER on table public.mv_player_xt to service_role;
grant TRUNCATE on table public.mv_player_xt to service_role;
grant UPDATE on table public.mv_player_xt to service_role;
grant SELECT on table public.mv_player_zones to anon;
grant SELECT on table public.mv_player_zones to authenticated;
grant DELETE on table public.mv_player_zones to postgres;
grant INSERT on table public.mv_player_zones to postgres;
grant MAINTAIN on table public.mv_player_zones to postgres;
grant REFERENCES on table public.mv_player_zones to postgres;
grant SELECT on table public.mv_player_zones to postgres;
grant TRIGGER on table public.mv_player_zones to postgres;
grant TRUNCATE on table public.mv_player_zones to postgres;
grant UPDATE on table public.mv_player_zones to postgres;
grant DELETE on table public.mv_player_zones to service_role;
grant INSERT on table public.mv_player_zones to service_role;
grant MAINTAIN on table public.mv_player_zones to service_role;
grant REFERENCES on table public.mv_player_zones to service_role;
grant SELECT on table public.mv_player_zones to service_role;
grant TRIGGER on table public.mv_player_zones to service_role;
grant TRUNCATE on table public.mv_player_zones to service_role;
grant UPDATE on table public.mv_player_zones to service_role;
grant SELECT on table public.mv_press_vs_buildup to anon;
grant SELECT on table public.mv_press_vs_buildup to authenticated;
grant DELETE on table public.mv_press_vs_buildup to postgres;
grant INSERT on table public.mv_press_vs_buildup to postgres;
grant MAINTAIN on table public.mv_press_vs_buildup to postgres;
grant REFERENCES on table public.mv_press_vs_buildup to postgres;
grant SELECT on table public.mv_press_vs_buildup to postgres;
grant TRIGGER on table public.mv_press_vs_buildup to postgres;
grant TRUNCATE on table public.mv_press_vs_buildup to postgres;
grant UPDATE on table public.mv_press_vs_buildup to postgres;
grant DELETE on table public.mv_press_vs_buildup to service_role;
grant INSERT on table public.mv_press_vs_buildup to service_role;
grant MAINTAIN on table public.mv_press_vs_buildup to service_role;
grant REFERENCES on table public.mv_press_vs_buildup to service_role;
grant SELECT on table public.mv_press_vs_buildup to service_role;
grant TRIGGER on table public.mv_press_vs_buildup to service_role;
grant TRUNCATE on table public.mv_press_vs_buildup to service_role;
grant UPDATE on table public.mv_press_vs_buildup to service_role;
grant SELECT on table public.mv_receipt_events to anon;
grant SELECT on table public.mv_receipt_events to authenticated;
grant DELETE on table public.mv_receipt_events to postgres;
grant INSERT on table public.mv_receipt_events to postgres;
grant MAINTAIN on table public.mv_receipt_events to postgres;
grant REFERENCES on table public.mv_receipt_events to postgres;
grant SELECT on table public.mv_receipt_events to postgres;
grant TRIGGER on table public.mv_receipt_events to postgres;
grant TRUNCATE on table public.mv_receipt_events to postgres;
grant UPDATE on table public.mv_receipt_events to postgres;
grant DELETE on table public.mv_receipt_events to service_role;
grant INSERT on table public.mv_receipt_events to service_role;
grant MAINTAIN on table public.mv_receipt_events to service_role;
grant REFERENCES on table public.mv_receipt_events to service_role;
grant SELECT on table public.mv_receipt_events to service_role;
grant TRIGGER on table public.mv_receipt_events to service_role;
grant TRUNCATE on table public.mv_receipt_events to service_role;
grant UPDATE on table public.mv_receipt_events to service_role;
grant SELECT on table public.mv_seq_events to anon;
grant SELECT on table public.mv_seq_events to authenticated;
grant DELETE on table public.mv_seq_events to postgres;
grant INSERT on table public.mv_seq_events to postgres;
grant MAINTAIN on table public.mv_seq_events to postgres;
grant REFERENCES on table public.mv_seq_events to postgres;
grant SELECT on table public.mv_seq_events to postgres;
grant TRIGGER on table public.mv_seq_events to postgres;
grant TRUNCATE on table public.mv_seq_events to postgres;
grant UPDATE on table public.mv_seq_events to postgres;
grant DELETE on table public.mv_seq_events to service_role;
grant INSERT on table public.mv_seq_events to service_role;
grant MAINTAIN on table public.mv_seq_events to service_role;
grant REFERENCES on table public.mv_seq_events to service_role;
grant SELECT on table public.mv_seq_events to service_role;
grant TRIGGER on table public.mv_seq_events to service_role;
grant TRUNCATE on table public.mv_seq_events to service_role;
grant UPDATE on table public.mv_seq_events to service_role;
grant SELECT on table public.mv_seq_state to anon;
grant SELECT on table public.mv_seq_state to authenticated;
grant DELETE on table public.mv_seq_state to postgres;
grant INSERT on table public.mv_seq_state to postgres;
grant MAINTAIN on table public.mv_seq_state to postgres;
grant REFERENCES on table public.mv_seq_state to postgres;
grant SELECT on table public.mv_seq_state to postgres;
grant TRIGGER on table public.mv_seq_state to postgres;
grant TRUNCATE on table public.mv_seq_state to postgres;
grant UPDATE on table public.mv_seq_state to postgres;
grant DELETE on table public.mv_seq_state to service_role;
grant INSERT on table public.mv_seq_state to service_role;
grant MAINTAIN on table public.mv_seq_state to service_role;
grant REFERENCES on table public.mv_seq_state to service_role;
grant SELECT on table public.mv_seq_state to service_role;
grant TRIGGER on table public.mv_seq_state to service_role;
grant TRUNCATE on table public.mv_seq_state to service_role;
grant UPDATE on table public.mv_seq_state to service_role;
grant SELECT on table public.mv_shot_features to anon;
grant SELECT on table public.mv_shot_features to authenticated;
grant DELETE on table public.mv_shot_features to postgres;
grant INSERT on table public.mv_shot_features to postgres;
grant MAINTAIN on table public.mv_shot_features to postgres;
grant REFERENCES on table public.mv_shot_features to postgres;
grant SELECT on table public.mv_shot_features to postgres;
grant TRIGGER on table public.mv_shot_features to postgres;
grant TRUNCATE on table public.mv_shot_features to postgres;
grant UPDATE on table public.mv_shot_features to postgres;
grant DELETE on table public.mv_shot_features to service_role;
grant INSERT on table public.mv_shot_features to service_role;
grant MAINTAIN on table public.mv_shot_features to service_role;
grant REFERENCES on table public.mv_shot_features to service_role;
grant SELECT on table public.mv_shot_features to service_role;
grant TRIGGER on table public.mv_shot_features to service_role;
grant TRUNCATE on table public.mv_shot_features to service_role;
grant UPDATE on table public.mv_shot_features to service_role;
grant SELECT on table public.mv_shot_xg to anon;
grant SELECT on table public.mv_shot_xg to authenticated;
grant DELETE on table public.mv_shot_xg to postgres;
grant INSERT on table public.mv_shot_xg to postgres;
grant MAINTAIN on table public.mv_shot_xg to postgres;
grant REFERENCES on table public.mv_shot_xg to postgres;
grant SELECT on table public.mv_shot_xg to postgres;
grant TRIGGER on table public.mv_shot_xg to postgres;
grant TRUNCATE on table public.mv_shot_xg to postgres;
grant UPDATE on table public.mv_shot_xg to postgres;
grant DELETE on table public.mv_shot_xg to service_role;
grant INSERT on table public.mv_shot_xg to service_role;
grant MAINTAIN on table public.mv_shot_xg to service_role;
grant REFERENCES on table public.mv_shot_xg to service_role;
grant SELECT on table public.mv_shot_xg to service_role;
grant TRIGGER on table public.mv_shot_xg to service_role;
grant TRUNCATE on table public.mv_shot_xg to service_role;
grant UPDATE on table public.mv_shot_xg to service_role;
grant SELECT on table public.mv_site_summary to anon;
grant SELECT on table public.mv_site_summary to authenticated;
grant DELETE on table public.mv_site_summary to postgres;
grant INSERT on table public.mv_site_summary to postgres;
grant MAINTAIN on table public.mv_site_summary to postgres;
grant REFERENCES on table public.mv_site_summary to postgres;
grant SELECT on table public.mv_site_summary to postgres;
grant TRIGGER on table public.mv_site_summary to postgres;
grant TRUNCATE on table public.mv_site_summary to postgres;
grant UPDATE on table public.mv_site_summary to postgres;
grant DELETE on table public.mv_site_summary to service_role;
grant INSERT on table public.mv_site_summary to service_role;
grant MAINTAIN on table public.mv_site_summary to service_role;
grant REFERENCES on table public.mv_site_summary to service_role;
grant SELECT on table public.mv_site_summary to service_role;
grant TRIGGER on table public.mv_site_summary to service_role;
grant TRUNCATE on table public.mv_site_summary to service_role;
grant UPDATE on table public.mv_site_summary to service_role;
grant SELECT on table public.mv_squad_role to anon;
grant SELECT on table public.mv_squad_role to authenticated;
grant DELETE on table public.mv_squad_role to postgres;
grant INSERT on table public.mv_squad_role to postgres;
grant MAINTAIN on table public.mv_squad_role to postgres;
grant REFERENCES on table public.mv_squad_role to postgres;
grant SELECT on table public.mv_squad_role to postgres;
grant TRIGGER on table public.mv_squad_role to postgres;
grant TRUNCATE on table public.mv_squad_role to postgres;
grant UPDATE on table public.mv_squad_role to postgres;
grant DELETE on table public.mv_squad_role to service_role;
grant INSERT on table public.mv_squad_role to service_role;
grant MAINTAIN on table public.mv_squad_role to service_role;
grant REFERENCES on table public.mv_squad_role to service_role;
grant SELECT on table public.mv_squad_role to service_role;
grant TRIGGER on table public.mv_squad_role to service_role;
grant TRUNCATE on table public.mv_squad_role to service_role;
grant UPDATE on table public.mv_squad_role to service_role;
grant SELECT on table public.mv_state_segments to anon;
grant SELECT on table public.mv_state_segments to authenticated;
grant DELETE on table public.mv_state_segments to postgres;
grant INSERT on table public.mv_state_segments to postgres;
grant MAINTAIN on table public.mv_state_segments to postgres;
grant REFERENCES on table public.mv_state_segments to postgres;
grant SELECT on table public.mv_state_segments to postgres;
grant TRIGGER on table public.mv_state_segments to postgres;
grant TRUNCATE on table public.mv_state_segments to postgres;
grant UPDATE on table public.mv_state_segments to postgres;
grant DELETE on table public.mv_state_segments to service_role;
grant INSERT on table public.mv_state_segments to service_role;
grant MAINTAIN on table public.mv_state_segments to service_role;
grant REFERENCES on table public.mv_state_segments to service_role;
grant SELECT on table public.mv_state_segments to service_role;
grant TRIGGER on table public.mv_state_segments to service_role;
grant TRUNCATE on table public.mv_state_segments to service_role;
grant UPDATE on table public.mv_state_segments to service_role;
grant SELECT on table public.mv_team_all to anon;
grant SELECT on table public.mv_team_all to authenticated;
grant DELETE on table public.mv_team_all to postgres;
grant INSERT on table public.mv_team_all to postgres;
grant MAINTAIN on table public.mv_team_all to postgres;
grant REFERENCES on table public.mv_team_all to postgres;
grant SELECT on table public.mv_team_all to postgres;
grant TRIGGER on table public.mv_team_all to postgres;
grant TRUNCATE on table public.mv_team_all to postgres;
grant UPDATE on table public.mv_team_all to postgres;
grant DELETE on table public.mv_team_all to service_role;
grant INSERT on table public.mv_team_all to service_role;
grant MAINTAIN on table public.mv_team_all to service_role;
grant REFERENCES on table public.mv_team_all to service_role;
grant SELECT on table public.mv_team_all to service_role;
grant TRIGGER on table public.mv_team_all to service_role;
grant TRUNCATE on table public.mv_team_all to service_role;
grant UPDATE on table public.mv_team_all to service_role;
grant SELECT on table public.mv_team_attackphase to anon;
grant SELECT on table public.mv_team_attackphase to authenticated;
grant DELETE on table public.mv_team_attackphase to postgres;
grant INSERT on table public.mv_team_attackphase to postgres;
grant MAINTAIN on table public.mv_team_attackphase to postgres;
grant REFERENCES on table public.mv_team_attackphase to postgres;
grant SELECT on table public.mv_team_attackphase to postgres;
grant TRIGGER on table public.mv_team_attackphase to postgres;
grant TRUNCATE on table public.mv_team_attackphase to postgres;
grant UPDATE on table public.mv_team_attackphase to postgres;
grant DELETE on table public.mv_team_attackphase to service_role;
grant INSERT on table public.mv_team_attackphase to service_role;
grant MAINTAIN on table public.mv_team_attackphase to service_role;
grant REFERENCES on table public.mv_team_attackphase to service_role;
grant SELECT on table public.mv_team_attackphase to service_role;
grant TRIGGER on table public.mv_team_attackphase to service_role;
grant TRUNCATE on table public.mv_team_attackphase to service_role;
grant UPDATE on table public.mv_team_attackphase to service_role;
grant SELECT on table public.mv_team_breakdown to anon;
grant SELECT on table public.mv_team_breakdown to authenticated;
grant DELETE on table public.mv_team_breakdown to postgres;
grant INSERT on table public.mv_team_breakdown to postgres;
grant MAINTAIN on table public.mv_team_breakdown to postgres;
grant REFERENCES on table public.mv_team_breakdown to postgres;
grant SELECT on table public.mv_team_breakdown to postgres;
grant TRIGGER on table public.mv_team_breakdown to postgres;
grant TRUNCATE on table public.mv_team_breakdown to postgres;
grant UPDATE on table public.mv_team_breakdown to postgres;
grant DELETE on table public.mv_team_breakdown to service_role;
grant INSERT on table public.mv_team_breakdown to service_role;
grant MAINTAIN on table public.mv_team_breakdown to service_role;
grant REFERENCES on table public.mv_team_breakdown to service_role;
grant SELECT on table public.mv_team_breakdown to service_role;
grant TRIGGER on table public.mv_team_breakdown to service_role;
grant TRUNCATE on table public.mv_team_breakdown to service_role;
grant UPDATE on table public.mv_team_breakdown to service_role;
grant SELECT on table public.mv_team_buildphase to anon;
grant SELECT on table public.mv_team_buildphase to authenticated;
grant DELETE on table public.mv_team_buildphase to postgres;
grant INSERT on table public.mv_team_buildphase to postgres;
grant MAINTAIN on table public.mv_team_buildphase to postgres;
grant REFERENCES on table public.mv_team_buildphase to postgres;
grant SELECT on table public.mv_team_buildphase to postgres;
grant TRIGGER on table public.mv_team_buildphase to postgres;
grant TRUNCATE on table public.mv_team_buildphase to postgres;
grant UPDATE on table public.mv_team_buildphase to postgres;
grant DELETE on table public.mv_team_buildphase to service_role;
grant INSERT on table public.mv_team_buildphase to service_role;
grant MAINTAIN on table public.mv_team_buildphase to service_role;
grant REFERENCES on table public.mv_team_buildphase to service_role;
grant SELECT on table public.mv_team_buildphase to service_role;
grant TRIGGER on table public.mv_team_buildphase to service_role;
grant TRUNCATE on table public.mv_team_buildphase to service_role;
grant UPDATE on table public.mv_team_buildphase to service_role;
grant SELECT on table public.mv_team_buildup to anon;
grant SELECT on table public.mv_team_buildup to authenticated;
grant DELETE on table public.mv_team_buildup to postgres;
grant INSERT on table public.mv_team_buildup to postgres;
grant MAINTAIN on table public.mv_team_buildup to postgres;
grant REFERENCES on table public.mv_team_buildup to postgres;
grant SELECT on table public.mv_team_buildup to postgres;
grant TRIGGER on table public.mv_team_buildup to postgres;
grant TRUNCATE on table public.mv_team_buildup to postgres;
grant UPDATE on table public.mv_team_buildup to postgres;
grant DELETE on table public.mv_team_buildup to service_role;
grant INSERT on table public.mv_team_buildup to service_role;
grant MAINTAIN on table public.mv_team_buildup to service_role;
grant REFERENCES on table public.mv_team_buildup to service_role;
grant SELECT on table public.mv_team_buildup to service_role;
grant TRIGGER on table public.mv_team_buildup to service_role;
grant TRUNCATE on table public.mv_team_buildup to service_role;
grant UPDATE on table public.mv_team_buildup to service_role;
grant SELECT on table public.mv_team_carry_zones to anon;
grant SELECT on table public.mv_team_carry_zones to authenticated;
grant DELETE on table public.mv_team_carry_zones to postgres;
grant INSERT on table public.mv_team_carry_zones to postgres;
grant MAINTAIN on table public.mv_team_carry_zones to postgres;
grant REFERENCES on table public.mv_team_carry_zones to postgres;
grant SELECT on table public.mv_team_carry_zones to postgres;
grant TRIGGER on table public.mv_team_carry_zones to postgres;
grant TRUNCATE on table public.mv_team_carry_zones to postgres;
grant UPDATE on table public.mv_team_carry_zones to postgres;
grant DELETE on table public.mv_team_carry_zones to service_role;
grant INSERT on table public.mv_team_carry_zones to service_role;
grant MAINTAIN on table public.mv_team_carry_zones to service_role;
grant REFERENCES on table public.mv_team_carry_zones to service_role;
grant SELECT on table public.mv_team_carry_zones to service_role;
grant TRIGGER on table public.mv_team_carry_zones to service_role;
grant TRUNCATE on table public.mv_team_carry_zones to service_role;
grant UPDATE on table public.mv_team_carry_zones to service_role;
grant SELECT on table public.mv_team_directness_state to anon;
grant SELECT on table public.mv_team_directness_state to authenticated;
grant DELETE on table public.mv_team_directness_state to postgres;
grant INSERT on table public.mv_team_directness_state to postgres;
grant MAINTAIN on table public.mv_team_directness_state to postgres;
grant REFERENCES on table public.mv_team_directness_state to postgres;
grant SELECT on table public.mv_team_directness_state to postgres;
grant TRIGGER on table public.mv_team_directness_state to postgres;
grant TRUNCATE on table public.mv_team_directness_state to postgres;
grant UPDATE on table public.mv_team_directness_state to postgres;
grant DELETE on table public.mv_team_directness_state to service_role;
grant INSERT on table public.mv_team_directness_state to service_role;
grant MAINTAIN on table public.mv_team_directness_state to service_role;
grant REFERENCES on table public.mv_team_directness_state to service_role;
grant SELECT on table public.mv_team_directness_state to service_role;
grant TRIGGER on table public.mv_team_directness_state to service_role;
grant TRUNCATE on table public.mv_team_directness_state to service_role;
grant UPDATE on table public.mv_team_directness_state to service_role;
grant SELECT on table public.mv_team_lanes to anon;
grant SELECT on table public.mv_team_lanes to authenticated;
grant DELETE on table public.mv_team_lanes to postgres;
grant INSERT on table public.mv_team_lanes to postgres;
grant MAINTAIN on table public.mv_team_lanes to postgres;
grant REFERENCES on table public.mv_team_lanes to postgres;
grant SELECT on table public.mv_team_lanes to postgres;
grant TRIGGER on table public.mv_team_lanes to postgres;
grant TRUNCATE on table public.mv_team_lanes to postgres;
grant UPDATE on table public.mv_team_lanes to postgres;
grant DELETE on table public.mv_team_lanes to service_role;
grant INSERT on table public.mv_team_lanes to service_role;
grant MAINTAIN on table public.mv_team_lanes to service_role;
grant REFERENCES on table public.mv_team_lanes to service_role;
grant SELECT on table public.mv_team_lanes to service_role;
grant TRIGGER on table public.mv_team_lanes to service_role;
grant TRUNCATE on table public.mv_team_lanes to service_role;
grant UPDATE on table public.mv_team_lanes to service_role;
grant SELECT on table public.mv_team_league to anon;
grant SELECT on table public.mv_team_league to authenticated;
grant DELETE on table public.mv_team_league to postgres;
grant INSERT on table public.mv_team_league to postgres;
grant MAINTAIN on table public.mv_team_league to postgres;
grant REFERENCES on table public.mv_team_league to postgres;
grant SELECT on table public.mv_team_league to postgres;
grant TRIGGER on table public.mv_team_league to postgres;
grant TRUNCATE on table public.mv_team_league to postgres;
grant UPDATE on table public.mv_team_league to postgres;
grant DELETE on table public.mv_team_league to service_role;
grant INSERT on table public.mv_team_league to service_role;
grant MAINTAIN on table public.mv_team_league to service_role;
grant REFERENCES on table public.mv_team_league to service_role;
grant SELECT on table public.mv_team_league to service_role;
grant TRIGGER on table public.mv_team_league to service_role;
grant TRUNCATE on table public.mv_team_league to service_role;
grant UPDATE on table public.mv_team_league to service_role;
grant SELECT on table public.mv_team_match to anon;
grant SELECT on table public.mv_team_match to authenticated;
grant DELETE on table public.mv_team_match to postgres;
grant INSERT on table public.mv_team_match to postgres;
grant MAINTAIN on table public.mv_team_match to postgres;
grant REFERENCES on table public.mv_team_match to postgres;
grant SELECT on table public.mv_team_match to postgres;
grant TRIGGER on table public.mv_team_match to postgres;
grant TRUNCATE on table public.mv_team_match to postgres;
grant UPDATE on table public.mv_team_match to postgres;
grant DELETE on table public.mv_team_match to service_role;
grant INSERT on table public.mv_team_match to service_role;
grant MAINTAIN on table public.mv_team_match to service_role;
grant REFERENCES on table public.mv_team_match to service_role;
grant SELECT on table public.mv_team_match to service_role;
grant TRIGGER on table public.mv_team_match to service_role;
grant TRUNCATE on table public.mv_team_match to service_role;
grant UPDATE on table public.mv_team_match to service_role;
grant SELECT on table public.mv_team_percentiles to anon;
grant SELECT on table public.mv_team_percentiles to authenticated;
grant DELETE on table public.mv_team_percentiles to postgres;
grant INSERT on table public.mv_team_percentiles to postgres;
grant MAINTAIN on table public.mv_team_percentiles to postgres;
grant REFERENCES on table public.mv_team_percentiles to postgres;
grant SELECT on table public.mv_team_percentiles to postgres;
grant TRIGGER on table public.mv_team_percentiles to postgres;
grant TRUNCATE on table public.mv_team_percentiles to postgres;
grant UPDATE on table public.mv_team_percentiles to postgres;
grant DELETE on table public.mv_team_percentiles to service_role;
grant INSERT on table public.mv_team_percentiles to service_role;
grant MAINTAIN on table public.mv_team_percentiles to service_role;
grant REFERENCES on table public.mv_team_percentiles to service_role;
grant SELECT on table public.mv_team_percentiles to service_role;
grant TRIGGER on table public.mv_team_percentiles to service_role;
grant TRUNCATE on table public.mv_team_percentiles to service_role;
grant UPDATE on table public.mv_team_percentiles to service_role;
grant SELECT on table public.mv_team_season to anon;
grant SELECT on table public.mv_team_season to authenticated;
grant DELETE on table public.mv_team_season to postgres;
grant INSERT on table public.mv_team_season to postgres;
grant MAINTAIN on table public.mv_team_season to postgres;
grant REFERENCES on table public.mv_team_season to postgres;
grant SELECT on table public.mv_team_season to postgres;
grant TRIGGER on table public.mv_team_season to postgres;
grant TRUNCATE on table public.mv_team_season to postgres;
grant UPDATE on table public.mv_team_season to postgres;
grant DELETE on table public.mv_team_season to service_role;
grant INSERT on table public.mv_team_season to service_role;
grant MAINTAIN on table public.mv_team_season to service_role;
grant REFERENCES on table public.mv_team_season to service_role;
grant SELECT on table public.mv_team_season to service_role;
grant TRIGGER on table public.mv_team_season to service_role;
grant TRUNCATE on table public.mv_team_season to service_role;
grant UPDATE on table public.mv_team_season to service_role;
grant SELECT on table public.mv_team_sequences to anon;
grant SELECT on table public.mv_team_sequences to authenticated;
grant DELETE on table public.mv_team_sequences to postgres;
grant INSERT on table public.mv_team_sequences to postgres;
grant MAINTAIN on table public.mv_team_sequences to postgres;
grant REFERENCES on table public.mv_team_sequences to postgres;
grant SELECT on table public.mv_team_sequences to postgres;
grant TRIGGER on table public.mv_team_sequences to postgres;
grant TRUNCATE on table public.mv_team_sequences to postgres;
grant UPDATE on table public.mv_team_sequences to postgres;
grant DELETE on table public.mv_team_sequences to service_role;
grant INSERT on table public.mv_team_sequences to service_role;
grant MAINTAIN on table public.mv_team_sequences to service_role;
grant REFERENCES on table public.mv_team_sequences to service_role;
grant SELECT on table public.mv_team_sequences to service_role;
grant TRIGGER on table public.mv_team_sequences to service_role;
grant TRUNCATE on table public.mv_team_sequences to service_role;
grant UPDATE on table public.mv_team_sequences to service_role;
grant SELECT on table public.mv_team_stat_ranks to anon;
grant SELECT on table public.mv_team_stat_ranks to authenticated;
grant DELETE on table public.mv_team_stat_ranks to postgres;
grant INSERT on table public.mv_team_stat_ranks to postgres;
grant MAINTAIN on table public.mv_team_stat_ranks to postgres;
grant REFERENCES on table public.mv_team_stat_ranks to postgres;
grant SELECT on table public.mv_team_stat_ranks to postgres;
grant TRIGGER on table public.mv_team_stat_ranks to postgres;
grant TRUNCATE on table public.mv_team_stat_ranks to postgres;
grant UPDATE on table public.mv_team_stat_ranks to postgres;
grant DELETE on table public.mv_team_stat_ranks to service_role;
grant INSERT on table public.mv_team_stat_ranks to service_role;
grant MAINTAIN on table public.mv_team_stat_ranks to service_role;
grant REFERENCES on table public.mv_team_stat_ranks to service_role;
grant SELECT on table public.mv_team_stat_ranks to service_role;
grant TRIGGER on table public.mv_team_stat_ranks to service_role;
grant TRUNCATE on table public.mv_team_stat_ranks to service_role;
grant UPDATE on table public.mv_team_stat_ranks to service_role;
grant SELECT on table public.mv_team_zones to anon;
grant SELECT on table public.mv_team_zones to authenticated;
grant DELETE on table public.mv_team_zones to postgres;
grant INSERT on table public.mv_team_zones to postgres;
grant MAINTAIN on table public.mv_team_zones to postgres;
grant REFERENCES on table public.mv_team_zones to postgres;
grant SELECT on table public.mv_team_zones to postgres;
grant TRIGGER on table public.mv_team_zones to postgres;
grant TRUNCATE on table public.mv_team_zones to postgres;
grant UPDATE on table public.mv_team_zones to postgres;
grant DELETE on table public.mv_team_zones to service_role;
grant INSERT on table public.mv_team_zones to service_role;
grant MAINTAIN on table public.mv_team_zones to service_role;
grant REFERENCES on table public.mv_team_zones to service_role;
grant SELECT on table public.mv_team_zones to service_role;
grant TRIGGER on table public.mv_team_zones to service_role;
grant TRUNCATE on table public.mv_team_zones to service_role;
grant UPDATE on table public.mv_team_zones to service_role;
grant SELECT on table public.mv_xg_bins to anon;
grant SELECT on table public.mv_xg_bins to authenticated;
grant DELETE on table public.mv_xg_bins to postgres;
grant INSERT on table public.mv_xg_bins to postgres;
grant MAINTAIN on table public.mv_xg_bins to postgres;
grant REFERENCES on table public.mv_xg_bins to postgres;
grant SELECT on table public.mv_xg_bins to postgres;
grant TRIGGER on table public.mv_xg_bins to postgres;
grant TRUNCATE on table public.mv_xg_bins to postgres;
grant UPDATE on table public.mv_xg_bins to postgres;
grant DELETE on table public.mv_xg_bins to service_role;
grant INSERT on table public.mv_xg_bins to service_role;
grant MAINTAIN on table public.mv_xg_bins to service_role;
grant REFERENCES on table public.mv_xg_bins to service_role;
grant SELECT on table public.mv_xg_bins to service_role;
grant TRIGGER on table public.mv_xg_bins to service_role;
grant TRUNCATE on table public.mv_xg_bins to service_role;
grant UPDATE on table public.mv_xg_bins to service_role;
grant SELECT on table public.pcr_z to anon;
grant SELECT on table public.pcr_z to authenticated;
grant DELETE on table public.pcr_z to postgres;
grant INSERT on table public.pcr_z to postgres;
grant MAINTAIN on table public.pcr_z to postgres;
grant REFERENCES on table public.pcr_z to postgres;
grant SELECT on table public.pcr_z to postgres;
grant TRIGGER on table public.pcr_z to postgres;
grant TRUNCATE on table public.pcr_z to postgres;
grant UPDATE on table public.pcr_z to postgres;
grant DELETE on table public.pcr_z to service_role;
grant INSERT on table public.pcr_z to service_role;
grant MAINTAIN on table public.pcr_z to service_role;
grant REFERENCES on table public.pcr_z to service_role;
grant SELECT on table public.pcr_z to service_role;
grant TRIGGER on table public.pcr_z to service_role;
grant TRUNCATE on table public.pcr_z to service_role;
grant UPDATE on table public.pcr_z to service_role;
grant SELECT on table public.pillar_defs to anon;
grant SELECT on table public.pillar_defs to authenticated;
grant DELETE on table public.pillar_defs to postgres;
grant INSERT on table public.pillar_defs to postgres;
grant MAINTAIN on table public.pillar_defs to postgres;
grant REFERENCES on table public.pillar_defs to postgres;
grant SELECT on table public.pillar_defs to postgres;
grant TRIGGER on table public.pillar_defs to postgres;
grant TRUNCATE on table public.pillar_defs to postgres;
grant UPDATE on table public.pillar_defs to postgres;
grant DELETE on table public.pillar_defs to service_role;
grant INSERT on table public.pillar_defs to service_role;
grant MAINTAIN on table public.pillar_defs to service_role;
grant REFERENCES on table public.pillar_defs to service_role;
grant SELECT on table public.pillar_defs to service_role;
grant TRIGGER on table public.pillar_defs to service_role;
grant TRUNCATE on table public.pillar_defs to service_role;
grant UPDATE on table public.pillar_defs to service_role;
grant SELECT on table public.player_bio to anon;
grant SELECT on table public.player_bio to authenticated;
grant DELETE on table public.player_bio to postgres;
grant INSERT on table public.player_bio to postgres;
grant MAINTAIN on table public.player_bio to postgres;
grant REFERENCES on table public.player_bio to postgres;
grant SELECT on table public.player_bio to postgres;
grant TRIGGER on table public.player_bio to postgres;
grant TRUNCATE on table public.player_bio to postgres;
grant UPDATE on table public.player_bio to postgres;
grant DELETE on table public.player_bio to service_role;
grant INSERT on table public.player_bio to service_role;
grant MAINTAIN on table public.player_bio to service_role;
grant REFERENCES on table public.player_bio to service_role;
grant SELECT on table public.player_bio to service_role;
grant TRIGGER on table public.player_bio to service_role;
grant TRUNCATE on table public.player_bio to service_role;
grant UPDATE on table public.player_bio to service_role;
grant SELECT on table public.player_chain_pct to anon;
grant SELECT on table public.player_chain_pct to authenticated;
grant DELETE on table public.player_chain_pct to postgres;
grant INSERT on table public.player_chain_pct to postgres;
grant MAINTAIN on table public.player_chain_pct to postgres;
grant REFERENCES on table public.player_chain_pct to postgres;
grant SELECT on table public.player_chain_pct to postgres;
grant TRIGGER on table public.player_chain_pct to postgres;
grant TRUNCATE on table public.player_chain_pct to postgres;
grant UPDATE on table public.player_chain_pct to postgres;
grant DELETE on table public.player_chain_pct to service_role;
grant INSERT on table public.player_chain_pct to service_role;
grant MAINTAIN on table public.player_chain_pct to service_role;
grant REFERENCES on table public.player_chain_pct to service_role;
grant SELECT on table public.player_chain_pct to service_role;
grant TRIGGER on table public.player_chain_pct to service_role;
grant TRUNCATE on table public.player_chain_pct to service_role;
grant UPDATE on table public.player_chain_pct to service_role;
grant SELECT on table public.player_chain_roles to anon;
grant SELECT on table public.player_chain_roles to authenticated;
grant DELETE on table public.player_chain_roles to postgres;
grant INSERT on table public.player_chain_roles to postgres;
grant MAINTAIN on table public.player_chain_roles to postgres;
grant REFERENCES on table public.player_chain_roles to postgres;
grant SELECT on table public.player_chain_roles to postgres;
grant TRIGGER on table public.player_chain_roles to postgres;
grant TRUNCATE on table public.player_chain_roles to postgres;
grant UPDATE on table public.player_chain_roles to postgres;
grant DELETE on table public.player_chain_roles to service_role;
grant INSERT on table public.player_chain_roles to service_role;
grant MAINTAIN on table public.player_chain_roles to service_role;
grant REFERENCES on table public.player_chain_roles to service_role;
grant SELECT on table public.player_chain_roles to service_role;
grant TRIGGER on table public.player_chain_roles to service_role;
grant TRUNCATE on table public.player_chain_roles to service_role;
grant UPDATE on table public.player_chain_roles to service_role;
grant SELECT on table public.player_search to anon;
grant SELECT on table public.player_search to authenticated;
grant DELETE on table public.player_search to postgres;
grant INSERT on table public.player_search to postgres;
grant MAINTAIN on table public.player_search to postgres;
grant REFERENCES on table public.player_search to postgres;
grant SELECT on table public.player_search to postgres;
grant TRIGGER on table public.player_search to postgres;
grant TRUNCATE on table public.player_search to postgres;
grant UPDATE on table public.player_search to postgres;
grant DELETE on table public.player_search to service_role;
grant INSERT on table public.player_search to service_role;
grant MAINTAIN on table public.player_search to service_role;
grant REFERENCES on table public.player_search to service_role;
grant SELECT on table public.player_search to service_role;
grant TRIGGER on table public.player_search to service_role;
grant TRUNCATE on table public.player_search to service_role;
grant UPDATE on table public.player_search to service_role;
grant SELECT on table public.players to anon;
grant SELECT on table public.players to authenticated;
grant DELETE on table public.players to postgres;
grant INSERT on table public.players to postgres;
grant MAINTAIN on table public.players to postgres;
grant REFERENCES on table public.players to postgres;
grant SELECT on table public.players to postgres;
grant TRIGGER on table public.players to postgres;
grant TRUNCATE on table public.players to postgres;
grant UPDATE on table public.players to postgres;
grant DELETE on table public.players to service_role;
grant INSERT on table public.players to service_role;
grant MAINTAIN on table public.players to service_role;
grant REFERENCES on table public.players to service_role;
grant SELECT on table public.players to service_role;
grant TRIGGER on table public.players to service_role;
grant TRUNCATE on table public.players to service_role;
grant UPDATE on table public.players to service_role;
grant SELECT on table public.pool_metric_relevance to anon;
grant SELECT on table public.pool_metric_relevance to authenticated;
grant DELETE on table public.pool_metric_relevance to postgres;
grant INSERT on table public.pool_metric_relevance to postgres;
grant MAINTAIN on table public.pool_metric_relevance to postgres;
grant REFERENCES on table public.pool_metric_relevance to postgres;
grant SELECT on table public.pool_metric_relevance to postgres;
grant TRIGGER on table public.pool_metric_relevance to postgres;
grant TRUNCATE on table public.pool_metric_relevance to postgres;
grant UPDATE on table public.pool_metric_relevance to postgres;
grant DELETE on table public.pool_metric_relevance to service_role;
grant INSERT on table public.pool_metric_relevance to service_role;
grant MAINTAIN on table public.pool_metric_relevance to service_role;
grant REFERENCES on table public.pool_metric_relevance to service_role;
grant SELECT on table public.pool_metric_relevance to service_role;
grant TRIGGER on table public.pool_metric_relevance to service_role;
grant TRUNCATE on table public.pool_metric_relevance to service_role;
grant UPDATE on table public.pool_metric_relevance to service_role;
grant SELECT on table public.role_pillar_weights to anon;
grant SELECT on table public.role_pillar_weights to authenticated;
grant DELETE on table public.role_pillar_weights to postgres;
grant INSERT on table public.role_pillar_weights to postgres;
grant MAINTAIN on table public.role_pillar_weights to postgres;
grant REFERENCES on table public.role_pillar_weights to postgres;
grant SELECT on table public.role_pillar_weights to postgres;
grant TRIGGER on table public.role_pillar_weights to postgres;
grant TRUNCATE on table public.role_pillar_weights to postgres;
grant UPDATE on table public.role_pillar_weights to postgres;
grant DELETE on table public.role_pillar_weights to service_role;
grant INSERT on table public.role_pillar_weights to service_role;
grant MAINTAIN on table public.role_pillar_weights to service_role;
grant REFERENCES on table public.role_pillar_weights to service_role;
grant SELECT on table public.role_pillar_weights to service_role;
grant TRIGGER on table public.role_pillar_weights to service_role;
grant TRUNCATE on table public.role_pillar_weights to service_role;
grant UPDATE on table public.role_pillar_weights to service_role;
grant SELECT on table public.seq_fz to anon;
grant SELECT on table public.seq_fz to authenticated;
grant DELETE on table public.seq_fz to postgres;
grant INSERT on table public.seq_fz to postgres;
grant MAINTAIN on table public.seq_fz to postgres;
grant REFERENCES on table public.seq_fz to postgres;
grant SELECT on table public.seq_fz to postgres;
grant TRIGGER on table public.seq_fz to postgres;
grant TRUNCATE on table public.seq_fz to postgres;
grant UPDATE on table public.seq_fz to postgres;
grant DELETE on table public.seq_fz to service_role;
grant INSERT on table public.seq_fz to service_role;
grant MAINTAIN on table public.seq_fz to service_role;
grant REFERENCES on table public.seq_fz to service_role;
grant SELECT on table public.seq_fz to service_role;
grant TRIGGER on table public.seq_fz to service_role;
grant TRUNCATE on table public.seq_fz to service_role;
grant UPDATE on table public.seq_fz to service_role;
grant SELECT on table public.sequences to anon;
grant SELECT on table public.sequences to authenticated;
grant DELETE on table public.sequences to postgres;
grant INSERT on table public.sequences to postgres;
grant MAINTAIN on table public.sequences to postgres;
grant REFERENCES on table public.sequences to postgres;
grant SELECT on table public.sequences to postgres;
grant TRIGGER on table public.sequences to postgres;
grant TRUNCATE on table public.sequences to postgres;
grant UPDATE on table public.sequences to postgres;
grant DELETE on table public.sequences to service_role;
grant INSERT on table public.sequences to service_role;
grant MAINTAIN on table public.sequences to service_role;
grant REFERENCES on table public.sequences to service_role;
grant SELECT on table public.sequences to service_role;
grant TRIGGER on table public.sequences to service_role;
grant TRUNCATE on table public.sequences to service_role;
grant UPDATE on table public.sequences to service_role;
grant SELECT on table public.team_metric_defs to anon;
grant SELECT on table public.team_metric_defs to authenticated;
grant DELETE on table public.team_metric_defs to postgres;
grant INSERT on table public.team_metric_defs to postgres;
grant MAINTAIN on table public.team_metric_defs to postgres;
grant REFERENCES on table public.team_metric_defs to postgres;
grant SELECT on table public.team_metric_defs to postgres;
grant TRIGGER on table public.team_metric_defs to postgres;
grant TRUNCATE on table public.team_metric_defs to postgres;
grant UPDATE on table public.team_metric_defs to postgres;
grant DELETE on table public.team_metric_defs to service_role;
grant INSERT on table public.team_metric_defs to service_role;
grant MAINTAIN on table public.team_metric_defs to service_role;
grant REFERENCES on table public.team_metric_defs to service_role;
grant SELECT on table public.team_metric_defs to service_role;
grant TRIGGER on table public.team_metric_defs to service_role;
grant TRUNCATE on table public.team_metric_defs to service_role;
grant UPDATE on table public.team_metric_defs to service_role;
grant SELECT on table public.team_names to anon;
grant SELECT on table public.team_names to authenticated;
grant DELETE on table public.team_names to postgres;
grant INSERT on table public.team_names to postgres;
grant MAINTAIN on table public.team_names to postgres;
grant REFERENCES on table public.team_names to postgres;
grant SELECT on table public.team_names to postgres;
grant TRIGGER on table public.team_names to postgres;
grant TRUNCATE on table public.team_names to postgres;
grant UPDATE on table public.team_names to postgres;
grant DELETE on table public.team_names to service_role;
grant INSERT on table public.team_names to service_role;
grant MAINTAIN on table public.team_names to service_role;
grant REFERENCES on table public.team_names to service_role;
grant SELECT on table public.team_names to service_role;
grant TRIGGER on table public.team_names to service_role;
grant TRUNCATE on table public.team_names to service_role;
grant UPDATE on table public.team_names to service_role;
grant SELECT on table public.team_names_cup to anon;
grant SELECT on table public.team_names_cup to authenticated;
grant DELETE on table public.team_names_cup to postgres;
grant INSERT on table public.team_names_cup to postgres;
grant MAINTAIN on table public.team_names_cup to postgres;
grant REFERENCES on table public.team_names_cup to postgres;
grant SELECT on table public.team_names_cup to postgres;
grant TRIGGER on table public.team_names_cup to postgres;
grant TRUNCATE on table public.team_names_cup to postgres;
grant UPDATE on table public.team_names_cup to postgres;
grant DELETE on table public.team_names_cup to service_role;
grant INSERT on table public.team_names_cup to service_role;
grant MAINTAIN on table public.team_names_cup to service_role;
grant REFERENCES on table public.team_names_cup to service_role;
grant SELECT on table public.team_names_cup to service_role;
grant TRIGGER on table public.team_names_cup to service_role;
grant TRUNCATE on table public.team_names_cup to service_role;
grant UPDATE on table public.team_names_cup to service_role;
grant SELECT on table public.team_sequence_agg to anon;
grant SELECT on table public.team_sequence_agg to authenticated;
grant DELETE on table public.team_sequence_agg to postgres;
grant INSERT on table public.team_sequence_agg to postgres;
grant MAINTAIN on table public.team_sequence_agg to postgres;
grant REFERENCES on table public.team_sequence_agg to postgres;
grant SELECT on table public.team_sequence_agg to postgres;
grant TRIGGER on table public.team_sequence_agg to postgres;
grant TRUNCATE on table public.team_sequence_agg to postgres;
grant UPDATE on table public.team_sequence_agg to postgres;
grant DELETE on table public.team_sequence_agg to service_role;
grant INSERT on table public.team_sequence_agg to service_role;
grant MAINTAIN on table public.team_sequence_agg to service_role;
grant REFERENCES on table public.team_sequence_agg to service_role;
grant SELECT on table public.team_sequence_agg to service_role;
grant TRIGGER on table public.team_sequence_agg to service_role;
grant TRUNCATE on table public.team_sequence_agg to service_role;
grant UPDATE on table public.team_sequence_agg to service_role;
grant SELECT on table public.team_sequence_style to anon;
grant SELECT on table public.team_sequence_style to authenticated;
grant DELETE on table public.team_sequence_style to postgres;
grant INSERT on table public.team_sequence_style to postgres;
grant MAINTAIN on table public.team_sequence_style to postgres;
grant REFERENCES on table public.team_sequence_style to postgres;
grant SELECT on table public.team_sequence_style to postgres;
grant TRIGGER on table public.team_sequence_style to postgres;
grant TRUNCATE on table public.team_sequence_style to postgres;
grant UPDATE on table public.team_sequence_style to postgres;
grant DELETE on table public.team_sequence_style to service_role;
grant INSERT on table public.team_sequence_style to service_role;
grant MAINTAIN on table public.team_sequence_style to service_role;
grant REFERENCES on table public.team_sequence_style to service_role;
grant SELECT on table public.team_sequence_style to service_role;
grant TRIGGER on table public.team_sequence_style to service_role;
grant TRUNCATE on table public.team_sequence_style to service_role;
grant UPDATE on table public.team_sequence_style to service_role;
grant SELECT on table public.v_goal_fix to anon;
grant SELECT on table public.v_goal_fix to authenticated;
grant DELETE on table public.v_goal_fix to postgres;
grant INSERT on table public.v_goal_fix to postgres;
grant MAINTAIN on table public.v_goal_fix to postgres;
grant REFERENCES on table public.v_goal_fix to postgres;
grant SELECT on table public.v_goal_fix to postgres;
grant TRIGGER on table public.v_goal_fix to postgres;
grant TRUNCATE on table public.v_goal_fix to postgres;
grant UPDATE on table public.v_goal_fix to postgres;
grant DELETE on table public.v_goal_fix to service_role;
grant INSERT on table public.v_goal_fix to service_role;
grant MAINTAIN on table public.v_goal_fix to service_role;
grant REFERENCES on table public.v_goal_fix to service_role;
grant SELECT on table public.v_goal_fix to service_role;
grant TRIGGER on table public.v_goal_fix to service_role;
grant TRUNCATE on table public.v_goal_fix to service_role;
grant UPDATE on table public.v_goal_fix to service_role;
grant SELECT on table public.v_league_availability to anon;
grant SELECT on table public.v_league_availability to authenticated;
grant DELETE on table public.v_league_availability to postgres;
grant INSERT on table public.v_league_availability to postgres;
grant MAINTAIN on table public.v_league_availability to postgres;
grant REFERENCES on table public.v_league_availability to postgres;
grant SELECT on table public.v_league_availability to postgres;
grant TRIGGER on table public.v_league_availability to postgres;
grant TRUNCATE on table public.v_league_availability to postgres;
grant UPDATE on table public.v_league_availability to postgres;
grant DELETE on table public.v_league_availability to service_role;
grant INSERT on table public.v_league_availability to service_role;
grant MAINTAIN on table public.v_league_availability to service_role;
grant REFERENCES on table public.v_league_availability to service_role;
grant SELECT on table public.v_league_availability to service_role;
grant TRIGGER on table public.v_league_availability to service_role;
grant TRUNCATE on table public.v_league_availability to service_role;
grant UPDATE on table public.v_league_availability to service_role;
grant SELECT on table public.v_league_competitions to anon;
grant SELECT on table public.v_league_competitions to authenticated;
grant DELETE on table public.v_league_competitions to postgres;
grant INSERT on table public.v_league_competitions to postgres;
grant MAINTAIN on table public.v_league_competitions to postgres;
grant REFERENCES on table public.v_league_competitions to postgres;
grant SELECT on table public.v_league_competitions to postgres;
grant TRIGGER on table public.v_league_competitions to postgres;
grant TRUNCATE on table public.v_league_competitions to postgres;
grant UPDATE on table public.v_league_competitions to postgres;
grant DELETE on table public.v_league_competitions to service_role;
grant INSERT on table public.v_league_competitions to service_role;
grant MAINTAIN on table public.v_league_competitions to service_role;
grant REFERENCES on table public.v_league_competitions to service_role;
grant SELECT on table public.v_league_competitions to service_role;
grant TRIGGER on table public.v_league_competitions to service_role;
grant TRUNCATE on table public.v_league_competitions to service_role;
grant UPDATE on table public.v_league_competitions to service_role;
grant SELECT on table public.v_league_events to anon;
grant SELECT on table public.v_league_events to authenticated;
grant DELETE on table public.v_league_events to postgres;
grant INSERT on table public.v_league_events to postgres;
grant MAINTAIN on table public.v_league_events to postgres;
grant REFERENCES on table public.v_league_events to postgres;
grant SELECT on table public.v_league_events to postgres;
grant TRIGGER on table public.v_league_events to postgres;
grant TRUNCATE on table public.v_league_events to postgres;
grant UPDATE on table public.v_league_events to postgres;
grant DELETE on table public.v_league_events to service_role;
grant INSERT on table public.v_league_events to service_role;
grant MAINTAIN on table public.v_league_events to service_role;
grant REFERENCES on table public.v_league_events to service_role;
grant SELECT on table public.v_league_events to service_role;
grant TRIGGER on table public.v_league_events to service_role;
grant TRUNCATE on table public.v_league_events to service_role;
grant UPDATE on table public.v_league_events to service_role;
grant SELECT on table public.v_league_lineups to anon;
grant SELECT on table public.v_league_lineups to authenticated;
grant DELETE on table public.v_league_lineups to postgres;
grant INSERT on table public.v_league_lineups to postgres;
grant MAINTAIN on table public.v_league_lineups to postgres;
grant REFERENCES on table public.v_league_lineups to postgres;
grant SELECT on table public.v_league_lineups to postgres;
grant TRIGGER on table public.v_league_lineups to postgres;
grant TRUNCATE on table public.v_league_lineups to postgres;
grant UPDATE on table public.v_league_lineups to postgres;
grant DELETE on table public.v_league_lineups to service_role;
grant INSERT on table public.v_league_lineups to service_role;
grant MAINTAIN on table public.v_league_lineups to service_role;
grant REFERENCES on table public.v_league_lineups to service_role;
grant SELECT on table public.v_league_lineups to service_role;
grant TRIGGER on table public.v_league_lineups to service_role;
grant TRUNCATE on table public.v_league_lineups to service_role;
grant UPDATE on table public.v_league_lineups to service_role;
grant SELECT on table public.v_league_matches to anon;
grant SELECT on table public.v_league_matches to authenticated;
grant DELETE on table public.v_league_matches to postgres;
grant INSERT on table public.v_league_matches to postgres;
grant MAINTAIN on table public.v_league_matches to postgres;
grant REFERENCES on table public.v_league_matches to postgres;
grant SELECT on table public.v_league_matches to postgres;
grant TRIGGER on table public.v_league_matches to postgres;
grant TRUNCATE on table public.v_league_matches to postgres;
grant UPDATE on table public.v_league_matches to postgres;
grant DELETE on table public.v_league_matches to service_role;
grant INSERT on table public.v_league_matches to service_role;
grant MAINTAIN on table public.v_league_matches to service_role;
grant REFERENCES on table public.v_league_matches to service_role;
grant SELECT on table public.v_league_matches to service_role;
grant TRIGGER on table public.v_league_matches to service_role;
grant TRUNCATE on table public.v_league_matches to service_role;
grant UPDATE on table public.v_league_matches to service_role;
grant SELECT on table public.v_league_sequences to anon;
grant SELECT on table public.v_league_sequences to authenticated;
grant DELETE on table public.v_league_sequences to postgres;
grant INSERT on table public.v_league_sequences to postgres;
grant MAINTAIN on table public.v_league_sequences to postgres;
grant REFERENCES on table public.v_league_sequences to postgres;
grant SELECT on table public.v_league_sequences to postgres;
grant TRIGGER on table public.v_league_sequences to postgres;
grant TRUNCATE on table public.v_league_sequences to postgres;
grant UPDATE on table public.v_league_sequences to postgres;
grant DELETE on table public.v_league_sequences to service_role;
grant INSERT on table public.v_league_sequences to service_role;
grant MAINTAIN on table public.v_league_sequences to service_role;
grant REFERENCES on table public.v_league_sequences to service_role;
grant SELECT on table public.v_league_sequences to service_role;
grant TRIGGER on table public.v_league_sequences to service_role;
grant TRUNCATE on table public.v_league_sequences to service_role;
grant UPDATE on table public.v_league_sequences to service_role;
grant SELECT on table public.v_league_summary to anon;
grant SELECT on table public.v_league_summary to authenticated;
grant DELETE on table public.v_league_summary to postgres;
grant INSERT on table public.v_league_summary to postgres;
grant MAINTAIN on table public.v_league_summary to postgres;
grant REFERENCES on table public.v_league_summary to postgres;
grant SELECT on table public.v_league_summary to postgres;
grant TRIGGER on table public.v_league_summary to postgres;
grant TRUNCATE on table public.v_league_summary to postgres;
grant UPDATE on table public.v_league_summary to postgres;
grant DELETE on table public.v_league_summary to service_role;
grant INSERT on table public.v_league_summary to service_role;
grant MAINTAIN on table public.v_league_summary to service_role;
grant REFERENCES on table public.v_league_summary to service_role;
grant SELECT on table public.v_league_summary to service_role;
grant TRIGGER on table public.v_league_summary to service_role;
grant TRUNCATE on table public.v_league_summary to service_role;
grant UPDATE on table public.v_league_summary to service_role;
grant SELECT on table public.v_loaded_games to anon;
grant SELECT on table public.v_loaded_games to authenticated;
grant DELETE on table public.v_loaded_games to postgres;
grant INSERT on table public.v_loaded_games to postgres;
grant MAINTAIN on table public.v_loaded_games to postgres;
grant REFERENCES on table public.v_loaded_games to postgres;
grant SELECT on table public.v_loaded_games to postgres;
grant TRIGGER on table public.v_loaded_games to postgres;
grant TRUNCATE on table public.v_loaded_games to postgres;
grant UPDATE on table public.v_loaded_games to postgres;
grant DELETE on table public.v_loaded_games to service_role;
grant INSERT on table public.v_loaded_games to service_role;
grant MAINTAIN on table public.v_loaded_games to service_role;
grant REFERENCES on table public.v_loaded_games to service_role;
grant SELECT on table public.v_loaded_games to service_role;
grant TRIGGER on table public.v_loaded_games to service_role;
grant TRUNCATE on table public.v_loaded_games to service_role;
grant UPDATE on table public.v_loaded_games to service_role;
grant SELECT on table public.v_match_events to anon;
grant SELECT on table public.v_match_events to authenticated;
grant DELETE on table public.v_match_events to postgres;
grant INSERT on table public.v_match_events to postgres;
grant MAINTAIN on table public.v_match_events to postgres;
grant REFERENCES on table public.v_match_events to postgres;
grant SELECT on table public.v_match_events to postgres;
grant TRIGGER on table public.v_match_events to postgres;
grant TRUNCATE on table public.v_match_events to postgres;
grant UPDATE on table public.v_match_events to postgres;
grant DELETE on table public.v_match_events to service_role;
grant INSERT on table public.v_match_events to service_role;
grant MAINTAIN on table public.v_match_events to service_role;
grant REFERENCES on table public.v_match_events to service_role;
grant SELECT on table public.v_match_events to service_role;
grant TRIGGER on table public.v_match_events to service_role;
grant TRUNCATE on table public.v_match_events to service_role;
grant UPDATE on table public.v_match_events to service_role;
grant SELECT on table public.v_match_season_scope to anon;
grant SELECT on table public.v_match_season_scope to authenticated;
grant DELETE on table public.v_match_season_scope to postgres;
grant INSERT on table public.v_match_season_scope to postgres;
grant MAINTAIN on table public.v_match_season_scope to postgres;
grant REFERENCES on table public.v_match_season_scope to postgres;
grant SELECT on table public.v_match_season_scope to postgres;
grant TRIGGER on table public.v_match_season_scope to postgres;
grant TRUNCATE on table public.v_match_season_scope to postgres;
grant UPDATE on table public.v_match_season_scope to postgres;
grant DELETE on table public.v_match_season_scope to service_role;
grant INSERT on table public.v_match_season_scope to service_role;
grant MAINTAIN on table public.v_match_season_scope to service_role;
grant REFERENCES on table public.v_match_season_scope to service_role;
grant SELECT on table public.v_match_season_scope to service_role;
grant TRIGGER on table public.v_match_season_scope to service_role;
grant TRUNCATE on table public.v_match_season_scope to service_role;
grant UPDATE on table public.v_match_season_scope to service_role;
grant SELECT on table public.v_player_actions to anon;
grant SELECT on table public.v_player_actions to authenticated;
grant DELETE on table public.v_player_actions to postgres;
grant INSERT on table public.v_player_actions to postgres;
grant MAINTAIN on table public.v_player_actions to postgres;
grant REFERENCES on table public.v_player_actions to postgres;
grant SELECT on table public.v_player_actions to postgres;
grant TRIGGER on table public.v_player_actions to postgres;
grant TRUNCATE on table public.v_player_actions to postgres;
grant UPDATE on table public.v_player_actions to postgres;
grant DELETE on table public.v_player_actions to service_role;
grant INSERT on table public.v_player_actions to service_role;
grant MAINTAIN on table public.v_player_actions to service_role;
grant REFERENCES on table public.v_player_actions to service_role;
grant SELECT on table public.v_player_actions to service_role;
grant TRIGGER on table public.v_player_actions to service_role;
grant TRUNCATE on table public.v_player_actions to service_role;
grant UPDATE on table public.v_player_actions to service_role;
grant SELECT on table public.v_player_carries to anon;
grant SELECT on table public.v_player_carries to authenticated;
grant DELETE on table public.v_player_carries to postgres;
grant INSERT on table public.v_player_carries to postgres;
grant MAINTAIN on table public.v_player_carries to postgres;
grant REFERENCES on table public.v_player_carries to postgres;
grant SELECT on table public.v_player_carries to postgres;
grant TRIGGER on table public.v_player_carries to postgres;
grant TRUNCATE on table public.v_player_carries to postgres;
grant UPDATE on table public.v_player_carries to postgres;
grant DELETE on table public.v_player_carries to service_role;
grant INSERT on table public.v_player_carries to service_role;
grant MAINTAIN on table public.v_player_carries to service_role;
grant REFERENCES on table public.v_player_carries to service_role;
grant SELECT on table public.v_player_carries to service_role;
grant TRIGGER on table public.v_player_carries to service_role;
grant TRUNCATE on table public.v_player_carries to service_role;
grant UPDATE on table public.v_player_carries to service_role;
grant SELECT on table public.v_player_metrics_ext to anon;
grant SELECT on table public.v_player_metrics_ext to authenticated;
grant DELETE on table public.v_player_metrics_ext to postgres;
grant INSERT on table public.v_player_metrics_ext to postgres;
grant MAINTAIN on table public.v_player_metrics_ext to postgres;
grant REFERENCES on table public.v_player_metrics_ext to postgres;
grant SELECT on table public.v_player_metrics_ext to postgres;
grant TRIGGER on table public.v_player_metrics_ext to postgres;
grant TRUNCATE on table public.v_player_metrics_ext to postgres;
grant UPDATE on table public.v_player_metrics_ext to postgres;
grant DELETE on table public.v_player_metrics_ext to service_role;
grant INSERT on table public.v_player_metrics_ext to service_role;
grant MAINTAIN on table public.v_player_metrics_ext to service_role;
grant REFERENCES on table public.v_player_metrics_ext to service_role;
grant SELECT on table public.v_player_metrics_ext to service_role;
grant TRIGGER on table public.v_player_metrics_ext to service_role;
grant TRUNCATE on table public.v_player_metrics_ext to service_role;
grant UPDATE on table public.v_player_metrics_ext to service_role;
grant SELECT on table public.v_player_pct_all to anon;
grant SELECT on table public.v_player_pct_all to authenticated;
grant DELETE on table public.v_player_pct_all to postgres;
grant INSERT on table public.v_player_pct_all to postgres;
grant MAINTAIN on table public.v_player_pct_all to postgres;
grant REFERENCES on table public.v_player_pct_all to postgres;
grant SELECT on table public.v_player_pct_all to postgres;
grant TRIGGER on table public.v_player_pct_all to postgres;
grant TRUNCATE on table public.v_player_pct_all to postgres;
grant UPDATE on table public.v_player_pct_all to postgres;
grant DELETE on table public.v_player_pct_all to service_role;
grant INSERT on table public.v_player_pct_all to service_role;
grant MAINTAIN on table public.v_player_pct_all to service_role;
grant REFERENCES on table public.v_player_pct_all to service_role;
grant SELECT on table public.v_player_pct_all to service_role;
grant TRIGGER on table public.v_player_pct_all to service_role;
grant TRUNCATE on table public.v_player_pct_all to service_role;
grant UPDATE on table public.v_player_pct_all to service_role;
grant SELECT on table public.v_player_receipts to anon;
grant SELECT on table public.v_player_receipts to authenticated;
grant DELETE on table public.v_player_receipts to postgres;
grant INSERT on table public.v_player_receipts to postgres;
grant MAINTAIN on table public.v_player_receipts to postgres;
grant REFERENCES on table public.v_player_receipts to postgres;
grant SELECT on table public.v_player_receipts to postgres;
grant TRIGGER on table public.v_player_receipts to postgres;
grant TRUNCATE on table public.v_player_receipts to postgres;
grant UPDATE on table public.v_player_receipts to postgres;
grant DELETE on table public.v_player_receipts to service_role;
grant INSERT on table public.v_player_receipts to service_role;
grant MAINTAIN on table public.v_player_receipts to service_role;
grant REFERENCES on table public.v_player_receipts to service_role;
grant SELECT on table public.v_player_receipts to service_role;
grant TRIGGER on table public.v_player_receipts to service_role;
grant TRUNCATE on table public.v_player_receipts to service_role;
grant UPDATE on table public.v_player_receipts to service_role;
grant SELECT on table public.v_player_sot_fix to anon;
grant SELECT on table public.v_player_sot_fix to authenticated;
grant DELETE on table public.v_player_sot_fix to postgres;
grant INSERT on table public.v_player_sot_fix to postgres;
grant MAINTAIN on table public.v_player_sot_fix to postgres;
grant REFERENCES on table public.v_player_sot_fix to postgres;
grant SELECT on table public.v_player_sot_fix to postgres;
grant TRIGGER on table public.v_player_sot_fix to postgres;
grant TRUNCATE on table public.v_player_sot_fix to postgres;
grant UPDATE on table public.v_player_sot_fix to postgres;
grant DELETE on table public.v_player_sot_fix to service_role;
grant INSERT on table public.v_player_sot_fix to service_role;
grant MAINTAIN on table public.v_player_sot_fix to service_role;
grant REFERENCES on table public.v_player_sot_fix to service_role;
grant SELECT on table public.v_player_sot_fix to service_role;
grant TRIGGER on table public.v_player_sot_fix to service_role;
grant TRUNCATE on table public.v_player_sot_fix to service_role;
grant UPDATE on table public.v_player_sot_fix to service_role;
grant SELECT on table public.v_player_xt_actions to anon;
grant SELECT on table public.v_player_xt_actions to authenticated;
grant DELETE on table public.v_player_xt_actions to postgres;
grant INSERT on table public.v_player_xt_actions to postgres;
grant MAINTAIN on table public.v_player_xt_actions to postgres;
grant REFERENCES on table public.v_player_xt_actions to postgres;
grant SELECT on table public.v_player_xt_actions to postgres;
grant TRIGGER on table public.v_player_xt_actions to postgres;
grant TRUNCATE on table public.v_player_xt_actions to postgres;
grant UPDATE on table public.v_player_xt_actions to postgres;
grant DELETE on table public.v_player_xt_actions to service_role;
grant INSERT on table public.v_player_xt_actions to service_role;
grant MAINTAIN on table public.v_player_xt_actions to service_role;
grant REFERENCES on table public.v_player_xt_actions to service_role;
grant SELECT on table public.v_player_xt_actions to service_role;
grant TRIGGER on table public.v_player_xt_actions to service_role;
grant TRUNCATE on table public.v_player_xt_actions to service_role;
grant UPDATE on table public.v_player_xt_actions to service_role;
grant SELECT on table public.v_press_profile to anon;
grant SELECT on table public.v_press_profile to authenticated;
grant DELETE on table public.v_press_profile to postgres;
grant INSERT on table public.v_press_profile to postgres;
grant MAINTAIN on table public.v_press_profile to postgres;
grant REFERENCES on table public.v_press_profile to postgres;
grant SELECT on table public.v_press_profile to postgres;
grant TRIGGER on table public.v_press_profile to postgres;
grant TRUNCATE on table public.v_press_profile to postgres;
grant UPDATE on table public.v_press_profile to postgres;
grant DELETE on table public.v_press_profile to service_role;
grant INSERT on table public.v_press_profile to service_role;
grant MAINTAIN on table public.v_press_profile to service_role;
grant REFERENCES on table public.v_press_profile to service_role;
grant SELECT on table public.v_press_profile to service_role;
grant TRIGGER on table public.v_press_profile to service_role;
grant TRUNCATE on table public.v_press_profile to service_role;
grant UPDATE on table public.v_press_profile to service_role;
grant SELECT on table public.v_season_stats to anon;
grant SELECT on table public.v_season_stats to authenticated;
grant DELETE on table public.v_season_stats to postgres;
grant INSERT on table public.v_season_stats to postgres;
grant MAINTAIN on table public.v_season_stats to postgres;
grant REFERENCES on table public.v_season_stats to postgres;
grant SELECT on table public.v_season_stats to postgres;
grant TRIGGER on table public.v_season_stats to postgres;
grant TRUNCATE on table public.v_season_stats to postgres;
grant UPDATE on table public.v_season_stats to postgres;
grant DELETE on table public.v_season_stats to service_role;
grant INSERT on table public.v_season_stats to service_role;
grant MAINTAIN on table public.v_season_stats to service_role;
grant REFERENCES on table public.v_season_stats to service_role;
grant SELECT on table public.v_season_stats to service_role;
grant TRIGGER on table public.v_season_stats to service_role;
grant TRUNCATE on table public.v_season_stats to service_role;
grant UPDATE on table public.v_season_stats to service_role;
grant SELECT on table public.v_seq_directness to anon;
grant SELECT on table public.v_seq_directness to authenticated;
grant DELETE on table public.v_seq_directness to postgres;
grant INSERT on table public.v_seq_directness to postgres;
grant MAINTAIN on table public.v_seq_directness to postgres;
grant REFERENCES on table public.v_seq_directness to postgres;
grant SELECT on table public.v_seq_directness to postgres;
grant TRIGGER on table public.v_seq_directness to postgres;
grant TRUNCATE on table public.v_seq_directness to postgres;
grant UPDATE on table public.v_seq_directness to postgres;
grant DELETE on table public.v_seq_directness to service_role;
grant INSERT on table public.v_seq_directness to service_role;
grant MAINTAIN on table public.v_seq_directness to service_role;
grant REFERENCES on table public.v_seq_directness to service_role;
grant SELECT on table public.v_seq_directness to service_role;
grant TRIGGER on table public.v_seq_directness to service_role;
grant TRUNCATE on table public.v_seq_directness to service_role;
grant UPDATE on table public.v_seq_directness to service_role;
grant SELECT on table public.v_squad_role to anon;
grant SELECT on table public.v_squad_role to authenticated;
grant DELETE on table public.v_squad_role to postgres;
grant INSERT on table public.v_squad_role to postgres;
grant MAINTAIN on table public.v_squad_role to postgres;
grant REFERENCES on table public.v_squad_role to postgres;
grant SELECT on table public.v_squad_role to postgres;
grant TRIGGER on table public.v_squad_role to postgres;
grant TRUNCATE on table public.v_squad_role to postgres;
grant UPDATE on table public.v_squad_role to postgres;
grant DELETE on table public.v_squad_role to service_role;
grant INSERT on table public.v_squad_role to service_role;
grant MAINTAIN on table public.v_squad_role to service_role;
grant REFERENCES on table public.v_squad_role to service_role;
grant SELECT on table public.v_squad_role to service_role;
grant TRIGGER on table public.v_squad_role to service_role;
grant TRUNCATE on table public.v_squad_role to service_role;
grant UPDATE on table public.v_squad_role to service_role;
grant SELECT on table public.v_team_actions to anon;
grant SELECT on table public.v_team_actions to authenticated;
grant DELETE on table public.v_team_actions to postgres;
grant INSERT on table public.v_team_actions to postgres;
grant MAINTAIN on table public.v_team_actions to postgres;
grant REFERENCES on table public.v_team_actions to postgres;
grant SELECT on table public.v_team_actions to postgres;
grant TRIGGER on table public.v_team_actions to postgres;
grant TRUNCATE on table public.v_team_actions to postgres;
grant UPDATE on table public.v_team_actions to postgres;
grant DELETE on table public.v_team_actions to service_role;
grant INSERT on table public.v_team_actions to service_role;
grant MAINTAIN on table public.v_team_actions to service_role;
grant REFERENCES on table public.v_team_actions to service_role;
grant SELECT on table public.v_team_actions to service_role;
grant TRIGGER on table public.v_team_actions to service_role;
grant TRUNCATE on table public.v_team_actions to service_role;
grant UPDATE on table public.v_team_actions to service_role;
grant SELECT on table public.v_team_carries to anon;
grant SELECT on table public.v_team_carries to authenticated;
grant DELETE on table public.v_team_carries to postgres;
grant INSERT on table public.v_team_carries to postgres;
grant MAINTAIN on table public.v_team_carries to postgres;
grant REFERENCES on table public.v_team_carries to postgres;
grant SELECT on table public.v_team_carries to postgres;
grant TRIGGER on table public.v_team_carries to postgres;
grant TRUNCATE on table public.v_team_carries to postgres;
grant UPDATE on table public.v_team_carries to postgres;
grant DELETE on table public.v_team_carries to service_role;
grant INSERT on table public.v_team_carries to service_role;
grant MAINTAIN on table public.v_team_carries to service_role;
grant REFERENCES on table public.v_team_carries to service_role;
grant SELECT on table public.v_team_carries to service_role;
grant TRIGGER on table public.v_team_carries to service_role;
grant TRUNCATE on table public.v_team_carries to service_role;
grant UPDATE on table public.v_team_carries to service_role;
grant SELECT on table public.v_team_directory to anon;
grant SELECT on table public.v_team_directory to authenticated;
grant DELETE on table public.v_team_directory to postgres;
grant INSERT on table public.v_team_directory to postgres;
grant MAINTAIN on table public.v_team_directory to postgres;
grant REFERENCES on table public.v_team_directory to postgres;
grant SELECT on table public.v_team_directory to postgres;
grant TRIGGER on table public.v_team_directory to postgres;
grant TRUNCATE on table public.v_team_directory to postgres;
grant UPDATE on table public.v_team_directory to postgres;
grant DELETE on table public.v_team_directory to service_role;
grant INSERT on table public.v_team_directory to service_role;
grant MAINTAIN on table public.v_team_directory to service_role;
grant REFERENCES on table public.v_team_directory to service_role;
grant SELECT on table public.v_team_directory to service_role;
grant TRIGGER on table public.v_team_directory to service_role;
grant TRUNCATE on table public.v_team_directory to service_role;
grant UPDATE on table public.v_team_directory to service_role;
grant SELECT on table public.v_team_sample to anon;
grant SELECT on table public.v_team_sample to authenticated;
grant DELETE on table public.v_team_sample to postgres;
grant INSERT on table public.v_team_sample to postgres;
grant MAINTAIN on table public.v_team_sample to postgres;
grant REFERENCES on table public.v_team_sample to postgres;
grant SELECT on table public.v_team_sample to postgres;
grant TRIGGER on table public.v_team_sample to postgres;
grant TRUNCATE on table public.v_team_sample to postgres;
grant UPDATE on table public.v_team_sample to postgres;
grant DELETE on table public.v_team_sample to service_role;
grant INSERT on table public.v_team_sample to service_role;
grant MAINTAIN on table public.v_team_sample to service_role;
grant REFERENCES on table public.v_team_sample to service_role;
grant SELECT on table public.v_team_sample to service_role;
grant TRIGGER on table public.v_team_sample to service_role;
grant TRUNCATE on table public.v_team_sample to service_role;
grant UPDATE on table public.v_team_sample to service_role;
grant SELECT on table public.v_team_shots to anon;
grant SELECT on table public.v_team_shots to authenticated;
grant DELETE on table public.v_team_shots to postgres;
grant INSERT on table public.v_team_shots to postgres;
grant MAINTAIN on table public.v_team_shots to postgres;
grant REFERENCES on table public.v_team_shots to postgres;
grant SELECT on table public.v_team_shots to postgres;
grant TRIGGER on table public.v_team_shots to postgres;
grant TRUNCATE on table public.v_team_shots to postgres;
grant UPDATE on table public.v_team_shots to postgres;
grant DELETE on table public.v_team_shots to service_role;
grant INSERT on table public.v_team_shots to service_role;
grant MAINTAIN on table public.v_team_shots to service_role;
grant REFERENCES on table public.v_team_shots to service_role;
grant SELECT on table public.v_team_shots to service_role;
grant TRIGGER on table public.v_team_shots to service_role;
grant TRUNCATE on table public.v_team_shots to service_role;
grant UPDATE on table public.v_team_shots to service_role;
grant SELECT on table public.v_team_signature to anon;
grant SELECT on table public.v_team_signature to authenticated;
grant DELETE on table public.v_team_signature to postgres;
grant INSERT on table public.v_team_signature to postgres;
grant MAINTAIN on table public.v_team_signature to postgres;
grant REFERENCES on table public.v_team_signature to postgres;
grant SELECT on table public.v_team_signature to postgres;
grant TRIGGER on table public.v_team_signature to postgres;
grant TRUNCATE on table public.v_team_signature to postgres;
grant UPDATE on table public.v_team_signature to postgres;
grant DELETE on table public.v_team_signature to service_role;
grant INSERT on table public.v_team_signature to service_role;
grant MAINTAIN on table public.v_team_signature to service_role;
grant REFERENCES on table public.v_team_signature to service_role;
grant SELECT on table public.v_team_signature to service_role;
grant TRIGGER on table public.v_team_signature to service_role;
grant TRUNCATE on table public.v_team_signature to service_role;
grant UPDATE on table public.v_team_signature to service_role;
grant SELECT on table public.v_xg_model_support to anon;
grant SELECT on table public.v_xg_model_support to authenticated;
grant DELETE on table public.v_xg_model_support to postgres;
grant INSERT on table public.v_xg_model_support to postgres;
grant MAINTAIN on table public.v_xg_model_support to postgres;
grant REFERENCES on table public.v_xg_model_support to postgres;
grant SELECT on table public.v_xg_model_support to postgres;
grant TRIGGER on table public.v_xg_model_support to postgres;
grant TRUNCATE on table public.v_xg_model_support to postgres;
grant UPDATE on table public.v_xg_model_support to postgres;
grant DELETE on table public.v_xg_model_support to service_role;
grant INSERT on table public.v_xg_model_support to service_role;
grant MAINTAIN on table public.v_xg_model_support to service_role;
grant REFERENCES on table public.v_xg_model_support to service_role;
grant SELECT on table public.v_xg_model_support to service_role;
grant TRIGGER on table public.v_xg_model_support to service_role;
grant TRUNCATE on table public.v_xg_model_support to service_role;
grant UPDATE on table public.v_xg_model_support to service_role;
grant SELECT on table public.v_xg_temporal_holdout to anon;
grant SELECT on table public.v_xg_temporal_holdout to authenticated;
grant DELETE on table public.v_xg_temporal_holdout to postgres;
grant INSERT on table public.v_xg_temporal_holdout to postgres;
grant MAINTAIN on table public.v_xg_temporal_holdout to postgres;
grant REFERENCES on table public.v_xg_temporal_holdout to postgres;
grant SELECT on table public.v_xg_temporal_holdout to postgres;
grant TRIGGER on table public.v_xg_temporal_holdout to postgres;
grant TRUNCATE on table public.v_xg_temporal_holdout to postgres;
grant UPDATE on table public.v_xg_temporal_holdout to postgres;
grant DELETE on table public.v_xg_temporal_holdout to service_role;
grant INSERT on table public.v_xg_temporal_holdout to service_role;
grant MAINTAIN on table public.v_xg_temporal_holdout to service_role;
grant REFERENCES on table public.v_xg_temporal_holdout to service_role;
grant SELECT on table public.v_xg_temporal_holdout to service_role;
grant TRIGGER on table public.v_xg_temporal_holdout to service_role;
grant TRUNCATE on table public.v_xg_temporal_holdout to service_role;
grant UPDATE on table public.v_xg_temporal_holdout to service_role;
grant SELECT on table public.v_xt_model_status to anon;
grant SELECT on table public.v_xt_model_status to authenticated;
grant DELETE on table public.v_xt_model_status to postgres;
grant INSERT on table public.v_xt_model_status to postgres;
grant MAINTAIN on table public.v_xt_model_status to postgres;
grant REFERENCES on table public.v_xt_model_status to postgres;
grant SELECT on table public.v_xt_model_status to postgres;
grant TRIGGER on table public.v_xt_model_status to postgres;
grant TRUNCATE on table public.v_xt_model_status to postgres;
grant UPDATE on table public.v_xt_model_status to postgres;
grant DELETE on table public.v_xt_model_status to service_role;
grant INSERT on table public.v_xt_model_status to service_role;
grant MAINTAIN on table public.v_xt_model_status to service_role;
grant REFERENCES on table public.v_xt_model_status to service_role;
grant SELECT on table public.v_xt_model_status to service_role;
grant TRIGGER on table public.v_xt_model_status to service_role;
grant TRUNCATE on table public.v_xt_model_status to service_role;
grant UPDATE on table public.v_xt_model_status to service_role;
grant SELECT on table public.xt_grid to anon;
grant SELECT on table public.xt_grid to authenticated;
grant DELETE on table public.xt_grid to postgres;
grant INSERT on table public.xt_grid to postgres;
grant MAINTAIN on table public.xt_grid to postgres;
grant REFERENCES on table public.xt_grid to postgres;
grant SELECT on table public.xt_grid to postgres;
grant TRIGGER on table public.xt_grid to postgres;
grant TRUNCATE on table public.xt_grid to postgres;
grant UPDATE on table public.xt_grid to postgres;
grant DELETE on table public.xt_grid to service_role;
grant INSERT on table public.xt_grid to service_role;
grant MAINTAIN on table public.xt_grid to service_role;
grant REFERENCES on table public.xt_grid to service_role;
grant SELECT on table public.xt_grid to service_role;
grant TRIGGER on table public.xt_grid to service_role;
grant TRUNCATE on table public.xt_grid to service_role;
grant UPDATE on table public.xt_grid to service_role;
grant EXECUTE on function analytics_rebuild_run_status(uuid) to postgres;
grant EXECUTE on function analytics_rebuild_run_status(uuid) to service_role;
grant EXECUTE on function build_insights_extra() to postgres;
grant EXECUTE on function build_insights_extra() to service_role;
grant EXECUTE on function build_insights_players() to postgres;
grant EXECUTE on function build_insights_players() to service_role;
grant EXECUTE on function build_insights() to postgres;
grant EXECUTE on function build_insights() to service_role;
grant EXECUTE on function build_player_chain_roles() to postgres;
grant EXECUTE on function build_player_chain_roles() to service_role;
grant EXECUTE on function build_press_insights() to postgres;
grant EXECUTE on function build_press_insights() to service_role;
grant EXECUTE on function build_reactivity_insights() to postgres;
grant EXECUTE on function build_reactivity_insights() to service_role;
grant EXECUTE on function build_sequences() to postgres;
grant EXECUTE on function build_sequences() to service_role;
grant EXECUTE on function build_team_profile_insights() to postgres;
grant EXECUTE on function build_team_profile_insights() to service_role;
grant EXECUTE on function comparison_scopes() to PUBLIC;
grant EXECUTE on function comparison_scopes() to anon;
grant EXECUTE on function comparison_scopes() to authenticated;
grant EXECUTE on function comparison_scopes() to postgres;
grant EXECUTE on function comparison_scopes() to service_role;
grant EXECUTE on function create_analytics_rebuild_run(uuid,text) to postgres;
grant EXECUTE on function create_analytics_rebuild_run(uuid,text) to service_role;
grant EXECUTE on function detector_min_denominator(text) to PUBLIC;
grant EXECUTE on function detector_min_denominator(text) to anon;
grant EXECUTE on function detector_min_denominator(text) to authenticated;
grant EXECUTE on function detector_min_denominator(text) to postgres;
grant EXECUTE on function detector_min_denominator(text) to service_role;
grant EXECUTE on function detector_min_matches(text) to PUBLIC;
grant EXECUTE on function detector_min_matches(text) to anon;
grant EXECUTE on function detector_min_matches(text) to authenticated;
grant EXECUTE on function detector_min_matches(text) to postgres;
grant EXECUTE on function detector_min_matches(text) to service_role;
grant EXECUTE on function get_starter_names(text) to PUBLIC;
grant EXECUTE on function get_starter_names(text) to anon;
grant EXECUTE on function get_starter_names(text) to authenticated;
grant EXECUTE on function get_starter_names(text) to postgres;
grant EXECUTE on function get_starter_names(text) to service_role;
grant EXECUTE on function gin_extract_query_trgm(text,internal,smallint,internal,internal,internal,internal) to PUBLIC;
grant EXECUTE on function gin_extract_query_trgm(text,internal,smallint,internal,internal,internal,internal) to anon;
grant EXECUTE on function gin_extract_query_trgm(text,internal,smallint,internal,internal,internal,internal) to authenticated;
grant EXECUTE on function gin_extract_query_trgm(text,internal,smallint,internal,internal,internal,internal) to postgres;
grant EXECUTE on function gin_extract_query_trgm(text,internal,smallint,internal,internal,internal,internal) to service_role;
grant EXECUTE on function gin_extract_query_trgm(text,internal,smallint,internal,internal,internal,internal) to supabase_admin;
grant EXECUTE on function gin_extract_value_trgm(text,internal) to PUBLIC;
grant EXECUTE on function gin_extract_value_trgm(text,internal) to anon;
grant EXECUTE on function gin_extract_value_trgm(text,internal) to authenticated;
grant EXECUTE on function gin_extract_value_trgm(text,internal) to postgres;
grant EXECUTE on function gin_extract_value_trgm(text,internal) to service_role;
grant EXECUTE on function gin_extract_value_trgm(text,internal) to supabase_admin;
grant EXECUTE on function gin_trgm_consistent(internal,smallint,text,integer,internal,internal,internal,internal) to PUBLIC;
grant EXECUTE on function gin_trgm_consistent(internal,smallint,text,integer,internal,internal,internal,internal) to anon;
grant EXECUTE on function gin_trgm_consistent(internal,smallint,text,integer,internal,internal,internal,internal) to authenticated;
grant EXECUTE on function gin_trgm_consistent(internal,smallint,text,integer,internal,internal,internal,internal) to postgres;
grant EXECUTE on function gin_trgm_consistent(internal,smallint,text,integer,internal,internal,internal,internal) to service_role;
grant EXECUTE on function gin_trgm_consistent(internal,smallint,text,integer,internal,internal,internal,internal) to supabase_admin;
grant EXECUTE on function gin_trgm_triconsistent(internal,smallint,text,integer,internal,internal,internal) to PUBLIC;
grant EXECUTE on function gin_trgm_triconsistent(internal,smallint,text,integer,internal,internal,internal) to anon;
grant EXECUTE on function gin_trgm_triconsistent(internal,smallint,text,integer,internal,internal,internal) to authenticated;
grant EXECUTE on function gin_trgm_triconsistent(internal,smallint,text,integer,internal,internal,internal) to postgres;
grant EXECUTE on function gin_trgm_triconsistent(internal,smallint,text,integer,internal,internal,internal) to service_role;
grant EXECUTE on function gin_trgm_triconsistent(internal,smallint,text,integer,internal,internal,internal) to supabase_admin;
grant EXECUTE on function gtrgm_compress(internal) to PUBLIC;
grant EXECUTE on function gtrgm_compress(internal) to anon;
grant EXECUTE on function gtrgm_compress(internal) to authenticated;
grant EXECUTE on function gtrgm_compress(internal) to postgres;
grant EXECUTE on function gtrgm_compress(internal) to service_role;
grant EXECUTE on function gtrgm_compress(internal) to supabase_admin;
grant EXECUTE on function gtrgm_consistent(internal,text,smallint,oid,internal) to PUBLIC;
grant EXECUTE on function gtrgm_consistent(internal,text,smallint,oid,internal) to anon;
grant EXECUTE on function gtrgm_consistent(internal,text,smallint,oid,internal) to authenticated;
grant EXECUTE on function gtrgm_consistent(internal,text,smallint,oid,internal) to postgres;
grant EXECUTE on function gtrgm_consistent(internal,text,smallint,oid,internal) to service_role;
grant EXECUTE on function gtrgm_consistent(internal,text,smallint,oid,internal) to supabase_admin;
grant EXECUTE on function gtrgm_decompress(internal) to PUBLIC;
grant EXECUTE on function gtrgm_decompress(internal) to anon;
grant EXECUTE on function gtrgm_decompress(internal) to authenticated;
grant EXECUTE on function gtrgm_decompress(internal) to postgres;
grant EXECUTE on function gtrgm_decompress(internal) to service_role;
grant EXECUTE on function gtrgm_decompress(internal) to supabase_admin;
grant EXECUTE on function gtrgm_distance(internal,text,smallint,oid,internal) to PUBLIC;
grant EXECUTE on function gtrgm_distance(internal,text,smallint,oid,internal) to anon;
grant EXECUTE on function gtrgm_distance(internal,text,smallint,oid,internal) to authenticated;
grant EXECUTE on function gtrgm_distance(internal,text,smallint,oid,internal) to postgres;
grant EXECUTE on function gtrgm_distance(internal,text,smallint,oid,internal) to service_role;
grant EXECUTE on function gtrgm_distance(internal,text,smallint,oid,internal) to supabase_admin;
grant EXECUTE on function gtrgm_in(cstring) to PUBLIC;
grant EXECUTE on function gtrgm_in(cstring) to anon;
grant EXECUTE on function gtrgm_in(cstring) to authenticated;
grant EXECUTE on function gtrgm_in(cstring) to postgres;
grant EXECUTE on function gtrgm_in(cstring) to service_role;
grant EXECUTE on function gtrgm_in(cstring) to supabase_admin;
grant EXECUTE on function gtrgm_options(internal) to PUBLIC;
grant EXECUTE on function gtrgm_options(internal) to anon;
grant EXECUTE on function gtrgm_options(internal) to authenticated;
grant EXECUTE on function gtrgm_options(internal) to postgres;
grant EXECUTE on function gtrgm_options(internal) to service_role;
grant EXECUTE on function gtrgm_options(internal) to supabase_admin;
grant EXECUTE on function gtrgm_out(gtrgm) to PUBLIC;
grant EXECUTE on function gtrgm_out(gtrgm) to anon;
grant EXECUTE on function gtrgm_out(gtrgm) to authenticated;
grant EXECUTE on function gtrgm_out(gtrgm) to postgres;
grant EXECUTE on function gtrgm_out(gtrgm) to service_role;
grant EXECUTE on function gtrgm_out(gtrgm) to supabase_admin;
grant EXECUTE on function gtrgm_penalty(internal,internal,internal) to PUBLIC;
grant EXECUTE on function gtrgm_penalty(internal,internal,internal) to anon;
grant EXECUTE on function gtrgm_penalty(internal,internal,internal) to authenticated;
grant EXECUTE on function gtrgm_penalty(internal,internal,internal) to postgres;
grant EXECUTE on function gtrgm_penalty(internal,internal,internal) to service_role;
grant EXECUTE on function gtrgm_penalty(internal,internal,internal) to supabase_admin;
grant EXECUTE on function gtrgm_picksplit(internal,internal) to PUBLIC;
grant EXECUTE on function gtrgm_picksplit(internal,internal) to anon;
grant EXECUTE on function gtrgm_picksplit(internal,internal) to authenticated;
grant EXECUTE on function gtrgm_picksplit(internal,internal) to postgres;
grant EXECUTE on function gtrgm_picksplit(internal,internal) to service_role;
grant EXECUTE on function gtrgm_picksplit(internal,internal) to supabase_admin;
grant EXECUTE on function gtrgm_same(gtrgm,gtrgm,internal) to PUBLIC;
grant EXECUTE on function gtrgm_same(gtrgm,gtrgm,internal) to anon;
grant EXECUTE on function gtrgm_same(gtrgm,gtrgm,internal) to authenticated;
grant EXECUTE on function gtrgm_same(gtrgm,gtrgm,internal) to postgres;
grant EXECUTE on function gtrgm_same(gtrgm,gtrgm,internal) to service_role;
grant EXECUTE on function gtrgm_same(gtrgm,gtrgm,internal) to supabase_admin;
grant EXECUTE on function gtrgm_union(internal,internal) to PUBLIC;
grant EXECUTE on function gtrgm_union(internal,internal) to anon;
grant EXECUTE on function gtrgm_union(internal,internal) to authenticated;
grant EXECUTE on function gtrgm_union(internal,internal) to postgres;
grant EXECUTE on function gtrgm_union(internal,internal) to service_role;
grant EXECUTE on function gtrgm_union(internal,internal) to supabase_admin;
grant EXECUTE on function lafc_events_list(text) to PUBLIC;
grant EXECUTE on function lafc_events_list(text) to anon;
grant EXECUTE on function lafc_events_list(text) to authenticated;
grant EXECUTE on function lafc_events_list(text) to postgres;
grant EXECUTE on function lafc_events_list(text) to service_role;
grant EXECUTE on function lafc_links_delete(text,uuid) to PUBLIC;
grant EXECUTE on function lafc_links_delete(text,uuid) to anon;
grant EXECUTE on function lafc_links_delete(text,uuid) to authenticated;
grant EXECUTE on function lafc_links_delete(text,uuid) to postgres;
grant EXECUTE on function lafc_links_delete(text,uuid) to service_role;
grant EXECUTE on function lafc_links_list(text) to PUBLIC;
grant EXECUTE on function lafc_links_list(text) to anon;
grant EXECUTE on function lafc_links_list(text) to authenticated;
grant EXECUTE on function lafc_links_list(text) to postgres;
grant EXECUTE on function lafc_links_list(text) to service_role;
grant EXECUTE on function lafc_links_save(text,uuid,text,text,integer) to PUBLIC;
grant EXECUTE on function lafc_links_save(text,uuid,text,text,integer) to anon;
grant EXECUTE on function lafc_links_save(text,uuid,text,text,integer) to authenticated;
grant EXECUTE on function lafc_links_save(text,uuid,text,text,integer) to postgres;
grant EXECUTE on function lafc_links_save(text,uuid,text,text,integer) to service_role;
grant EXECUTE on function lafc_projects_delete(text,uuid) to PUBLIC;
grant EXECUTE on function lafc_projects_delete(text,uuid) to anon;
grant EXECUTE on function lafc_projects_delete(text,uuid) to authenticated;
grant EXECUTE on function lafc_projects_delete(text,uuid) to postgres;
grant EXECUTE on function lafc_projects_delete(text,uuid) to service_role;
grant EXECUTE on function lafc_projects_list(text) to PUBLIC;
grant EXECUTE on function lafc_projects_list(text) to anon;
grant EXECUTE on function lafc_projects_list(text) to authenticated;
grant EXECUTE on function lafc_projects_list(text) to postgres;
grant EXECUTE on function lafc_projects_list(text) to service_role;
grant EXECUTE on function lafc_projects_save(text,uuid,text,text,text,text,text,integer,date,text,jsonb) to PUBLIC;
grant EXECUTE on function lafc_projects_save(text,uuid,text,text,text,text,text,integer,date,text,jsonb) to anon;
grant EXECUTE on function lafc_projects_save(text,uuid,text,text,text,text,text,integer,date,text,jsonb) to authenticated;
grant EXECUTE on function lafc_projects_save(text,uuid,text,text,text,text,text,integer,date,text,jsonb) to postgres;
grant EXECUTE on function lafc_projects_save(text,uuid,text,text,text,text,text,integer,date,text,jsonb) to service_role;
grant EXECUTE on function lafc_projects_touch() to PUBLIC;
grant EXECUTE on function lafc_projects_touch() to anon;
grant EXECUTE on function lafc_projects_touch() to authenticated;
grant EXECUTE on function lafc_projects_touch() to postgres;
grant EXECUTE on function lafc_projects_touch() to service_role;
grant EXECUTE on function lafc_todos_clear_done(text) to PUBLIC;
grant EXECUTE on function lafc_todos_clear_done(text) to anon;
grant EXECUTE on function lafc_todos_clear_done(text) to authenticated;
grant EXECUTE on function lafc_todos_clear_done(text) to postgres;
grant EXECUTE on function lafc_todos_clear_done(text) to service_role;
grant EXECUTE on function lafc_todos_delete(text,uuid) to PUBLIC;
grant EXECUTE on function lafc_todos_delete(text,uuid) to anon;
grant EXECUTE on function lafc_todos_delete(text,uuid) to authenticated;
grant EXECUTE on function lafc_todos_delete(text,uuid) to postgres;
grant EXECUTE on function lafc_todos_delete(text,uuid) to service_role;
grant EXECUTE on function lafc_todos_list(text) to PUBLIC;
grant EXECUTE on function lafc_todos_list(text) to anon;
grant EXECUTE on function lafc_todos_list(text) to authenticated;
grant EXECUTE on function lafc_todos_list(text) to postgres;
grant EXECUTE on function lafc_todos_list(text) to service_role;
grant EXECUTE on function lafc_todos_save(text,uuid,text,boolean,integer) to PUBLIC;
grant EXECUTE on function lafc_todos_save(text,uuid,text,boolean,integer) to anon;
grant EXECUTE on function lafc_todos_save(text,uuid,text,boolean,integer) to authenticated;
grant EXECUTE on function lafc_todos_save(text,uuid,text,boolean,integer) to postgres;
grant EXECUTE on function lafc_todos_save(text,uuid,text,boolean,integer) to service_role;
grant EXECUTE on function lafc_tracker_auth(text) to PUBLIC;
grant EXECUTE on function lafc_tracker_auth(text) to anon;
grant EXECUTE on function lafc_tracker_auth(text) to authenticated;
grant EXECUTE on function lafc_tracker_auth(text) to postgres;
grant EXECUTE on function lafc_tracker_auth(text) to service_role;
grant EXECUTE on function nl_query(text,integer) to PUBLIC;
grant EXECUTE on function nl_query(text,integer) to anon;
grant EXECUTE on function nl_query(text,integer) to authenticated;
grant EXECUTE on function nl_query(text,integer) to postgres;
grant EXECUTE on function nl_query(text,integer) to service_role;
grant EXECUTE on function player_card_scoped(text,text[]) to PUBLIC;
grant EXECUTE on function player_card_scoped(text,text[]) to anon;
grant EXECUTE on function player_card_scoped(text,text[]) to authenticated;
grant EXECUTE on function player_card_scoped(text,text[]) to postgres;
grant EXECUTE on function player_card_scoped(text,text[]) to service_role;
grant EXECUTE on function player_card(text) to PUBLIC;
grant EXECUTE on function player_card(text) to anon;
grant EXECUTE on function player_card(text) to authenticated;
grant EXECUTE on function player_card(text) to postgres;
grant EXECUTE on function player_card(text) to service_role;
grant EXECUTE on function player_metric_events(text,text,integer) to PUBLIC;
grant EXECUTE on function player_metric_events(text,text,integer) to anon;
grant EXECUTE on function player_metric_events(text,text,integer) to authenticated;
grant EXECUTE on function player_metric_events(text,text,integer) to postgres;
grant EXECUTE on function player_metric_events(text,text,integer) to service_role;
grant EXECUTE on function player_pct_scoped(text,text[],text[]) to PUBLIC;
grant EXECUTE on function player_pct_scoped(text,text[],text[]) to anon;
grant EXECUTE on function player_pct_scoped(text,text[],text[]) to authenticated;
grant EXECUTE on function player_pct_scoped(text,text[],text[]) to postgres;
grant EXECUTE on function player_pct_scoped(text,text[],text[]) to service_role;
grant EXECUTE on function player_xt_map(text,text,boolean,integer) to PUBLIC;
grant EXECUTE on function player_xt_map(text,text,boolean,integer) to anon;
grant EXECUTE on function player_xt_map(text,text,boolean,integer) to authenticated;
grant EXECUTE on function player_xt_map(text,text,boolean,integer) to postgres;
grant EXECUTE on function player_xt_map(text,text,boolean,integer) to service_role;
grant EXECUTE on function polish_insights() to postgres;
grant EXECUTE on function polish_insights() to service_role;
grant EXECUTE on function preflight_league(text) to postgres;
grant EXECUTE on function preflight_league(text) to service_role;
grant EXECUTE on function pretty_metric(text) to PUBLIC;
grant EXECUTE on function pretty_metric(text) to anon;
grant EXECUTE on function pretty_metric(text) to authenticated;
grant EXECUTE on function pretty_metric(text) to postgres;
grant EXECUTE on function pretty_metric(text) to service_role;
grant EXECUTE on function process_analytics_rebuild_queue() to postgres;
grant EXECUTE on function process_analytics_rebuild_queue() to service_role;
grant EXECUTE on function rebuild_all_verified(uuid,text,text) to postgres;
grant EXECUTE on function rebuild_all_verified(uuid,text,text) to service_role;
grant EXECUTE on function rebuild_all() to postgres;
grant EXECUTE on function rebuild_all() to service_role;
grant EXECUTE on function rebuild_step(text,text) to postgres;
grant EXECUTE on function rebuild_step(text,text) to service_role;
grant EXECUTE on function rebuild_team_names(text) to postgres;
grant EXECUTE on function rebuild_team_names(text) to service_role;
grant EXECUTE on function refresh_analytics_batch(integer) to postgres;
grant EXECUTE on function refresh_analytics_batch(integer) to service_role;
grant EXECUTE on function refresh_analytics() to postgres;
grant EXECUTE on function refresh_analytics() to service_role;
grant EXECUTE on function refresh_site_summaries() to postgres;
grant EXECUTE on function refresh_site_summaries() to service_role;
grant EXECUTE on function resolve_player(text) to PUBLIC;
grant EXECUTE on function resolve_player(text) to anon;
grant EXECUTE on function resolve_player(text) to authenticated;
grant EXECUTE on function resolve_player(text) to postgres;
grant EXECUTE on function resolve_player(text) to service_role;
grant EXECUTE on function run_invariants() to postgres;
grant EXECUTE on function run_invariants() to service_role;
grant EXECUTE on function set_limit(real) to PUBLIC;
grant EXECUTE on function set_limit(real) to anon;
grant EXECUTE on function set_limit(real) to authenticated;
grant EXECUTE on function set_limit(real) to postgres;
grant EXECUTE on function set_limit(real) to service_role;
grant EXECUTE on function set_limit(real) to supabase_admin;
grant EXECUTE on function show_limit() to PUBLIC;
grant EXECUTE on function show_limit() to anon;
grant EXECUTE on function show_limit() to authenticated;
grant EXECUTE on function show_limit() to postgres;
grant EXECUTE on function show_limit() to service_role;
grant EXECUTE on function show_limit() to supabase_admin;
grant EXECUTE on function show_trgm(text) to PUBLIC;
grant EXECUTE on function show_trgm(text) to anon;
grant EXECUTE on function show_trgm(text) to authenticated;
grant EXECUTE on function show_trgm(text) to postgres;
grant EXECUTE on function show_trgm(text) to service_role;
grant EXECUTE on function show_trgm(text) to supabase_admin;
grant EXECUTE on function similar_players_chain(text,integer) to PUBLIC;
grant EXECUTE on function similar_players_chain(text,integer) to anon;
grant EXECUTE on function similar_players_chain(text,integer) to authenticated;
grant EXECUTE on function similar_players_chain(text,integer) to postgres;
grant EXECUTE on function similar_players_chain(text,integer) to service_role;
grant EXECUTE on function similar_players_full(text,integer,text[]) to PUBLIC;
grant EXECUTE on function similar_players_full(text,integer,text[]) to anon;
grant EXECUTE on function similar_players_full(text,integer,text[]) to authenticated;
grant EXECUTE on function similar_players_full(text,integer,text[]) to postgres;
grant EXECUTE on function similar_players_full(text,integer,text[]) to service_role;
grant EXECUTE on function similar_sequences(text,integer) to PUBLIC;
grant EXECUTE on function similar_sequences(text,integer) to anon;
grant EXECUTE on function similar_sequences(text,integer) to authenticated;
grant EXECUTE on function similar_sequences(text,integer) to postgres;
grant EXECUTE on function similar_sequences(text,integer) to service_role;
grant EXECUTE on function similar_teams(text,integer) to PUBLIC;
grant EXECUTE on function similar_teams(text,integer) to anon;
grant EXECUTE on function similar_teams(text,integer) to authenticated;
grant EXECUTE on function similar_teams(text,integer) to postgres;
grant EXECUTE on function similar_teams(text,integer) to service_role;
grant EXECUTE on function similarity_dist(text,text) to PUBLIC;
grant EXECUTE on function similarity_dist(text,text) to anon;
grant EXECUTE on function similarity_dist(text,text) to authenticated;
grant EXECUTE on function similarity_dist(text,text) to postgres;
grant EXECUTE on function similarity_dist(text,text) to service_role;
grant EXECUTE on function similarity_dist(text,text) to supabase_admin;
grant EXECUTE on function similarity_op(text,text) to PUBLIC;
grant EXECUTE on function similarity_op(text,text) to anon;
grant EXECUTE on function similarity_op(text,text) to authenticated;
grant EXECUTE on function similarity_op(text,text) to postgres;
grant EXECUTE on function similarity_op(text,text) to service_role;
grant EXECUTE on function similarity_op(text,text) to supabase_admin;
grant EXECUTE on function similarity(text,text) to PUBLIC;
grant EXECUTE on function similarity(text,text) to anon;
grant EXECUTE on function similarity(text,text) to authenticated;
grant EXECUTE on function similarity(text,text) to postgres;
grant EXECUTE on function similarity(text,text) to service_role;
grant EXECUTE on function similarity(text,text) to supabase_admin;
grant EXECUTE on function stamp_sequence_leagues() to postgres;
grant EXECUTE on function stamp_sequence_leagues() to service_role;
grant EXECUTE on function state_weight(numeric) to PUBLIC;
grant EXECUTE on function state_weight(numeric) to anon;
grant EXECUTE on function state_weight(numeric) to authenticated;
grant EXECUTE on function state_weight(numeric) to postgres;
grant EXECUTE on function state_weight(numeric) to service_role;
grant EXECUTE on function strict_word_similarity_commutator_op(text,text) to PUBLIC;
grant EXECUTE on function strict_word_similarity_commutator_op(text,text) to anon;
grant EXECUTE on function strict_word_similarity_commutator_op(text,text) to authenticated;
grant EXECUTE on function strict_word_similarity_commutator_op(text,text) to postgres;
grant EXECUTE on function strict_word_similarity_commutator_op(text,text) to service_role;
grant EXECUTE on function strict_word_similarity_commutator_op(text,text) to supabase_admin;
grant EXECUTE on function strict_word_similarity_dist_commutator_op(text,text) to PUBLIC;
grant EXECUTE on function strict_word_similarity_dist_commutator_op(text,text) to anon;
grant EXECUTE on function strict_word_similarity_dist_commutator_op(text,text) to authenticated;
grant EXECUTE on function strict_word_similarity_dist_commutator_op(text,text) to postgres;
grant EXECUTE on function strict_word_similarity_dist_commutator_op(text,text) to service_role;
grant EXECUTE on function strict_word_similarity_dist_commutator_op(text,text) to supabase_admin;
grant EXECUTE on function strict_word_similarity_dist_op(text,text) to PUBLIC;
grant EXECUTE on function strict_word_similarity_dist_op(text,text) to anon;
grant EXECUTE on function strict_word_similarity_dist_op(text,text) to authenticated;
grant EXECUTE on function strict_word_similarity_dist_op(text,text) to postgres;
grant EXECUTE on function strict_word_similarity_dist_op(text,text) to service_role;
grant EXECUTE on function strict_word_similarity_dist_op(text,text) to supabase_admin;
grant EXECUTE on function strict_word_similarity_op(text,text) to PUBLIC;
grant EXECUTE on function strict_word_similarity_op(text,text) to anon;
grant EXECUTE on function strict_word_similarity_op(text,text) to authenticated;
grant EXECUTE on function strict_word_similarity_op(text,text) to postgres;
grant EXECUTE on function strict_word_similarity_op(text,text) to service_role;
grant EXECUTE on function strict_word_similarity_op(text,text) to supabase_admin;
grant EXECUTE on function strict_word_similarity(text,text) to PUBLIC;
grant EXECUTE on function strict_word_similarity(text,text) to anon;
grant EXECUTE on function strict_word_similarity(text,text) to authenticated;
grant EXECUTE on function strict_word_similarity(text,text) to postgres;
grant EXECUTE on function strict_word_similarity(text,text) to service_role;
grant EXECUTE on function strict_word_similarity(text,text) to supabase_admin;
grant EXECUTE on function suppress_low_sample_insights() to postgres;
grant EXECUTE on function suppress_low_sample_insights() to service_role;
grant EXECUTE on function top_sequences_by_type(text,integer) to PUBLIC;
grant EXECUTE on function top_sequences_by_type(text,integer) to anon;
grant EXECUTE on function top_sequences_by_type(text,integer) to authenticated;
grant EXECUTE on function top_sequences_by_type(text,integer) to postgres;
grant EXECUTE on function top_sequences_by_type(text,integer) to service_role;
grant EXECUTE on function unaccent_init(internal) to PUBLIC;
grant EXECUTE on function unaccent_init(internal) to anon;
grant EXECUTE on function unaccent_init(internal) to authenticated;
grant EXECUTE on function unaccent_init(internal) to postgres;
grant EXECUTE on function unaccent_init(internal) to service_role;
grant EXECUTE on function unaccent_init(internal) to supabase_admin;
grant EXECUTE on function unaccent_lexize(internal,internal,internal,internal) to PUBLIC;
grant EXECUTE on function unaccent_lexize(internal,internal,internal,internal) to anon;
grant EXECUTE on function unaccent_lexize(internal,internal,internal,internal) to authenticated;
grant EXECUTE on function unaccent_lexize(internal,internal,internal,internal) to postgres;
grant EXECUTE on function unaccent_lexize(internal,internal,internal,internal) to service_role;
grant EXECUTE on function unaccent_lexize(internal,internal,internal,internal) to supabase_admin;
grant EXECUTE on function unaccent(regdictionary,text) to PUBLIC;
grant EXECUTE on function unaccent(regdictionary,text) to anon;
grant EXECUTE on function unaccent(regdictionary,text) to authenticated;
grant EXECUTE on function unaccent(regdictionary,text) to postgres;
grant EXECUTE on function unaccent(regdictionary,text) to service_role;
grant EXECUTE on function unaccent(regdictionary,text) to supabase_admin;
grant EXECUTE on function unaccent(text) to PUBLIC;
grant EXECUTE on function unaccent(text) to anon;
grant EXECUTE on function unaccent(text) to authenticated;
grant EXECUTE on function unaccent(text) to postgres;
grant EXECUTE on function unaccent(text) to service_role;
grant EXECUTE on function unaccent(text) to supabase_admin;
grant EXECUTE on function verify_rebuild() to postgres;
grant EXECUTE on function verify_rebuild() to service_role;
grant EXECUTE on function word_similarity_commutator_op(text,text) to PUBLIC;
grant EXECUTE on function word_similarity_commutator_op(text,text) to anon;
grant EXECUTE on function word_similarity_commutator_op(text,text) to authenticated;
grant EXECUTE on function word_similarity_commutator_op(text,text) to postgres;
grant EXECUTE on function word_similarity_commutator_op(text,text) to service_role;
grant EXECUTE on function word_similarity_commutator_op(text,text) to supabase_admin;
grant EXECUTE on function word_similarity_dist_commutator_op(text,text) to PUBLIC;
grant EXECUTE on function word_similarity_dist_commutator_op(text,text) to anon;
grant EXECUTE on function word_similarity_dist_commutator_op(text,text) to authenticated;
grant EXECUTE on function word_similarity_dist_commutator_op(text,text) to postgres;
grant EXECUTE on function word_similarity_dist_commutator_op(text,text) to service_role;
grant EXECUTE on function word_similarity_dist_commutator_op(text,text) to supabase_admin;
grant EXECUTE on function word_similarity_dist_op(text,text) to PUBLIC;
grant EXECUTE on function word_similarity_dist_op(text,text) to anon;
grant EXECUTE on function word_similarity_dist_op(text,text) to authenticated;
grant EXECUTE on function word_similarity_dist_op(text,text) to postgres;
grant EXECUTE on function word_similarity_dist_op(text,text) to service_role;
grant EXECUTE on function word_similarity_dist_op(text,text) to supabase_admin;
grant EXECUTE on function word_similarity_op(text,text) to PUBLIC;
grant EXECUTE on function word_similarity_op(text,text) to anon;
grant EXECUTE on function word_similarity_op(text,text) to authenticated;
grant EXECUTE on function word_similarity_op(text,text) to postgres;
grant EXECUTE on function word_similarity_op(text,text) to service_role;
grant EXECUTE on function word_similarity_op(text,text) to supabase_admin;
grant EXECUTE on function word_similarity(text,text) to PUBLIC;
grant EXECUTE on function word_similarity(text,text) to anon;
grant EXECUTE on function word_similarity(text,text) to authenticated;
grant EXECUTE on function word_similarity(text,text) to postgres;
grant EXECUTE on function word_similarity(text,text) to service_role;
grant EXECUTE on function word_similarity(text,text) to supabase_admin;
grant EXECUTE on function write_insight_notes() to postgres;
grant EXECUTE on function write_insight_notes() to service_role;
grant EXECUTE on function xt_at(double precision,double precision) to PUBLIC;
grant EXECUTE on function xt_at(double precision,double precision) to anon;
grant EXECUTE on function xt_at(double precision,double precision) to authenticated;
grant EXECUTE on function xt_at(double precision,double precision) to postgres;
grant EXECUTE on function xt_at(double precision,double precision) to service_role;
grant EXECUTE on function xt_val(double precision,double precision) to PUBLIC;
grant EXECUTE on function xt_val(double precision,double precision) to anon;
grant EXECUTE on function xt_val(double precision,double precision) to authenticated;
grant EXECUTE on function xt_val(double precision,double precision) to postgres;
grant EXECUTE on function xt_val(double precision,double precision) to service_role;

-- === seed ===
insert into public.detector_priority select * from jsonb_populate_recordset(null::public.detector_priority,$seed$[{"band": 9, "note": "squad fragility, highest planning value", "detector": "key_man"}, {"band": 9, "note": "a whole tactical identity in one read", "detector": "counter_attack"}, {"band": 9, "note": "diagnosis plus implied recruitment need", "detector": "sterile_control"}, {"band": 8, "note": "direct recruitment lane", "detector": "squad_gap"}, {"band": 8, "note": null, "detector": "low_block"}, {"band": 8, "note": "opposition planning", "detector": "press_vulnerability"}, {"band": 7, "note": "shortlist anchor", "detector": "standout_profile"}, {"band": 7, "note": null, "detector": "territorial"}, {"band": 7, "note": null, "detector": "central_funnel"}, {"band": 7, "note": null, "detector": "byline_team"}, {"band": 6, "note": null, "detector": "game_state_reactivity"}, {"band": 6, "note": "always fires, so should not lead", "detector": "team_profile"}, {"band": 6, "note": null, "detector": "misfit_profile"}, {"band": 5, "note": "a caveat rather than a finding", "detector": "minutes_inflated"}, {"band": 4, "note": "always fires", "detector": "team_strength"}, {"band": 4, "note": "always fires", "detector": "team_weakness"}, {"band": 3, "note": "plentiful, so ranks below team reads", "detector": "player_elite"}, {"band": 2, "note": "least actionable on its own", "detector": "player_weakness"}]$seed$::jsonb);
insert into public.detector_requirements select * from jsonb_populate_recordset(null::public.detector_requirements,$seed$[{"detector": "low_block", "rationale": "PPDA and line height are unstable below a handful of matches.", "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "sterile_control", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "territorial", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "central_funnel", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "byline_team", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "team_profile", "rationale": "Fires for every club, so the sample gate matters most here.", "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "team_strength", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "team_weakness", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "key_man", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "squad_gap", "rationale": null, "min_matches": 6, "requirement": "at least 6 matches", "min_denominator": null, "denominator_label": null}, {"detector": "player_elite", "rationale": null, "min_matches": 6, "requirement": "player has 8+ full matches", "min_denominator": null, "denominator_label": null}, {"detector": "player_weakness", "rationale": null, "min_matches": 6, "requirement": "player has 10+ full matches", "min_denominator": null, "denominator_label": null}, {"detector": "minutes_inflated", "rationale": null, "min_matches": 6, "requirement": "player has 6+ available matches at the club", "min_denominator": null, "denominator_label": null}, {"detector": "counter_attack", "rationale": "A rank-based detector fires for the top four even when every team in the league scores zero. Six of them did.", "min_matches": 6, "requirement": "counter_pct > 0 and at least 120 deep-start possessions", "min_denominator": 120, "denominator_label": "deep-start possessions"}, {"detector": "press_vulnerability", "rationale": "Containment rates on a handful of possessions are noise.", "min_matches": 6, "requirement": "at least 60 opponent possessions in each build-up type compared", "min_denominator": 60, "denominator_label": "opponent possessions per build-up type"}, {"detector": "standout_profile", "rationale": null, "min_matches": 6, "requirement": "player has 150+ involvements", "min_denominator": 150, "denominator_label": "player involvements"}, {"detector": "misfit_profile", "rationale": null, "min_matches": 6, "requirement": "player has 250+ involvements", "min_denominator": 250, "denominator_label": "player involvements"}, {"detector": "game_state_reactivity", "rationale": "A side that has rarely trailed has no losing sample to compare against.", "min_matches": 6, "requirement": "at least 80 possessions both winning and losing", "min_denominator": 80, "denominator_label": "possessions in each game state"}]$seed$::jsonb);
insert into public.invariants select * from jsonb_populate_recordset(null::public.invariants,$seed$[{"name": "seq_league_matches_events", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.sequences s\n    join (select distinct game_id, league from public.events) e using (game_id)\n    where s.league is distinct from e.league", "description": "Every sequence carries the same league as the events it was built from."}, {"name": "pcr_league_matches_player", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.player_chain_roles p\n    join public.mv_player_league l using (player_id)\n    where p.league is distinct from l.league", "description": "Every player chain-role row carries the league the player actually played in."}, {"name": "no_null_league", "enabled": true, "severity": "error", "check_sql": "select (select count(*) from public.events where league is null)\n         + (select count(*) from public.matches where league is null)\n         + (select count(*) from public.lineups where league is null)\n         + (select count(*) from public.sequences where league is null)", "description": "No ingest row is missing a league."}, {"name": "league_registered", "enabled": true, "severity": "error", "check_sql": "select count(*) from (select distinct league from public.events) e\n    where not exists (select 1 from public.leagues l where l.league = e.league)", "description": "Every league present in events is registered in the leagues table."}, {"name": "events_have_matches", "enabled": true, "severity": "error", "check_sql": "select count(*) from (select distinct game_id from public.events) e\n    where not exists (select 1 from public.matches m where m.game_id = e.game_id)", "description": "Every game with events has a matching row in matches."}, {"name": "seq_covers_events", "enabled": true, "severity": "error", "check_sql": "select abs((select count(distinct game_id) from public.sequences)\n             - (select count(distinct game_id) from public.events))", "description": "The sequence layer covers exactly the games that have events."}, {"name": "no_null_xt", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.sequences where xt_sum is null", "description": "No sequence has a null threat value."}, {"name": "percentiles_in_range", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.mv_player_pct\n    where pct_pool < 0 or pct_pool > 100", "description": "Every percentile falls between 0 and 100."}, {"name": "search_matches_roles", "enabled": true, "severity": "error", "check_sql": "select abs((select count(*) from public.player_search)\n             - (select count(*) from public.player_chain_roles))", "description": "The search index contains every profiled player and no others."}, {"name": "team_names_one_to_one", "enabled": true, "severity": "error", "check_sql": "select count(*) from (\n     select league, match_name from public.team_names\n     group by league, match_name having count(*) > 1) d", "description": "Each club maps to exactly one schedule name, and no two clubs share one. A duplicate match_name means an away side was paired with its opponent, which shows up as \"Elche 1-1 Elche\" in fixture lists."}, {"name": "team_names_resolve", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.team_names t\n    where not exists (select 1 from public.matches m\n      where m.league = t.league\n        and (m.home_team = t.match_name or m.away_team = t.match_name))", "description": "Every schedule name in team_names actually appears in the fixture list for that league."}, {"name": "possession_sums", "enabled": true, "severity": "error", "check_sql": "select count(*) from (\n    select game_id, sum(possession_pct) t from public.mv_team_match group by game_id) z\n    where t not between 99.0 and 101.0", "description": "Each match must have both sides' possession shares summing to 100. A drift here means the touch attribution is wrong."}, {"name": "xg_calibration", "enabled": true, "severity": "error", "check_sql": "select case when abs(\n      (select sum(xg) from public.mv_shot_xg where is_pen=false)\n      - (select count(*) from public.mv_shot_xg where is_pen=false and is_goal)\n    ) / nullif((select count(*) from public.mv_shot_xg where is_pen=false and is_goal),0)\n    > 0.10 then 1 else 0 end", "description": "Across the season, total non-penalty xG should land within 10 percent of goals actually scored. Wider than that means the shot model has drifted away from reality."}, {"name": "no_foreign_teams", "enabled": true, "severity": "error", "check_sql": "select count(*) from (select distinct league, team from public.events where team is not null) e\n    join public.leagues l on l.league = e.league\n    where l.expected_teams is not null\n      and (select count(*) from public.team_names t where t.league = e.league) >= l.expected_teams\n      and not exists (select 1 from public.team_names t\n                      where t.league = e.league and t.event_name = e.team)", "description": "No team appears in a league whose whitelist does not contain it. Only checked once a league's whitelist is complete, since a league still bootstrapping will legitimately meet new clubs each week."}, {"name": "insight_no_zero_claim", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.insights\n    where (metrics->>'counter_pct') is not null and (metrics->>'counter_pct')::numeric = 0\n       or (metrics->>'share_pct')   is not null and (metrics->>'share_pct')::numeric   = 0\n       or (metrics->>'value')       is not null and (metrics->>'value')::numeric       = 0\n          and detector in ('player_elite','standout_profile')", "description": "No insight asserts a behaviour while its own supporting metric is zero. This is the defect that produced six clubs described as breaking at speed from deep on a 0.00% counter-attack rate."}, {"name": "played_without_events", "enabled": true, "severity": "warn", "check_sql": "select count(*) from public.v_league_matches m where m.home_score is not null and not exists(select 1 from public.v_league_events e where e.game_id=m.game_id)", "description": "Current-season played matches that have no event data."}, {"name": "shots_in_xg_model", "enabled": true, "severity": "warn", "check_sql": "select count(*) from public.v_league_events e where e.is_shot and not coalesce(e.qualifiers @> '[{\"type\":{\"displayName\":\"OwnGoal\"}}]'::jsonb,false) and not exists(select 1 from public.mv_shot_xg x where x.game_id=e.game_id and x.ws_id=e.ws_id)", "description": "Current-season non-own-goal shots missing from the xG model. Own goals are intentionally excluded from model training and scoring."}, {"name": "leagues_without_whitelist", "enabled": true, "severity": "warn", "check_sql": "select count(*) from public.leagues l where l.is_active and exists(select 1 from public.v_league_matches m where m.league=l.league) and not exists(select 1 from public.team_names t where t.league=l.league)", "description": "Active leagues with current-season match data but no team whitelist."}, {"name": "insight_meets_sample", "enabled": true, "severity": "error", "check_sql": "select count(*) from public.insights i\n    join public.v_team_sample ts on ts.team = i.team\n    where not ts.meets_min_matches", "description": "No team-scoped insight exists for a club below the published minimum match count. Thresholds live in detector_requirements."}, {"name": "insight_denominator_declared", "enabled": true, "severity": "error", "check_sql": "select count(*) from (select distinct detector from public.insights) d\n    where not exists (select 1 from public.detector_requirements r where r.detector = d.detector)", "description": "Every detector currently producing insights has a published denominator requirement, so no detector runs without a stated sample basis."}, {"name": "insight_no_all_zero_tie", "enabled": true, "severity": "error", "check_sql": "with r as (\n      select i.detector, tl.league, (i.metrics->>'counter_pct')::numeric v\n      from public.insights i\n      join public.mv_team_league tl on tl.team = i.team\n      where i.detector = 'counter_attack' and i.metrics ? 'counter_pct')\n    select count(*) from (\n      select league from r group by league having max(v) = 0 and count(*) > 0) z", "description": "No rank-based detector fires when every team in that league scored zero on the ranked metric. A rank of first among identical zeros is not a finding."}, {"name": "unused_subs_carry_minutes", "enabled": true, "severity": "warn", "check_sql": "select count(*) from public.mv_player_season s\n    where s.minutes > 0\n      and not exists (select 1 from public.events e where e.player_id = s.player_id)", "description": "Players with no events are credited minutes in mv_player_season. Every lineup row is treated as 90 minutes regardless of whether the player was used, so unused substitutes accrue appearances and minutes they did not play. Any metric derived from mv_player_season.minutes for these players is wrong. Tracked as a known defect pending a fix to the minutes derivation."}, {"name": "xg_bins_sparse", "enabled": true, "severity": "warn", "check_sql": "select count(*) from mv_xg_bins where n < 20", "description": "Shot-model lookup bins holding fewer than 20 shots. Rates in these bins are noise rather than signal, so any xG assigned from them is weakly supported. Reported as a count, not a pass or fail, because no defensible sparse-bin ceiling has been established. Currently 18 of 44 bins, covering under 1 percent of shots."}, {"name": "league_mart_reads_scoped_sources", "enabled": true, "severity": "error", "check_sql": "select count(*) from (\n     select distinct c.relname\n     from pg_depend d\n     join pg_rewrite r on r.oid = d.objid\n     join pg_class c on c.oid = r.ev_class\n     join pg_class src on src.oid = d.refobjid\n     join pg_namespace sn on sn.oid = src.relnamespace and sn.nspname = 'public'\n     where src.relname in ('events','matches','sequences','lineups')\n       and c.relname in (select object_name from league_mart_entry_objects)\n   ) z", "description": "Audited league-mart entry objects must read the canonical scoped sources (v_league_events, v_league_matches, v_league_sequences, v_league_lineups) rather than the raw events, matches, sequences or lineups tables. Structural rather than value based: it catches a new object that pools competitions before any wrong number is published."}, {"name": "no_non_league_fixture_in_metrics", "enabled": true, "severity": "error", "check_sql": "select count(*) from mv_team_match tm\n     join matches m on m.game_id = tm.game_id\n     join leagues l on l.league = m.league\n    where l.competition_type <> 'league'", "description": "No domestic_cup or continental fixture may contribute to team metric grains. Counts contributing matches in mv_team_match whose competition is not a league."}, {"name": "no_non_league_row_in_league_outputs", "enabled": true, "severity": "error", "check_sql": "select\n     (select count(*) from v_team_sample where league in (select league from leagues where competition_type <> 'league'))\n   + (select count(*) from mv_team_league where league in (select league from leagues where competition_type <> 'league'))\n   + (select count(*) from mv_team_percentiles where league in (select league from leagues where competition_type <> 'league'))\n   + (select count(*) from mv_team_stat_ranks where league in (select league from leagues where competition_type <> 'league'))\n   + (select count(*) from mv_team_breakdown where league in (select league from leagues where competition_type <> 'league'))\n   + (select count(*) from mv_team_directness_state where league in (select league from leagues where competition_type <> 'league'))", "description": "No league-scoped output object may carry a row labelled with a domestic_cup or continental competition."}, {"name": "league_outputs_current_season", "enabled": true, "severity": "error", "check_sql": "\n  select count(*) from (\n    select m.game_id::text as row_id\n    from public.v_league_matches m\n    join public.leagues l on l.league=m.league\n    where m.season is distinct from l.season\n    union all\n    select e.id::text\n    from public.v_league_events e\n    join public.matches m on m.game_id=e.game_id\n    join public.leagues l on l.league=e.league\n    where m.season is distinct from l.season\n    union all\n    select s.seq_uid\n    from public.v_league_sequences s\n    join public.matches m on m.game_id=s.game_id\n    join public.leagues l on l.league=s.league\n    where m.season is distinct from l.season\n    union all\n    select li.id::text\n    from public.v_league_lineups li\n    join public.matches m on m.game_id=li.game_id\n    join public.leagues l on l.league=li.league\n    where m.season is distinct from l.season\n  ) leaked\n  ", "description": "Canonical league sources must contain only the season registered as current for each league."}, {"name": "player_exposure_within_current_season", "enabled": true, "severity": "error", "check_sql": "\n  with league_max as (\n    select league,max(matches)::numeric as matches\n    from public.v_team_sample group by league\n  )\n  select count(*)\n  from public.mv_player_season ps\n  join public.mv_player_league pl on pl.player_id=ps.player_id\n  join league_max lm on lm.league=pl.league\n  where ps.nineties > lm.matches*1.20\n  ", "description": "No player can accumulate materially more nineties than the largest current-season team sample in that player league."}, {"name": "goals_reconcile", "enabled": true, "severity": "error", "check_sql": "\nwith ev as (\n  select g.game_id,\n         count(*) filter(where g.scoring_team=x.home_ev) as h,\n         count(*) filter(where g.scoring_team=x.away_ev) as a\n  from public.mv_game_goals g\n  join (\n    select m.game_id,\n           coalesce(th.event_name,m.home_team) as home_ev,\n           coalesce(ta.event_name,m.away_team) as away_ev\n    from public.v_league_matches m\n    left join public.team_names th\n      on th.match_name=m.home_team and th.league=m.league\n    left join public.team_names ta\n      on ta.match_name=m.away_team and ta.league=m.league\n  ) x on x.game_id=g.game_id\n  group by g.game_id\n)\nselect count(*)\nfrom public.v_league_matches m\nleft join ev on ev.game_id=m.game_id\nwhere m.home_score is not null\n  and exists (\n    select 1 from public.v_league_events e where e.game_id=m.game_id\n  )\n  and (\n    m.home_score<>coalesce(ev.h,0)\n    or m.away_score<>coalesce(ev.a,0)\n  )\n", "description": "Current-season league goals parsed from events must equal the published scoreline."}, {"name": "team_league_resolves", "enabled": true, "severity": "error", "check_sql": "\n      select\n        (select count(*)\n         from (select distinct e.team from public.v_league_events e where e.team is not null) t\n         where not exists (\n           select 1 from public.mv_team_league tl where tl.team = t.team\n         ))\n        +\n        (select count(*)\n         from public.mv_team_league tl\n         where not exists (\n           select 1 from public.v_league_events e\n           where e.team = tl.team and e.league = tl.league\n         ))\n    ", "description": "Every current-season club resolves to a league it actually played in during the registered season."}]$seed$::jsonb);
insert into public.league_mart_entry_objects select * from jsonb_populate_recordset(null::public.league_mart_entry_objects,$seed$[{"note": "per-match team metrics, feature source", "object_name": "mv_team_match"}, {"note": "season aggregate over mv_team_match", "object_name": "mv_team_season"}, {"note": "feeds mv_team_all, absent from the dependency tree", "object_name": "mv_team_lanes"}, {"note": "feeds mv_team_all", "object_name": "mv_team_attackphase"}, {"note": "feeds mv_team_all", "object_name": "mv_team_buildphase"}, {"note": "territory", "object_name": "mv_team_zones"}, {"note": "sequence counts", "object_name": "mv_team_sequences"}, {"note": "club to league resolution", "object_name": "mv_team_league"}, {"note": "game state spine", "object_name": "mv_state_segments"}, {"note": "squad usage", "object_name": "mv_squad_role"}, {"note": "league totals", "object_name": "mv_league_summary"}, {"note": "insight availability", "object_name": "mv_league_availability"}, {"note": "route breakdown", "object_name": "mv_team_breakdown"}, {"note": "state adjusted player output", "object_name": "mv_player_state_output"}, {"note": "player percentile layer", "object_name": "mv_player_percentiles"}, {"note": "season stat source for ranks", "object_name": "v_season_stats"}, {"note": "directness", "object_name": "v_seq_directness"}, {"note": "team evidence base, six match minimum", "object_name": "v_team_sample"}, {"note": "team directory", "object_name": "v_team_directory"}]$seed$::jsonb);
insert into public.leagues select * from jsonb_populate_recordset(null::public.leagues,$seed$[{"tier": 1, "league": "USA-MLS", "season": "2627", "country": "USA", "ws_name": "USA - Major League Soccer", "added_at": "2026-08-06T20:43:27.930487+00:00", "is_active": true, "display_name": "Major League Soccer", "expected_teams": 30, "competition_type": "league"}, {"tier": 1, "league": "ENG-Premier League", "season": "2627", "country": "England", "ws_name": "England - Premier League", "added_at": "2026-08-07T17:07:01.258232+00:00", "is_active": true, "display_name": "Premier League", "expected_teams": 20, "competition_type": "league"}, {"tier": 1, "league": "ESP-La Liga", "season": "2627", "country": "Spain", "ws_name": "Spain - LaLiga", "added_at": "2026-08-18T03:39:06.02266+00:00", "is_active": true, "display_name": "La Liga", "expected_teams": 20, "competition_type": "league"}, {"tier": 1, "league": "ITA-Serie A", "season": "2627", "country": "Italy", "ws_name": "Italy - Serie A", "added_at": "2026-08-18T03:39:06.02266+00:00", "is_active": true, "display_name": "Serie A", "expected_teams": 20, "competition_type": "league"}, {"tier": 1, "league": "FRA-Ligue 1", "season": "2627", "country": "France", "ws_name": "France - Ligue 1", "added_at": "2026-08-18T03:39:06.02266+00:00", "is_active": true, "display_name": "Ligue 1", "expected_teams": 18, "competition_type": "league"}, {"tier": null, "league": "ENG-FA Cup", "season": "2526", "country": "England", "ws_name": null, "added_at": "2026-08-24T20:29:20.623753+00:00", "is_active": false, "display_name": "FA Cup", "expected_teams": null, "competition_type": "domestic_cup"}, {"tier": null, "league": "ENG-League Cup", "season": "2526", "country": "England", "ws_name": null, "added_at": "2026-08-24T20:29:20.623753+00:00", "is_active": false, "display_name": "EFL Cup", "expected_teams": null, "competition_type": "domestic_cup"}, {"tier": null, "league": "INT-Champions League", "season": "2526", "country": "International", "ws_name": null, "added_at": "2026-08-24T20:29:20.623753+00:00", "is_active": false, "display_name": "Champions League", "expected_teams": null, "competition_type": "continental"}, {"tier": 1, "league": "GER-Bundesliga", "season": "2627", "country": "Germany", "ws_name": "Germany - Bundesliga", "added_at": "2026-08-18T03:39:06.02266+00:00", "is_active": false, "display_name": "Bundesliga", "expected_teams": 18, "competition_type": "league"}]$seed$::jsonb);
insert into public.metric_catalog select * from jsonb_populate_recordset(null::public.metric_catalog,$seed$[{"grp": "Threat", "unit": null, "label": "xT per 90", "metric": "xt_90", "higher_better": true}, {"grp": "Threat", "unit": null, "label": "xT from passes", "metric": "xt_pass_90", "higher_better": true}, {"grp": "Threat", "unit": null, "label": "xT from carries", "metric": "xt_carry_90", "higher_better": true}, {"grp": "Threat", "unit": null, "label": "Total chain xT", "metric": "player_xt", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Progressive passes attempted", "metric": "prog_att_90", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Progressive passes completed", "metric": "prog_cmp_90", "higher_better": true}, {"grp": "Progression", "unit": "%", "label": "Progressive pass completion", "metric": "prog_completion", "higher_better": true}, {"grp": "Progression", "unit": "%", "label": "Progressive pass tendency", "metric": "prog_tendency_pct", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Progressions into final third", "metric": "prog_into_final_90", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Passes into box", "metric": "into_box_90", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Final-third passes", "metric": "final_third_90", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Through balls", "metric": "through_90", "higher_better": true}, {"grp": "Progression", "unit": "per 90", "label": "Long passes", "metric": "long_90", "higher_better": true}, {"grp": "Progression", "unit": "%", "label": "Long pass accuracy", "metric": "long_pct", "higher_better": true}, {"grp": "Passing", "unit": "per 90", "label": "Passes completed", "metric": "pass_cmp_90", "higher_better": true}, {"grp": "Passing", "unit": "%", "label": "Pass completion", "metric": "pass_pct", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Forward passes over", "metric": "pct_over", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Forward passes around", "metric": "pct_around", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Forward passes through", "metric": "pct_through", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Forward passes in behind", "metric": "pct_in_behind", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Forward passes inside", "metric": "pct_inside", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Forward passes outside", "metric": "pct_outside", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Through-pass completion", "metric": "comp_through", "higher_better": true}, {"grp": "Trajectory", "unit": "%", "label": "Over-pass completion", "metric": "comp_over", "higher_better": true}, {"grp": "Carrying", "unit": "per 90", "label": "Carries", "metric": "carries_90", "higher_better": true}, {"grp": "Carrying", "unit": "per 90", "label": "Progressive carries", "metric": "prog_carries_90", "higher_better": true}, {"grp": "Carrying", "unit": "per 90", "label": "Carries into box", "metric": "carry_box_90", "higher_better": true}, {"grp": "Carrying", "unit": "per 90", "label": "Carries into penalty area", "metric": "carry_pen_90", "higher_better": true}, {"grp": "Carrying", "unit": "m", "label": "Average carry distance", "metric": "mean_carry_m", "higher_better": true}, {"grp": "Carrying", "unit": "per 90", "label": "Take-ons", "metric": "takeon_90", "higher_better": true}, {"grp": "Carrying", "unit": "%", "label": "Take-on success", "metric": "takeon_pct", "higher_better": true}, {"grp": "Carrying", "unit": "per 90", "label": "Dispossessed", "metric": "disp_90", "higher_better": false}, {"grp": "Creation", "unit": null, "label": "xA per 90", "metric": "xa_90", "higher_better": true}, {"grp": "Creation", "unit": "per 90", "label": "Key passes", "metric": "key_pass_90", "higher_better": true}, {"grp": "Creation", "unit": "per 90", "label": "Shot-creating actions", "metric": "sca_90", "higher_better": true}, {"grp": "Creation", "unit": "per 90", "label": "Big chances created", "metric": "bcc_90", "higher_better": true}, {"grp": "Creation", "unit": "per 90", "label": "Assists", "metric": "assist_90", "higher_better": true}, {"grp": "Creation", "unit": "per 90", "label": "Crosses", "metric": "cross_90", "higher_better": true}, {"grp": "Creation", "unit": "%", "label": "Cross accuracy", "metric": "cross_pct", "higher_better": true}, {"grp": "Shooting", "unit": null, "label": "xG per 90", "metric": "xg_90", "higher_better": true}, {"grp": "Shooting", "unit": "per 90", "label": "Goals", "metric": "goals_90", "higher_better": true}, {"grp": "Shooting", "unit": "per 90", "label": "Shots", "metric": "shots_90", "higher_better": true}, {"grp": "Shooting", "unit": "per 90", "label": "Shots on target", "metric": "sot_90", "higher_better": true}, {"grp": "Shooting", "unit": null, "label": "xG per shot", "metric": "xg_per_shot", "higher_better": true}, {"grp": "Shooting", "unit": "%", "label": "Conversion rate", "metric": "conversion", "higher_better": true}, {"grp": "Shooting", "unit": null, "label": "Finishing over xG", "metric": "finishing", "higher_better": true}, {"grp": "Shooting", "unit": "per 90", "label": "Big chances", "metric": "bigchance_90", "higher_better": true}, {"grp": "Chain value", "unit": "per 90", "label": "Early involvement in shot chains", "metric": "early_shot_inv_90", "higher_better": true}, {"grp": "Chain value", "unit": "%", "label": "Share of touches in shot chains", "metric": "shot_chain_pct", "higher_better": true}, {"grp": "Chain value", "unit": "%", "label": "Share of touches early in shot chains", "metric": "early_shot_pct", "higher_better": true}, {"grp": "Chain value", "unit": null, "label": "Average xT of chains involved in", "metric": "mean_chain_xt", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Defensive actions", "metric": "def_action_90", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Tackles", "metric": "tackle_90", "higher_better": true}, {"grp": "Defending", "unit": "%", "label": "Tackle success", "metric": "tackle_pct", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Interceptions", "metric": "int_90", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Recoveries", "metric": "recov_90", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Aerials won", "metric": "aerial_90", "higher_better": true}, {"grp": "Defending", "unit": "%", "label": "Aerial success", "metric": "aerial_pct", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Counterpressures", "metric": "counterpress_90", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Defensive actions in box", "metric": "box_def_90", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Channel defending", "metric": "channel_def_90", "higher_better": true}, {"grp": "Defending", "unit": "per 90", "label": "Flank defending", "metric": "flank_def_90", "higher_better": true}]$seed$::jsonb);
insert into public.metric_defs select * from jsonb_populate_recordset(null::public.metric_defs,$seed$[{"grp": "Possession", "key": "seq_passes_seq", "calc": "Mean n_pass across open-play sequences.", "unit": null, "label": "Passes per possession", "grp_order": 13, "definition": "Average number of passes in an unbroken spell of possession. The league averages 3.61, and the spread between sides is narrower than intuition suggests.", "sort_order": 1, "higher_is_better": true}, {"grp": "Possession", "key": "seq_seconds_seq", "calc": "Mean duration across open-play sequences.", "unit": "s", "label": "Seconds per possession", "grp_order": 13, "definition": "How long a side keeps the ball once it wins it. League average 10.2 seconds. Long spells indicate patience, not necessarily control.", "sort_order": 2, "higher_is_better": true}, {"grp": "Possession", "key": "seq_xt_seq", "calc": "Mean xt_sum across open-play sequences.", "unit": null, "label": "xT per possession", "grp_order": 13, "definition": "Threat generated per spell of possession. The single best summary of whether having the ball is worth anything. League average 0.0164.", "sort_order": 3, "higher_is_better": true}, {"grp": "Possession", "key": "seq_ends_in_shot", "calc": "Share of open-play sequences where ended_shot is true.", "unit": "%", "label": "Possessions ending in a shot", "grp_order": 13, "definition": "The conversion of possession into attempts. League average 9.2%. High possession with a low figure here is the signature of sterile control.", "sort_order": 4, "higher_is_better": true}, {"grp": "Possession", "key": "seq_low_build", "calc": "Share of sequences with start_x below 33.3.", "unit": "%", "label": "Building from deep", "grp_order": 13, "definition": "Share of possessions starting in the defensive third. High values mean a side that plays out rather than winning the ball high.", "sort_order": 5, "higher_is_better": true}, {"grp": "Possession", "key": "seq_high_build", "calc": "Share of sequences with start_x at or above 50.", "unit": "%", "label": "Winning it high", "grp_order": 13, "definition": "Share of possessions beginning in the attacking half — a proxy for pressing success rather than a pressing metric itself.", "sort_order": 6, "higher_is_better": true}, {"grp": "Possession", "key": "seq_long_ball", "calc": "Share of sequences flagged long_ball.", "unit": "%", "label": "Going long", "grp_order": 13, "definition": "Share of possessions containing a long or lofted pass. Neither good nor bad in isolation; read it against whether the route produces shots.", "sort_order": 7, "higher_is_better": false}, {"grp": "Possession", "key": "seq_switches", "calc": "Share of sequences flagged has_switch.", "unit": "%", "label": "Switching play", "grp_order": 13, "definition": "Share of possessions containing a switch across the pitch. Indicates a side that manipulates a block rather than attacking one side.", "sort_order": 8, "higher_is_better": true}, {"grp": "Possession", "key": "seq_finds_central", "calc": "Share of sequences flagged finds_central.", "unit": "%", "label": "Progressing centrally", "grp_order": 13, "definition": "Share of possessions where the first attacking-third entry arrives through the middle. Miami lead the league at 34.9%.", "sort_order": 9, "higher_is_better": true}, {"grp": "Possession", "key": "seq_finds_wide", "calc": "Share of sequences flagged finds_wide.", "unit": "%", "label": "Progressing wide", "grp_order": 13, "definition": "Share of possessions where the first attacking-third entry arrives in a wide channel. The counterpart to central progression.", "sort_order": 10, "higher_is_better": true}, {"grp": "Possession", "key": "seq_directness", "calc": "(end_x - start_x) / (mean pass length x pass count), clamped to -1..1.", "unit": null, "label": "Possession directness", "grp_order": 13, "definition": "Net upfield progress as a share of total distance the ball travelled. 1.0 would be a straight line at goal; near zero is sideways circulation.", "sort_order": 11, "higher_is_better": true}, {"grp": "Possession", "key": "seq_state_swing", "calc": "Directness when losing minus directness when winning.", "unit": null, "label": "Directness swing by game state", "grp_order": 13, "definition": "How much a side's directness changes between losing and winning. A large swing marks a reactive side; near zero marks a settled identity. Neither is inherently better.", "sort_order": 12, "higher_is_better": true}, {"grp": "Passing", "key": "long_90", "calc": null, "unit": null, "label": "Long balls", "grp_order": 1, "definition": "Long passes attempted, per 90.", "sort_order": 11, "higher_is_better": true}, {"grp": "Passing", "key": "long_pct", "calc": null, "unit": "%", "label": "Long ball accuracy", "grp_order": 1, "definition": "Completion rate of long balls. Needs 25 attempts.", "sort_order": 12, "higher_is_better": true}, {"grp": "Possession", "key": "seq_route_productivity", "calc": "Shot-ending share per route, z-scored within league.", "unit": null, "label": "Route productivity", "grp_order": 13, "definition": "How often a given route produces a shot, measured against the league average for that same route. Separates what a side does from whether it works.", "sort_order": 13, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_initiator", "calc": "Share of involvements at position 1 in the chain.", "unit": "%", "label": "Initiator", "grp_order": 14, "definition": "Share of a player's involvements that begin a possession. High values mark the player a side builds from, typically a defender or deep midfielder.", "sort_order": 1, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_bridge", "calc": "Share of involvements that are mid-chain passes crossing a third boundary.", "unit": "%", "label": "Third-man bridge", "grp_order": 14, "definition": "Mid-chain passes that advance the ball a full third. The connector between build-up and attack — De Paul and Herrera both lead on this.", "sort_order": 2, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_progressor", "calc": "Share of involvements that are progressive passes.", "unit": "%", "label": "Progressor", "grp_order": 14, "definition": "Share of involvements that move the ball at least 10 units upfield. The most straightforward measure of forward intent.", "sort_order": 3, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_carrier", "calc": "Consecutive same-player forward touches.", "unit": "%", "label": "Carrier", "grp_order": 14, "definition": "Ball progression under the player's own power rather than by pass. Derived, because the event feed has no explicit carry event.", "sort_order": 4, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_vertical", "calc": "Forward passes with small lateral deviation.", "unit": "%", "label": "Vertical passer", "grp_order": 14, "definition": "Forward passes played straight rather than diagonally. Marks a player who plays through a block rather than around it.", "sort_order": 5, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_support", "calc": "Passes in the 35-55 degree band, made or received.", "unit": "%", "label": "Diagonal support", "grp_order": 14, "definition": "Passes made or received at roughly 45 degrees. The angle of a player offering himself as an option rather than receiving flat.", "sort_order": 6, "higher_is_better": true}, {"grp": "Shooting", "key": "bigchance_90", "calc": null, "unit": null, "label": "Big-chance shots", "grp_order": 3, "definition": "Shots from a big chance, per 90.", "sort_order": 8, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_individual", "calc": "Share of involvements that are TakeOn events.", "unit": "%", "label": "1v1 dribbler", "grp_order": 14, "definition": "Share of involvements that are take-ons. Distinct from carrying: this is beating a man, not covering ground.", "sort_order": 7, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_creator", "calc": "Share of involvements directly followed by a shot.", "unit": "%", "label": "Creator", "grp_order": 14, "definition": "Passes immediately preceding a shot. The conventional key pass, expressed as a share of everything the player does.", "sort_order": 8, "higher_is_better": true}, {"grp": "Passing", "key": "pass_cmp_90", "calc": "Count events where type = Pass, outcome = Successful, set pieces excluded. Divided by minutes/90.", "unit": null, "label": "Passes completed", "grp_order": 1, "definition": "Completed open-play passes per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Passing", "key": "pass_pct", "calc": "Completed open-play passes divided by attempted, as a percentage.", "unit": "%", "label": "Pass accuracy", "grp_order": 1, "definition": "Completion rate in open play.", "sort_order": 2, "higher_is_better": true}, {"grp": "Passing", "key": "prog_cmp_90", "calc": "A pass counts as progressive if it moves the ball at least 30 units toward goal inside the own half, 15 across halves, or 10 inside the opposition half. Completed only, per 90.", "unit": null, "label": "Progressive passes", "grp_order": 1, "definition": "Completed passes advancing the ball meaningfully toward goal, per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Passing", "key": "prog_pct", "calc": "Completed progressive passes divided by attempted. Suppressed below 25 attempts because the rate is unstable.", "unit": "%", "label": "Prog. pass accuracy", "grp_order": 1, "definition": "Completion rate of progressive passes. Needs 25 attempts.", "sort_order": 4, "higher_is_better": true}, {"grp": "Passing", "key": "territory_90", "calc": "For each completed pass, the forward distance gained, scaled to metres (pitch length 105m). Backward passes count zero. Summed, then per 90.", "unit": "m", "label": "Territory gained", "grp_order": 1, "definition": "Metres of forward distance eliminated by completed passes, per 90.", "sort_order": 5, "higher_is_better": true}, {"grp": "Passing", "key": "into_box_90", "calc": "Completed passes whose end point falls inside the penalty area, per 90.", "unit": null, "label": "Passes into box", "grp_order": 1, "definition": "Completed open-play passes ending in the penalty area, per 90.", "sort_order": 6, "higher_is_better": true}, {"grp": "Passing", "key": "final_third_90", "calc": "Completed passes ending beyond two-thirds of the pitch length, per 90.", "unit": null, "label": "Final third passes", "grp_order": 1, "definition": "Completed passes into the final third, per 90.", "sort_order": 7, "higher_is_better": true}, {"grp": "Passing", "key": "through_90", "calc": "Passes carrying the provider's Throughball qualifier, per 90.", "unit": null, "label": "Through balls", "grp_order": 1, "definition": "Passes played in behind the defensive line, per 90.", "sort_order": 8, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_box_threat", "calc": "Share of involvements with x at or above 83 in the central channel.", "unit": "%", "label": "Box threat", "grp_order": 14, "definition": "Share of involvements occurring inside the penalty area. Separates a penalty-box striker from a forward who drops in.", "sort_order": 9, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_finisher", "calc": "Share of involvements that are shot events.", "unit": "%", "label": "Finisher", "grp_order": 14, "definition": "Share of involvements that are shots. Messi reads highest among attacking midfielders, reflecting a role that now ends moves rather than building them.", "sort_order": 10, "higher_is_better": true}, {"grp": "Chain roles", "key": "role_controller", "calc": "Mean hold time, whole-second resolution.", "unit": "s", "label": "Tempo", "grp_order": 14, "definition": "Average seconds between receiving and releasing. Neither high nor low is better: it separates a player who slows a game from one who moves it on.", "sort_order": 11, "higher_is_better": true}, {"grp": "Chain roles", "key": "chain_early_shot", "calc": "Involvements at least 3 steps from the end of a shot-ending sequence, per 90.", "unit": null, "label": "Early involvement in shot chains", "grp_order": 14, "definition": "How often a player appears three or more actions before a shot. Credits the pass that starts a move rather than the one that finishes it. Contaminated by teammate quality.", "sort_order": 12, "higher_is_better": true}, {"grp": "Passing", "key": "cross_90", "calc": "Passes carrying the Cross qualifier, set pieces excluded, per 90.", "unit": null, "label": "Crosses", "grp_order": 1, "definition": "Open-play crosses attempted, per 90.", "sort_order": 9, "higher_is_better": true}, {"grp": "Passing", "key": "cross_pct", "calc": "Completed crosses over attempted. Needs 20 attempts.", "unit": "%", "label": "Cross accuracy", "grp_order": 1, "definition": "Share of open-play crosses completed. Needs 20 attempts.", "sort_order": 10, "higher_is_better": true}, {"grp": "Creation", "key": "key_pass_90", "calc": "Passes carrying the KeyPass qualifier, meaning the next action was a shot, per 90.", "unit": null, "label": "Key passes", "grp_order": 2, "definition": "Passes directly creating a shot, per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Creation", "key": "assist_90", "calc": "Passes carrying the IntentionalGoalAssist qualifier, per 90.", "unit": null, "label": "Assists", "grp_order": 2, "definition": "Passes directly creating a goal, per 90.", "sort_order": 2, "higher_is_better": true}, {"grp": "Creation", "key": "bcc_90", "calc": "Passes carrying the BigChanceCreated qualifier, per 90.", "unit": null, "label": "Big chances created", "grp_order": 2, "definition": "Passes creating a big chance, per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Shooting", "key": "shots_90", "calc": "Open-play shot events (saved, blocked, off target, post, goal), per 90.", "unit": null, "label": "Shots", "grp_order": 3, "definition": "Open-play shots per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Shooting", "key": "goals_90", "calc": "Goal events, own goals removed, per 90.", "unit": null, "label": "Goals", "grp_order": 3, "definition": "Open-play goals per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Shooting", "key": "box_share", "calc": "Shots taken inside the penalty area as a share of all his shots.", "unit": "%", "label": "Shots in box share", "grp_order": 3, "definition": "Share of shots taken inside the area. High means good positions.", "sort_order": 4, "higher_is_better": true}, {"grp": "Shooting", "key": "shot_dist", "calc": "Straight-line distance from the centre of the goal to the shot, averaged, in metres.", "unit": "m", "label": "Mean shot distance", "grp_order": 3, "definition": "Average distance from goal. Lower is generally better.", "sort_order": 5, "higher_is_better": false}, {"grp": "Shooting", "key": "conversion", "calc": "Goals divided by shots. Needs 12 shots.", "unit": "%", "label": "Conversion", "grp_order": 3, "definition": "Goals per shot. Needs 12 shots.", "sort_order": 6, "higher_is_better": true}, {"grp": "Shooting", "key": "shot_acc", "calc": "On-target shots over total shots, blocks excluded.", "unit": "%", "label": "Shot accuracy", "grp_order": 3, "definition": "Share of shots on target.", "sort_order": 7, "higher_is_better": true}, {"grp": "Shooting", "key": "weak_foot_share", "calc": "Of shots where a foot is recorded, the share taken with the less-used foot. 50% means genuinely two-footed.", "unit": "%", "label": "Weak-foot share", "grp_order": 3, "definition": "Share of shooting on the weaker foot. 50% is two-footed.", "sort_order": 9, "higher_is_better": true}, {"grp": "Carrying", "key": "takeon_90", "calc": "Attempted dribbles past an opponent, per 90.", "unit": null, "label": "Take-ons", "grp_order": 4, "definition": "Dribbles attempted per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Shooting", "key": "sot_90", "calc": "Shots that reached the keeper: saved plus scored. Blocked attempts are excluded even though the provider files them as saves.", "unit": null, "label": "Shots on target", "grp_order": 3, "definition": "On-target shots per 90. Blocked attempts are excluded: the provider logs them as saves, but they never reach the keeper.", "sort_order": 2, "higher_is_better": true}, {"grp": "Carrying", "key": "takeon_pct", "calc": "Take-ons completed over attempted. Needs 15 attempts.", "unit": "%", "label": "Take-on success", "grp_order": 4, "definition": "Share of take-ons completed. Needs 15 attempts.", "sort_order": 2, "higher_is_better": true}, {"grp": "Carrying", "key": "disp_90", "calc": "Times the ball was taken off him, per 90.", "unit": null, "label": "Dispossessed", "grp_order": 4, "definition": "Times dispossessed per 90. Lower is better.", "sort_order": 3, "higher_is_better": false}, {"grp": "Carrying", "key": "badtouch_90", "calc": "Miscontrols per 90.", "unit": null, "label": "Bad touches", "grp_order": 4, "definition": "Miscontrols per 90. Lower is better.", "sort_order": 4, "higher_is_better": false}, {"grp": "Carrying", "key": "carries_90", "calc": "Carries are not recorded by the provider. We infer them: where the ball arrived to a player and where his next action began. Movements of 3m or more count. Per 90.", "unit": null, "label": "Carries", "grp_order": 4, "definition": "Times he moved the ball 3m or more before releasing it, per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Carrying", "key": "prog_carries_90", "calc": "Carries that cut the distance to goal by more than 15%, per 90.", "unit": null, "label": "Progressive carries", "grp_order": 4, "definition": "Carries cutting the distance to goal by more than 15%, per 90.", "sort_order": 2, "higher_is_better": true}, {"grp": "Carrying", "key": "carry_box_90", "calc": "Carries ending inside the penalty area having started outside it, per 90.", "unit": null, "label": "Carries into box", "grp_order": 4, "definition": "Carries ending inside the penalty area, per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Carrying", "key": "mean_carry_m", "calc": "Average length of a carry in metres.", "unit": "m", "label": "Mean carry distance", "grp_order": 4, "definition": "Average length of a carry.", "sort_order": 4, "higher_is_better": true}, {"grp": "Carrying", "key": "carry_pen_90", "calc": "Metres of distance-to-goal eliminated by progressive carries, per 90.", "unit": "m", "label": "Carry penetration", "grp_order": 4, "definition": "Metres of distance-to-goal eliminated by carrying, per 90.", "sort_order": 5, "higher_is_better": true}, {"grp": "Tempo", "key": "median_ttr", "calc": "Seconds between the ball arriving and the player releasing it, taken as the median across every receipt.", "unit": "s", "label": "Median release", "grp_order": 5, "definition": "Seconds between receiving the ball and releasing it. Lower is quicker.", "sort_order": 1, "higher_is_better": false}, {"grp": "Tempo", "key": "quick_pct", "calc": "Share of passes released inside two seconds of receiving.", "unit": "%", "label": "Quick passes", "grp_order": 5, "definition": "Share of passes released within two seconds of receiving.", "sort_order": 2, "higher_is_better": true}, {"grp": "Tempo", "key": "one_touch_pct", "calc": "Share of passes released inside one second.", "unit": "%", "label": "One-touch tempo", "grp_order": 5, "definition": "Share of passes released within one second.", "sort_order": 3, "higher_is_better": true}, {"grp": "Aerial", "key": "aq_per_duel", "calc": "For each aerial he wins we follow the next event: 2 points if he keeps it himself, 1 if it drops to a team-mate, minus 1 if the opposition get it. Averaged over duels won.", "unit": null, "label": "AQ points per duel", "grp_order": 7, "definition": "Aerial Quality: 2 for keeping the ball yourself, 1 for it dropping to a teammate, minus 1 for handing it to the opposition. Averaged over duels won.", "sort_order": 1, "higher_is_better": true}, {"grp": "Aerial", "key": "duel_quality", "calc": "Of the aerials he wins, the share where the ball stays with his own side. Needs 10 wins.", "unit": "%", "label": "Duel quality", "grp_order": 7, "definition": "Of the aerials he wins, the share where the ball stays with his own side. Needs 10 wins.", "sort_order": 2, "higher_is_better": true}, {"grp": "Aerial", "key": "recov_retention", "calc": "After winning the ball back, the completion rate of his next pass. Needs 10 attempts.", "unit": "%", "label": "Post-recovery retention", "grp_order": 7, "definition": "Completion rate of his first pass after winning the ball back. Needs 10 attempts.", "sort_order": 3, "higher_is_better": true}, {"grp": "Aerial", "key": "recov_prog_90", "calc": "Completed progressive passes played immediately off a ball recovery, per 90.", "unit": null, "label": "Prog. passes off recovery", "grp_order": 7, "definition": "Completed progressive passes played straight off a ball recovery, per 90.", "sort_order": 4, "higher_is_better": true}, {"grp": "Defending", "key": "tackle_90", "calc": "Tackle events per 90, won or lost.", "unit": null, "label": "Tackles", "grp_order": 6, "definition": "Tackles attempted per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Defending", "key": "tackle_pct", "calc": "Tackles won over attempted. Needs 15 attempts.", "unit": "%", "label": "Tackle success", "grp_order": 6, "definition": "Share of tackles won. Needs 15 attempts.", "sort_order": 2, "higher_is_better": true}, {"grp": "Defending", "key": "int_90", "calc": "Interception events per 90.", "unit": null, "label": "Interceptions", "grp_order": 6, "definition": "Interceptions per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Defending", "key": "clear_90", "calc": "Clearance events per 90.", "unit": null, "label": "Clearances", "grp_order": 6, "definition": "Clearances per 90.", "sort_order": 4, "higher_is_better": true}, {"grp": "Defending", "key": "block_90", "calc": "Blocked passes per 90.", "unit": null, "label": "Blocks", "grp_order": 6, "definition": "Passes blocked per 90.", "sort_order": 5, "higher_is_better": true}, {"grp": "Defending", "key": "recov_90", "calc": "Loose balls won per 90.", "unit": null, "label": "Recoveries", "grp_order": 6, "definition": "Loose balls won per 90.", "sort_order": 6, "higher_is_better": true}, {"grp": "Defending", "key": "aerial_90", "calc": "Aerial duels contested per 90.", "unit": null, "label": "Aerial duels", "grp_order": 6, "definition": "Aerial duels contested per 90.", "sort_order": 7, "higher_is_better": true}, {"grp": "Defending", "key": "aerial_pct", "calc": "Aerial duels won over contested. Needs 20 duels.", "unit": "%", "label": "Aerial win rate", "grp_order": 6, "definition": "Share of aerial duels won. Needs 20 duels.", "sort_order": 8, "higher_is_better": true}, {"grp": "Defending", "key": "def_action_90", "calc": "Tackles, interceptions, clearances, blocks and recoveries combined, per 90.", "unit": null, "label": "Defensive actions", "grp_order": 6, "definition": "All defensive actions per 90.", "sort_order": 9, "higher_is_better": true}, {"grp": "Defending", "key": "def_height", "calc": "Mean pitch position of his defensive actions, on a 0-100 scale where 100 is the opposition goal.", "unit": null, "label": "Defensive line height", "grp_order": 6, "definition": "Average pitch position of defensive actions. Higher means he defends further up.", "sort_order": 10, "higher_is_better": true}, {"grp": "Discipline", "key": "foul_com_90", "calc": "Fouls conceded per 90.", "unit": null, "label": "Fouls committed", "grp_order": 8, "definition": "Fouls conceded per 90. Lower is better.", "sort_order": 1, "higher_is_better": false}, {"grp": "Discipline", "key": "foul_won_90", "calc": "Fouls drawn per 90.", "unit": null, "label": "Fouls won", "grp_order": 8, "definition": "Fouls drawn per 90.", "sort_order": 2, "higher_is_better": true}, {"grp": "Discipline", "key": "error_90", "calc": "Errors leading to an opposition chance, per 90.", "unit": null, "label": "Errors", "grp_order": 8, "definition": "Errors leading to a chance, per 90. Lower is better.", "sort_order": 3, "higher_is_better": false}, {"grp": "Defending", "key": "padj_tackle_90", "calc": "Tackles, possession-adjusted the same way.", "unit": null, "label": "Tackles (padj)", "grp_order": 6, "definition": "Tackles per 90, adjusted for how much possession his team concedes. Neutralises the advantage of playing for a low-possession side.", "sort_order": 11, "higher_is_better": true}, {"grp": "Defending", "key": "padj_int_90", "calc": "Interceptions, possession-adjusted.", "unit": null, "label": "Interceptions (padj)", "grp_order": 6, "definition": "Interceptions per 90, possession-adjusted.", "sort_order": 12, "higher_is_better": true}, {"grp": "Defending", "key": "padj_def_90", "calc": "Defensive actions scaled by 50 divided by the possession his team concedes. A defender at a dominant side gets fewer chances to defend, and this corrects for it.", "unit": null, "label": "Defensive actions (padj)", "grp_order": 6, "definition": "All defensive actions per 90, possession-adjusted.", "sort_order": 13, "higher_is_better": true}, {"grp": "Defending", "key": "padj_recov_90", "calc": "Recoveries, possession-adjusted.", "unit": null, "label": "Recoveries (padj)", "grp_order": 6, "definition": "Ball recoveries per 90, possession-adjusted.", "sort_order": 14, "higher_is_better": true}, {"grp": "Shooting", "key": "xg_90", "calc": "Every shot is placed in a bin by distance, angle to the goal mouth, header or not, and big-chance flag. The bin's conversion rate in this season is its xG, pulled toward the league mean so thin bins behave. Penalties fixed at 0.76.", "unit": null, "label": "xG", "grp_order": 3, "definition": "Expected goals per 90, from an empirical model fitted on this season (distance, angle, body part, big-chance context). Penalties valued at 0.76.", "sort_order": 10, "higher_is_better": true}, {"grp": "Shooting", "key": "xg_per_shot", "calc": "Total xG divided by shots. Measures the quality of positions he gets into rather than volume.", "unit": null, "label": "xG per shot", "grp_order": 3, "definition": "Average chance quality. High means he gets into good positions rather than shooting from range.", "sort_order": 11, "higher_is_better": true}, {"grp": "Shooting", "key": "finishing", "calc": "Goals minus expected goals, per 90. Positive means he is scoring more than his chances merit.", "unit": null, "label": "Finishing (G-xG)", "grp_order": 3, "definition": "Goals minus expected goals, per 90. Positive means he scores more than his chances merit.", "sort_order": 12, "higher_is_better": true}, {"grp": "Creation", "key": "xa_90", "calc": "For every shot, we look at the pass immediately before it. If that pass was a key pass, its player is credited with the shot's xG. Summed, then per 90.", "unit": null, "label": "xA", "grp_order": 2, "definition": "Expected assists per 90: the xG of the shots his passes created.", "sort_order": 4, "higher_is_better": true}, {"grp": "Creation", "key": "xt_90", "calc": "The pitch is a 12x8 grid, each cell holding a threat value. Every completed pass and carry earns the difference between its end cell and its start cell. Summed, then per 90.", "unit": null, "label": "xT added", "grp_order": 2, "definition": "Expected Threat added per 90 by moving the ball, combining passes and carries.", "sort_order": 5, "higher_is_better": true}, {"grp": "Creation", "key": "xt_pass_90", "calc": "As xT added, counting passes only.", "unit": null, "label": "xT from passing", "grp_order": 2, "definition": "Expected Threat added per 90 by passing alone.", "sort_order": 6, "higher_is_better": true}, {"grp": "Creation", "key": "xt_carry_90", "calc": "As xT added, counting carries only.", "unit": null, "label": "xT from carrying", "grp_order": 2, "definition": "Expected Threat added per 90 by carrying alone.", "sort_order": 7, "higher_is_better": true}, {"grp": "Goalkeeping", "key": "save_pct", "calc": "Saves over shots on target faced. Needs 15 faced.", "unit": "%", "label": "Save rate", "grp_order": 9, "definition": "Saves as a share of shots on target faced. Needs 15 faced.", "sort_order": 1, "higher_is_better": true}, {"grp": "Goalkeeping", "key": "goals_prevented_90", "calc": "xG of the shots on target he faced, minus goals conceded, per 90. Positive means he saves more than the chances merited.", "unit": null, "label": "Goals prevented", "grp_order": 9, "definition": "xG of shots on target faced minus goals conceded, per 90. Positive means he saves more than expected.", "sort_order": 2, "higher_is_better": true}, {"grp": "Goalkeeping", "key": "saves_90", "calc": "Save events per 90.", "unit": null, "label": "Saves", "grp_order": 9, "definition": "Saves per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Goalkeeping", "key": "claims_90", "calc": "Crosses claimed per 90.", "unit": null, "label": "Claims", "grp_order": 9, "definition": "Crosses claimed per 90.", "sort_order": 4, "higher_is_better": true}, {"grp": "Goalkeeping", "key": "sweeps_90", "calc": "Actions outside his box to cut out a through ball, per 90.", "unit": null, "label": "Sweeps", "grp_order": 9, "definition": "Actions outside the box to cut out a through ball, per 90.", "sort_order": 5, "higher_is_better": true}, {"grp": "Goalkeeping", "key": "sweep_x", "calc": "Mean pitch position of those sweeping actions. Higher means a higher defensive line behind him.", "unit": null, "label": "Sweep height", "grp_order": 9, "definition": "Average pitch position of sweeping actions. Higher means a higher defensive line.", "sort_order": 6, "higher_is_better": true}, {"grp": "Creation", "key": "sca_90", "calc": "The two on-ball actions immediately preceding a shot, credited to distinct team-mates, per 90.", "unit": null, "label": "Shot-creating actions", "grp_order": 2, "definition": "The two offensive actions immediately preceding a shot, credited to distinct team-mates, per 90.", "sort_order": 8, "higher_is_better": true}, {"grp": "Half-Spaces", "key": "hs_passes_90", "calc": "The half-spaces are the two strips between the edge of the penalty area and the six-yard line extended. Passes played from those strips in the attacking half, per 90.", "unit": null, "label": "Half-space passes", "grp_order": 10, "definition": "Passes played from the half-space strips in the attacking half, per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Half-Spaces", "key": "hs_prog_90", "calc": "Completed progressive passes from the half-space, per 90.", "unit": null, "label": "Half-space prog. passes", "grp_order": 10, "definition": "Completed progressive passes from the half-space, per 90.", "sort_order": 2, "higher_is_better": true}, {"grp": "Half-Spaces", "key": "hs_key_90", "calc": "Shot-creating passes from the half-space, per 90.", "unit": null, "label": "Half-space key passes", "grp_order": 10, "definition": "Shot-creating passes from the half-space, per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Half-Spaces", "key": "hs_shots_90", "calc": "Shots taken from the half-space strips, per 90.", "unit": null, "label": "Half-space shots", "grp_order": 10, "definition": "Shots taken from the half-space strips, per 90.", "sort_order": 4, "higher_is_better": true}, {"grp": "Half-Spaces", "key": "hs_takeons_90", "calc": "Take-ons attempted in the half-space, per 90.", "unit": null, "label": "Half-space take-ons", "grp_order": 10, "definition": "Take-ons attempted in the half-space, per 90.", "sort_order": 5, "higher_is_better": true}, {"grp": "Defending", "key": "box_def_90", "calc": "Defensive actions inside his own penalty area, per 90.", "unit": null, "label": "Box defending", "grp_order": 6, "definition": "Defensive actions inside his own penalty area, per 90.", "sort_order": 15, "higher_is_better": true}, {"grp": "Defending", "key": "channel_def_90", "calc": "Defensive actions in the half-space channels of his own half, per 90.", "unit": null, "label": "Channel defending", "grp_order": 6, "definition": "Defensive actions in the half-space channels of his own half, per 90.", "sort_order": 16, "higher_is_better": true}, {"grp": "Defending", "key": "flank_def_90", "calc": "Defensive actions in the wide areas of his own half, per 90.", "unit": null, "label": "Flank defending", "grp_order": 6, "definition": "Defensive actions in the wide areas of his own half, per 90.", "sort_order": 17, "higher_is_better": true}, {"grp": "Defending", "key": "counterpress_90", "calc": "Defensive actions made within five seconds of his team losing the ball, per 90.", "unit": null, "label": "Counter-pressing", "grp_order": 6, "definition": "Defensive actions made within five seconds of his team losing the ball, per 90.", "sort_order": 18, "higher_is_better": true}, {"grp": "Hold-Up", "key": "holds_90", "calc": "Times he kept the ball five seconds or more in the final third, per 90.", "unit": null, "label": "Hold-up episodes", "grp_order": 11, "definition": "Times he held the ball five seconds or more in the final third, per 90.", "sort_order": 1, "higher_is_better": true}, {"grp": "Hold-Up", "key": "hold_retention", "calc": "Share of those holds where his team still had the ball afterwards.", "unit": "%", "label": "Hold retention", "grp_order": 11, "definition": "Share of hold-ups where his team kept the ball.", "sort_order": 2, "higher_is_better": true}, {"grp": "Hold-Up", "key": "hold_prog_pct", "calc": "Share of holds he ended by carrying meaningfully forward.", "unit": "%", "label": "Progressive release", "grp_order": 11, "definition": "Share of hold-ups he ended by carrying the ball meaningfully forward.", "sort_order": 3, "higher_is_better": true}, {"grp": "Hold-Up", "key": "hold_shot_pct", "calc": "Share of holds ending in his own shot.", "unit": "%", "label": "Shot from hold", "grp_order": 11, "definition": "Share of hold-ups ending in his own shot.", "sort_order": 4, "higher_is_better": true}, {"grp": "Set Pieces", "key": "sp_xg_90", "calc": "A set-piece phase is the ten seconds after a dead-ball delivery. xG from shots inside those phases, per 90. Throw-ins count as deliveries.", "unit": null, "label": "Set-piece xG", "grp_order": 12, "definition": "Expected goals from set-piece phases, per 90. A phase is the ten seconds after a dead-ball delivery, which includes throw-ins.", "sort_order": 1, "higher_is_better": true}, {"grp": "Set Pieces", "key": "sp_shots_90", "calc": "Shots taken inside set-piece phases, per 90.", "unit": null, "label": "Set-piece shots", "grp_order": 12, "definition": "Shots taken in set-piece phases, per 90.", "sort_order": 2, "higher_is_better": true}, {"grp": "Set Pieces", "key": "sp_aerials_90", "calc": "Aerial duels won inside set-piece phases, per 90.", "unit": null, "label": "Set-piece aerials won", "grp_order": 12, "definition": "Aerial duels won in set-piece phases, per 90.", "sort_order": 3, "higher_is_better": true}, {"grp": "Set Pieces", "key": "sp_key_90", "calc": "Dead-ball deliveries that created a shot, per 90.", "unit": null, "label": "Set-piece deliveries", "grp_order": 12, "definition": "Dead-ball deliveries that created a shot, per 90.", "sort_order": 4, "higher_is_better": true}, {"grp": "Shooting", "key": "blocked_90", "calc": "His own shots stopped by a defender before reaching the keeper, per 90.", "unit": null, "label": "Shots blocked", "grp_order": 3, "definition": "His own shots blocked by a defender, per 90. The provider files these as saves, but they never reached the keeper.", "sort_order": 13, "higher_is_better": false}]$seed$::jsonb);
insert into public.metric_synonyms select * from jsonb_populate_recordset(null::public.metric_synonyms,$seed$[{"grp": null, "metric": "xt_pass_90", "phrase": "threat from passing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xt_pass_90", "phrase": "passing threat", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xt_carry_90", "phrase": "threat from carrying", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xt_carry_90", "phrase": "carrying threat", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "prog_cmp_90", "phrase": "progressive passing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "prog_cmp_90", "phrase": "progressive passes", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "into_box_90", "phrase": "passes into the box", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "into_box_90", "phrase": "box entries", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "through_90", "phrase": "through balls", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "long_90", "phrase": "long passing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "takeon_90", "phrase": "dribbling", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "takeon_90", "phrase": "take ons", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "takeon_90", "phrase": "take-ons", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "takeon_90", "phrase": "one v one", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "takeon_90", "phrase": "1v1", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "prog_carries_90", "phrase": "progressive carries", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "carry_box_90", "phrase": "carries into the box", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "key_pass_90", "phrase": "key passes", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "assist_90", "phrase": "assists", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xa_90", "phrase": "expected assists", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xa_90", "phrase": "xa", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "cross_90", "phrase": "crossing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "cross_90", "phrase": "crosses", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "bcc_90", "phrase": "big chances created", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "goals_90", "phrase": "goals", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "shots_90", "phrase": "shots", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xg_90", "phrase": "expected goals", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xg_90", "phrase": "xg", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "xg_per_shot", "phrase": "shot quality", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "conversion", "phrase": "conversion", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "tackle_90", "phrase": "tackling", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "tackle_90", "phrase": "tackles", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "int_90", "phrase": "interceptions", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "recov_90", "phrase": "recoveries", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "aerial_90", "phrase": "aerials", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "aerial_90", "phrase": "aerial ability", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "counterpress_90", "phrase": "pressing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "counterpress_90", "phrase": "counterpressing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "pct_over", "phrase": "balls over the top", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "pct_in_behind", "phrase": "playing in behind", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "early_shot_inv_90", "phrase": "early involvement", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "early_shot_inv_90", "phrase": "deep involvement", "weight": 1, "rank_metric": null}, {"grp": "Threat", "metric": null, "phrase": "expected threat", "weight": 1, "rank_metric": "xt_90"}, {"grp": "Threat", "metric": null, "phrase": "threat", "weight": 1, "rank_metric": "xt_90"}, {"grp": "Threat", "metric": null, "phrase": "xt", "weight": 1, "rank_metric": "xt_90"}, {"grp": "Threat", "metric": null, "phrase": "threat creation", "weight": 1, "rank_metric": "xt_90"}, {"grp": "Threat", "metric": null, "phrase": "expected threat creation", "weight": 1, "rank_metric": "xt_90"}, {"grp": "Progression", "metric": null, "phrase": "progression", "weight": 1, "rank_metric": "prog_cmp_90"}, {"grp": "Progression", "metric": null, "phrase": "ball progression", "weight": 1, "rank_metric": "prog_cmp_90"}, {"grp": "Carrying", "metric": null, "phrase": "carrying", "weight": 1, "rank_metric": "carries_90"}, {"grp": "Carrying", "metric": null, "phrase": "ball carrying", "weight": 1, "rank_metric": "carries_90"}, {"grp": "Carrying", "metric": null, "phrase": "carries", "weight": 1, "rank_metric": "carries_90"}, {"grp": "Creation", "metric": null, "phrase": "creation", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Creation", "metric": null, "phrase": "chance creation", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Creation", "metric": null, "phrase": "creativity", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Shooting", "metric": null, "phrase": "shooting", "weight": 1, "rank_metric": "xg_90"}, {"grp": "Shooting", "metric": null, "phrase": "finishing", "weight": 1, "rank_metric": "xg_90"}, {"grp": "Shooting", "metric": null, "phrase": "goalscoring", "weight": 1, "rank_metric": "xg_90"}, {"grp": "Defending", "metric": null, "phrase": "defending", "weight": 1, "rank_metric": "def_action_90"}, {"grp": "Defending", "metric": null, "phrase": "defensive work", "weight": 1, "rank_metric": "def_action_90"}, {"grp": "Passing", "metric": null, "phrase": "passing", "weight": 1, "rank_metric": "pass_cmp_90"}, {"grp": "Passing", "metric": null, "phrase": "distribution", "weight": 1, "rank_metric": "pass_cmp_90"}, {"grp": "Trajectory", "metric": null, "phrase": "pass trajectory", "weight": 1, "rank_metric": "pct_through"}, {"grp": "Trajectory", "metric": null, "phrase": "trajectory", "weight": 1, "rank_metric": "pct_through"}, {"grp": "Chain value", "metric": null, "phrase": "chain involvement", "weight": 1, "rank_metric": "early_shot_inv_90"}, {"grp": "Chain value", "metric": null, "phrase": "build up involvement", "weight": 1, "rank_metric": "early_shot_inv_90"}, {"grp": "Creation", "metric": null, "phrase": "creative", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Creation", "metric": null, "phrase": "playmaking", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Progression", "metric": null, "phrase": "progressive", "weight": 1, "rank_metric": "prog_cmp_90"}, {"grp": null, "metric": "takeon_90", "phrase": "press resistance", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "pass_pct", "phrase": "ball retention", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "final_third_90", "phrase": "final third passing", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "shots_90", "phrase": "shot volume", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "box_threat", "phrase": "poaching", "weight": 1, "rank_metric": null}, {"grp": "Shooting", "metric": null, "phrase": "shooter", "weight": 1, "rank_metric": "xg_90"}, {"grp": "Shooting", "metric": null, "phrase": "finisher", "weight": 1, "rank_metric": "xg_90"}, {"grp": "Shooting", "metric": null, "phrase": "goalscorer", "weight": 1, "rank_metric": "goals_90"}, {"grp": "Shooting", "metric": null, "phrase": "goal scorer", "weight": 1, "rank_metric": "goals_90"}, {"grp": null, "metric": "box_threat", "phrase": "poacher", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "box_threat", "phrase": "penalty box striker", "weight": 1, "rank_metric": null}, {"grp": "Shooting", "metric": null, "phrase": "shot taker", "weight": 1, "rank_metric": "shots_90"}, {"grp": "Passing", "metric": null, "phrase": "passer", "weight": 1, "rank_metric": "pass_cmp_90"}, {"grp": null, "metric": "prog_cmp_90", "phrase": "progressive passer", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "prog_cmp_90", "phrase": "progressor", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "prog_cmp_90", "phrase": "deep lying playmaker", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "prog_cmp_90", "phrase": "deep-lying playmaker", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "key_pass_90", "phrase": "key passer", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "through_90", "phrase": "line breaker", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "through_90", "phrase": "line-breaker", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "long_90", "phrase": "long passer", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "long_90", "phrase": "switcher", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "cross_90", "phrase": "crosser", "weight": 1, "rank_metric": null}, {"grp": "Passing", "metric": null, "phrase": "distributor", "weight": 1, "rank_metric": "pass_cmp_90"}, {"grp": "Creation", "metric": null, "phrase": "creator", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Creation", "metric": null, "phrase": "chance creator", "weight": 1, "rank_metric": "xa_90"}, {"grp": null, "metric": "assist_90", "phrase": "assister", "weight": 1, "rank_metric": null}, {"grp": "Creation", "metric": null, "phrase": "number 10", "weight": 1, "rank_metric": "xa_90"}, {"grp": "Carrying", "metric": null, "phrase": "carrier", "weight": 1, "rank_metric": "prog_carries_90"}, {"grp": "Carrying", "metric": null, "phrase": "ball carrier", "weight": 1, "rank_metric": "prog_carries_90"}, {"grp": null, "metric": "takeon_90", "phrase": "dribbler", "weight": 1, "rank_metric": null}, {"grp": "Carrying", "metric": null, "phrase": "runner", "weight": 1, "rank_metric": "prog_carries_90"}, {"grp": null, "metric": "takeon_90", "phrase": "take on merchant", "weight": 1, "rank_metric": null}, {"grp": "Defending", "metric": null, "phrase": "defender", "weight": 1, "rank_metric": "def_action_90"}, {"grp": null, "metric": "tackle_90", "phrase": "tackler", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "int_90", "phrase": "interceptor", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "counterpress_90", "phrase": "presser", "weight": 1, "rank_metric": null}, {"grp": "Defending", "metric": null, "phrase": "ball winner", "weight": 1, "rank_metric": "def_action_90"}, {"grp": "Defending", "metric": null, "phrase": "destroyer", "weight": 1, "rank_metric": "def_action_90"}, {"grp": null, "metric": "aerial_90", "phrase": "aerial threat", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "aerial_90", "phrase": "header of the ball", "weight": 1, "rank_metric": null}, {"grp": "Threat", "metric": null, "phrase": "threat creator", "weight": 1, "rank_metric": "xt_90"}, {"grp": "Chain value", "metric": null, "phrase": "build up player", "weight": 1, "rank_metric": "early_shot_inv_90"}, {"grp": "Chain value", "metric": null, "phrase": "build-up player", "weight": 1, "rank_metric": "early_shot_inv_90"}, {"grp": null, "metric": "early_shot_inv_90", "phrase": "chain starter", "weight": 1, "rank_metric": null}, {"grp": "Chain value", "metric": null, "phrase": "tempo setter", "weight": 1, "rank_metric": "early_shot_inv_90"}, {"grp": null, "metric": "carry_box_90", "phrase": "box threat", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "carry_box_90", "phrase": "in the box", "weight": 1, "rank_metric": null}, {"grp": null, "metric": "carry_box_90", "phrase": "penalty box presence", "weight": 1, "rank_metric": null}]$seed$::jsonb);
insert into public.pillar_defs select * from jsonb_populate_recordset(null::public.pillar_defs,$seed$[{"ord": 1, "kind": "quality", "metric": "prog_cmp_90", "pillar": "Progression", "weight": 1}, {"ord": 1, "kind": "quality", "metric": "xt_pass_90", "pillar": "Progression", "weight": 1}, {"ord": 2, "kind": "quality", "metric": "xa_90", "pillar": "Creation", "weight": 1}, {"ord": 2, "kind": "quality", "metric": "sca_90", "pillar": "Creation", "weight": 1}, {"ord": 3, "kind": "quality", "metric": "xg_90", "pillar": "Finishing", "weight": 1}, {"ord": 3, "kind": "quality", "metric": "finishing", "pillar": "Finishing", "weight": 1}, {"ord": 3, "kind": "quality", "metric": "box_share", "pillar": "Finishing", "weight": 1}, {"ord": 6, "kind": "quality", "metric": "padj_def_90", "pillar": "Defending", "weight": 1}, {"ord": 6, "kind": "quality", "metric": "tackle_pct", "pillar": "Defending", "weight": 1}, {"ord": 6, "kind": "quality", "metric": "counterpress_90", "pillar": "Defending", "weight": 1}, {"ord": 6, "kind": "quality", "metric": "aq_per_duel", "pillar": "Defending", "weight": 1}, {"ord": 7, "kind": "quality", "metric": "pass_pct", "pillar": "Security", "weight": 1}, {"ord": 7, "kind": "quality", "metric": "disp_90", "pillar": "Security", "weight": 1}, {"ord": 7, "kind": "quality", "metric": "badtouch_90", "pillar": "Security", "weight": 1}, {"ord": 7, "kind": "quality", "metric": "error_90", "pillar": "Security", "weight": 1}, {"ord": 4, "kind": "style", "metric": "prog_carries_90", "pillar": "Carrying", "weight": 1}, {"ord": 4, "kind": "style", "metric": "takeon_pct", "pillar": "Carrying", "weight": 1}, {"ord": 4, "kind": "style", "metric": "carry_box_90", "pillar": "Carrying", "weight": 1}, {"ord": 5, "kind": "style", "metric": "median_ttr", "pillar": "Tempo", "weight": 1}, {"ord": 5, "kind": "style", "metric": "one_touch_pct", "pillar": "Tempo", "weight": 1}, {"ord": 5, "kind": "style", "metric": "quick_pct", "pillar": "Tempo", "weight": 1}]$seed$::jsonb);
insert into public.pool_metric_relevance select * from jsonb_populate_recordset(null::public.pool_metric_relevance,$seed$[{"grp": "Passing", "pool": "CB"}, {"grp": "Progression", "pool": "CB"}, {"grp": "Defending", "pool": "CB"}, {"grp": "Chain value", "pool": "CB"}, {"grp": "Passing", "pool": "FB"}, {"grp": "Progression", "pool": "FB"}, {"grp": "Carrying", "pool": "FB"}, {"grp": "Creation", "pool": "FB"}, {"grp": "Defending", "pool": "FB"}, {"grp": "Passing", "pool": "CM"}, {"grp": "Progression", "pool": "CM"}, {"grp": "Creation", "pool": "CM"}, {"grp": "Carrying", "pool": "CM"}, {"grp": "Defending", "pool": "CM"}, {"grp": "Chain value", "pool": "CM"}, {"grp": "Threat", "pool": "CM"}, {"grp": "Creation", "pool": "AM"}, {"grp": "Progression", "pool": "AM"}, {"grp": "Carrying", "pool": "AM"}, {"grp": "Shooting", "pool": "AM"}, {"grp": "Threat", "pool": "AM"}, {"grp": "Carrying", "pool": "W"}, {"grp": "Creation", "pool": "W"}, {"grp": "Shooting", "pool": "W"}, {"grp": "Threat", "pool": "W"}, {"grp": "Progression", "pool": "W"}, {"grp": "Shooting", "pool": "ST"}, {"grp": "Creation", "pool": "ST"}, {"grp": "Carrying", "pool": "ST"}, {"grp": "Threat", "pool": "ST"}]$seed$::jsonb);
insert into public.role_pillar_weights select * from jsonb_populate_recordset(null::public.role_pillar_weights,$seed$[{"pool": "CB", "pillar": "Progression", "weight": 3}, {"pool": "CB", "pillar": "Creation", "weight": 0}, {"pool": "CB", "pillar": "Finishing", "weight": 0}, {"pool": "CB", "pillar": "Carrying", "weight": 1}, {"pool": "CB", "pillar": "Defending", "weight": 5}, {"pool": "CB", "pillar": "Security", "weight": 4}, {"pool": "CB", "pillar": "Tempo", "weight": 0}, {"pool": "FB", "pillar": "Progression", "weight": 4}, {"pool": "FB", "pillar": "Creation", "weight": 3}, {"pool": "FB", "pillar": "Finishing", "weight": 1}, {"pool": "FB", "pillar": "Carrying", "weight": 3}, {"pool": "FB", "pillar": "Defending", "weight": 4}, {"pool": "FB", "pillar": "Security", "weight": 3}, {"pool": "FB", "pillar": "Tempo", "weight": 0}, {"pool": "CM", "pillar": "Progression", "weight": 5}, {"pool": "CM", "pillar": "Creation", "weight": 4}, {"pool": "CM", "pillar": "Finishing", "weight": 1}, {"pool": "CM", "pillar": "Carrying", "weight": 3}, {"pool": "CM", "pillar": "Defending", "weight": 4}, {"pool": "CM", "pillar": "Security", "weight": 4}, {"pool": "CM", "pillar": "Tempo", "weight": 0}, {"pool": "AM", "pillar": "Progression", "weight": 4}, {"pool": "AM", "pillar": "Creation", "weight": 5}, {"pool": "AM", "pillar": "Finishing", "weight": 3}, {"pool": "AM", "pillar": "Carrying", "weight": 4}, {"pool": "AM", "pillar": "Defending", "weight": 1}, {"pool": "AM", "pillar": "Security", "weight": 3}, {"pool": "AM", "pillar": "Tempo", "weight": 0}, {"pool": "W", "pillar": "Progression", "weight": 3}, {"pool": "W", "pillar": "Creation", "weight": 5}, {"pool": "W", "pillar": "Finishing", "weight": 4}, {"pool": "W", "pillar": "Carrying", "weight": 5}, {"pool": "W", "pillar": "Defending", "weight": 1}, {"pool": "W", "pillar": "Security", "weight": 2}, {"pool": "W", "pillar": "Tempo", "weight": 0}, {"pool": "ST", "pillar": "Progression", "weight": 2}, {"pool": "ST", "pillar": "Creation", "weight": 3}, {"pool": "ST", "pillar": "Finishing", "weight": 5}, {"pool": "ST", "pillar": "Carrying", "weight": 3}, {"pool": "ST", "pillar": "Defending", "weight": 1}, {"pool": "ST", "pillar": "Security", "weight": 2}, {"pool": "ST", "pillar": "Tempo", "weight": 0}]$seed$::jsonb);
insert into public.team_metric_defs select * from jsonb_populate_recordset(null::public.team_metric_defs,$seed$[{"grp": "Control", "key": "possession_pct", "unit": "%", "label": "Possession", "grp_order": 1, "definition": "Share of all passes in the match played by this team.", "sort_order": 1, "higher_is_better": true}, {"grp": "Control", "key": "field_tilt", "unit": "%", "label": "Field tilt", "grp_order": 1, "definition": "Share of final-third touches. Territorial dominance rather than raw possession.", "sort_order": 2, "higher_is_better": true}, {"grp": "Control", "key": "avg_touch_x", "unit": null, "label": "Average touch height", "grp_order": 1, "definition": "Mean pitch position of the team's touches. Higher means they play further up.", "sort_order": 3, "higher_is_better": true}, {"grp": "Control", "key": "directness", "unit": "m", "label": "Directness", "grp_order": 1, "definition": "Metres of forward progress per completed pass. High means vertical, low means patient.", "sort_order": 4, "higher_is_better": true}, {"grp": "Control", "key": "long_ball_pct", "unit": "%", "label": "Long ball share", "grp_order": 1, "definition": "Share of passes hit long. Lower usually means a shorter build-up.", "sort_order": 5, "higher_is_better": false}, {"grp": "Control", "key": "build_from_back_pct", "unit": "%", "label": "Build from the back", "grp_order": 1, "definition": "Share of passes played from the defensive third.", "sort_order": 6, "higher_is_better": true}, {"grp": "Pressing", "key": "ppda", "unit": null, "label": "PPDA", "grp_order": 2, "definition": "Opponent passes allowed per defensive action in their own 60%. Lower means a more aggressive press.", "sort_order": 1, "higher_is_better": false}, {"grp": "Pressing", "key": "def_height", "unit": null, "label": "Defensive line height", "grp_order": 2, "definition": "Average pitch position of defensive actions. Higher means a higher line.", "sort_order": 2, "higher_is_better": true}, {"grp": "Build-up phase", "key": "gk_long_pct", "unit": "%", "label": "Keeper goes long", "grp_order": 3, "definition": "Share of the goalkeeper's passes hit long. Low means they play out.", "sort_order": 1, "higher_is_better": false}, {"grp": "Build-up phase", "key": "d3_pass_share", "unit": "%", "label": "Own-third pass share", "grp_order": 3, "definition": "Share of all their passes played from their own third. High means they spend real time building.", "sort_order": 2, "higher_is_better": true}, {"grp": "Build-up phase", "key": "d3_accuracy", "unit": "%", "label": "Own-third accuracy", "grp_order": 3, "definition": "Completion rate of passes from their own third. The pressure test on playing out.", "sort_order": 3, "higher_is_better": true}, {"grp": "Build-up phase", "key": "d3_long_pct", "unit": "%", "label": "Own-third long balls", "grp_order": 3, "definition": "Share of own-third passes hit long, bypassing the phase rather than playing through it.", "sort_order": 4, "higher_is_better": false}, {"grp": "Build-up phase", "key": "deep_circulation_pg", "unit": null, "label": "Deep circulation", "grp_order": 3, "definition": "Completed passes that both start and end in their own third, per game. Sideways build-up.", "sort_order": 5, "higher_is_better": true}, {"grp": "Build-up phase", "key": "cb_prog_pg", "unit": null, "label": "Centre-back progression", "grp_order": 3, "definition": "Progressive passes played by centre-backs per game. Whether defenders break lines themselves.", "sort_order": 6, "higher_is_better": true}, {"grp": "Build-up phase", "key": "escape_pct", "unit": "%", "label": "Escape rate", "grp_order": 3, "definition": "Of possessions starting in their own third, the share reaching at least the halfway line.", "sort_order": 7, "higher_is_better": true}, {"grp": "Build-up phase", "key": "deep_to_final_pct", "unit": "%", "label": "Deep to final third", "grp_order": 3, "definition": "Of possessions starting in their own third, the share reaching the final third.", "sort_order": 8, "higher_is_better": true}, {"grp": "Build-up phase", "key": "d3_touch_share", "unit": "%", "label": "Own-third touch share", "grp_order": 3, "definition": "Share of all their touches taken in their own third.", "sort_order": 9, "higher_is_better": true}, {"grp": "Attacking phase", "key": "att_directness", "unit": "m", "label": "Attacking directness", "grp_order": 4, "definition": "Metres of forward progress per completed pass in the attacking half. High means vertical once they are up.", "sort_order": 1, "higher_is_better": true}, {"grp": "Attacking phase", "key": "mid_release", "unit": "s", "label": "Middle-third release", "grp_order": 4, "definition": "Median seconds on the ball in the middle third. Low means quick circulation through midfield.", "sort_order": 2, "higher_is_better": false}, {"grp": "Attacking phase", "key": "ft_release", "unit": "s", "label": "Final-third release", "grp_order": 4, "definition": "Median seconds on the ball in the final third. Low means they move it quickly near the box.", "sort_order": 3, "higher_is_better": false}, {"grp": "Attacking phase", "key": "passes_per_shot", "unit": null, "label": "Passes per shot", "grp_order": 4, "definition": "Completed passes for every shot taken. Low means efficient; high means they circulate without threatening.", "sort_order": 4, "higher_is_better": false}, {"grp": "Attacking phase", "key": "ft_entries_pg", "unit": null, "label": "Final-third entries", "grp_order": 4, "definition": "Passes and carries entering the final third, per game.", "sort_order": 5, "higher_is_better": true}, {"grp": "Attacking phase", "key": "box_per_entry", "unit": "%", "label": "Entries reaching the box", "grp_order": 4, "definition": "Of final-third entries, the share that become a completed pass into the penalty area. Territory converted into penetration.", "sort_order": 6, "higher_is_better": true}, {"grp": "Attacking phase", "key": "final_to_shot_pct", "unit": "%", "label": "Final third to shot", "grp_order": 4, "definition": "Of possessions reaching the final third, the share ending in a shot.", "sort_order": 7, "higher_is_better": true}, {"grp": "Output", "key": "prog_passes_pg", "unit": null, "label": "Progressive passes", "grp_order": 5, "definition": "Completed progressive passes per game.", "sort_order": 1, "higher_is_better": true}, {"grp": "Output", "key": "crosses_pg", "unit": null, "label": "Crosses", "grp_order": 5, "definition": "Open-play crosses per game.", "sort_order": 3, "higher_is_better": true}, {"grp": "Output", "key": "box_entries_pg", "unit": null, "label": "Passes into box", "grp_order": 5, "definition": "Completed passes into the penalty area per game.", "sort_order": 2, "higher_is_better": true}, {"grp": "Output", "key": "shots_pg", "unit": null, "label": "Shots", "grp_order": 5, "definition": "Shots taken per game.", "sort_order": 4, "higher_is_better": true}, {"grp": "Output", "key": "goals_pg", "unit": null, "label": "Goals", "grp_order": 5, "definition": "Goals scored per game.", "sort_order": 5, "higher_is_better": true}, {"grp": "Output", "key": "open_play_shot_pct", "unit": "%", "label": "Open-play shot share", "grp_order": 5, "definition": "Share of shots coming from open play rather than set-piece phases.", "sort_order": 6, "higher_is_better": true}, {"grp": "Possession shape", "key": "passes_per_seq", "unit": null, "label": "Passes per possession", "grp_order": 6, "definition": "How many passes they string together before losing it. High means patient.", "sort_order": 1, "higher_is_better": true}, {"grp": "Possession shape", "key": "secs_per_seq", "unit": "s", "label": "Seconds per possession", "grp_order": 6, "definition": "How long they keep the ball each time they win it.", "sort_order": 2, "higher_is_better": true}, {"grp": "Possession shape", "key": "long_sequence_pct", "unit": "%", "label": "Long possessions", "grp_order": 6, "definition": "Share of possessions reaching six or more passes.", "sort_order": 3, "higher_is_better": true}, {"grp": "Possession shape", "key": "pct_ending_in_shot", "unit": "%", "label": "Possessions ending in a shot", "grp_order": 6, "definition": "How often keeping the ball produces an attempt.", "sort_order": 5, "higher_is_better": true}, {"grp": "Possession shape", "key": "ground_gained", "unit": null, "label": "Ground gained per possession", "grp_order": 6, "definition": "How far up the pitch a typical possession travels.", "sort_order": 6, "higher_is_better": true}, {"grp": "Possession shape", "key": "sequences_pg", "unit": null, "label": "Possessions per game", "grp_order": 6, "definition": "How often they have the ball. High means a broken, transitional game.", "sort_order": 8, "higher_is_better": true}, {"grp": "Defending", "key": "shots_against_pg", "unit": null, "label": "Shots conceded", "grp_order": 7, "definition": "Shots faced per game. Lower is better.", "sort_order": 1, "higher_is_better": false}, {"grp": "Defending", "key": "goals_against_pg", "unit": null, "label": "Goals conceded", "grp_order": 7, "definition": "Goals conceded per game. Lower is better.", "sort_order": 2, "higher_is_better": false}, {"grp": "Channels", "key": "pct_left", "unit": "%", "label": "Left channel share", "grp_order": 8, "definition": "Share of final-third involvement down their left. The left channel is the far side of the pitch as drawn, since attack runs left to right.", "sort_order": 1, "higher_is_better": true}, {"grp": "Channels", "key": "pct_centre", "unit": "%", "label": "Central share", "grp_order": 8, "definition": "Share of final-third involvement through the middle third of the pitch width.", "sort_order": 2, "higher_is_better": true}, {"grp": "Channels", "key": "pct_right", "unit": "%", "label": "Right channel share", "grp_order": 8, "definition": "Share of final-third involvement down their right. The right channel is the near side of the pitch as drawn.", "sort_order": 3, "higher_is_better": true}]$seed$::jsonb);
insert into public.team_names select * from jsonb_populate_recordset(null::public.team_names,$seed$[{"league": "USA-MLS", "event_name": "Chicago", "match_name": "Chicago Fire FC", "display_name": "Chicago Fire FC"}, {"league": "USA-MLS", "event_name": "Colorado", "match_name": "Colorado Rapids", "display_name": "Colorado Rapids"}, {"league": "USA-MLS", "event_name": "Columbus", "match_name": "Columbus Crew", "display_name": "Columbus Crew"}, {"league": "USA-MLS", "event_name": "Houston", "match_name": "Houston Dynamo FC", "display_name": "Houston Dynamo FC"}, {"league": "USA-MLS", "event_name": "Kansas City", "match_name": "Sporting Kansas City", "display_name": "Sporting Kansas City"}, {"league": "USA-MLS", "event_name": "L.A. Galaxy", "match_name": "LA Galaxy", "display_name": "LA Galaxy"}, {"league": "USA-MLS", "event_name": "Montreal", "match_name": "CF Montreal", "display_name": "CF Montréal"}, {"league": "USA-MLS", "event_name": "New England", "match_name": "New England Revolution", "display_name": "New England Revolution"}, {"league": "USA-MLS", "event_name": "New York", "match_name": "Red Bull New York", "display_name": "New York Red Bulls"}, {"league": "USA-MLS", "event_name": "Philadelphia", "match_name": "Philadelphia Union", "display_name": "Philadelphia Union"}, {"league": "USA-MLS", "event_name": "Portland", "match_name": "Portland Timbers", "display_name": "Portland Timbers"}, {"league": "USA-MLS", "event_name": "Salt Lake", "match_name": "Real Salt Lake", "display_name": "Real Salt Lake"}, {"league": "USA-MLS", "event_name": "San Jose", "match_name": "San Jose Earthquakes", "display_name": "San Jose Earthquakes"}, {"league": "USA-MLS", "event_name": "Seattle", "match_name": "Seattle Sounders FC", "display_name": "Seattle Sounders FC"}, {"league": "USA-MLS", "event_name": "Toronto", "match_name": "Toronto FC", "display_name": "Toronto FC"}, {"league": "USA-MLS", "event_name": "Vancouver", "match_name": "Vancouver Whitecaps", "display_name": "Vancouver Whitecaps"}, {"league": "USA-MLS", "event_name": "Atlanta United", "match_name": "Atlanta United", "display_name": "Atlanta United"}, {"league": "USA-MLS", "event_name": "Austin FC", "match_name": "Austin FC", "display_name": "Austin FC"}, {"league": "USA-MLS", "event_name": "Charlotte FC", "match_name": "Charlotte FC", "display_name": "Charlotte FC"}, {"league": "USA-MLS", "event_name": "DC United", "match_name": "DC United", "display_name": "D.C. United"}, {"league": "USA-MLS", "event_name": "FC Cincinnati", "match_name": "FC Cincinnati", "display_name": "FC Cincinnati"}, {"league": "USA-MLS", "event_name": "FC Dallas", "match_name": "FC Dallas", "display_name": "FC Dallas"}, {"league": "USA-MLS", "event_name": "Inter Miami CF", "match_name": "Inter Miami CF", "display_name": "Inter Miami CF"}, {"league": "USA-MLS", "event_name": "Los Angeles FC", "match_name": "Los Angeles FC", "display_name": "Los Angeles FC"}, {"league": "USA-MLS", "event_name": "Minnesota United", "match_name": "Minnesota United", "display_name": "Minnesota United"}, {"league": "USA-MLS", "event_name": "Nashville SC", "match_name": "Nashville SC", "display_name": "Nashville SC"}, {"league": "USA-MLS", "event_name": "New York City FC", "match_name": "New York City FC", "display_name": "New York City FC"}, {"league": "USA-MLS", "event_name": "Orlando City", "match_name": "Orlando City", "display_name": "Orlando City"}, {"league": "USA-MLS", "event_name": "San Diego FC", "match_name": "San Diego FC", "display_name": "San Diego FC"}, {"league": "USA-MLS", "event_name": "St. Louis City", "match_name": "St. Louis City", "display_name": "St. Louis City"}, {"league": "ESP-La Liga", "event_name": "Athletic Club", "match_name": "Athletic Club", "display_name": "Athletic Club"}, {"league": "ESP-La Liga", "event_name": "Atletico", "match_name": "Atletico Madrid", "display_name": "Atletico Madrid"}, {"league": "ESP-La Liga", "event_name": "Celta Vigo", "match_name": "Celta Vigo", "display_name": "Celta Vigo"}, {"league": "ESP-La Liga", "event_name": "Deportivo", "match_name": "Deportivo de A Coruna", "display_name": "Deportivo de A Coruna"}, {"league": "ESP-La Liga", "event_name": "Deportivo Alaves", "match_name": "Deportivo Alaves", "display_name": "Deportivo Alaves"}, {"league": "ESP-La Liga", "event_name": "Elche", "match_name": "Elche", "display_name": "Elche"}, {"league": "ESP-La Liga", "event_name": "Espanyol", "match_name": "Espanyol", "display_name": "Espanyol"}, {"league": "ESP-La Liga", "event_name": "Getafe", "match_name": "Getafe", "display_name": "Getafe"}, {"league": "ESP-La Liga", "event_name": "Levante", "match_name": "Levante", "display_name": "Levante"}, {"league": "ESP-La Liga", "event_name": "Malaga", "match_name": "Malaga", "display_name": "Malaga"}, {"league": "ESP-La Liga", "event_name": "Racing Santander", "match_name": "Racing Santander", "display_name": "Racing Santander"}, {"league": "ESP-La Liga", "event_name": "Rayo Vallecano", "match_name": "Rayo Vallecano", "display_name": "Rayo Vallecano"}, {"league": "ESP-La Liga", "event_name": "Real Betis", "match_name": "Real Betis", "display_name": "Real Betis"}, {"league": "ESP-La Liga", "event_name": "Real Madrid", "match_name": "Real Madrid", "display_name": "Real Madrid"}, {"league": "ESP-La Liga", "event_name": "Real Sociedad", "match_name": "Real Sociedad", "display_name": "Real Sociedad"}, {"league": "ESP-La Liga", "event_name": "Sevilla", "match_name": "Sevilla", "display_name": "Sevilla"}, {"league": "ESP-La Liga", "event_name": "Valencia", "match_name": "Valencia", "display_name": "Valencia"}, {"league": "ESP-La Liga", "event_name": "Villarreal", "match_name": "Villarreal", "display_name": "Villarreal"}, {"league": "ENG-Premier League", "event_name": "Arsenal", "match_name": "Arsenal", "display_name": "Arsenal"}, {"league": "ENG-Premier League", "event_name": "Brentford", "match_name": "Brentford", "display_name": "Brentford"}, {"league": "ENG-Premier League", "event_name": "Coventry", "match_name": "Coventry", "display_name": "Coventry"}, {"league": "ENG-Premier League", "event_name": "Crystal Palace", "match_name": "Crystal Palace", "display_name": "Crystal Palace"}, {"league": "ENG-Premier League", "event_name": "Everton", "match_name": "Everton", "display_name": "Everton"}, {"league": "ENG-Premier League", "event_name": "Hull", "match_name": "Hull", "display_name": "Hull"}, {"league": "ENG-Premier League", "event_name": "Ipswich", "match_name": "Ipswich", "display_name": "Ipswich"}, {"league": "ENG-Premier League", "event_name": "Leeds", "match_name": "Leeds", "display_name": "Leeds"}, {"league": "ENG-Premier League", "event_name": "Man Utd", "match_name": "Manchester United", "display_name": "Manchester United"}, {"league": "ENG-Premier League", "event_name": "Nottingham Forest", "match_name": "Nottingham Forest", "display_name": "Nottingham Forest"}, {"league": "ENG-Premier League", "event_name": "Sunderland", "match_name": "Sunderland", "display_name": "Sunderland"}, {"league": "ENG-Premier League", "event_name": "Tottenham", "match_name": "Tottenham", "display_name": "Tottenham"}, {"league": "FRA-Ligue 1", "event_name": "Auxerre", "match_name": "Auxerre", "display_name": "Auxerre"}, {"league": "FRA-Ligue 1", "event_name": "Brest", "match_name": "Brest", "display_name": "Brest"}, {"league": "FRA-Ligue 1", "event_name": "Le Mans", "match_name": "Le Mans", "display_name": "Le Mans"}, {"league": "FRA-Ligue 1", "event_name": "Lens", "match_name": "Lens", "display_name": "Lens"}, {"league": "FRA-Ligue 1", "event_name": "Lorient", "match_name": "Lorient", "display_name": "Lorient"}, {"league": "FRA-Ligue 1", "event_name": "Lyon", "match_name": "Lyon", "display_name": "Lyon"}, {"league": "FRA-Ligue 1", "event_name": "Marseille", "match_name": "Marseille", "display_name": "Marseille"}, {"league": "FRA-Ligue 1", "event_name": "Nice", "match_name": "Nice", "display_name": "Nice"}, {"league": "FRA-Ligue 1", "event_name": "Paris FC", "match_name": "Paris FC", "display_name": "Paris FC"}, {"league": "FRA-Ligue 1", "event_name": "Strasbourg", "match_name": "Strasbourg", "display_name": "Strasbourg"}, {"league": "FRA-Ligue 1", "event_name": "Toulouse", "match_name": "Toulouse", "display_name": "Toulouse"}, {"league": "FRA-Ligue 1", "event_name": "Troyes", "match_name": "Troyes", "display_name": "Troyes"}, {"league": "ITA-Serie A", "event_name": "Cagliari", "match_name": "Cagliari", "display_name": "Cagliari"}, {"league": "ITA-Serie A", "event_name": "Como", "match_name": "Como", "display_name": "Como"}, {"league": "ITA-Serie A", "event_name": "Genoa", "match_name": "Genoa", "display_name": "Genoa"}, {"league": "ITA-Serie A", "event_name": "Inter", "match_name": "Inter", "display_name": "Inter"}, {"league": "ITA-Serie A", "event_name": "Monza", "match_name": "Monza", "display_name": "Monza"}, {"league": "ITA-Serie A", "event_name": "Napoli", "match_name": "Napoli", "display_name": "Napoli"}, {"league": "ITA-Serie A", "event_name": "Parma Calcio 1913", "match_name": "Parma Calcio 1913", "display_name": "Parma Calcio 1913"}, {"league": "ITA-Serie A", "event_name": "Udinese", "match_name": "Udinese", "display_name": "Udinese"}, {"league": "ENG-Premier League", "event_name": "Man City", "match_name": "Manchester City", "display_name": "Manchester City"}, {"league": "ENG-FA Cup", "event_name": "Arsenal", "match_name": "Arsenal", "display_name": "Arsenal"}, {"league": "ENG-FA Cup", "event_name": "Mansfield", "match_name": "Mansfield", "display_name": "Mansfield Town"}, {"league": "ENG-FA Cup", "event_name": "Portsmouth", "match_name": "Portsmouth", "display_name": "Portsmouth"}, {"league": "ENG-FA Cup", "event_name": "Southampton", "match_name": "Southampton", "display_name": "Southampton"}, {"league": "ENG-FA Cup", "event_name": "Wigan", "match_name": "Wigan", "display_name": "Wigan Athletic"}, {"league": "ENG-League Cup", "event_name": "Arsenal", "match_name": "Arsenal", "display_name": "Arsenal"}, {"league": "ENG-League Cup", "event_name": "Brighton", "match_name": "Brighton", "display_name": "Brighton"}, {"league": "ENG-League Cup", "event_name": "Chelsea", "match_name": "Chelsea", "display_name": "Chelsea"}, {"league": "ENG-League Cup", "event_name": "Crystal Palace", "match_name": "Crystal Palace", "display_name": "Crystal Palace"}, {"league": "ENG-League Cup", "event_name": "Man City", "match_name": "Manchester City", "display_name": "Manchester City"}, {"league": "ENG-League Cup", "event_name": "Port Vale", "match_name": "Port Vale", "display_name": "Port Vale"}, {"league": "INT-Champions League", "event_name": "Arsenal", "match_name": "Arsenal", "display_name": "Arsenal"}, {"league": "INT-Champions League", "event_name": "Athletic Club", "match_name": "Athletic Club", "display_name": "Athletic Club"}, {"league": "INT-Champions League", "event_name": "Atletico", "match_name": "Atletico Madrid", "display_name": "Atletico Madrid"}, {"league": "INT-Champions League", "event_name": "Bayern", "match_name": "Bayern Munich", "display_name": "Bayern Munich"}, {"league": "INT-Champions League", "event_name": "Club Brugge", "match_name": "Club Brugge", "display_name": "Club Brugge"}, {"league": "INT-Champions League", "event_name": "Inter", "match_name": "Inter", "display_name": "Inter"}, {"league": "INT-Champions League", "event_name": "Kairat Almaty", "match_name": "Kairat Almaty", "display_name": "Kairat Almaty"}, {"league": "INT-Champions League", "event_name": "Leverkusen", "match_name": "Bayer Leverkusen", "display_name": "Bayer Leverkusen"}, {"league": "INT-Champions League", "event_name": "Olympiacos", "match_name": "Olympiacos", "display_name": "Olympiacos"}, {"league": "INT-Champions League", "event_name": "Slavia Prague", "match_name": "Slavia Prague", "display_name": "Slavia Prague"}, {"league": "INT-Champions League", "event_name": "Sporting", "match_name": "Sporting CP", "display_name": "Sporting CP"}]$seed$::jsonb);
insert into public.xt_grid select * from jsonb_populate_recordset(null::public.xt_grid,$seed$[{"v": 0.000, "x_bin": 0, "y_bin": 0}, {"v": 0.000, "x_bin": 0, "y_bin": 1}, {"v": 0.000, "x_bin": 0, "y_bin": 2}, {"v": 0.000, "x_bin": 0, "y_bin": 3}, {"v": 0.000, "x_bin": 0, "y_bin": 4}, {"v": 0.000, "x_bin": 0, "y_bin": 5}, {"v": 0.000, "x_bin": 0, "y_bin": 6}, {"v": 0.000, "x_bin": 0, "y_bin": 7}, {"v": 0.001, "x_bin": 1, "y_bin": 0}, {"v": 0.001, "x_bin": 1, "y_bin": 1}, {"v": 0.001, "x_bin": 1, "y_bin": 2}, {"v": 0.002, "x_bin": 1, "y_bin": 3}, {"v": 0.002, "x_bin": 1, "y_bin": 4}, {"v": 0.001, "x_bin": 1, "y_bin": 5}, {"v": 0.001, "x_bin": 1, "y_bin": 6}, {"v": 0.001, "x_bin": 1, "y_bin": 7}, {"v": 0.002, "x_bin": 2, "y_bin": 0}, {"v": 0.003, "x_bin": 2, "y_bin": 1}, {"v": 0.004, "x_bin": 2, "y_bin": 2}, {"v": 0.005, "x_bin": 2, "y_bin": 3}, {"v": 0.005, "x_bin": 2, "y_bin": 4}, {"v": 0.004, "x_bin": 2, "y_bin": 5}, {"v": 0.003, "x_bin": 2, "y_bin": 6}, {"v": 0.002, "x_bin": 2, "y_bin": 7}, {"v": 0.004, "x_bin": 3, "y_bin": 0}, {"v": 0.006, "x_bin": 3, "y_bin": 1}, {"v": 0.008, "x_bin": 3, "y_bin": 2}, {"v": 0.011, "x_bin": 3, "y_bin": 3}, {"v": 0.011, "x_bin": 3, "y_bin": 4}, {"v": 0.008, "x_bin": 3, "y_bin": 5}, {"v": 0.006, "x_bin": 3, "y_bin": 6}, {"v": 0.004, "x_bin": 3, "y_bin": 7}, {"v": 0.006, "x_bin": 4, "y_bin": 0}, {"v": 0.009, "x_bin": 4, "y_bin": 1}, {"v": 0.014, "x_bin": 4, "y_bin": 2}, {"v": 0.019, "x_bin": 4, "y_bin": 3}, {"v": 0.019, "x_bin": 4, "y_bin": 4}, {"v": 0.014, "x_bin": 4, "y_bin": 5}, {"v": 0.009, "x_bin": 4, "y_bin": 6}, {"v": 0.006, "x_bin": 4, "y_bin": 7}, {"v": 0.010, "x_bin": 5, "y_bin": 0}, {"v": 0.015, "x_bin": 5, "y_bin": 1}, {"v": 0.022, "x_bin": 5, "y_bin": 2}, {"v": 0.030, "x_bin": 5, "y_bin": 3}, {"v": 0.030, "x_bin": 5, "y_bin": 4}, {"v": 0.022, "x_bin": 5, "y_bin": 5}, {"v": 0.015, "x_bin": 5, "y_bin": 6}, {"v": 0.010, "x_bin": 5, "y_bin": 7}, {"v": 0.016, "x_bin": 6, "y_bin": 0}, {"v": 0.024, "x_bin": 6, "y_bin": 1}, {"v": 0.035, "x_bin": 6, "y_bin": 2}, {"v": 0.048, "x_bin": 6, "y_bin": 3}, {"v": 0.048, "x_bin": 6, "y_bin": 4}, {"v": 0.035, "x_bin": 6, "y_bin": 5}, {"v": 0.024, "x_bin": 6, "y_bin": 6}, {"v": 0.016, "x_bin": 6, "y_bin": 7}, {"v": 0.025, "x_bin": 7, "y_bin": 0}, {"v": 0.037, "x_bin": 7, "y_bin": 1}, {"v": 0.054, "x_bin": 7, "y_bin": 2}, {"v": 0.075, "x_bin": 7, "y_bin": 3}, {"v": 0.075, "x_bin": 7, "y_bin": 4}, {"v": 0.054, "x_bin": 7, "y_bin": 5}, {"v": 0.037, "x_bin": 7, "y_bin": 6}, {"v": 0.025, "x_bin": 7, "y_bin": 7}, {"v": 0.038, "x_bin": 8, "y_bin": 0}, {"v": 0.056, "x_bin": 8, "y_bin": 1}, {"v": 0.082, "x_bin": 8, "y_bin": 2}, {"v": 0.115, "x_bin": 8, "y_bin": 3}, {"v": 0.115, "x_bin": 8, "y_bin": 4}, {"v": 0.082, "x_bin": 8, "y_bin": 5}, {"v": 0.056, "x_bin": 8, "y_bin": 6}, {"v": 0.038, "x_bin": 8, "y_bin": 7}, {"v": 0.055, "x_bin": 9, "y_bin": 0}, {"v": 0.082, "x_bin": 9, "y_bin": 1}, {"v": 0.122, "x_bin": 9, "y_bin": 2}, {"v": 0.170, "x_bin": 9, "y_bin": 3}, {"v": 0.170, "x_bin": 9, "y_bin": 4}, {"v": 0.122, "x_bin": 9, "y_bin": 5}, {"v": 0.082, "x_bin": 9, "y_bin": 6}, {"v": 0.055, "x_bin": 9, "y_bin": 7}, {"v": 0.082, "x_bin": 10, "y_bin": 0}, {"v": 0.120, "x_bin": 10, "y_bin": 1}, {"v": 0.178, "x_bin": 10, "y_bin": 2}, {"v": 0.250, "x_bin": 10, "y_bin": 3}, {"v": 0.250, "x_bin": 10, "y_bin": 4}, {"v": 0.178, "x_bin": 10, "y_bin": 5}, {"v": 0.120, "x_bin": 10, "y_bin": 6}, {"v": 0.082, "x_bin": 10, "y_bin": 7}, {"v": 0.120, "x_bin": 11, "y_bin": 0}, {"v": 0.180, "x_bin": 11, "y_bin": 1}, {"v": 0.270, "x_bin": 11, "y_bin": 2}, {"v": 0.390, "x_bin": 11, "y_bin": 3}, {"v": 0.390, "x_bin": 11, "y_bin": 4}, {"v": 0.270, "x_bin": 11, "y_bin": 5}, {"v": 0.180, "x_bin": 11, "y_bin": 6}, {"v": 0.120, "x_bin": 11, "y_bin": 7}]$seed$::jsonb);
insert into public.analytics_publication_probe select * from jsonb_populate_recordset(null::public.analytics_publication_probe,$seed$[{"value": 0, "singleton": true}]$seed$::jsonb);

-- === materialized_data ===
refresh materialized view public.mv_invariant_status;
refresh materialized view public.mv_event_phase;
refresh materialized view public.mv_game_goals;
refresh materialized view public.mv_match_length;
refresh materialized view public.mv_pass_traj;
refresh materialized view public.mv_player_chains;
refresh materialized view public.mv_player_counterpress;
refresh materialized view public.mv_player_defload;
refresh materialized view public.mv_player_foot;
refresh materialized view public.mv_player_league;
refresh materialized view public.mv_player_sca;
refresh materialized view public.mv_player_stints;
refresh materialized view public.mv_player_territory;
refresh materialized view public.mv_player_zones;
refresh materialized view public.mv_press_vs_buildup;
refresh materialized view public.mv_receipt_events;
refresh materialized view public.mv_seq_events;
refresh materialized view public.mv_shot_features;
refresh materialized view public.mv_team_lanes;
refresh materialized view public.mv_team_league;
refresh materialized view public.mv_team_match;
refresh materialized view public.mv_team_sequences;
refresh materialized view public.seq_fz;
refresh materialized view public.mv_player_carry;
refresh materialized view public.mv_player_holdup;
refresh materialized view public.mv_player_minutes;
refresh materialized view public.mv_player_pass_traj;
refresh materialized view public.mv_player_xt;
refresh materialized view public.mv_seq_state;
refresh materialized view public.mv_state_segments;
refresh materialized view public.mv_team_attackphase;
refresh materialized view public.mv_team_breakdown;
refresh materialized view public.mv_team_buildup;
refresh materialized view public.mv_team_carry_zones;
refresh materialized view public.mv_team_season;
refresh materialized view public.mv_team_stat_ranks;
refresh materialized view public.mv_team_zones;
refresh materialized view public.mv_xg_bins;
refresh materialized view public.mv_player_leverage;
refresh materialized view public.mv_player_pool;
refresh materialized view public.mv_player_season;
refresh materialized view public.mv_player_team_poss;
refresh materialized view public.mv_shot_xg;
refresh materialized view public.mv_gk_match;
refresh materialized view public.mv_league_availability;
refresh materialized view public.mv_player_metrics_raw;
refresh materialized view public.mv_player_role;
refresh materialized view public.mv_player_setpiece;
refresh materialized view public.mv_player_state_output;
refresh materialized view public.mv_player_xa;
refresh materialized view public.mv_squad_role;
refresh materialized view public.mv_team_directness_state;
refresh materialized view public.mv_player_gk;
refresh materialized view public.mv_team_buildphase;
refresh materialized view public.mv_player_archetype;
refresh materialized view public.mv_player_metrics;
refresh materialized view public.mv_team_all;
refresh materialized view public.mv_team_percentiles;
refresh materialized view public.mv_player_chain_value;
refresh materialized view public.mv_player_percentiles;
refresh materialized view public.mv_player_progression;
refresh materialized view public.mv_metric_examples;
refresh materialized view public.mv_player_pillars;
refresh materialized view public.player_search;
refresh materialized view public.mv_league_summary;
refresh materialized view public.mv_player_dna;
refresh materialized view public.mv_player_pct;
refresh materialized view public.mv_site_summary;

-- === finish ===
commit;
