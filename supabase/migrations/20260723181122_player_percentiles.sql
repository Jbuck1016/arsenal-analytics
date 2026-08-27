create materialized view mv_player_percentiles as
with long as (
  select m.player_id, r.pool, m.nineties, v.metric, v.value
  from mv_player_metrics m
  join mv_player_role r using (player_id)
  cross join lateral (values
    ('pass_cmp_90',m.pass_cmp_90),('pass_pct',m.pass_pct),
    ('prog_cmp_90',m.prog_cmp_90),('prog_pct',m.prog_pct),
    ('territory_90',m.territory_90),('into_box_90',m.into_box_90),
    ('final_third_90',m.final_third_90),('through_90',m.through_90),
    ('cross_90',m.cross_90),('cross_pct',m.cross_pct),
    ('key_pass_90',m.key_pass_90),('assist_90',m.assist_90),('bcc_90',m.bcc_90),
    ('long_90',m.long_90),('long_pct',m.long_pct),
    ('shots_90',m.shots_90),('sot_90',m.sot_90),('goals_90',m.goals_90),
    ('box_share',m.box_share),('shot_dist',m.shot_dist),('conversion',m.conversion),
    ('shot_acc',m.shot_acc),('bigchance_90',m.bigchance_90),
    ('weak_foot_share',m.weak_foot_share),
    ('tackle_90',m.tackle_90),('tackle_pct',m.tackle_pct),('int_90',m.int_90),
    ('clear_90',m.clear_90),('block_90',m.block_90),('recov_90',m.recov_90),
    ('aerial_90',m.aerial_90),('aerial_pct',m.aerial_pct),
    ('def_action_90',m.def_action_90),('def_height',m.def_height),
    ('takeon_90',m.takeon_90),('takeon_pct',m.takeon_pct),
    ('disp_90',m.disp_90),('badtouch_90',m.badtouch_90),
    ('foul_com_90',m.foul_com_90),('foul_won_90',m.foul_won_90),('error_90',m.error_90)
  ) as v(metric, value)
),
ranked as (
  select l.*, d.higher_is_better,
    case when l.nineties >= 6 and l.value is not null then
      percent_rank() over (
        partition by l.pool, l.metric
        order by l.value
      )
    end as pr
  from long l
  join public.metric_defs d on d.key = l.metric
  where l.nineties >= 6 and l.value is not null
)
select
  player_id, pool, metric, value,
  round((100 * case when higher_is_better then pr else 1 - pr end)::numeric, 0) as pct
from ranked;

create index on mv_player_percentiles (player_id);
create index on mv_player_percentiles (pool, metric);
grant select on mv_player_percentiles to anon, authenticated;
