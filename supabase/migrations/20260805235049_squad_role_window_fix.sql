
-- Window runs from a player's first appearance for the club to the club's most recent
-- game, NOT to his last appearance. Otherwise someone who played three games in April and
-- was then dropped scores as an ever-present. The exception is a genuine departure, which
-- we detect when the same player_id later appears for a different club.
drop materialized view if exists public.mv_squad_role cascade;
create materialized view public.mv_squad_role as
with tg as (
  select distinct e.game_id, e.team, m.date
  from public.events e join public.matches m on m.game_id = e.game_id
  where e.team is not null and m.date is not null
),
mlen as (select game_id, max(expanded_minute)+1 as end_min from public.events group by game_id),
pt as (
  select pm.player_id, pm.team, min(t.date) first_date, max(t.date) last_date,
    sum(pm.minutes) minutes_played, count(*) appearances,
    count(*) filter (where pm.is_starter) starts
  from public.mv_player_minutes pm
  join tg t on t.game_id = pm.game_id and t.team = pm.team
  group by pm.player_id, pm.team
),
moved as (  -- did he turn out for a different club after leaving this one?
  select a.player_id, a.team, max(b.last_date) later_elsewhere
  from pt a join pt b on b.player_id = a.player_id and b.team <> a.team and b.last_date > a.last_date
  group by a.player_id, a.team
),
bounds as (
  select p.*,
    case when mv.later_elsewhere is not null then p.last_date
         else (select max(t2.date) from tg t2 where t2.team = p.team) end as window_end
  from pt p left join moved mv on mv.player_id = p.player_id and mv.team = p.team
),
avail as (
  select b.*,
    (select count(*) from tg t2 where t2.team = b.team and t2.date between b.first_date and b.window_end) games_available,
    (select coalesce(sum(ml.end_min),0) from tg t2 join mlen ml on ml.game_id = t2.game_id
      where t2.team = b.team and t2.date between b.first_date and b.window_end) minutes_available
  from bounds b
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
    when r.selection_pct >= 45 then 'Starter'
    when r.selection_pct >= 20 then 'Rotation'
    else 'Fringe' end as squad_role,
  (r.selection_pct >= 40 and r.leverage_z_in_squad <= -1.0) as minutes_inflated
from ranked r
join public.player_chain_roles pcr on pcr.player_id = r.player_id
where r.games_available >= 6;
create index mv_squad_role_player on public.mv_squad_role (player_id);
create index mv_squad_role_team on public.mv_squad_role (team);
grant select on public.mv_squad_role to anon, authenticated;
