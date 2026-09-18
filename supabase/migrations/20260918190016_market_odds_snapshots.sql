-- Immutable service-only 1X2 market snapshots for model benchmarking.

create table public.ml_market_odds_snapshots (
  id bigint generated always as identity primary key,
  game_id text not null references public.matches(game_id),
  source text not null,
  source_event_id text not null,
  bookmaker_key text not null,
  bookmaker_name text not null,
  market_key text not null default 'h2h' check (market_key = 'h2h'),
  snapshot_kind text not null check (snapshot_kind in ('thursday','pre_kickoff','ad_hoc')),
  captured_at timestamptz not null,
  commence_time timestamptz not null,
  source_updated_at timestamptz,
  home_odds numeric(12,6) not null check (home_odds > 1),
  draw_odds numeric(12,6) not null check (draw_odds > 1),
  away_odds numeric(12,6) not null check (away_odds > 1),
  home_probability_fair numeric(12,10) not null check (home_probability_fair between 0 and 1),
  draw_probability_fair numeric(12,10) not null check (draw_probability_fair between 0 and 1),
  away_probability_fair numeric(12,10) not null check (away_probability_fair between 0 and 1),
  overround numeric(12,10) not null check (overround > -0.25 and overround < 1),
  payload_hash text not null unique check (payload_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  constraint ml_market_odds_fair_probability_sum check (
    abs(home_probability_fair + draw_probability_fair + away_probability_fair - 1) <= 0.000001
  ),
  constraint ml_market_odds_pre_match_capture check (captured_at < commence_time)
);

comment on table public.ml_market_odds_snapshots is
  'Immutable bookmaker-level pre-match 1X2 snapshots. Service-only research data; never a guaranteed-profit signal or an automatic model-training target.';
comment on column public.ml_market_odds_snapshots.snapshot_kind is
  'thursday is captured with the frozen forecast; pre_kickoff is a later price and is only called closing when its measured time-to-kickoff satisfies the reporting gate.';

create index ml_market_odds_game_capture_idx
  on public.ml_market_odds_snapshots (game_id, captured_at desc);
create index ml_market_odds_kind_capture_idx
  on public.ml_market_odds_snapshots (snapshot_kind, captured_at desc);

alter table public.ml_market_odds_snapshots enable row level security;
revoke all on table public.ml_market_odds_snapshots from anon, authenticated;
revoke all on sequence public.ml_market_odds_snapshots_id_seq from anon, authenticated;
grant select, insert on table public.ml_market_odds_snapshots to service_role;
grant usage, select on sequence public.ml_market_odds_snapshots_id_seq to service_role;

create view public.v_ml_market_odds_consensus
with (security_invoker = true)
as
select
  game_id,
  source,
  snapshot_kind,
  captured_at,
  commence_time,
  count(*)::integer as bookmaker_count,
  avg(home_probability_fair)::numeric(12,10) as home_probability_fair,
  avg(draw_probability_fair)::numeric(12,10) as draw_probability_fair,
  avg(away_probability_fair)::numeric(12,10) as away_probability_fair,
  avg(overround)::numeric(12,10) as mean_overround,
  min(source_updated_at) as oldest_source_update,
  max(source_updated_at) as newest_source_update,
  extract(epoch from (commence_time - captured_at)) / 60.0 as minutes_before_kickoff
from public.ml_market_odds_snapshots
group by game_id, source, snapshot_kind, captured_at, commence_time;

comment on view public.v_ml_market_odds_consensus is
  'Equal-weight consensus of de-vigged bookmaker 1X2 probabilities for each immutable capture batch.';

revoke all on table public.v_ml_market_odds_consensus from anon, authenticated;
grant select on table public.v_ml_market_odds_consensus to service_role;
