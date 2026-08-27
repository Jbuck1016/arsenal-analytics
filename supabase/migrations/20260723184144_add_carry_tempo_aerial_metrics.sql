insert into public.metric_defs (key,label,grp,unit,higher_is_better,definition,grp_order,sort_order) values
 ('carries_90','Carries','Carrying',null,true,'Times he moved the ball 3m or more before releasing it, per 90.',4,1),
 ('prog_carries_90','Progressive carries','Carrying',null,true,'Carries cutting the distance to goal by more than 15%, per 90.',4,2),
 ('carry_box_90','Carries into box','Carrying',null,true,'Carries ending inside the penalty area, per 90.',4,3),
 ('mean_carry_m','Mean carry distance','Carrying','m',true,'Average length of a carry.',4,4),
 ('carry_pen_90','Carry penetration','Carrying','m',true,'Metres of distance-to-goal eliminated by carrying, per 90.',4,5),
 ('median_ttr','Median release','Tempo','s',false,'Seconds between receiving the ball and releasing it. Lower is quicker.',5,1),
 ('quick_pct','Quick passes','Tempo','%',true,'Share of passes released within two seconds of receiving.',5,2),
 ('one_touch_pct','One-touch tempo','Tempo','%',true,'Share of passes released within one second.',5,3),
 ('aq_per_duel','AQ points per duel','Aerial',null,true,'Aerial Quality: 2 for keeping the ball yourself, 1 for it dropping to a teammate, minus 1 for handing it to the opposition. Averaged over duels won.',7,1),
 ('duel_quality','Duel quality','Aerial','%',true,'Of the aerials he wins, the share where the ball stays with his own side. Needs 10 wins.',7,2),
 ('recov_retention','Post-recovery retention','Aerial','%',true,'Completion rate of his first pass after winning the ball back. Needs 10 attempts.',7,3),
 ('recov_prog_90','Prog. passes off recovery','Aerial',null,true,'Completed progressive passes played straight off a ball recovery, per 90.',7,4)
on conflict (key) do nothing;

update public.metric_defs set grp_order = 6 where grp='Defending';
update public.metric_defs set grp_order = 8 where grp='Discipline';

drop materialized view if exists mv_player_percentiles cascade;
drop materialized view if exists mv_player_metrics cascade;

