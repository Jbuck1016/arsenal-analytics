
drop materialized view if exists public.player_search cascade;
create materialized view public.player_search as
select
  pcr.player_id, pcr.player, pcr.team, pcr.pos,
  case right(pcr.pos,1) when 'R' then 'R' when 'L' then 'L' else 'C' end as side,
  z.pool, m.nineties, pcr.inv,
  b.age_seen, b.age_seen_date, b.height_cm, b.weight_kg, b.nationality,
  ft.foot, ft.left_share, ft.foot_confidence,
  ar.primary_label as archetype_primary, ar.secondary_label as archetype_secondary,
  ar.archetype, ar.pool_archetype,
  pcr.initiator, pcr.bridge, pcr.progressor, pcr.carrier, pcr.vertical,
  pcr.support_angle, pcr.individual, pcr.creator, pcr.box_threat, pcr.finisher,
  pcr.hold_secs, pcr.player_xt,
  pr.prog_att_90, pr.prog_completion, pr.prog_tendency_pct, pr.prog_into_final_90,
  tj.pct_over, tj.pct_around, tj.pct_through,
  tj.pct_inside, tj.pct_in_behind, tj.pct_outside,
  tj.comp_over, tj.comp_around, tj.comp_through, tj.fwd_passes,
  cv.early_shot_inv_90, cv.shot_chain_pct, cv.early_shot_pct, cv.mean_chain_xt, cv.mean_steps_from_end,
  m.pass_cmp_90, m.pass_pct, m.prog_cmp_90, m.prog_pct, m.into_box_90, m.final_third_90,
  m.through_90, m.cross_90, m.cross_pct, m.key_pass_90, m.assist_90, m.bcc_90, m.long_90, m.long_pct,
  m.carries_90, m.prog_carries_90, m.carry_box_90, m.mean_carry_m, m.carry_pen_90,
  m.takeon_90, m.takeon_pct, m.disp_90,
  m.shots_90, m.sot_90, m.goals_90, m.xg_90, m.xg_per_shot, m.conversion, m.bigchance_90, m.finishing,
  m.xt_90, m.xt_pass_90, m.xt_carry_90, m.xa_90, m.sca_90,
  m.tackle_90, m.tackle_pct, m.int_90, m.recov_90, m.aerial_90, m.aerial_pct,
  m.counterpress_90, m.def_action_90, m.box_def_90, m.channel_def_90, m.flank_def_90,
  coalesce(pl.league, 'USA-MLS') as league
from public.player_chain_roles pcr
join public.pcr_z z on z.player_id = pcr.player_id
left join public.v_player_metrics_ext m on m.player_id = pcr.player_id
left join public.player_bio b on b.player_id = pcr.player_id
left join public.mv_player_foot ft on ft.player_id = pcr.player_id
left join public.mv_player_archetype ar on ar.player_id = pcr.player_id
left join public.mv_player_progression pr on pr.player_id = pcr.player_id
left join public.mv_player_pass_traj tj on tj.player_id = pcr.player_id
left join public.mv_player_chain_value cv on cv.player_id = pcr.player_id
left join public.mv_player_league pl on pl.player_id = pcr.player_id;
create unique index player_search_pk on public.player_search (player_id);
create index player_search_side on public.player_search (side);
create index player_search_pool on public.player_search (pool);
create index player_search_pos  on public.player_search (pos);
create index player_search_age  on public.player_search (age_seen);
create index player_search_foot on public.player_search (foot);
create index player_search_league on public.player_search (league);
grant select on public.player_search to anon, authenticated;
