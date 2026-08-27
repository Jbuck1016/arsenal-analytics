
-- The inflation flag must be ABSOLUTE, not relative to squad: at a side that wins by three
-- every week the whole squad has low leverage, so nobody stands out against teammates.
-- What matters for recruitment is whether his minutes came in decided games by league standards.
create or replace view public.v_squad_role as
with lg as (
  select percentile_cont(0.25) within group (order by leverage_pct) p25,
         percentile_cont(0.50) within group (order by leverage_pct) p50
  from public.mv_squad_role where leverage_pct is not null
)
select r.player_id, r.player, r.team, r.pos, r.squad_role, r.squad_rank,
  r.selection_pct, r.start_pct, r.leverage_pct, r.leverage_z_in_squad,
  r.minutes_played, r.minutes_available, r.appearances, r.starts, r.games_available,
  r.first_date, r.window_end,
  round(100.0*percent_rank() over (order by r.leverage_pct))::int as leverage_pct_rank,
  (r.selection_pct >= 40 and r.leverage_pct < lg.p25) as minutes_inflated,
  (r.selection_pct >= 40 and r.leverage_pct >= lg.p50 and r.leverage_z_in_squad >= 0.5) as high_leverage_regular
from public.mv_squad_role r cross join lg;
grant select on public.v_squad_role to anon, authenticated;
