-- Possession sequences: consecutive events by the same team, broken whenever the
-- opposition touches it. This is what lets us separate a patient build-up from a
-- direct attack, which raw pass counts cannot.
create materialized view mv_team_sequences as
with base as (
  select game_id, ws_id, team, type, x, y, end_x, is_shot,
         (minute*60+second) as sec,
         case when lag(team) over (partition by game_id order by ws_id) is distinct from team
              then 1 else 0 end as newseq
  from public.events
  where team is not null and x is not null
    and type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','OffsideProvoked','CornerAwarded')
),
numbered as (
  select *, sum(newseq) over (partition by game_id order by ws_id
                              rows between unbounded preceding and current row) as seq_id
  from base
)
select
  game_id, seq_id, team,
  count(*)                                        as actions,
  count(*) filter (where type='Pass')             as passes,
  max(sec) - min(sec)                             as duration_s,
  min(x)                                          as start_x,
  max(coalesce(end_x,x))                          as max_x,
  bool_or(is_shot)                                as ended_in_shot,
  min(sec)                                        as start_sec
from numbered
group by game_id, seq_id, team
having count(*) >= 2;
create index on mv_team_sequences (team);

-- Team attacking profile: tempo, patience and directness of their possessions
create materialized view mv_team_buildup as
with s as (select * from mv_team_sequences),
m as (select team, count(*) as matches from mv_team_match group by team)
select
  s.team,
  count(*)                                                          as sequences,
  round(avg(s.passes)::numeric,2)                                   as passes_per_seq,
  round(avg(s.duration_s)::numeric,1)                               as secs_per_seq,
  round(100.0*count(*) filter (where s.ended_in_shot)/count(*),1)   as pct_ending_in_shot,
  -- direct attack: begins in own half, reaches a shot inside 15 seconds
  round(100.0*count(*) filter (where s.start_x < 50 and s.ended_in_shot and s.duration_s <= 15)
        / nullif(count(*) filter (where s.start_x < 50),0), 2)      as direct_attack_pct,
  -- patient build-up: 8+ passes before releasing it
  round(100.0*count(*) filter (where s.passes >= 8)/count(*),1)     as long_sequence_pct,
  round(avg(s.max_x - s.start_x)::numeric,1)                        as ground_gained,
  round((count(*) filter (where s.passes>=8))::numeric/nullif(m.matches,0),1) as long_seq_pg,
  round(avg(s.passes) filter (where s.ended_in_shot)::numeric,2)    as passes_before_shot
from s join m on m.team=s.team
group by s.team, m.matches;
create unique index on mv_team_buildup (team);

-- Which side of the pitch a team attacks through
create materialized view mv_team_lanes as
with a as (
  select team,
    case when y < 33.3 then 'L' when y < 66.7 then 'C' else 'R' end as lane,
    (x >= 66.7) as final_third,
    (type='Pass' and end_x >= 83 and end_y between 21 and 79) as into_box,
    is_shot
  from public.events
  where team is not null and x is not null and y is not null and is_open_play
    and type in ('Pass','TakeOn','BallTouch','Dispossessed')
       or (team is not null and x is not null and y is not null and is_shot)
)
select team, lane,
  count(*)                                        as touches,
  count(*) filter (where final_third)             as final_third_touches,
  count(*) filter (where into_box)                as box_entries,
  count(*) filter (where is_shot)                 as shots,
  round(100.0*count(*) filter (where final_third)
        / nullif(sum(count(*) filter (where final_third)) over (partition by team),0),1) as pct_of_final_third
from a group by team, lane;
create index on mv_team_lanes (team);

grant select on mv_team_sequences, mv_team_buildup, mv_team_lanes to anon, authenticated;
notify pgrst, 'reload schema';
