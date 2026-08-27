-- Purely SPATIAL profile: where a player operates, not how well he plays.
-- Kept deliberately free of quality/volume metrics so it can define role
-- without being circular with the performance metrics we later percentile.
create materialized view mv_player_territory as
select
  e.player_id,
  count(*)                                              as touches,
  round(avg(e.x)::numeric, 2)                           as avg_x,
  round(stddev_pop(e.x)::numeric, 2)                    as sd_x,
  round(avg(abs(e.y - 50))::numeric, 2)                 as centrality,   -- higher = wider
  round(stddev_pop(e.y)::numeric, 2)                    as sd_y,
  round(100.0*count(*) filter (where e.x < 33.3)/count(*), 2)  as pct_def_third,
  round(100.0*count(*) filter (where e.x >= 66.7)/count(*), 2) as pct_att_third,
  round(100.0*count(*) filter (where e.x >= 83 and e.y between 21 and 79)/count(*), 2) as pct_box,
  round(100.0*count(*) filter (where e.y < 21 or e.y > 79)/count(*), 2) as pct_wide_lane
from public.events e
where e.is_touch and e.is_open_play and e.x is not null and e.y is not null
group by e.player_id;
create unique index on mv_player_territory (player_id);

-- Defensive workload (share of a player's actions that are defensive).
-- Role-defining volume, used for classification only.
create materialized view mv_player_defload as
select
  player_id,
  round(100.0*count(*) filter (
    where type in ('Tackle','Interception','BallRecovery','Clearance','BlockedPass','Challenge','Aerial')
  )/nullif(count(*),0), 2) as pct_def_actions
from public.events
where is_open_play and player_id is not null
group by player_id;
create unique index on mv_player_defload (player_id);

grant select on mv_player_territory, mv_player_defload to anon, authenticated;
