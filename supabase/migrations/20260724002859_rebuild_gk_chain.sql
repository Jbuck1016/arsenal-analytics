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
    count(*) filter (where x.game_id is not null) as shots_faced,
    count(*) filter (where x.is_goal) as goals_conceded,
    -- only shots that actually reached the keeper count toward goals prevented
    round(sum(x.xg) filter (where x.outcome in ('saved','goal'))::numeric,3) as xg_on_target_faced
  from gk g
  left join mv_shot_xg x on x.game_id = g.game_id and x.team <> g.team
  group by g.game_id, g.team, g.player_id, g.minutes
)
select * from faced;
create index on mv_gk_match (player_id);

create materialized view mv_player_gk as
with keepers as (select player_id from mv_player_pool where modal_position='GK'),
acts as (
  select e.player_id,
    count(*) filter (where e.type='Save')          as saves,
    count(*) filter (where e.type='Claim')         as claims,
    count(*) filter (where e.type='KeeperSweeper') as sweeps,
    count(*) filter (where e.type='Punch')         as punches,
    round(avg(e.x) filter (where e.type='KeeperSweeper')::numeric,1) as sweep_x
  from public.events e
  join keepers k on k.player_id = e.player_id
  where e.type in ('Save','Claim','KeeperSweeper','Punch','KeeperPickup')
  group by e.player_id
),
m as (
  select g.player_id, sum(g.goals_conceded) as goals_conceded, sum(g.xg_on_target_faced) as xg_faced
  from mv_gk_match g join keepers k on k.player_id = g.player_id
  group by g.player_id
)
select coalesce(a.player_id,m.player_id) as player_id,
  a.saves, a.claims, a.sweeps, a.punches, a.sweep_x,
  m.goals_conceded, m.xg_faced,
  case when (coalesce(a.saves,0)+coalesce(m.goals_conceded,0)) >= 15
       then round(100.0*a.saves/(a.saves+m.goals_conceded),1) end as save_pct,
  round((coalesce(m.xg_faced,0)-coalesce(m.goals_conceded,0))::numeric,2) as goals_prevented
from acts a full outer join m on m.player_id=a.player_id;
create unique index on mv_player_gk (player_id);

grant select on mv_gk_match, mv_player_gk to anon, authenticated;
