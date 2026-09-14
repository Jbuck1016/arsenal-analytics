begin;

-- Model and archive objects are deliberately additive.  The historical
-- scraper may continue writing public.matches/events/lineups while this
-- migration is applied; no existing relation is rewritten or locked for a
-- long-running data copy.

alter table public.matches
  add column if not exists kickoff_at timestamptz;

comment on column public.matches.kickoff_at is
  'Canonical scheduled kickoff instant when the source provides one. Match date remains the historical fallback.';

create table if not exists public.archive_match_manifest (
  game_id text primary key references public.matches(game_id),
  season text not null,
  league text not null,
  source_provider text not null default 'WhoScored',
  object_bucket text not null default 'historical-match-archive',
  object_path text not null unique,
  compression text not null default 'gzip'
    check (compression in ('gzip')),
  content_sha256 text not null
    check (content_sha256 ~ '^[0-9a-f]{64}$'),
  raw_bytes bigint not null check (raw_bytes > 0),
  compressed_bytes bigint not null check (compressed_bytes > 0),
  event_count integer not null check (event_count >= 0),
  lineup_count integer check (lineup_count >= 0),
  archive_schema_version integer not null default 1
    check (archive_schema_version > 0),
  archived_at timestamptz not null default now(),
  verified_at timestamptz,
  check (compressed_bytes <= raw_bytes)
);

create index if not exists archive_match_manifest_scope_idx
  on public.archive_match_manifest(season, league, game_id);

comment on table public.archive_match_manifest is
  'Service-only manifest for immutable compressed raw match objects. A verified row is required before relational raw history can ever be retired.';

create table if not exists public.ml_team_match_features (
  game_id text not null references public.matches(game_id),
  team text not null,
  feature_schema_version integer not null check (feature_schema_version > 0),
  as_of timestamptz not null,
  history_cutoff_date date not null,
  source_match_count integer not null check (source_match_count >= 0),
  features jsonb not null check (jsonb_typeof(features) = 'object'),
  content_sha256 text not null
    check (content_sha256 ~ '^[0-9a-f]{64}$'),
  computed_at timestamptz not null default now(),
  primary key (game_id, team, feature_schema_version)
);

create index if not exists ml_team_match_features_asof_idx
  on public.ml_team_match_features(as_of, feature_schema_version);

comment on table public.ml_team_match_features is
  'Point-in-time pre-match feature snapshots. The builder must enforce history_cutoff_date < the target match date to prevent leakage.';

create table if not exists public.ml_model_runs (
  id bigint generated always as identity primary key,
  model_key text not null,
  model_version text not null,
  status text not null default 'training'
    check (status in ('training','validated','shadow','active','retired','failed')),
  algorithm text not null,
  feature_schema_version integer not null check (feature_schema_version > 0),
  trained_through date not null,
  hyperparameters jsonb not null default '{}'::jsonb
    check (jsonb_typeof(hyperparameters) = 'object'),
  metrics jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metrics) = 'object'),
  artifact_bucket text,
  artifact_path text,
  artifact_sha256 text
    check (artifact_sha256 is null or artifact_sha256 ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  promoted_at timestamptz,
  notes text,
  unique (model_key, model_version),
  check ((artifact_bucket is null) = (artifact_path is null)),
  check (status <> 'active' or promoted_at is not null)
);

create unique index if not exists ml_model_runs_one_active_idx
  on public.ml_model_runs(model_key)
  where status = 'active';

create table if not exists public.ml_match_predictions (
  id bigint generated always as identity primary key,
  model_run_id bigint not null references public.ml_model_runs(id),
  game_id text not null references public.matches(game_id),
  forecast_kind text not null
    check (forecast_kind in ('thursday_frozen','latest','confirmed_lineup')),
  as_of timestamptz not null,
  home_expected_goals numeric(7,4) not null check (home_expected_goals >= 0),
  away_expected_goals numeric(7,4) not null check (away_expected_goals >= 0),
  home_win_probability numeric(8,7) not null
    check (home_win_probability between 0 and 1),
  draw_probability numeric(8,7) not null
    check (draw_probability between 0 and 1),
  away_win_probability numeric(8,7) not null
    check (away_win_probability between 0 and 1),
  scoreline_distribution jsonb not null default '{}'::jsonb
    check (jsonb_typeof(scoreline_distribution) = 'object'),
  created_at timestamptz not null default now(),
  unique (model_run_id, game_id, forecast_kind, as_of),
  check (abs((home_win_probability + draw_probability + away_win_probability) - 1) <= 0.000001)
);

create index if not exists ml_match_predictions_game_asof_idx
  on public.ml_match_predictions(game_id, as_of desc);

create table if not exists public.ml_season_simulation_runs (
  id bigint generated always as identity primary key,
  model_run_id bigint not null references public.ml_model_runs(id),
  league text not null,
  season text not null,
  as_of timestamptz not null,
  source_forecast_kind text not null
    check (source_forecast_kind in ('thursday_frozen','latest','confirmed_lineup')),
  simulation_count integer not null check (simulation_count >= 1000),
  rules_version integer not null default 1 check (rules_version > 0),
  status text not null default 'complete'
    check (status in ('running','complete','failed')),
  created_at timestamptz not null default now(),
  unique (model_run_id, league, season, as_of, source_forecast_kind)
);

