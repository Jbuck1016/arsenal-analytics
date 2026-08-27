create materialized view mv_player_metrics_raw as
with ev as (
  select
    e.player_id, e.type, e.is_shot, e.is_open_play,
    e.x, e.y, e.end_x, e.end_y,
    (e.outcome_type = 'Successful') as ok,
    (e.type='Pass' and e.x is not null and e.end_x is not null and (
      (e.x<50 and e.end_x<50  and (e.end_x-e.x)>=30) or
      (e.x<50 and e.end_x>=50 and (e.end_x-e.x)>=15) or
      (e.x>=50 and e.end_x>=50 and (e.end_x-e.x)>=10))) as prog,
    e.qualifiers @> '[{"type":{"displayName":"Cross"}}]'::jsonb                 as q_cross,
    e.qualifiers @> '[{"type":{"displayName":"Throughball"}}]'::jsonb           as q_through,
    e.qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb               as q_keypass,
    e.qualifiers @> '[{"type":{"displayName":"IntentionalGoalAssist"}}]'::jsonb as q_assist,
    e.qualifiers @> '[{"type":{"displayName":"BigChanceCreated"}}]'::jsonb      as q_bcc,
    e.qualifiers @> '[{"type":{"displayName":"BigChance"}}]'::jsonb             as q_bigchance,
    e.qualifiers @> '[{"type":{"displayName":"Longball"}}]'::jsonb              as q_long,
    e.qualifiers @> '[{"type":{"displayName":"Head"}}]'::jsonb                  as q_head,
    e.qualifiers @> '[{"type":{"displayName":"RightFoot"}}]'::jsonb             as q_rf,
    e.qualifiers @> '[{"type":{"displayName":"LeftFoot"}}]'::jsonb              as q_lf
  from public.events e
  where e.player_id is not null
),
agg as (
  select player_id,
    count(*) filter (where type='Pass' and is_open_play)                       as pass_att,
    count(*) filter (where type='Pass' and is_open_play and ok)                as pass_cmp,
    count(*) filter (where type='Pass' and is_open_play and prog)              as prog_att,
    count(*) filter (where type='Pass' and is_open_play and prog and ok)       as prog_cmp,
    coalesce(sum(greatest(0, end_x - x) * 1.05)
      filter (where type='Pass' and is_open_play and ok), 0)                   as territory_gained,
    count(*) filter (where type='Pass' and is_open_play and ok
                       and end_x >= 83 and end_y between 21 and 79)            as into_box,
    count(*) filter (where type='Pass' and is_open_play and ok and end_x >= 66.7) as final_third_passes,
    count(*) filter (where type='Pass' and is_open_play and q_cross)           as cross_att,
    count(*) filter (where type='Pass' and is_open_play and q_cross and ok)    as cross_cmp,
    count(*) filter (where type='Pass' and is_open_play and q_through)         as through_balls,
    count(*) filter (where type='Pass' and q_keypass)                          as key_passes,
    count(*) filter (where type='Pass' and q_assist)                           as assists,
    count(*) filter (where type='Pass' and q_bcc)                              as big_chances_created,
    count(*) filter (where type='Pass' and is_open_play and q_long)            as long_att,
    count(*) filter (where type='Pass' and is_open_play and q_long and ok)     as long_cmp,
    count(*) filter (where type='Pass' and is_open_play and ok and end_x > x+3) as fwd_passes,
    count(*) filter (where type='Pass' and is_open_play and ok and end_x < x-3) as bwd_passes,
    count(*) filter (where is_shot and is_open_play)                           as shots,
    count(*) filter (where is_open_play and type in ('SavedShot','Goal'))      as sot,
    count(*) filter (where is_open_play and type='Goal')                       as goals,
    count(*) filter (where is_shot and is_open_play and x >= 83 and y between 21 and 79) as shots_in_box,
    count(*) filter (where is_shot and is_open_play and q_bigchance)           as big_chance_shots,
    count(*) filter (where is_shot and is_open_play and q_head)                as headed_shots,
    count(*) filter (where is_shot and is_open_play and q_rf)                  as rf_shots,
    count(*) filter (where is_shot and is_open_play and q_lf)                  as lf_shots,
    coalesce(sum(sqrt(power((100-x)*1.05,2) + power((50-y)*0.68,2)))
      filter (where is_shot and is_open_play), 0)                              as shot_dist_sum,
    count(*) filter (where type='Tackle')                                      as tackle_att,
    count(*) filter (where type='Tackle' and ok)                               as tackle_won,
    count(*) filter (where type='Interception')                                as interceptions,
    count(*) filter (where type='Clearance')                                   as clearances,
    count(*) filter (where type='BlockedPass')                                 as blocks,
    count(*) filter (where type='BallRecovery')                                as recoveries,
    count(*) filter (where type='Aerial')                                      as aerial_att,
    count(*) filter (where type='Aerial' and ok)                               as aerial_won,
    count(*) filter (where type='Challenge')                                   as challenges_lost,
    count(*) filter (where type='Foul' and not ok)                             as fouls_committed,
    count(*) filter (where type='Foul' and ok)                                 as fouls_won,
    count(*) filter (where type='Error')                                       as errors,
    count(*) filter (where type='TakeOn')                                      as takeon_att,
    count(*) filter (where type='TakeOn' and ok)                               as takeon_won,
    count(*) filter (where type='Dispossessed')                                as dispossessed,
    count(*) filter (where type='BallTouch' and not ok)                        as bad_touches,
    round(avg(x) filter (where type in
      ('Tackle','Interception','Clearance','BallRecovery','BlockedPass','Challenge'))::numeric,2) as def_action_x
  from ev group by player_id
)
select a.*, s.player_name, s.team, s.nineties, s.minutes, s.apps, s.starts
from agg a join mv_player_season s on s.player_id = a.player_id;

create unique index on mv_player_metrics_raw (player_id);
grant select on mv_player_metrics_raw to anon, authenticated;
