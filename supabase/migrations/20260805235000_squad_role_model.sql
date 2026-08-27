
-- Squad role = availability-adjusted selection x leverage.
-- Selection is measured only across games available between a player's first and last
-- appearance FOR THAT CLUB, so mid-season signings and long injuries are not punished.
-- This is a USAGE measure, not a quality measure.
drop materialized view if exists public.mv_squad_role cascade;
create materialized view public.mv_squad_role as
with tg as (
  select distinct e.game_id, e.team, m.date
  from public.events e join public.matches m on m.game_id = e.game_id
  where e.team is not null and m.date is not null
),
mlen as (select game_id, max(expanded_minute)+1 as end_min from public.events group by game_id),
window_pt as (
  select pm.player_id, pm.team, min(t.date) first_date, max(t.date) last_date,
    sum(pm.minutes) minutes_played, count(*) appearances,
    count(*) filter (where pm.is_starter) starts
  from public.mv_player_minutes pm
  join tg t on t.game_id = pm.game_id and t.team = pm.team
  group by pm.player_id, pm.team
),
avail as (
  select w.player_id, w.team, w.first_date, w.last_date, w.minutes_played, w.appearances, w.starts,
    (select count(*) from tg t2 where t2.team = w.team and t2.date between w.first_date and w.last_date) games_available,
    (select coalesce(sum(ml.end_min),0) from tg t2 join mlen ml on ml.game_id = t2.game_id
      where t2.team = w.team and t2.date between w.first_date and w.last_date) minutes_available
  from window_pt w
),
scored as (
  select a.*, lv.leverage_pct,
    round(100.0*a.minutes_played/nullif(a.minutes_available,0), 1) as selection_pct,
    round(100.0*a.starts/nullif(a.games_available,0), 1) as start_pct
  from avail a
  left join public.mv_player_leverage lv on lv.player_id = a.player_id and lv.team = a.team
),
ranked as (
  select s.*,
    rank() over (partition by s.team order by s.selection_pct desc nulls last) squad_rank,
    round(((s.leverage_pct - avg(s.leverage_pct) over (partition by s.team))
      / nullif(stddev_samp(s.leverage_pct) over (partition by s.team),0))::numeric, 2) leverage_z_in_squad
  from scored s
)
select r.*, pcr.player, pcr.pos,
  case
    when r.selection_pct >= 70 then 'Key player'
    when r.selection_pct >= 50 then 'Starter'
    when r.selection_pct >= 25 then 'Rotation'
    else 'Fringe' end as squad_role,
  -- strong usage but his minutes came disproportionately in decided games
  (r.selection_pct >= 40 and r.leverage_z_in_squad <= -1.0) as minutes_inflated
from ranked r
join public.player_chain_roles pcr on pcr.player_id = r.player_id
where r.games_available >= 3;
create index mv_squad_role_player on public.mv_squad_role (player_id);
create index mv_squad_role_team on public.mv_squad_role (team);
grant select on public.mv_squad_role to anon, authenticated;