create table if not exists public.ml_season_simulation_teams (
  simulation_run_id bigint not null
    references public.ml_season_simulation_runs(id) on delete cascade,
  team text not null,
  expected_points numeric(7,3) not null,
  expected_position numeric(6,3) not null check (expected_position >= 1),
  finish_distribution jsonb not null
    check (jsonb_typeof(finish_distribution) = 'object'),
  title_probability numeric(8,7) not null default 0
    check (title_probability between 0 and 1),
  europe_probability numeric(8,7) not null default 0
    check (europe_probability between 0 and 1),
  relegation_probability numeric(8,7) not null default 0
    check (relegation_probability between 0 and 1),
  primary key (simulation_run_id, team)
);

create or replace view public.v_ml_team_match_outcomes
with (security_invoker = true) as
with completed_matches as (
  select m.game_id,
         m.season,
         m.league,
         m.date as match_date,
         m.kickoff_at,
         m.matchday,
         m.home_team,
         m.away_team,
         m.home_score,
         m.away_score
  from public.matches m
  join public.leagues l on l.league = m.league
  where l.competition_type = 'league'
    and m.home_score is not null
    and m.away_score is not null
), team_rows as (
  select game_id, season, league, match_date, kickoff_at, matchday,
         home_team as team, away_team as opponent, true as is_home,
         home_score as goals_for, away_score as goals_against
  from completed_matches
  union all
  select game_id, season, league, match_date, kickoff_at, matchday,
         away_team as team, home_team as opponent, false as is_home,
         away_score as goals_for, home_score as goals_against
  from completed_matches
), labelled as (
  select *,
         goals_for - goals_against as goal_difference,
         case when goals_for > goals_against then 'W'
              when goals_for = goals_against then 'D' else 'L' end as result,
         case when goals_for > goals_against then 3
              when goals_for = goals_against then 1 else 0 end as points
  from team_rows
)
select *,
       count(*) over season_prior as pre_matches_played,
       coalesce(sum(points) over season_prior, 0) as pre_points,
       count(*) filter (where result = 'W') over season_prior as pre_wins,
       count(*) filter (where result = 'D') over season_prior as pre_draws,
       count(*) filter (where result = 'L') over season_prior as pre_losses,
       coalesce(sum(goals_for) over season_prior, 0) as pre_goals_for,
       coalesce(sum(goals_against) over season_prior, 0) as pre_goals_against,
       coalesce(sum(goal_difference) over season_prior, 0) as pre_goal_difference,
       round(avg(points::numeric) over last_3, 3) as pre_points_per_match_3,
       round(avg(points::numeric) over last_5, 3) as pre_points_per_match_5,
       round(avg(points::numeric) over last_10, 3) as pre_points_per_match_10,
       sum(points) over season_through as post_points,
       sum(goal_difference) over season_through as post_goal_difference
from labelled
window
  season_prior as (
    partition by season, league, team
    order by match_date, kickoff_at nulls last, game_id
    rows between unbounded preceding and 1 preceding
  ),
  season_through as (
    partition by season, league, team
    order by match_date, kickoff_at nulls last, game_id
    rows between unbounded preceding and current row
  ),
  last_3 as (
    partition by season, league, team
    order by match_date, kickoff_at nulls last, game_id
    rows between 3 preceding and 1 preceding
  ),
  last_5 as (
    partition by season, league, team
    order by match_date, kickoff_at nulls last, game_id
    rows between 5 preceding and 1 preceding
  ),
  last_10 as (
    partition by season, league, team
    order by match_date, kickoff_at nulls last, game_id
    rows between 10 preceding and 1 preceding
  );

comment on view public.v_ml_team_match_outcomes is
  'Service-only team-perspective labels and strictly prior league form. Result and points are targets; pre_* columns exclude the target match.';

alter table public.archive_match_manifest enable row level security;
alter table public.ml_team_match_features enable row level security;
alter table public.ml_model_runs enable row level security;
alter table public.ml_match_predictions enable row level security;
alter table public.ml_season_simulation_runs enable row level security;
alter table public.ml_season_simulation_teams enable row level security;

revoke all on table public.archive_match_manifest from public, anon, authenticated;
revoke all on table public.ml_team_match_features from public, anon, authenticated;
revoke all on table public.ml_model_runs from public, anon, authenticated;
revoke all on table public.ml_match_predictions from public, anon, authenticated;
revoke all on table public.ml_season_simulation_runs from public, anon, authenticated;
revoke all on table public.ml_season_simulation_teams from public, anon, authenticated;
revoke all on table public.v_ml_team_match_outcomes from public, anon, authenticated;

grant select, insert, update, delete on table public.archive_match_manifest to service_role;
grant select, insert, update, delete on table public.ml_team_match_features to service_role;
grant select, insert, update, delete on table public.ml_model_runs to service_role;
grant select, insert, update, delete on table public.ml_match_predictions to service_role;
grant select, insert, update, delete on table public.ml_season_simulation_runs to service_role;
grant select, insert, update, delete on table public.ml_season_simulation_teams to service_role;
grant select on table public.v_ml_team_match_outcomes to service_role;

grant usage, select on sequence public.ml_model_runs_id_seq to service_role;
grant usage, select on sequence public.ml_match_predictions_id_seq to service_role;
grant usage, select on sequence public.ml_season_simulation_runs_id_seq to service_role;

commit;
