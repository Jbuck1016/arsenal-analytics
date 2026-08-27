
create or replace view v_season_stats as
with ev as (
  select
    e.game_id, e.team,
    (e.type='Pass' and e.end_x is not null and e.end_x >= 66) as ft,
    (e.type='Pass' and e.end_x is not null and e.end_x between 66 and 83 and e.end_y between 21 and 79) as z14,
    (e.type='Pass' and e.end_x is not null and e.end_x >= 83 and e.end_y between 21 and 79) as box,
    (e.type='Pass' and e.x is not null and e.end_x is not null and (
        (e.x<50 and e.end_x<50  and (e.end_x-e.x)>=30) or
        (e.x<50 and e.end_x>=50 and (e.end_x-e.x)>=15) or
        (e.x>=50 and e.end_x>=50 and (e.end_x-e.x)>=10)
    )) as prog,
    (e.type='Pass' and e.end_x is not null and e.end_x > e.x+3)        as fwd,
    (e.type='Pass' and e.end_x is not null and abs(e.end_x-e.x) <= 3)  as lat,
    (e.type='Pass' and e.end_x is not null and e.end_x < e.x-3)        as bwd,
    (e.type in ('Tackle','Interception','Clearance','BallRecovery','BlockedPass','Aerial','Challenge')) as defa,
    (e.type in ('Tackle','Interception','Clearance','BallRecovery','BlockedPass','Aerial','Challenge') and e.outcome_type='Successful') as defw,
    e.is_shot as shot,
    (e.is_shot and (e.outcome_type='Saved' or e.is_goal)) as sot
  from events e
),
agg as (
  select game_id, team,
    count(*) filter (where ft)   as final_third_passes,
    count(*) filter (where z14)  as zone14_passes,
    count(*) filter (where prog) as progressive_passes,
    count(*) filter (where box)  as passes_into_box,
    count(*) filter (where defa) as defensive_actions,
    count(*) filter (where defw) as defensive_actions_won,
    count(*) filter (where shot) as shots,
    count(*) filter (where sot)  as shots_on_target,
    count(*) filter (where fwd)  as fwd_passes,
    count(*) filter (where lat)  as lat_passes,
    count(*) filter (where bwd)  as bwd_passes
  from ev group by game_id, team
)
select
  a.game_id, a.team,
  case when a.team = m.home_team then m.away_team  else m.home_team  end as opponent,
  case when a.team = m.home_team then 'H' else 'A' end                  as ha,
  case when a.team = m.home_team then m.home_score else m.away_score end as team_score,
  case when a.team = m.home_team then m.away_score else m.home_score end as opp_score,
  a.final_third_passes, a.zone14_passes, a.progressive_passes, a.passes_into_box,
  a.defensive_actions, a.defensive_actions_won, a.shots, a.shots_on_target,
  a.fwd_passes, a.lat_passes, a.bwd_passes
from agg a
join matches m on m.game_id = a.game_id;

grant select on v_season_stats to anon, authenticated;

create or replace function get_starter_names(p_game_id text)
returns table(player_name text, player_pos text)
language sql stable security definer set search_path = public
as $$
  select p.player_name, l.position
  from lineups l
  join players p on p.player_id = l.player_id
  where l.game_id = p_game_id and l.is_starter = true;
$$;

grant execute on function get_starter_names(text) to anon, authenticated;
