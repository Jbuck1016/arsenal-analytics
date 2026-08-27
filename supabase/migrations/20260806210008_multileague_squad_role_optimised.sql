
drop materialized view if exists public.mv_squad_role cascade;
create materialized view public.mv_squad_role as
with mlen as (select game_id, max(expanded_minute)+1 as end_min from public.events group by game_id),
tg as (
  select distinct e.game_id, e.team, e.league, m.date, ml.end_min
  from public.events e
  join public.matches m on m.game_id = e.game_id
  join mlen ml on ml.game_id = e.game_id
  where e.team is not null and m.date is not null
),
team_last as (select team, max(date) as last_team_date from tg group by team),
pt as (
  select pm.player_id, pm.team, min(t.league) league, min(t.date) first_date, max(t.date) last_date,
    sum(pm.minutes) minutes_played, count(*) appearances, count(*) filter (where pm.is_starter) starts
  from public.mv_player_stints pm join tg t on t.game_id = pm.game_id and t.team = pm.team
  group by pm.player_id, pm.team
),
moved as (
  select a.player_id, a.team, max(b.last_date) later_elsewhere
  from pt a join pt b on b.player_id = a.player_id and b.team <> a.team and b.last_date > a.last_date
  group by a.player_id, a.team
),
bounds as (
  select p.*, case when mv.later_elsewhere is not null then p.last_date else tl.last_team_date end as window_end
  from pt p
  left join moved mv on mv.player_id = p.player_id and mv.team = p.team
  join team_last tl on tl.team = p.team
),
avail as (
  select b.player_id, b.team, b.league, b.first_date, b.last_date, b.window_end,
    b.minutes_played, b.appearances, b.starts,
    count(t.game_id) as games_available,
    coalesce(sum(t.end_min),0) as minutes_available
  from bounds b
  left join tg t on t.team = b.team and t.date between b.first_date and b.window_end
  group by b.player_id, b.team, b.league, b.first_date, b.last_date, b.window_end,
           b.minutes_played, b.appearances, b.starts
),
scored as (
  select a.*, lv.leverage_pct,
    round(100.0*a.minutes_played/nullif(a.minutes_available,0), 1) as selection_pct,
    round(100.0*a.starts/nullif(a.games_available,0), 1) as start_pct
  from avail a left join public.mv_player_leverage lv on lv.player_id=a.player_id and lv.team=a.team
),
ranked as (
  select s.*, rank() over (partition by s.team order by s.selection_pct desc nulls last) squad_rank,
    round(((s.leverage_pct - avg(s.leverage_pct) over (partition by s.team))
      / nullif(stddev_samp(s.leverage_pct) over (partition by s.team),0))::numeric, 2) leverage_z_in_squad
  from scored s
)
select r.*, pcr.player, pcr.pos,
  case when r.selection_pct >= 70 then 'Key player'
       when r.selection_pct >= 45 then 'Starter'
       when r.selection_pct >= 20 then 'Rotation'
       else 'Fringe' end as squad_role
from ranked r
join public.player_chain_roles pcr on pcr.player_id = r.player_id
where r.games_available >= 6;
create index mv_squad_role_player on public.mv_squad_role (player_id);
grant select on public.mv_squad_role to anon, authenticated;

create or replace view public.v_squad_role as
with lg as (
  select league,
    percentile_cont(0.25) within group (order by leverage_pct) p25,
    percentile_cont(0.50) within group (order by leverage_pct) p50
  from public.mv_squad_role where leverage_pct is not null group by league
)
select r.player_id, r.player, r.team, r.pos, r.squad_role, r.squad_rank,
  r.selection_pct, r.start_pct, r.leverage_pct, r.leverage_z_in_squad,
  r.minutes_played, r.minutes_available, r.appearances, r.starts, r.games_available,
  round(100.0*percent_rank() over (partition by r.league order by r.leverage_pct))::int as leverage_pct_rank,
  (r.selection_pct >= 40 and r.leverage_pct < lg.p25) as minutes_inflated,
  r.league
from public.mv_squad_role r join lg on lg.league = r.league;
grant select on public.v_squad_role to anon, authenticated;
