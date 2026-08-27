
-- Minutes derived from substitution events, NOT lineups.is_starter, which is unreliable
-- (the scraper defaults isFirstEleven to true when WhoScored omits it, giving 8.4 flagged
-- starters per team-game and over 11 in 96 team-games).
-- A starter is anyone who appeared with no SubstitutionOn event.
drop materialized view if exists public.mv_player_minutes cascade;
create materialized view public.mv_player_minutes as
with mlen as (
  select game_id, max(expanded_minute) + 1 as end_min from public.events group by game_id
),
appear as (
  select distinct l.game_id, l.player_id, l.team from public.lineups l where l.player_id is not null
),
subs as (
  select game_id, player_id,
    min(expanded_minute) filter (where type='SubstitutionOn')  as on_min,
    min(expanded_minute) filter (where type='SubstitutionOff') as off_min
  from public.events
  where type in ('SubstitutionOn','SubstitutionOff') and player_id is not null
  group by game_id, player_id
),
touched as (
  select distinct game_id, player_id from public.events where player_id is not null
)
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
create index mv_player_minutes_pg on public.mv_player_minutes (player_id, game_id);
grant select on public.mv_player_minutes to anon, authenticated;

-- Score-margin segments per team per match, so any on-pitch interval can be split
-- into "close" (within one goal) and "decided" time.
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
    coalesce(lead(r.t) over (partition by r.game_id, r.team order by r.t), m.end_min) as seg_end,
    r.margin
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

-- Leverage: what share of a player's minutes were played with the game still in the balance.
drop materialized view if exists public.mv_player_leverage cascade;
create materialized view public.mv_player_leverage as
select pm.player_id, pm.team,
  sum(pm.minutes) as minutes_total,
  sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))
      ) filter (where abs(sg.margin) <= 1) as minutes_close,
  round(100.0 * sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))
        ) filter (where abs(sg.margin) <= 1)
      / nullif(sum(greatest(0, least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))), 0), 1
  ) as leverage_pct
from public.mv_player_minutes pm
join public.mv_state_segments sg
  on sg.game_id = pm.game_id and sg.team = pm.team
 and sg.seg_start < pm.end_min and sg.seg_end > pm.start_min
group by pm.player_id, pm.team;
create index mv_player_leverage_p on public.mv_player_leverage (player_id);
grant select on public.mv_player_leverage to anon, authenticated;
