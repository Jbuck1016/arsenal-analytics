create materialized view mv_player_metrics as
select
  r.player_id, r.player_name, r.team, r.nineties,
  round(r.pass_cmp / r.nineties, 2) as pass_cmp_90,
  round(100.0*r.pass_cmp / nullif(r.pass_att,0), 1) as pass_pct,
  round(r.prog_cmp / r.nineties, 2) as prog_cmp_90,
  case when r.prog_att >= 25 then round(100.0*r.prog_cmp/r.prog_att,1) end as prog_pct,
  round((r.territory_gained / r.nineties)::numeric, 1) as territory_90,
  round(r.into_box / r.nineties, 2) as into_box_90,
  round(r.final_third_passes / r.nineties, 2) as final_third_90,
  round(r.through_balls / r.nineties, 3) as through_90,
  round(r.cross_att / r.nineties, 2) as cross_90,
  case when r.cross_att >= 20 then round(100.0*r.cross_cmp/r.cross_att,1) end as cross_pct,
  round(r.key_passes / r.nineties, 2) as key_pass_90,
  round(r.assists / r.nineties, 3) as assist_90,
  round(r.big_chances_created / r.nineties, 3) as bcc_90,
  round(r.long_att / r.nineties, 2) as long_90,
  case when r.long_att >= 25 then round(100.0*r.long_cmp/r.long_att,1) end as long_pct,
  round(r.shots / r.nineties, 2) as shots_90,
  round(coalesce(sf.sot_true,0) / r.nineties, 2) as sot_90,
  round(coalesce(sf.blocked,0) / r.nineties, 2) as blocked_90,
  round(greatest(r.goals - coalesce(og.own_goals,0),0) / r.nineties, 3) as goals_90,
  case when r.shots >= 10 then round(100.0*r.shots_in_box/r.shots,1) end as box_share,
  case when r.shots >= 10 then round((r.shot_dist_sum/r.shots)::numeric,1) end as shot_dist,
  case when r.shots >= 12 then round(100.0*greatest(r.goals-coalesce(og.own_goals,0),0)/r.shots,1) end as conversion,
  case when r.shots >= 10 then round(100.0*coalesce(sf.sot_true,0)/r.shots,1) end as shot_acc,
  round(r.big_chance_shots / r.nineties, 3) as bigchance_90,
  case when (r.rf_shots+r.lf_shots) >= 10
       then round(100.0*least(r.rf_shots,r.lf_shots)/(r.rf_shots+r.lf_shots),1) end as weak_foot_share,
  round(r.tackle_att / r.nineties, 2) as tackle_90,
  case when r.tackle_att >= 15 then round(100.0*r.tackle_won/r.tackle_att,1) end as tackle_pct,
  round(r.interceptions / r.nineties, 2) as int_90,
  round(r.clearances / r.nineties, 2) as clear_90,
  round(r.blocks / r.nineties, 2) as block_90,
  round(r.recoveries / r.nineties, 2) as recov_90,
  round(r.aerial_att / r.nineties, 2) as aerial_90,
  case when r.aerial_att >= 20 then round(100.0*r.aerial_won/r.aerial_att,1) end as aerial_pct,
  round((r.tackle_att+r.interceptions+r.clearances+r.blocks+r.recoveries)/r.nineties,2) as def_action_90,
  r.def_action_x as def_height,
  round(r.takeon_att / r.nineties, 2) as takeon_90,
  case when r.takeon_att >= 15 then round(100.0*r.takeon_won/r.takeon_att,1) end as takeon_pct,
  round(r.dispossessed / r.nineties, 2) as disp_90,
  round(r.bad_touches / r.nineties, 2) as badtouch_90,
  round(r.fouls_committed / r.nineties, 2) as foul_com_90,
  round(r.fouls_won / r.nineties, 2) as foul_won_90,
  round(r.errors / r.nineties, 3) as error_90,
  round(c.carries / r.nineties, 2) as carries_90,
  round(c.prog_carries / r.nineties, 2) as prog_carries_90,
  round(c.carries_into_box / r.nineties, 2) as carry_box_90,
  c.mean_carry_m,
  round(c.carry_penetration / r.nineties, 1) as carry_pen_90,
  round(c.median_ttr::numeric,2) as median_ttr,
  case when c.pass_releases >= 50 then round(100.0*c.quick_release/c.pass_releases,1) end as quick_pct,
  case when c.pass_releases >= 50 then round(100.0*c.one_touch/c.pass_releases,1) end as one_touch_pct,
  ch.aq_per_duel, ch.duel_quality, ch.recov_retention,
  round(ch.recov_prog_pass / r.nineties, 2) as recov_prog_90,
  round(coalesce(sx.xg,0) / r.nineties, 3) as xg_90,
  case when r.shots >= 10 then round((coalesce(sx.xg,0)/nullif(sx.shots,0))::numeric,3) end as xg_per_shot,
  round((greatest(r.goals-coalesce(og.own_goals,0),0) - coalesce(sx.xg,0)) / r.nineties, 3) as finishing,
  round(coalesce(xa.xa,0) / r.nineties, 3) as xa_90,
  round(coalesce(xt.xt_total,0) / r.nineties, 3) as xt_90,
  round(coalesce(xt.xt_pass,0)  / r.nineties, 3) as xt_pass_90,
  round(coalesce(xt.xt_carry,0) / r.nineties, 3) as xt_carry_90,
  gk.save_pct,
  round(coalesce(gk.goals_prevented,0) / r.nineties, 3) as goals_prevented_90,
  round(gk.saves / r.nineties, 2)  as saves_90,
  round(gk.claims / r.nineties, 2) as claims_90,
  round(gk.sweeps / r.nineties, 2) as sweeps_90,
  gk.sweep_x
from mv_player_metrics_raw r
left join mv_player_carry  c  on c.player_id  = r.player_id
left join mv_player_chains ch on ch.player_id = r.player_id
left join mv_player_xa     xa on xa.player_id = r.player_id
left join mv_player_xt     xt on xt.player_id = r.player_id
left join mv_player_gk     gk on gk.player_id = r.player_id
left join v_goal_fix       og on og.player_id = r.player_id
left join v_player_sot_fix sf on sf.player_id = r.player_id
left join (select player_id, sum(xg) as xg, count(*) as shots from mv_shot_xg group by player_id) sx
       on sx.player_id = r.player_id
where r.nineties > 0;
create unique index on mv_player_metrics (player_id);
grant select on mv_player_metrics to anon, authenticated;
