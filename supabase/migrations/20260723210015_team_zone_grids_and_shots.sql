-- Season action grids per team, 12 x 8 zones (same geometry as the xT grid).
-- Aggregated server-side: 7,500 raw events per team would render as noise.
create materialized view mv_team_zones as
with e as (
  select
    team,
    least(11,greatest(0,floor(x/100*12)::int)) as zx,
    least(7, greatest(0,floor(y/100*8)::int))  as zy,
    type, is_shot, is_open_play,
    (outcome_type='Successful') as ok,
    (type='Pass' and x is not null and end_x is not null and (
      (x<50 and end_x<50  and (end_x-x)>=30) or
      (x<50 and end_x>=50 and (end_x-x)>=15) or
      (x>=50 and end_x>=50 and (end_x-x)>=10))) as prog
  from public.events
  where team is not null and x is not null and y is not null
    and type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded','OffsideProvoked')
),
m as (select team, count(*) as matches from mv_team_match group by team)
select
  e.team, e.zx, e.zy,
  count(*)                                                     as touches,
  count(*) filter (where e.type='Pass' and e.ok)               as passes,
  count(*) filter (where e.prog and e.ok)                      as prog_passes,
  count(*) filter (where e.is_shot)                            as shots,
  count(*) filter (where e.type in ('Tackle','Interception','BallRecovery','BlockedPass','Clearance','Challenge')) as def_actions,
  round(count(*)::numeric / nullif(m.matches,0), 2)            as touches_pg
from e join m on m.team = e.team
group by e.team, e.zx, e.zy, m.matches;
create index on mv_team_zones (team);

-- Carry origins/destinations aggregated per zone
create materialized view mv_team_carry_zones as
with c as (
  select r.team,
    least(11,greatest(0,floor(r.start_x/100*12)::int)) as zx,
    least(7, greatest(0,floor(r.start_y/100*8)::int))  as zy,
    r.is_progressive, r.into_box, r.carry_m
  from mv_receipt_events r where r.is_carry
),
m as (select team, count(*) as matches from mv_team_match group by team)
select c.team, c.zx, c.zy,
  count(*) as carries,
  count(*) filter (where c.is_progressive) as prog_carries,
  count(*) filter (where c.into_box)       as carries_into_box,
  round(avg(c.carry_m)::numeric,1)         as mean_m,
  round(count(*)::numeric/nullif(m.matches,0),2) as carries_pg
from c join m on m.team=c.team
group by c.team, c.zx, c.zy, m.matches;
create index on mv_team_carry_zones (team);

-- Team shots, for and against, with xG
create or replace view v_team_shots as
select x.team, x.game_id, x.is_goal, x.is_open_play, x.is_pen, x.xg,
       x.is_header, x.is_bigchance, f.x, f.y
from mv_shot_xg x
join mv_shot_features f on f.game_id=x.game_id and f.ws_id=x.ws_id;

grant select on mv_team_zones, mv_team_carry_zones, v_team_shots to anon, authenticated;
notify pgrst, 'reload schema';
