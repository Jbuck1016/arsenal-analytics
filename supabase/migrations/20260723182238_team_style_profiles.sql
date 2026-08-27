-- Per-team, per-match style metrics.
-- WhoScored x is always attack-direction relative (0 = own goal, 100 = opponent goal),
-- so PPDA zones can be expressed directly per team without mirroring.
create materialized view mv_team_match as
with ev as (
  select e.game_id, e.team, e.type, e.x, e.y, e.end_x, e.end_y, e.is_shot, e.is_open_play,
         (e.outcome_type='Successful') as ok,
         (e.type='Pass' and e.x is not null and e.end_x is not null and (
           (e.x<50 and e.end_x<50  and (e.end_x-e.x)>=30) or
           (e.x<50 and e.end_x>=50 and (e.end_x-e.x)>=15) or
           (e.x>=50 and e.end_x>=50 and (e.end_x-e.x)>=10))) as prog,
         e.qualifiers @> '[{"type":{"displayName":"Cross"}}]'::jsonb   as q_cross,
         e.qualifiers @> '[{"type":{"displayName":"Longball"}}]'::jsonb as q_long
  from public.events e
  where e.team is not null
),
t as (
  select game_id, team,
    count(*) filter (where type='Pass')                                     as passes,
    count(*) filter (where type='Pass' and ok)                              as passes_cmp,
    count(*) filter (where type='Pass' and is_open_play and q_long)         as long_balls,
    count(*) filter (where type='Pass' and prog and ok)                     as prog_passes,
    coalesce(sum(greatest(0,end_x-x)*1.05) filter (where type='Pass' and ok),0) as territory,
    count(*) filter (where is_touch_proxy and x>=66.7)                      as ft_touches,
    count(*) filter (where is_touch_proxy)                                  as touches,
    count(*) filter (where type='Pass' and x<33.3)                          as passes_from_def_third,
    count(*) filter (where type='Pass' and is_open_play and ok
                       and end_x>=83 and end_y between 21 and 79)           as box_entries_pass,
    count(*) filter (where type='Pass' and is_open_play and q_cross)        as crosses,
    count(*) filter (where is_shot)                                         as shots,
    count(*) filter (where is_shot and is_open_play)                        as shots_open,
    count(*) filter (where type='Goal')                                     as goals,
    count(*) filter (where type in ('Tackle','Interception','BallRecovery','BlockedPass','Challenge')) as def_actions,
    count(*) filter (where type in ('Tackle','Interception','BallRecovery','BlockedPass','Challenge')
                       and x>40)                                            as def_actions_high,
    count(*) filter (where type='Pass' and x<60)                            as passes_own60,
    round(avg(x) filter (where type in
      ('Tackle','Interception','BallRecovery','BlockedPass','Challenge'))::numeric,2) as def_height,
    round(avg(x) filter (where is_touch_proxy)::numeric,2)                  as avg_touch_x
  from (select *, (type not in ('SubstitutionOn','SubstitutionOff','Card','FormationChange',
        'FormationSet','Start','End','CornerAwarded','OffsideGiven','OffsideProvoked')
        and x is not null) as is_touch_proxy from ev) z
  group by game_id, team
),
paired as (
  select a.*, b.team as opp,
         b.passes as opp_passes, b.passes_own60 as opp_passes_own60,
         b.ft_touches as opp_ft_touches, b.touches as opp_touches,
         b.shots as opp_shots, b.goals as opp_goals
  from t a join t b on b.game_id = a.game_id and b.team <> a.team
)
select
  game_id, team, opp,
  passes, passes_cmp, shots, shots_open, goals, opp_shots, opp_goals,
  round(100.0*passes/nullif(passes+opp_passes,0),1)               as possession_pct,
  round(100.0*ft_touches/nullif(ft_touches+opp_ft_touches,0),1)   as field_tilt,
  round(opp_passes_own60::numeric/nullif(def_actions_high,0),2)   as ppda,
  def_height,
  avg_touch_x,
  round(100.0*long_balls/nullif(passes,0),1)                      as long_ball_pct,
  round(100.0*passes_from_def_third/nullif(passes,0),1)           as build_from_back_pct,
  round(territory::numeric/nullif(passes_cmp,0),2)                as directness,
  prog_passes, box_entries_pass, crosses, def_actions,
  round(100.0*shots_open/nullif(shots,0),1)                       as open_play_shot_pct
from paired;

create unique index on mv_team_match (game_id, team);

-- Season-level team style profile
create materialized view mv_team_season as
select
  team,
  count(*)                            as matches,
  round(avg(possession_pct),1)        as possession_pct,
  round(avg(field_tilt),1)            as field_tilt,
  round(avg(ppda),2)                  as ppda,
  round(avg(def_height),1)            as def_height,
  round(avg(avg_touch_x),1)           as avg_touch_x,
  round(avg(long_ball_pct),1)         as long_ball_pct,
  round(avg(build_from_back_pct),1)   as build_from_back_pct,
  round(avg(directness),2)            as directness,
  round(avg(prog_passes),1)           as prog_passes_pg,
  round(avg(box_entries_pass),1)      as box_entries_pg,
  round(avg(crosses),1)               as crosses_pg,
  round(avg(shots),1)                 as shots_pg,
  round(avg(opp_shots),1)             as shots_against_pg,
  round(avg(goals),2)                 as goals_pg,
  round(avg(opp_goals),2)             as goals_against_pg,
  round(avg(open_play_shot_pct),1)    as open_play_shot_pct
from mv_team_match
group by team;

create unique index on mv_team_season (team);
grant select on mv_team_match, mv_team_season to anon, authenticated;
