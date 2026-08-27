
drop materialized view if exists public.player_search;
create materialized view public.player_search as
select
  pcr.player_id, pcr.player, pcr.team, pcr.pos,
  case right(pcr.pos,1) when 'R' then 'R' when 'L' then 'L' else 'C' end as side,
  z.pool,
  m.nineties, pcr.inv,
  -- chain-role profile (% of involvements)
  pcr.initiator, pcr.bridge, pcr.progressor, pcr.carrier, pcr.vertical,
  pcr.support_angle, pcr.individual, pcr.creator, pcr.box_threat, pcr.finisher,
  pcr.hold_secs, pcr.player_xt,
  -- progression / passing
  m.pass_cmp_90, m.pass_pct, m.prog_cmp_90, m.prog_pct, m.into_box_90, m.final_third_90,
  m.through_90, m.cross_90, m.cross_pct, m.key_pass_90, m.assist_90, m.bcc_90, m.long_90, m.long_pct,
  -- carrying
  m.carries_90, m.prog_carries_90, m.carry_box_90, m.mean_carry_m, m.carry_pen_90,
  m.takeon_90, m.takeon_pct, m.disp_90,
  -- shooting / finishing
  m.shots_90, m.sot_90, m.goals_90, m.xg_90, m.xg_per_shot, m.conversion, m.bigchance_90, m.finishing,
  -- threat / creation
  m.xt_90, m.xt_pass_90, m.xt_carry_90, m.xa_90, m.sca_90,
  -- defending
  m.tackle_90, m.tackle_pct, m.int_90, m.recov_90, m.aerial_90, m.aerial_pct,
  m.counterpress_90, m.def_action_90, m.box_def_90, m.channel_def_90, m.flank_def_90
from public.player_chain_roles pcr
join public.pcr_z z on z.player_id = pcr.player_id
left join public.v_player_metrics_ext m on m.player_id = pcr.player_id;

create unique index player_search_pk on public.player_search (player_id);
create index player_search_side on public.player_search (side);
create index player_search_pool on public.player_search (pool);
create index player_search_pos  on public.player_search (pos);
grant select on public.player_search to anon, authenticated;