create materialized view mv_player_metrics as
select
  r.player_id, r.player_name, r.team, r.nineties,
  round(r.pass_cmp / r.nineties, 2)                                   as pass_cmp_90,
  round(100.0*r.pass_cmp / nullif(r.pass_att,0), 1)                   as pass_pct,
  round(r.prog_cmp / r.nineties, 2)                                   as prog_cmp_90,
  case when r.prog_att >= 25 then round(100.0*r.prog_cmp/r.prog_att,1) end as prog_pct,
  round((r.territory_gained / r.nineties)::numeric, 1)                as territory_90,
  round(r.into_box / r.nineties, 2)                                   as into_box_90,
  round(r.final_third_passes / r.nineties, 2)                         as final_third_90,
  round(r.through_balls / r.nineties, 3)                              as through_90,
  round(r.cross_att / r.nineties, 2)                                  as cross_90,
  case when r.cross_att >= 20 then round(100.0*r.cross_cmp/r.cross_att,1) end as cross_pct,
  round(r.key_passes / r.nineties, 2)                                 as key_pass_90,
  round(r.assists / r.nineties, 3)                                    as assist_90,
  round(r.big_chances_created / r.nineties, 3)                        as bcc_90,
  round(r.long_att / r.nineties, 2)                                   as long_90,
  case when r.long_att >= 25 then round(100.0*r.long_cmp/r.long_att,1) end as long_pct,
  round(r.shots / r.nineties, 2)                                      as shots_90,
  round(r.sot / r.nineties, 2)                                        as sot_90,
  round(r.goals / r.nineties, 3)                                      as goals_90,
  case when r.shots >= 10 then round(100.0*r.shots_in_box/r.shots,1) end as box_share,
  case when r.shots >= 10 then round((r.shot_dist_sum/r.shots)::numeric,1) end as shot_dist,
  case when r.shots >= 12 then round(100.0*r.goals/r.shots,1) end     as conversion,
  case when r.shots >= 10 then round(100.0*r.sot/r.shots,1) end       as shot_acc,
  round(r.big_chance_shots / r.nineties, 3)                           as bigchance_90,
  case when (r.rf_shots + r.lf_shots) >= 10
       then round(100.0*least(r.rf_shots,r.lf_shots)/(r.rf_shots+r.lf_shots),1) end as weak_foot_share,
  round(r.tackle_att / r.nineties, 2)                                 as tackle_90,
  case when r.tackle_att >= 15 then round(100.0*r.tackle_won/r.tackle_att,1) end as tackle_pct,
  round(r.interceptions / r.nineties, 2)                              as int_90,
  round(r.clearances / r.nineties, 2)                                 as clear_90,
  round(r.blocks / r.nineties, 2)                                     as block_90,
  round(r.recoveries / r.nineties, 2)                                 as recov_90,
  round(r.aerial_att / r.nineties, 2)                                 as aerial_90,
  case when r.aerial_att >= 20 then round(100.0*r.aerial_won/r.aerial_att,1) end as aerial_pct,
  round((r.tackle_att+r.interceptions+r.clearances+r.blocks+r.recoveries) / r.nineties, 2) as def_action_90,
  r.def_action_x                                                      as def_height,
  round(r.takeon_att / r.nineties, 2)                                 as takeon_90,
  case when r.takeon_att >= 15 then round(100.0*r.takeon_won/r.takeon_att,1) end as takeon_pct,
  round(r.dispossessed / r.nineties, 2)                               as disp_90,
  round(r.bad_touches / r.nineties, 2)                                as badtouch_90,
  round(r.fouls_committed / r.nineties, 2)                            as foul_com_90,
  round(r.fouls_won / r.nineties, 2)                                  as foul_won_90,
  round(r.errors / r.nineties, 3)                                     as error_90,
  -- carrying
  round(c.carries / r.nineties, 2)                                    as carries_90,
  round(c.prog_carries / r.nineties, 2)                               as prog_carries_90,
  round(c.carries_into_box / r.nineties, 2)                           as carry_box_90,
  c.mean_carry_m                                                      as mean_carry_m,
  round(c.carry_penetration / r.nineties, 1)                          as carry_pen_90,
  -- tempo
  round(c.median_ttr::numeric, 2)                                     as median_ttr,
  case when c.pass_releases >= 50
       then round(100.0*c.quick_release/c.pass_releases,1) end        as quick_pct,
  case when c.pass_releases >= 50
       then round(100.0*c.one_touch/c.pass_releases,1) end            as one_touch_pct,
  -- chains
  ch.aq_per_duel, ch.duel_quality, ch.recov_retention,
  round(ch.recov_prog_pass / r.nineties, 2)                           as recov_prog_90
from mv_player_metrics_raw r
left join mv_player_carry  c  on c.player_id  = r.player_id
left join mv_player_chains ch on ch.player_id = r.player_id
where r.nineties > 0;

create unique index on mv_player_metrics (player_id);

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
    ('shot_acc',m.shot_acc),('bigchance_90',m.bigchance_90),('weak_foot_share',m.weak_foot_share),
    ('tackle_90',m.tackle_90),('tackle_pct',m.tackle_pct),('int_90',m.int_90),
    ('clear_90',m.clear_90),('block_90',m.block_90),('recov_90',m.recov_90),
    ('aerial_90',m.aerial_90),('aerial_pct',m.aerial_pct),
    ('def_action_90',m.def_action_90),('def_height',m.def_height),
    ('takeon_90',m.takeon_90),('takeon_pct',m.takeon_pct),
    ('disp_90',m.disp_90),('badtouch_90',m.badtouch_90),
    ('foul_com_90',m.foul_com_90),('foul_won_90',m.foul_won_90),('error_90',m.error_90),
    ('carries_90',m.carries_90),('prog_carries_90',m.prog_carries_90),
    ('carry_box_90',m.carry_box_90),('mean_carry_m',m.mean_carry_m),('carry_pen_90',m.carry_pen_90),
    ('median_ttr',m.median_ttr),('quick_pct',m.quick_pct),('one_touch_pct',m.one_touch_pct),
    ('aq_per_duel',m.aq_per_duel),('duel_quality',m.duel_quality),
    ('recov_retention',m.recov_retention),('recov_prog_90',m.recov_prog_90)
  ) as v(metric, value)
),
ranked as (
  select l.*, d.higher_is_better,
    percent_rank() over (partition by l.pool, l.metric order by l.value) as pr
  from long l
  join public.metric_defs d on d.key = l.metric
  where l.nineties >= 6 and l.value is not null
)
select player_id, pool, metric, value,
       round((100 * case when higher_is_better then pr else 1 - pr end)::numeric, 0) as pct
from ranked;

create index on mv_player_percentiles (player_id);
create index on mv_player_percentiles (pool, metric);
grant select on mv_player_metrics, mv_player_percentiles to anon, authenticated;
