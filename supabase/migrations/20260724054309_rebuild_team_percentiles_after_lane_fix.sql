create materialized view mv_team_percentiles as
with long as (
  select t.team, v.metric, v.value
  from mv_team_all t
  cross join lateral (values
    ('possession_pct',t.possession_pct),('field_tilt',t.field_tilt),
    ('avg_touch_x',t.avg_touch_x),('directness',t.directness),
    ('long_ball_pct',t.long_ball_pct),('build_from_back_pct',t.build_from_back_pct),
    ('ppda',t.ppda),('def_height',t.def_height),
    ('prog_passes_pg',t.prog_passes_pg),('box_entries_pg',t.box_entries_pg),
    ('crosses_pg',t.crosses_pg),('shots_pg',t.shots_pg),('goals_pg',t.goals_pg),
    ('open_play_shot_pct',t.open_play_shot_pct),
    ('shots_against_pg',t.shots_against_pg),('goals_against_pg',t.goals_against_pg),
    ('passes_per_seq',t.passes_per_seq),('secs_per_seq',t.secs_per_seq),
    ('long_sequence_pct',t.long_sequence_pct),('direct_attack_pct',t.direct_attack_pct),
    ('pct_ending_in_shot',t.pct_ending_in_shot),('ground_gained',t.ground_gained),
    ('passes_before_shot',t.passes_before_shot),('sequences_pg',t.sequences_pg),
    ('pct_left',t.pct_left),('pct_centre',t.pct_centre),('pct_right',t.pct_right)
  ) as v(metric,value)
),
r as (
  select l.*, d.higher_is_better,
         percent_rank() over (partition by l.metric order by l.value) as pr
  from long l join public.team_metric_defs d on d.key=l.metric
  where l.value is not null
)
select team, metric, value,
       round((100*case when higher_is_better then pr else 1-pr end)::numeric,0) as pct
from r;
create index on mv_team_percentiles (team);
grant select on mv_team_percentiles to anon, authenticated;
notify pgrst, 'reload schema';
