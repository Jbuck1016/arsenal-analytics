create table if not exists public.team_metric_defs (
  key text primary key, label text not null, grp text not null, unit text,
  higher_is_better boolean not null default true, definition text, grp_order int, sort_order int
);
truncate public.team_metric_defs;
insert into public.team_metric_defs (key,label,grp,unit,higher_is_better,definition,grp_order,sort_order) values
 ('possession_pct','Possession','Control','%',true,'Share of all passes in the match played by this team.',1,1),
 ('field_tilt','Field tilt','Control','%',true,'Share of final-third touches. Territorial dominance rather than raw possession.',1,2),
 ('avg_touch_x','Average touch height','Control',null,true,'Mean pitch position of the team''s touches. Higher means they play further up.',1,3),
 ('directness','Directness','Control','m',true,'Metres of forward progress per completed pass. High means vertical, low means patient.',1,4),
 ('long_ball_pct','Long ball share','Control','%',false,'Share of passes hit long. Lower usually means a shorter build-up.',1,5),
 ('build_from_back_pct','Build from the back','Control','%',true,'Share of passes played from the defensive third.',1,6),
 ('ppda','PPDA','Pressing',null,false,'Opponent passes allowed per defensive action in their own 60%. Lower means a more aggressive press.',2,1),
 ('def_height','Defensive line height','Pressing',null,true,'Average pitch position of defensive actions. Higher means a higher line.',2,2),
 ('prog_passes_pg','Progressive passes','Attacking',null,true,'Completed progressive passes per game.',3,1),
 ('box_entries_pg','Passes into box','Attacking',null,true,'Completed passes into the penalty area per game.',3,2),
 ('crosses_pg','Crosses','Attacking',null,true,'Open-play crosses per game.',3,3),
 ('shots_pg','Shots','Attacking',null,true,'Shots taken per game.',3,4),
 ('goals_pg','Goals','Attacking',null,true,'Goals scored per game.',3,5),
 ('open_play_shot_pct','Open-play shot share','Attacking','%',true,'Share of shots coming from open play rather than set-piece phases.',3,6),
 ('shots_against_pg','Shots conceded','Defending',null,false,'Shots faced per game. Lower is better.',4,1),
 ('goals_against_pg','Goals conceded','Defending',null,false,'Goals conceded per game. Lower is better.',4,2);
grant select on public.team_metric_defs to anon, authenticated;

create materialized view mv_team_percentiles as
with long as (
  select t.team, v.metric, v.value
  from mv_team_season t
  cross join lateral (values
    ('possession_pct',t.possession_pct),('field_tilt',t.field_tilt),
    ('avg_touch_x',t.avg_touch_x),('directness',t.directness),
    ('long_ball_pct',t.long_ball_pct),('build_from_back_pct',t.build_from_back_pct),
    ('ppda',t.ppda),('def_height',t.def_height),
    ('prog_passes_pg',t.prog_passes_pg),('box_entries_pg',t.box_entries_pg),
    ('crosses_pg',t.crosses_pg),('shots_pg',t.shots_pg),('goals_pg',t.goals_pg),
    ('open_play_shot_pct',t.open_play_shot_pct),
    ('shots_against_pg',t.shots_against_pg),('goals_against_pg',t.goals_against_pg)
  ) as v(metric,value)
),
r as (
  select l.*, d.higher_is_better,
         percent_rank() over (partition by l.metric order by l.value) as pr
  from long l join public.team_metric_defs d on d.key = l.metric
  where l.value is not null
)
select team, metric, value,
       round((100*case when higher_is_better then pr else 1-pr end)::numeric,0) as pct
from r;
create index on mv_team_percentiles (team);
grant select on mv_team_percentiles to anon, authenticated;
notify pgrst, 'reload schema';
