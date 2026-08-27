drop materialized view if exists mv_player_carry cascade;
drop materialized view if exists mv_carry_events cascade;

-- Every ball receipt (no distance filter), flagged as a carry when the player
-- moved 3m+ before releasing. Tempo metrics need ALL receipts, including
-- one-touch releases; carrying metrics use the is_carry subset.
create materialized view mv_receipt_events as
with seq as (
  select
    game_id, ws_id, team, player_id, player, type, x, y, end_x, end_y,
    (minute*60 + second) as abs_sec,
    lag(team)               over w as prev_team,
    lag(coalesce(end_x, x)) over w as rx,
    lag(coalesce(end_y, y)) over w as ry,
    lag(minute*60 + second) over w as prev_sec
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
    sqrt(power((x - rx)*1.05,2) + power((y - ry)*0.68,2)) as carry_m,
    sqrt(power((100-rx)*1.05,2) + power((50-ry)*0.68,2))  as d0,
    sqrt(power((100-x )*1.05,2) + power((50-y )*0.68,2))  as d1
  from seq
  where prev_team = team
    and player_id is not null
    and x is not null and y is not null and rx is not null and ry is not null
    and (abs_sec - prev_sec) between 0 and 20
)
select
  game_id, ws_id, team, player_id, player, release_type,
  round(rx::numeric,1) as start_x, round(ry::numeric,1) as start_y,
  round(ax::numeric,1) as end_x,   round(ay::numeric,1) as end_y,
  ttr,
  round(carry_m::numeric,2)                        as carry_m,
  (carry_m >= 3)                                   as is_carry,
  (carry_m >= 3 and d1 < 0.85*d0)                  as is_progressive,
  (carry_m >= 3 and ax >= 83 and ay between 21 and 79
     and not (rx >= 83 and ry between 21 and 79))  as into_box,
  round((d0-d1)::numeric,2)                        as goal_dist_gained
from c;

create index on mv_receipt_events (player_id);
create index on mv_receipt_events (game_id);

create materialized view mv_player_carry as
select
  player_id,
  count(*) filter (where is_carry)                                    as carries,
  count(*) filter (where is_progressive)                              as prog_carries,
  count(*) filter (where into_box)                                    as carries_into_box,
  round(avg(carry_m) filter (where is_carry),2)                       as mean_carry_m,
  round(sum(greatest(goal_dist_gained,0)) filter (where is_progressive),0) as carry_penetration,
  -- tempo over ALL receipts
  count(*)                                                            as receipts,
  percentile_cont(0.5) within group (order by ttr)                    as median_ttr,
  count(*) filter (where release_type='Pass' and ttr < 2)             as quick_release,
  count(*) filter (where release_type='Pass' and ttr < 1)             as one_touch,
  count(*) filter (where release_type='Pass')                         as pass_releases
from mv_receipt_events
group by player_id;
create unique index on mv_player_carry (player_id);

grant select on mv_receipt_events, mv_player_carry to anon, authenticated;
