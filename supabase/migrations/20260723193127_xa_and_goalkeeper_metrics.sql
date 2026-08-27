-- xA: the xG of the shot a pass created, credited to the passer.
create materialized view mv_player_xa as
with seq as (
  select game_id, ws_id, team, player_id, type, is_shot,
         lag(player_id) over w as prev_player,
         lag(team)      over w as prev_team,
         lag(type)      over w as prev_type,
         lag(qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb) over w as prev_keypass,
         lag(qualifiers @> '[{"type":{"displayName":"ShotAssist"}}]'::jsonb) over w as prev_shotassist
  from public.events
  where type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded',
                     'OffsideGiven','OffsideProvoked')
  window w as (partition by game_id order by ws_id)
)
select s.prev_player as player_id,
       count(*)                    as chances_created,
       round(sum(x.xg)::numeric,3) as xa
from seq s
join mv_shot_xg x on x.game_id = s.game_id and x.ws_id = s.ws_id
where s.is_shot and s.prev_team = s.team and s.prev_type='Pass'
  and (s.prev_keypass or s.prev_shotassist)
  and s.prev_player is not null
group by s.prev_player;
create unique index on mv_player_xa (player_id);

-- Goalkeeper metrics. The starting keeper for each team-match is credited with
-- that match's shots faced; xG faced uses shots on target only.
create materialized view mv_gk_match as
with gk as (
  select distinct on (m.game_id, m.team) m.game_id, m.team, m.player_id, m.minutes
  from mv_player_minutes m
  join mv_player_pool p on p.player_id = m.player_id
  where p.modal_position = 'GK'
  order by m.game_id, m.team, m.minutes desc
),
faced as (
  select g.game_id, g.team, g.player_id, g.minutes,
    count(*) filter (where x.is_goal or x.game_id is not null) as shots_faced,
    count(*) filter (where x.is_goal) as goals_conceded,
    round(sum(x.xg) filter (where x.is_goal
              or exists (select 1 from public.events e2
                         where e2.game_id=x.game_id and e2.ws_id=x.ws_id and e2.type='SavedShot'))::numeric,3)
      as xg_on_target_faced
  from gk g
  left join mv_shot_xg x on x.game_id = g.game_id and x.team <> g.team
  group by g.game_id, g.team, g.player_id, g.minutes
)
select * from faced;
create index on mv_gk_match (player_id);

create materialized view mv_player_gk as
with acts as (
  select player_id,
    count(*) filter (where type='Save')          as saves,
    count(*) filter (where type='Claim')         as claims,
    count(*) filter (where type='KeeperSweeper') as sweeps,
    count(*) filter (where type='Punch')         as punches,
    count(*) filter (where type='KeeperPickup')  as pickups,
    round(avg(x) filter (where type='KeeperSweeper')::numeric,1) as sweep_x
  from public.events
  where type in ('Save','Claim','KeeperSweeper','Punch','KeeperPickup')
  group by player_id
),
m as (
  select player_id,
    sum(goals_conceded)     as goals_conceded,
    sum(xg_on_target_faced) as xg_faced
  from mv_gk_match group by player_id
)
select
  coalesce(a.player_id, m.player_id) as player_id,
  a.saves, a.claims, a.sweeps, a.punches, a.pickups, a.sweep_x,
  m.goals_conceded, m.xg_faced,
  case when (coalesce(a.saves,0) + coalesce(m.goals_conceded,0)) >= 15
       then round(100.0*a.saves/(a.saves + m.goals_conceded),1) end as save_pct,
  round((coalesce(m.xg_faced,0) - coalesce(m.goals_conceded,0))::numeric,2) as goals_prevented
from acts a
full outer join m on m.player_id = a.player_id;
create unique index on mv_player_gk (player_id);

grant select on mv_player_xa, mv_gk_match, mv_player_gk to anon, authenticated;
