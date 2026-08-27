-- Per-team season averages of the match-level stats shown in Season Stats,
-- with a league rank for each so a total can be read in context.
create materialized view mv_team_stat_ranks as
with per as (
  select team,
    count(*) as matches,
    avg(final_third_passes)    as final_third_passes,
    avg(zone14_passes)         as zone14_passes,
    avg(progressive_passes)    as progressive_passes,
    avg(passes_into_box)       as passes_into_box,
    avg(defensive_actions)     as defensive_actions,
    avg(defensive_actions_won) as defensive_actions_won,
    avg(shots)                 as shots,
    avg(shots_on_target)       as shots_on_target,
    avg(fwd_passes)            as fwd_passes,
    avg(lat_passes)            as lat_passes,
    avg(bwd_passes)            as bwd_passes
  from v_season_stats group by team
),
long as (
  select team, v.metric, v.value
  from per cross join lateral (values
    ('final_third_passes',final_third_passes),('zone14_passes',zone14_passes),
    ('progressive_passes',progressive_passes),('passes_into_box',passes_into_box),
    ('defensive_actions',defensive_actions),('defensive_actions_won',defensive_actions_won),
    ('shots',shots),('shots_on_target',shots_on_target),
    ('fwd_passes',fwd_passes),('lat_passes',lat_passes),('bwd_passes',bwd_passes)
  ) as v(metric,value)
)
select team, metric, round(value::numeric,2) as per_game,
       rank() over (partition by metric order by value desc) as league_rank,
       count(*) over (partition by metric) as of_teams
from long;
create index on mv_team_stat_ranks (team);
grant select on mv_team_stat_ranks to anon, authenticated;
notify pgrst, 'reload schema';
