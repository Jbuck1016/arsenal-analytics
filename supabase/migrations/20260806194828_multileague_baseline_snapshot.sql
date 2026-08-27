
-- Regression baseline for the multi-league retrofit.
-- With only MLS data present, a CORRECT retrofit must leave every one of these unchanged.
-- Anything that moves afterwards is a bug, not a feature.
drop table if exists public._ml_baseline;
create table public._ml_baseline as
  select 'player_pct'::text as src, player_id::text as k1, metric as k2, pct_pool::numeric as val
  from public.mv_player_pct
  union all
  select 'player_percentiles', player_id::text, metric, pct::numeric
  from public.mv_player_percentiles
  union all
  select 'player_chain_pct', player_id::text, role, pct::numeric
  from public.player_chain_pct
  union all
  select 'team_seq_style', team, metric, z::numeric
  from public.team_sequence_style
  union all
  select 'player_dna', player_id::text, 'dna', null::numeric
  from public.mv_player_dna
  union all
  select 'squad_role', player_id::text, squad_role, selection_pct::numeric
  from public.mv_squad_role
  union all
  select 'team_directness', team, 'swing', swing_l_minus_w::numeric
  from public.mv_team_directness_state;

create index _ml_baseline_idx on public._ml_baseline (src, k1, k2);

select 'baseline_rows' as k, count(*)::text as v from public._ml_baseline
union all select 'sources', count(distinct src)::text from public._ml_baseline;
