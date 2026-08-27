-- Carries are not recorded by WhoScored; they are inferred from the gap between
-- where the ball arrived and where the player's next action began.
-- lag() runs over the FULL game sequence so an intervening opponent event breaks
-- the chain (coordinates are attack-relative per team, so cross-team chaining
-- would be meaningless anyway).
create materialized view mv_carry_events as
with seq as (
  select
    game_id, ws_id, team, player_id, player, type, x, y, end_x, end_y,
    (minute*60 + second) as abs_sec,
    lag(team)                      over w as prev_team,
    lag(coalesce(end_x, x))        over w as rx,
    lag(coalesce(end_y, y))        over w as ry,
    lag(minute*60 + second)        over w as prev_sec,
    lag(type)                      over w as prev_type
  from public.events
  where type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded',
                     'OffsideGiven','OffsideProvoked')
  window w as (partition by game_id order by ws_id)
),
c as (
  select
    game_id, ws_id, team, player_id, player, type as release_type,
    rx, ry, x as ax, y as ay,
    (abs_sec - prev_sec) as ttr,
    sqrt(power((x - rx)*1.05, 2) + power((y - ry)*0.68, 2)) as carry_m,
    sqrt(power((100 - rx)*1.05, 2) + power((50 - ry)*0.68, 2)) as d0,
    sqrt(power((100 - x )*1.05, 2) + power((50 - y )*0.68, 2)) as d1
  from seq
  where prev_team = team
    and player_id is not null
    and x is not null and y is not null and rx is not null and ry is not null
    and (abs_sec - prev_sec) between 0 and 20      -- Playerprint caps carries at 20s
)
select
  game_id, ws_id, team, player_id, player, release_type,
  round(rx::numeric,1) as start_x, round(ry::numeric,1) as start_y,
  round(ax::numeric,1) as end_x,   round(ay::numeric,1) as end_y,
  ttr,
  round(carry_m::numeric,2) as carry_m,
  (d1 < 0.85 * d0)                                   as is_progressive,
  (ax >= 83 and ay between 21 and 79
     and not (rx >= 83 and ry between 21 and 79))    as into_box,
  round((d0 - d1)::numeric,2)                        as goal_dist_gained
from c
where carry_m >= 3;                                   -- below 3m is a touch, not a carry

create index on mv_carry_events (player_id);
create index on mv_carry_events (game_id);

-- Player-level carrying + tempo profile
create materialized view mv_player_carry as
select
  c.player_id,
  count(*)                                                  as carries,
  count(*) filter (where c.is_progressive)                  as prog_carries,
  count(*) filter (where c.into_box)                        as carries_into_box,
  round(avg(c.carry_m),2)                                   as mean_carry_m,
  round(sum(greatest(c.goal_dist_gained,0)),0)              as carry_penetration,
  round(avg(c.ttr)::numeric,2)                              as mean_ttr,
  percentile_cont(0.5) within group (order by c.ttr)        as median_ttr,
  count(*) filter (where c.release_type='Pass' and c.ttr < 2) as quick_releases,
  count(*) filter (where c.release_type='Pass')             as releases_pass
from mv_carry_events c
group by c.player_id;
create unique index on mv_player_carry (player_id);

grant select on mv_carry_events, mv_player_carry to anon, authenticated;
