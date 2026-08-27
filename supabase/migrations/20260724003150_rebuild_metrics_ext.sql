create or replace view v_player_metrics_ext as
select
  m.*,
  round(z.hs_passes      / m.nineties, 2) as hs_passes_90,
  round(z.hs_prog_passes / m.nineties, 2) as hs_prog_90,
  round(z.hs_key_passes  / m.nineties, 2) as hs_key_90,
  round(z.hs_shots       / m.nineties, 2) as hs_shots_90,
  round(z.hs_takeons     / m.nineties, 2) as hs_takeons_90,
  round(z.box_def_actions     / m.nineties, 2) as box_def_90,
  round(z.channel_def_actions / m.nineties, 2) as channel_def_90,
  round(z.flank_def_actions   / m.nineties, 2) as flank_def_90,
  round(cp.counterpress / m.nineties, 2)  as counterpress_90,
  round(sca.sca / m.nineties, 2)          as sca_90,
  round(hu.holds / m.nineties, 2)         as holds_90,
  case when hu.holds >= 10 then round(100.0*hu.holds_retained/hu.holds,1) end   as hold_retention,
  case when hu.holds >= 10 then round(100.0*hu.holds_prog_carry/hu.holds,1) end as hold_prog_pct,
  case when hu.holds >= 10 then round(100.0*hu.holds_shot/hu.holds,1) end       as hold_shot_pct,
  round(coalesce(sp.sp_xg,0) / m.nineties, 3)      as sp_xg_90,
  round(sp.sp_shots / m.nineties, 2)               as sp_shots_90,
  round(sp.sp_aerials_won / m.nineties, 2)         as sp_aerials_90,
  round(sp.sp_key_passes / m.nineties, 2)          as sp_key_90
from mv_player_metrics m
left join mv_player_zones        z   on z.player_id  = m.player_id
left join mv_player_counterpress cp  on cp.player_id = m.player_id
left join mv_player_sca          sca on sca.player_id= m.player_id
left join mv_player_holdup       hu  on hu.player_id = m.player_id
left join mv_player_setpiece     sp  on sp.player_id = m.player_id;
grant select on v_player_metrics_ext to anon, authenticated;
