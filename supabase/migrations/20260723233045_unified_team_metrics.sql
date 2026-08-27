-- One row per team carrying every team-level metric, so the rankings and league
-- map dropdowns stay in sync with whatever we add rather than needing three fetches.
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

insert into public.team_metric_defs (key,label,grp,unit,higher_is_better,definition,grp_order,sort_order) values
 ('passes_per_seq','Passes per possession','Build-up',null,true,'How many passes they string together before losing it. High means patient.',5,1),
 ('secs_per_seq','Seconds per possession','Build-up','s',true,'How long they keep the ball each time they win it.',5,2),
 ('long_sequence_pct','Long possessions','Build-up','%',true,'Share of possessions reaching six or more passes.',5,3),
 ('direct_attack_pct','Direct attacks','Build-up','%',true,'Possessions starting in their own half that reach a shot inside 15 seconds.',5,4),
 ('pct_ending_in_shot','Possessions ending in a shot','Build-up','%',true,'How often keeping the ball produces an attempt.',5,5),
 ('ground_gained','Ground gained per possession','Build-up',null,true,'How far up the pitch a typical possession travels.',5,6),
 ('passes_before_shot','Passes before a shot','Build-up',null,true,'Length of the possessions that end in an attempt.',5,7),
 ('sequences_pg','Possessions per game','Build-up',null,true,'How often they have the ball. High means a broken, transitional game.',5,8),
 ('pct_left','Left channel share','Channels','%',true,'Share of final-third involvement down their left.',6,1),
 ('pct_centre','Central share','Channels','%',true,'Share of final-third involvement through the middle.',6,2),
 ('pct_right','Right channel share','Channels','%',true,'Share of final-third involvement down their right.',6,3)
on conflict (key) do nothing;

drop materialized view if exists mv_team_percentiles cascade;
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
grant select on mv_team_all, mv_team_percentiles to anon, authenticated;
notify pgrst, 'reload schema';
