-- Verified empirically: right-backs average y=22, left-backs y=82. Low y is the
-- attacking team's RIGHT. The previous definition had the channels mirrored.
-- Also fixes an operator-precedence bug where the is_shot clause escaped the
-- open-play and type filters.
drop materialized view if exists mv_team_lanes cascade;

create materialized view mv_team_lanes as
with a as (
  select team,
    case when y < 33.3 then 'R' when y < 66.7 then 'C' else 'L' end as lane,
    (x >= 66.7) as final_third,
    (type='Pass' and end_x >= 83 and end_y between 21 and 79) as into_box,
    is_shot
  from public.events
  where team is not null and x is not null and y is not null
    and (
      (is_open_play and type in ('Pass','TakeOn','BallTouch','Dispossessed'))
      or is_shot
    )
)
select team, lane,
  count(*)                             as touches,
  count(*) filter (where final_third)  as final_third_touches,
  count(*) filter (where into_box)     as box_entries,
  count(*) filter (where is_shot)      as shots,
  round(100.0*count(*) filter (where final_third)
        / nullif(sum(count(*) filter (where final_third)) over (partition by team),0),1) as pct_of_final_third
from a group by team, lane;
create index on mv_team_lanes (team);
grant select on mv_team_lanes to anon, authenticated;

drop materialized view if exists mv_team_all cascade;
create materialized view mv_team_all as
select
  s.*,
  b.passes_per_seq, b.secs_per_seq, b.long_sequence_pct, b.direct_attack_pct,
  b.pct_ending_in_shot, b.ground_gained, b.passes_before_shot, b.sequences_pg,
  coalesce(l.pct_left,0)   as pct_left,
  coalesce(l.pct_centre,0) as pct_centre,
  coalesce(l.pct_right,0)  as pct_right
from mv_team_season s
left join mv_team_buildup b on b.team = s.team
left join (
  select team,
    max(pct_of_final_third) filter (where lane='L') as pct_left,
    max(pct_of_final_third) filter (where lane='C') as pct_centre,
    max(pct_of_final_third) filter (where lane='R') as pct_right
  from mv_team_lanes group by team
) l on l.team = s.team;
create unique index on mv_team_all (team);

update public.team_metric_defs set
  definition='Share of final-third involvement down their left. The left channel is the far side of the pitch as drawn, since attack runs left to right.'
  where key='pct_left';
update public.team_metric_defs set
  definition='Share of final-third involvement through the middle third of the pitch width.'
  where key='pct_centre';
update public.team_metric_defs set
  definition='Share of final-third involvement down their right. The right channel is the near side of the pitch as drawn.'
  where key='pct_right';

grant select on mv_team_all to anon, authenticated;
