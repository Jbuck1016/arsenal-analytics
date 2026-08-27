
-- NOTE: named mv_player_stints, NOT mv_player_minutes, which is an existing object the
-- whole metric stack depends on. This holds per-game on-pitch intervals with starter
-- status DERIVED from substitution events (lineups.is_starter is unreliable: the scraper
-- defaults isFirstEleven to true when absent, giving 8.4 starters per team-game).
drop materialized view if exists public.mv_player_stints cascade;
create materialized view public.mv_player_stints as
with mlen as (select game_id, max(expanded_minute) + 1 as end_min from public.events group by game_id),
appear as (select distinct l.game_id, l.player_id, l.team from public.lineups l where l.player_id is not null),
subs as (
  select game_id, player_id,
    min(expanded_minute) filter (where type='SubstitutionOn')  as on_min,
    min(expanded_minute) filter (where type='SubstitutionOff') as off_min
  from public.events where type in ('SubstitutionOn','SubstitutionOff') and player_id is not null
  group by game_id, player_id
),
touched as (select distinct game_id, player_id from public.events where player_id is not null)
select a.game_id, a.player_id, a.team,
  (s.on_min is null) as is_starter,
  coalesce(s.on_min, 0) as start_min,
  coalesce(s.off_min, m.end_min) as end_min,
  greatest(0, coalesce(s.off_min, m.end_min) - coalesce(s.on_min, 0)) as minutes,
  m.end_min as match_len
from appear a
join mlen m on m.game_id = a.game_id
left join subs s on s.game_id = a.game_id and s.player_id = a.player_id
where exists (select 1 from touched t where t.game_id=a.game_id and t.player_id=a.player_id);
create index mv_player_stints_pg on public.mv_player_stints (player_id, game_id);
grant select on public.mv_player_stints to anon, authenticated;

drop materialized view if exists public.mv_state_segments cascade;
create materialized view public.mv_state_segments as
with mlen as (select game_id, max(expanded_minute)+1 as end_min from public.events group by game_id),
tg as (select distinct game_id, team from public.events where team is not null),
ev as (
  select tg.game_id, tg.team, g.expanded_minute as t,
    case when g.scoring_team = tg.team then 1 else -1 end as d
  from tg join public.mv_game_goals g on g.game_id = tg.game_id
),
run as (
  select game_id, team, t,
    sum(d) over (partition by game_id, team order by t rows between unbounded preceding and current row) as margin
  from ev
),
after_goals as (
  select r.game_id, r.team, r.t as seg_start,
    coalesce(lead(r.t) over (partition by r.game_id, r.team order by r.t), m.end_min) as seg_end, r.margin
  from run r join mlen m on m.game_id = r.game_id
),
before_first as (
  select tg.game_id, tg.team, 0 as seg_start,
    coalesce((select min(t) from ev e where e.game_id=tg.game_id and e.team=tg.team), m.end_min) as seg_end,
    0 as margin
  from tg join mlen m on m.game_id = tg.game_id
)
select * from after_goals union all select * from before_first;
create index mv_state_segments_gt on public.mv_state_segments (game_id, team);
grant select on public.mv_state_segments to anon, authenticated;

drop materialized view if exists public.mv_player_leverage cascade;
create materialized view public.mv_player_leverage as
select pm.player_id, pm.team,
  sum(pm.minutes) as minutes_total,
  round(100.0 * sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))
        ) filter (where abs(sg.margin) <= 1)
      / nullif(sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))), 0), 1
  ) as leverage_pct
from public.mv_player_stints pm
join public.mv_state_segments sg
  on sg.game_id = pm.game_id and sg.team = pm.team
 and sg.seg_start < pm.end_min and sg.seg_end > pm.start_min
group by pm.player_id, pm.team;
create index mv_player_leverage_p on public.mv_player_leverage (player_id);
grant select on public.mv_player_leverage to anon, authenticated;

drop materialized view if exists public.mv_squad_role cascade;
create materialized view public.mv_squad_role as
with tg as (
  select distinct e.game_id, e.team, m.date from public.events e
  join public.matches m on m.game_id = e.game_id where e.team is not null and m.date is not null
),
mlen as (select game_id, max(expanded_minute)+1 as end_min from public.events group by game_id),
pt as (
  select pm.player_id, pm.team, min(t.date) first_date, max(t.date) last_date,
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
  select p.*, case when mv.later_elsewhere is not null then p.last_date
                   else (select max(t2.date) from tg t2 where t2.team = p.team) end as window_end
  from pt p left join moved mv on mv.player_id = p.player_id and mv.team = p.team
),
avail as (
  select b.*,
    (select count(*) from tg t2 where t2.team=b.team and t2.date between b.first_date and b.window_end) games_available,
    (select coalesce(sum(ml.end_min),0) from tg t2 join mlen ml on ml.game_id=t2.game_id
      where t2.team=b.team and t2.date between b.first_date and b.window_end) minutes_available
  from bounds b
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
  select percentile_cont(0.25) within group (order by leverage_pct) p25,
         percentile_cont(0.50) within group (order by leverage_pct) p50
  from public.mv_squad_role where leverage_pct is not null
)
select r.player_id, r.player, r.team, r.pos, r.squad_role, r.squad_rank,
  r.selection_pct, r.start_pct, r.leverage_pct, r.leverage_z_in_squad,
  r.minutes_played, r.minutes_available, r.appearances, r.starts, r.games_available,
  round(100.0*percent_rank() over (order by r.leverage_pct))::int as leverage_pct_rank,
  (r.selection_pct >= 40 and r.leverage_pct < lg.p25) as minutes_inflated
from public.mv_squad_role r cross join lg;
grant select on public.v_squad_role to anon, authenticated;
