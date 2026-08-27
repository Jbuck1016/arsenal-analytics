
create or replace function public.state_weight(p_margin numeric)
returns numeric language sql immutable as $$
  select case when abs(p_margin) <= 1 then 1.00 when abs(p_margin) = 2 then 0.60 else 0.35 end::numeric;
$$;

drop materialized view if exists public.mv_player_state_output cascade;
create materialized view public.mv_player_state_output as
with ev_state as (
  select e.game_id, e.team, e.player_id, e.ws_id, e.type, e.x, e.y, e.end_x, e.end_y, e.outcome_type,
    sg.margin::numeric as margin
  from public.events e
  join public.mv_state_segments sg
    on sg.game_id = e.game_id and sg.team = e.team
   and e.expanded_minute >= sg.seg_start and e.expanded_minute < sg.seg_end
  where e.player_id is not null
),
shots as (
  select s.player_id, s.xg, public.state_weight(es.margin) w
  from public.mv_shot_xg s join ev_state es on es.game_id=s.game_id and es.ws_id=s.ws_id
  where s.is_pen = false
),
xt as (
  select es.player_id,
    (coalesce(public.xt_val(es.end_x,es.end_y),0)-coalesce(public.xt_val(es.x,es.y),0)) xt_delta,
    public.state_weight(es.margin) w
  from ev_state es where es.type='Pass' and es.outcome_type='Successful' and es.end_x is not null
),
wmin as (
  select pm.player_id,
    sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))) raw_min,
    sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))
        * public.state_weight(sg.margin::numeric)) weighted_min
  from public.mv_player_stints pm
  join public.mv_state_segments sg on sg.game_id=pm.game_id and sg.team=pm.team
   and sg.seg_start < pm.end_min and sg.seg_end > pm.start_min
  group by pm.player_id
),
sh_agg as (select player_id, sum(xg) raw_xg, sum(xg*w) live_xg from shots group by player_id),
xt_agg as (select player_id, sum(xt_delta) raw_xt, sum(xt_delta*w) live_xt from xt group by player_id)
select w.player_id, pcr.player, pcr.team, pcr.pos,
  round(w.raw_min/90.0, 2) as nineties_raw,
  round(w.weighted_min/90.0, 2) as nineties_live,
  round(100.0*w.weighted_min/nullif(w.raw_min,0), 1) as live_minute_pct,
  round((coalesce(s.raw_xg,0)/nullif(w.raw_min/90.0,0))::numeric, 3) as xg_90_raw,
  round((coalesce(s.live_xg,0)/nullif(w.weighted_min/90.0,0))::numeric, 3) as xg_90_live,
  round(((coalesce(s.live_xg,0)/nullif(w.weighted_min/90.0,0))
       - (coalesce(s.raw_xg,0)/nullif(w.raw_min/90.0,0)))::numeric, 3) as xg_90_delta,
  round((coalesce(x.raw_xt,0)/nullif(w.raw_min/90.0,0))::numeric, 3) as xt_90_raw,
  round((coalesce(x.live_xt,0)/nullif(w.weighted_min/90.0,0))::numeric, 3) as xt_90_live,
  round(((coalesce(x.live_xt,0)/nullif(w.weighted_min/90.0,0))
       - (coalesce(x.raw_xt,0)/nullif(w.raw_min/90.0,0)))::numeric, 3) as xt_90_delta
from wmin w
join public.player_chain_roles pcr on pcr.player_id = w.player_id
left join sh_agg s on s.player_id = w.player_id
left join xt_agg x on x.player_id = w.player_id
where w.raw_min >= 540;
create unique index mv_player_state_output_pk on public.mv_player_state_output (player_id);
grant select on public.mv_player_state_output to anon, authenticated;

