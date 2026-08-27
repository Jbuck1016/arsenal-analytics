
-- How well each side defends against different kinds of build-up.
-- Every possession has an opponent; from the defending team's view it is a pressing test.
drop materialized view if exists public.mv_press_vs_buildup cascade;
create materialized view public.mv_press_vs_buildup as
with gteams as (
  select game_id, array_agg(distinct team) tms from public.sequences group by game_id
),
opp as (
  select s.seq_uid, s.game_id, s.team as attacking_team,
    (select t from unnest(gt.tms) t where t <> s.team limit 1) as defending_team,
    case
      when s.long_ball then 'direct'
      when s.start_x < 33.3 then 'short_build'
      when s.start_x >= 50 then 'high_start'
      else 'mid_start' end as buildup_type,
    s.end_x, s.end_third, s.ended_shot, s.ended_in_box, s.n_pass, s.dur_s
  from public.sequences s
  join gteams gt using (game_id)
  where s.is_open_play
)
select defending_team, buildup_type,
  count(*) as n,
  round(100.0*avg((end_x < 66.7 and not ended_shot)::int), 1) as contained_pct,
  round(100.0*avg((end_third = 'def')::int), 1) as died_in_their_third_pct,
  round(100.0*avg(ended_shot::int), 1) as conceded_shot_pct,
  round(100.0*avg(ended_in_box::int), 1) as conceded_box_pct,
  round(avg(n_pass)::numeric, 2) as opp_passes_per_seq,
  round(avg(dur_s)::numeric, 1) as opp_secs_per_seq
from opp
where defending_team is not null
group by defending_team, buildup_type;
create index mv_press_vs_buildup_team on public.mv_press_vs_buildup (defending_team);
grant select on public.mv_press_vs_buildup to anon, authenticated;

-- Wide view: does a side handle short build-up better or worse than direct play?
drop view if exists public.v_press_profile cascade;
create view public.v_press_profile as
select defending_team as team,
  max(contained_pct) filter (where buildup_type='short_build') as vs_short_build,
  max(contained_pct) filter (where buildup_type='direct')      as vs_direct,
  max(contained_pct) filter (where buildup_type='high_start')  as vs_high_start,
  max(conceded_shot_pct) filter (where buildup_type='short_build') as shot_vs_short,
  max(conceded_shot_pct) filter (where buildup_type='direct')      as shot_vs_direct,
  round((max(contained_pct) filter (where buildup_type='short_build')
       - max(contained_pct) filter (where buildup_type='direct'))::numeric, 1) as short_minus_direct
from public.mv_press_vs_buildup
group by defending_team;
grant select on public.v_press_profile to anon, authenticated;
