-- Five-lane pitch model (y, 0-100):
--   flank      0-21.1   /  78.9-100   (outside the box width)
--   half-space 21.1-36.8 / 63.2-78.9  (box edge to 6-yard-box line, extended)
--   centre     36.8-63.2
create materialized view mv_player_zones as
with e as (
  select player_id, type, x, y, end_x, end_y, is_shot, is_open_play,
         (outcome_type='Successful') as ok,
         (y between 21.1 and 36.8 or y between 63.2 and 78.9) as hs,
         (y < 21.1 or y > 78.9)                               as flank,
         (type='Pass' and x is not null and end_x is not null and (
            (x<50 and end_x<50 and (end_x-x)>=30) or
            (x<50 and end_x>=50 and (end_x-x)>=15) or
            (x>=50 and end_x>=50 and (end_x-x)>=10)))         as prog,
         qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb as q_kp
  from public.events
  where player_id is not null and x is not null and y is not null
)
select player_id,
  -- attacking half-space involvement (own half excluded: this is about threat)
  count(*) filter (where hs and x >= 50 and type='Pass' and is_open_play)            as hs_passes,
  count(*) filter (where hs and x >= 50 and type='Pass' and is_open_play and prog and ok) as hs_prog_passes,
  count(*) filter (where hs and x >= 50 and type='Pass' and q_kp)                    as hs_key_passes,
  count(*) filter (where hs and x >= 50 and is_shot and is_open_play)                as hs_shots,
  count(*) filter (where hs and x >= 50 and type='TakeOn')                           as hs_takeons,
  -- defensive zones, own half only
  count(*) filter (where x < 17 and y between 21.1 and 78.9 and
        type in ('Tackle','Interception','Clearance','BlockedPass','Aerial'))        as box_def_actions,
  count(*) filter (where x < 50 and hs and
        type in ('Tackle','Interception','Clearance','BlockedPass','BallRecovery'))  as channel_def_actions,
  count(*) filter (where x < 50 and flank and
        type in ('Tackle','Interception','Clearance','BlockedPass','BallRecovery'))  as flank_def_actions,
  count(*) filter (where x < 17 and y between 21.1 and 78.9 and type='Clearance')    as box_clearances,
  count(*) filter (where x < 17 and y between 21.1 and 78.9 and type='Aerial' and ok) as box_aerials_won
from e group by player_id;
create unique index on mv_player_zones (player_id);
grant select on mv_player_zones to anon, authenticated;
