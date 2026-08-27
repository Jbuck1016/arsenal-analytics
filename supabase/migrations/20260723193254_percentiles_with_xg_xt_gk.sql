create materialized view mv_player_percentiles as
with base as (
  select m.*, p.team_possession, (50.0/nullif(100-p.team_possession,0)) as padj
  from mv_player_metrics m left join mv_player_team_poss p using (player_id)
),
long as (
  select b.player_id, r.pool, b.nineties, v.metric, v.value
  from base b join mv_player_role r using (player_id)
  cross join lateral (values
    ('pass_cmp_90',b.pass_cmp_90),('pass_pct',b.pass_pct),
    ('prog_cmp_90',b.prog_cmp_90),('prog_pct',b.prog_pct),
    ('territory_90',b.territory_90),('into_box_90',b.into_box_90),
    ('final_third_90',b.final_third_90),('through_90',b.through_90),
    ('cross_90',b.cross_90),('cross_pct',b.cross_pct),
    ('key_pass_90',b.key_pass_90),('assist_90',b.assist_90),('bcc_90',b.bcc_90),
    ('xa_90',b.xa_90),('xt_90',b.xt_90),('xt_pass_90',b.xt_pass_90),('xt_carry_90',b.xt_carry_90),
    ('long_90',b.long_90),('long_pct',b.long_pct),
    ('shots_90',b.shots_90),('sot_90',b.sot_90),('goals_90',b.goals_90),
    ('xg_90',b.xg_90),('xg_per_shot',b.xg_per_shot),('finishing',b.finishing),
    ('box_share',b.box_share),('shot_dist',b.shot_dist),('conversion',b.conversion),
    ('shot_acc',b.shot_acc),('bigchance_90',b.bigchance_90),('weak_foot_share',b.weak_foot_share),
    ('tackle_90',b.tackle_90),('tackle_pct',b.tackle_pct),('int_90',b.int_90),
    ('clear_90',b.clear_90),('block_90',b.block_90),('recov_90',b.recov_90),
    ('aerial_90',b.aerial_90),('aerial_pct',b.aerial_pct),
    ('def_action_90',b.def_action_90),('def_height',b.def_height),
    ('takeon_90',b.takeon_90),('takeon_pct',b.takeon_pct),
    ('disp_90',b.disp_90),('badtouch_90',b.badtouch_90),
    ('foul_com_90',b.foul_com_90),('foul_won_90',b.foul_won_90),('error_90',b.error_90),
    ('carries_90',b.carries_90),('prog_carries_90',b.prog_carries_90),
    ('carry_box_90',b.carry_box_90),('mean_carry_m',b.mean_carry_m),('carry_pen_90',b.carry_pen_90),
    ('median_ttr',b.median_ttr),('quick_pct',b.quick_pct),('one_touch_pct',b.one_touch_pct),
    ('aq_per_duel',b.aq_per_duel),('duel_quality',b.duel_quality),
    ('recov_retention',b.recov_retention),('recov_prog_90',b.recov_prog_90),
    ('save_pct',b.save_pct),('goals_prevented_90',b.goals_prevented_90),
    ('saves_90',b.saves_90),('claims_90',b.claims_90),('sweeps_90',b.sweeps_90),('sweep_x',b.sweep_x),
    ('padj_tackle_90', round((b.tackle_90    *b.padj)::numeric,2)),
    ('padj_int_90',    round((b.int_90       *b.padj)::numeric,2)),
    ('padj_def_90',    round((b.def_action_90*b.padj)::numeric,2)),
    ('padj_recov_90',  round((b.recov_90     *b.padj)::numeric,2))
  ) as v(metric,value)
),
ranked as (
  select l.*, d.higher_is_better,
    percent_rank() over (partition by l.pool, l.metric order by l.value) as pr
  from long l join public.metric_defs d on d.key=l.metric
  where l.nineties >= 6 and l.value is not null
)
select player_id, pool, metric, value,
       round((100*case when higher_is_better then pr else 1-pr end)::numeric,0) as pct
from ranked;
create index on mv_player_percentiles (player_id);
create index on mv_player_percentiles (pool, metric);
grant select on mv_player_percentiles to anon, authenticated;

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
  refresh materialized view mv_player_xa;
  refresh materialized view mv_player_xt;
  refresh materialized view mv_team_match;
  refresh materialized view mv_team_season;
  refresh materialized view mv_player_team_poss;
  refresh materialized view mv_gk_match;
  refresh materialized view mv_player_gk;
  refresh materialized view mv_player_metrics;
  refresh materialized view mv_player_percentiles;
  return 'refreshed at ' || now()::text;
end;$$;
grant execute on function refresh_analytics() to anon, authenticated;
notify pgrst, 'reload schema';
