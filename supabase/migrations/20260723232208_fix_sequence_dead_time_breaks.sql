drop materialized view if exists mv_team_buildup cascade;
drop materialized view if exists mv_team_sequences cascade;

-- A possession ends when the opposition touches it OR when play stops. Without
-- the dead-time break a throw-in taken 40s later reads as the same possession,
-- which inflates duration and makes the tempo metrics meaningless.
create materialized view mv_team_sequences as
with base as (
  select game_id, ws_id, team, type, x, y, end_x, is_shot, period,
         (minute*60+second) as sec,
         lag(team)   over w as prev_team,
         lag(period) over w as prev_period,
         (minute*60+second) - lag(minute*60+second) over w as gap
  from public.events
  where team is not null and x is not null
    and type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','OffsideProvoked','CornerAwarded')
  window w as (partition by game_id order by ws_id)
),
flagged as (
  select *, case when prev_team is distinct from team
                   or prev_period is distinct from period
                   or coalesce(gap,99) > 8       -- ball out of play / restart
                 then 1 else 0 end as newseq
  from base
),
numbered as (
  select *, sum(newseq) over (partition by game_id order by ws_id
                              rows between unbounded preceding and current row) as seq_id
  from flagged
)
select game_id, seq_id, team,
  count(*) as actions,
  count(*) filter (where type='Pass') as passes,
  greatest(max(sec)-min(sec),0) as duration_s,
  min(x) as start_x, max(coalesce(end_x,x)) as max_x,
  bool_or(is_shot) as ended_in_shot
from numbered
group by game_id, seq_id, team
having count(*) >= 2;
create index on mv_team_sequences (team);

create materialized view mv_team_buildup as
with s as (select * from mv_team_sequences),
m as (select team, count(*) as matches from mv_team_match group by team)
select
  s.team,
  count(*)                                                        as sequences,
  round(count(*)::numeric/nullif(m.matches,0),1)                  as sequences_pg,
  round(avg(s.passes)::numeric,2)                                 as passes_per_seq,
  round(avg(s.duration_s)::numeric,1)                             as secs_per_seq,
  round(100.0*count(*) filter (where s.ended_in_shot)/count(*),1) as pct_ending_in_shot,
  round(100.0*count(*) filter (where s.start_x < 50 and s.ended_in_shot and s.duration_s <= 15)
        / nullif(count(*) filter (where s.start_x < 50),0),2)     as direct_attack_pct,
  round(100.0*count(*) filter (where s.passes >= 6)/count(*),1)   as long_sequence_pct,
  round(avg(s.max_x - s.start_x)::numeric,1)                      as ground_gained,
  round(avg(s.passes) filter (where s.ended_in_shot)::numeric,2)  as passes_before_shot,
  round(avg(s.duration_s) filter (where s.ended_in_shot)::numeric,1) as secs_before_shot
from s join m on m.team=s.team
group by s.team, m.matches;
create unique index on mv_team_buildup (team);
grant select on mv_team_sequences, mv_team_buildup to anon, authenticated;
notify pgrst, 'reload schema';
