
-- Repoint progression + chain value at base sources (they must not depend on player_search,
-- because player_search now depends on them).
drop materialized view if exists public.mv_player_progression cascade;
create materialized view public.mv_player_progression as
with pa as (
  select e.player_id,
    count(*) filter (where e.type='Pass') as passes_att,
    count(*) filter (where e.type='Pass' and e.end_x is not null and (e.end_x-e.x) >= 10) as prog_att,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful'
                      and e.end_x is not null and (e.end_x-e.x) >= 10) as prog_cmp,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful'
                      and e.end_x is not null and (e.end_x-e.x) >= 10 and e.end_x >= 66.7) as prog_into_final
  from public.events e where e.player_id is not null group by e.player_id
)
select pa.player_id, pcr.player, pcr.team, pcr.pos, m.nineties,
  pa.passes_att, pa.prog_att, pa.prog_cmp,
  round(pa.prog_att / nullif(m.nineties,0), 2) as prog_att_90,
  round(pa.prog_cmp / nullif(m.nineties,0), 2) as prog_cmp_90_own,
  round(pa.prog_into_final / nullif(m.nineties,0), 2) as prog_into_final_90,
  round(100.0*pa.prog_cmp / nullif(pa.prog_att,0), 1) as prog_completion,
  round(100.0*pa.prog_att / nullif(pa.passes_att,0), 1) as prog_tendency_pct
from pa
join public.player_chain_roles pcr on pcr.player_id = pa.player_id
left join public.v_player_metrics_ext m on m.player_id = pa.player_id;
create unique index mv_player_progression_pk on public.mv_player_progression (player_id);
grant select on public.mv_player_progression to anon, authenticated;

drop materialized view if exists public.mv_player_chain_value cascade;
create materialized view public.mv_player_chain_value as
with inv as (
  select se.player_id, se.player, se.team, se.ord_a, se.chain_len,
    (se.chain_len - se.ord_a) as steps_from_end,
    s.ended_shot, s.ended_goal, s.xt_sum, s.n_pass
  from public.mv_seq_events se
  join public.sequences s using (seq_uid)
  where se.seq_setpiece = false and s.is_open_play and se.player_id is not null
),
agg as (
  select player_id, max(player) player, max(team) team,
    count(*) involvements,
    count(*) filter (where ended_shot) shot_chain_inv,
    count(*) filter (where ended_shot and steps_from_end >= 3) early_shot_inv,
    count(*) filter (where ended_goal and steps_from_end >= 3) early_goal_inv,
    round(avg(steps_from_end)::numeric, 2) mean_steps_from_end,
    round(avg(xt_sum)::numeric, 4) mean_chain_xt
  from inv group by player_id
)
select a.*, m.nineties,
  round(100.0*a.shot_chain_inv/nullif(a.involvements,0), 2) as shot_chain_pct,
  round(100.0*a.early_shot_inv/nullif(a.involvements,0), 2) as early_shot_pct,
  round(a.early_shot_inv/nullif(m.nineties,0), 2) as early_shot_inv_90,
  round(a.shot_chain_inv/nullif(m.nineties,0), 2) as shot_chain_inv_90,
  round(a.early_goal_inv/nullif(m.nineties,0), 3) as early_goal_inv_90
from agg a
join public.player_chain_roles pcr on pcr.player_id = a.player_id
left join public.v_player_metrics_ext m on m.player_id = a.player_id
where a.involvements >= 120;
create unique index mv_player_chain_value_pk on public.mv_player_chain_value (player_id);
grant select on public.mv_player_chain_value to anon, authenticated;

-- Extended search index: bio + roles + metrics + foot + archetype + trajectory + chain value.
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
  m.counterpress_90, m.def_action_90, m.box_def_90, m.channel_def_90, m.flank_def_90
from public.player_chain_roles pcr
join public.pcr_z z on z.player_id = pcr.player_id
left join public.v_player_metrics_ext m on m.player_id = pcr.player_id
left join public.player_bio b on b.player_id = pcr.player_id
left join public.mv_player_foot ft on ft.player_id = pcr.player_id
left join public.mv_player_archetype ar on ar.player_id = pcr.player_id
left join public.mv_player_progression pr on pr.player_id = pcr.player_id
left join public.mv_player_pass_traj tj on tj.player_id = pcr.player_id
left join public.mv_player_chain_value cv on cv.player_id = pcr.player_id;
create unique index player_search_pk on public.player_search (player_id);
create index player_search_side on public.player_search (side);
create index player_search_pool on public.player_search (pool);
create index player_search_pos  on public.player_search (pos);
create index player_search_age  on public.player_search (age_seen);
create index player_search_foot on public.player_search (foot);
grant select on public.player_search to anon, authenticated;
