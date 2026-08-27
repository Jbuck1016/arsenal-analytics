
drop function if exists public.state_weight(int);
create or replace function public.state_weight(p_margin numeric)
returns numeric language sql immutable as $$
  select case when abs(p_margin) <= 1 then 1.00
              when abs(p_margin) = 2 then 0.60
              else 0.35 end::numeric;
$$;

drop materialized view if exists public.mv_player_state_output cascade;
create materialized view public.mv_player_state_output as
with ev_state as (
  select e.id, e.game_id, e.team, e.player_id, e.expanded_minute, e.ws_id, e.type,
    e.x, e.y, e.end_x, e.end_y, e.outcome_type, sg.margin::numeric as margin
  from public.events e
  join public.mv_state_segments sg
    on sg.game_id = e.game_id and sg.team = e.team
   and e.expanded_minute >= sg.seg_start and e.expanded_minute < sg.seg_end
  where e.player_id is not null
),
shots as (
  select s.player_id, s.xg, public.state_weight(es.margin) w
  from public.mv_shot_xg s
  join ev_state es on es.game_id = s.game_id and es.ws_id = s.ws_id
  where s.is_pen = false
),
xt as (
  select es.player_id,
    (coalesce(public.xt_val(es.end_x,es.end_y),0)-coalesce(public.xt_val(es.x,es.y),0)) xt_delta,
    public.state_weight(es.margin) w
  from ev_state es
  where es.type='Pass' and es.outcome_type='Successful' and es.end_x is not null
),
wmin as (
  select pm.player_id,
    sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))) raw_min,
    sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))
        * public.state_weight(sg.margin::numeric)) weighted_min
  from public.mv_player_minutes pm
  join public.mv_state_segments sg
    on sg.game_id = pm.game_id and sg.team = pm.team
   and sg.seg_start < pm.end_min and sg.seg_end > pm.start_min
  group by pm.player_id
),
sh_agg as (select player_id, sum(xg) raw_xg, sum(xg*w) live_xg from shots group by player_id),
xt_agg as (select player_id, sum(xt_delta) raw_xt, sum(xt_delta*w) live_xt from xt group by player_id)
select w.player_id, pcr.player, pcr.team, pcr.pos,
  round(w.raw_min/90.0, 2) as nineties_raw,
  round(w.weighted_min/90.0, 2) as nineties_live,
  round(100.0*w.weighted_min/nullif(w.raw_min,0), 1) as live_minute_pct,
  round((coalesce(s.raw_xg,0)  / nullif(w.raw_min/90.0,0))::numeric, 3) as xg_90_raw,
  round((coalesce(s.live_xg,0) / nullif(w.weighted_min/90.0,0))::numeric, 3) as xg_90_live,
  round(((coalesce(s.live_xg,0)/nullif(w.weighted_min/90.0,0))
       - (coalesce(s.raw_xg,0)/nullif(w.raw_min/90.0,0)))::numeric, 3) as xg_90_delta,
  round((coalesce(x.raw_xt,0)  / nullif(w.raw_min/90.0,0))::numeric, 3) as xt_90_raw,
  round((coalesce(x.live_xt,0) / nullif(w.weighted_min/90.0,0))::numeric, 3) as xt_90_live,
  round(((coalesce(x.live_xt,0)/nullif(w.weighted_min/90.0,0))
       - (coalesce(x.raw_xt,0)/nullif(w.raw_min/90.0,0)))::numeric, 3) as xt_90_delta
from wmin w
join public.player_chain_roles pcr on pcr.player_id = w.player_id
left join sh_agg s on s.player_id = w.player_id
left join xt_agg x on x.player_id = w.player_id
where w.raw_min >= 540;
create unique index mv_player_state_output_pk on public.mv_player_state_output (player_id);
grant select on public.mv_player_state_output to anon, authenticated;