-- Percentile layer keyed off metric_catalog (my registry), NOT metric_defs (yours).
drop materialized view if exists public.mv_player_pct cascade;
create materialized view public.mv_player_pct as
with u as (
  select ps.player_id, ps.player, ps.pool, ps.archetype_primary, m.metric, m.raw
  from public.player_search ps
  cross join lateral (values
    ('xt_90',ps.xt_90),('xt_pass_90',ps.xt_pass_90),('xt_carry_90',ps.xt_carry_90),('player_xt',ps.player_xt),
    ('prog_att_90',ps.prog_att_90),('prog_cmp_90',ps.prog_cmp_90),('prog_completion',ps.prog_completion),
    ('prog_tendency_pct',ps.prog_tendency_pct),('prog_into_final_90',ps.prog_into_final_90),
    ('into_box_90',ps.into_box_90),('final_third_90',ps.final_third_90),('through_90',ps.through_90),
    ('long_90',ps.long_90),('long_pct',ps.long_pct),('pass_cmp_90',ps.pass_cmp_90),('pass_pct',ps.pass_pct),
    ('pct_over',ps.pct_over),('pct_around',ps.pct_around),('pct_through',ps.pct_through),
    ('pct_in_behind',ps.pct_in_behind),('pct_inside',ps.pct_inside),('pct_outside',ps.pct_outside),
    ('comp_through',ps.comp_through),('comp_over',ps.comp_over),
    ('carries_90',ps.carries_90),('prog_carries_90',ps.prog_carries_90),('carry_box_90',ps.carry_box_90),
    ('carry_pen_90',ps.carry_pen_90),('mean_carry_m',ps.mean_carry_m),('takeon_90',ps.takeon_90),
    ('takeon_pct',ps.takeon_pct),('disp_90',ps.disp_90),
    ('xa_90',ps.xa_90),('key_pass_90',ps.key_pass_90),('sca_90',ps.sca_90),('bcc_90',ps.bcc_90),
    ('assist_90',ps.assist_90),('cross_90',ps.cross_90),('cross_pct',ps.cross_pct),
    ('xg_90',ps.xg_90),('goals_90',ps.goals_90),('shots_90',ps.shots_90),('sot_90',ps.sot_90),
    ('xg_per_shot',ps.xg_per_shot),('conversion',ps.conversion),('finishing',ps.finishing),
    ('bigchance_90',ps.bigchance_90),
    ('early_shot_inv_90',ps.early_shot_inv_90),('shot_chain_pct',ps.shot_chain_pct),
    ('early_shot_pct',ps.early_shot_pct),('mean_chain_xt',ps.mean_chain_xt),
    ('def_action_90',ps.def_action_90),('tackle_90',ps.tackle_90),('tackle_pct',ps.tackle_pct),
    ('int_90',ps.int_90),('recov_90',ps.recov_90),('aerial_90',ps.aerial_90),('aerial_pct',ps.aerial_pct),
    ('counterpress_90',ps.counterpress_90),('box_def_90',ps.box_def_90),
    ('channel_def_90',ps.channel_def_90),('flank_def_90',ps.flank_def_90)
  ) m(metric, raw)
  where ps.nineties >= 3
),
ranked as (
  select u.*, d.higher_better,
    percent_rank() over (partition by u.pool, u.metric order by u.raw) pr_pool,
    percent_rank() over (partition by u.archetype_primary, u.metric order by u.raw) pr_arch,
    count(*) over (partition by u.archetype_primary, u.metric) arch_n
  from u join public.metric_catalog d on d.metric = u.metric
  where u.raw is not null
)
select player_id, player, pool, archetype_primary, metric, raw, higher_better,
  round(100*(case when higher_better then pr_pool else 1-pr_pool end))::int as pct_pool,
  case when arch_n >= 15 then round(100*(case when higher_better then pr_arch else 1-pr_arch end))::int end as pct_archetype,
  arch_n as archetype_cohort
from ranked;
create index mv_player_pct_player on public.mv_player_pct (player_id);
create index mv_player_pct_metric on public.mv_player_pct (metric);
grant select on public.mv_player_pct to anon, authenticated;
