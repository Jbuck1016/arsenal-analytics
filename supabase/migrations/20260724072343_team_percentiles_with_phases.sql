create materialized view mv_team_percentiles as
with long as (
  select t.team, v.metric, v.value
  from mv_team_all t
  cross join lateral (values
    ('possession_pct',t.possession_pct),('field_tilt',t.field_tilt),
    ('avg_touch_x',t.avg_touch_x),('directness',t.directness),
    ('long_ball_pct',t.long_ball_pct),('build_from_back_pct',t.build_from_back_pct),
    ('ppda',t.ppda),('def_height',t.def_height),
    ('prog_passes_pg',t.prog_passes_pg),('box_entries_pg',t.box_entries_pg),
    ('crosses_pg',t.crosses_pg),('shots_pg',t.shots_pg),('goals_pg',t.goals_pg),
    ('open_play_shot_pct',t.open_play_shot_pct),
    ('shots_against_pg',t.shots_against_pg),('goals_against_pg',t.goals_against_pg),
    ('passes_per_seq',t.passes_per_seq),('secs_per_seq',t.secs_per_seq),
    ('long_sequence_pct',t.long_sequence_pct),
    ('pct_ending_in_shot',t.pct_ending_in_shot),('ground_gained',t.ground_gained),
    ('sequences_pg',t.sequences_pg),
    ('gk_long_pct',t.gk_long_pct),('d3_pass_share',t.d3_pass_share),
    ('d3_accuracy',t.d3_accuracy),('d3_long_pct',t.d3_long_pct),
    ('deep_circulation_pg',t.deep_circulation_pg),('cb_prog_pg',t.cb_prog_pg),
    ('escape_pct',t.escape_pct),('deep_to_final_pct',t.deep_to_final_pct),
    ('d3_touch_share',t.d3_touch_share),
    ('att_directness',t.att_directness),('mid_release',t.mid_release),
    ('ft_release',t.ft_release),('passes_per_shot',t.passes_per_shot),
    ('ft_entries_pg',t.ft_entries_pg),('box_per_entry',t.box_per_entry),
    ('final_to_shot_pct',t.final_to_shot_pct),
    ('pct_left',t.pct_left),('pct_centre',t.pct_centre),('pct_right',t.pct_right)
  ) as v(metric,value)
),
r as (
  select l.*, d.higher_is_better,
         percent_rank() over (partition by l.metric order by l.value) as pr
  from long l join public.team_metric_defs d on d.key=l.metric
  where l.value is not null
)
select team, metric, value,
       round((100*case when higher_is_better then pr else 1-pr end)::numeric,0) as pct
from r;
create index on mv_team_percentiles (team);
grant select on mv_team_percentiles to anon, authenticated;

create or replace function refresh_analytics()
returns text language plpgsql security definer set search_path = public as $$
begin
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
  refresh materialized view mv_player_metrics;
  refresh materialized view mv_player_percentiles;
  refresh materialized view mv_player_pillars;
  refresh materialized view mv_player_dna;
  refresh materialized view mv_metric_examples;
  return 'refreshed at ' || now()::text;
end;$$;
grant execute on function refresh_analytics() to anon, authenticated;
notify pgrst, 'reload schema';
