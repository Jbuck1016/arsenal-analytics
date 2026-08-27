-- Metric metadata: drives UI labels, tooltips, units, and percentile direction.
create table if not exists public.metric_defs (
  key               text primary key,
  label             text not null,
  grp               text not null,
  unit              text,
  higher_is_better  boolean not null default true,
  definition        text
);

insert into public.metric_defs (key,label,grp,unit,higher_is_better,definition) values
 ('pass_cmp_90','Passes completed','Passing',null,true,'Completed open-play passes per 90.'),
 ('pass_pct','Pass accuracy','Passing','%',true,'Completion rate in open play.'),
 ('prog_cmp_90','Progressive passes','Passing',null,true,'Completed passes advancing the ball meaningfully toward goal, per 90.'),
 ('prog_pct','Prog. pass accuracy','Passing','%',true,'Completion rate of progressive passes. Needs 25 attempts.'),
 ('territory_90','Territory gained','Passing','m',true,'Metres of forward distance eliminated by completed passes, per 90.'),
 ('into_box_90','Passes into box','Passing',null,true,'Completed open-play passes ending in the penalty area, per 90.'),
 ('final_third_90','Final third passes','Passing',null,true,'Completed passes into the final third, per 90.'),
 ('through_90','Through balls','Passing',null,true,'Passes played in behind the defensive line, per 90.'),
 ('cross_90','Crosses','Passing',null,true,'Open-play crosses attempted, per 90.'),
 ('cross_pct','Cross accuracy','Passing','%',true,'Share of open-play crosses completed. Needs 20 attempts.'),
 ('key_pass_90','Key passes','Creation',null,true,'Passes directly creating a shot, per 90.'),
 ('assist_90','Assists','Creation',null,true,'Passes directly creating a goal, per 90.'),
 ('bcc_90','Big chances created','Creation',null,true,'Passes creating a big chance, per 90.'),
 ('long_90','Long balls','Passing',null,true,'Long passes attempted, per 90.'),
 ('long_pct','Long ball accuracy','Passing','%',true,'Completion rate of long balls. Needs 25 attempts.'),
 ('shots_90','Shots','Shooting',null,true,'Open-play shots per 90.'),
 ('sot_90','Shots on target','Shooting',null,true,'On-target shots per 90.'),
 ('goals_90','Goals','Shooting',null,true,'Open-play goals per 90.'),
 ('box_share','Shots in box share','Shooting','%',true,'Share of shots taken inside the area. High means good positions.'),
 ('shot_dist','Mean shot distance','Shooting','m',false,'Average distance from goal. Lower is generally better.'),
 ('conversion','Conversion','Shooting','%',true,'Goals per shot. Needs 12 shots.'),
 ('shot_acc','Shot accuracy','Shooting','%',true,'Share of shots on target.'),
 ('bigchance_90','Big-chance shots','Shooting',null,true,'Shots from a big chance, per 90.'),
 ('weak_foot_share','Weak-foot share','Shooting','%',true,'Share of shooting on the weaker foot. 50% is two-footed.'),
 ('tackle_90','Tackles','Defending',null,true,'Tackles attempted per 90.'),
 ('tackle_pct','Tackle success','Defending','%',true,'Share of tackles won. Needs 15 attempts.'),
 ('int_90','Interceptions','Defending',null,true,'Interceptions per 90.'),
 ('clear_90','Clearances','Defending',null,true,'Clearances per 90.'),
 ('block_90','Blocks','Defending',null,true,'Passes blocked per 90.'),
 ('recov_90','Recoveries','Defending',null,true,'Loose balls won per 90.'),
 ('aerial_90','Aerial duels','Defending',null,true,'Aerial duels contested per 90.'),
 ('aerial_pct','Aerial win rate','Defending','%',true,'Share of aerial duels won. Needs 20 duels.'),
 ('def_action_90','Defensive actions','Defending',null,true,'All defensive actions per 90.'),
 ('def_height','Defensive line height','Defending',null,true,'Average pitch position of defensive actions. Higher means he defends further up.'),
 ('takeon_90','Take-ons','Carrying',null,true,'Dribbles attempted per 90.'),
 ('takeon_pct','Take-on success','Carrying','%',true,'Share of take-ons completed. Needs 15 attempts.'),
 ('disp_90','Dispossessed','Carrying',null,false,'Times dispossessed per 90. Lower is better.'),
 ('badtouch_90','Bad touches','Carrying',null,false,'Miscontrols per 90. Lower is better.'),
 ('foul_com_90','Fouls committed','Discipline',null,false,'Fouls conceded per 90. Lower is better.'),
 ('foul_won_90','Fouls won','Discipline',null,true,'Fouls drawn per 90.'),
 ('error_90','Errors','Discipline',null,false,'Errors leading to a chance, per 90. Lower is better.')
on conflict (key) do nothing;

grant select on public.metric_defs to anon, authenticated;

-- Per-90 rates and percentage metrics. NULL where the sample is too small to report.
create materialized view mv_player_metrics as
select
  r.player_id, r.player_name, r.team, r.nineties,
  round(r.pass_cmp / r.nineties, 2)                                   as pass_cmp_90,
  round(100.0*r.pass_cmp / nullif(r.pass_att,0), 1)                   as pass_pct,
  round(r.prog_cmp / r.nineties, 2)                                   as prog_cmp_90,
  case when r.prog_att >= 25 then round(100.0*r.prog_cmp/r.prog_att,1) end as prog_pct,
  round((r.territory_gained / r.nineties)::numeric, 1)                as territory_90,
  round(r.into_box / r.nineties, 2)                                   as into_box_90,
  round(r.final_third_passes / r.nineties, 2)                         as final_third_90,
  round(r.through_balls / r.nineties, 3)                              as through_90,
  round(r.cross_att / r.nineties, 2)                                  as cross_90,
  case when r.cross_att >= 20 then round(100.0*r.cross_cmp/r.cross_att,1) end as cross_pct,
  round(r.key_passes / r.nineties, 2)                                 as key_pass_90,
  round(r.assists / r.nineties, 3)                                    as assist_90,
  round(r.big_chances_created / r.nineties, 3)                        as bcc_90,
  round(r.long_att / r.nineties, 2)                                   as long_90,
  case when r.long_att >= 25 then round(100.0*r.long_cmp/r.long_att,1) end as long_pct,
  round(r.shots / r.nineties, 2)                                      as shots_90,
  round(r.sot / r.nineties, 2)                                        as sot_90,
  round(r.goals / r.nineties, 3)                                      as goals_90,
  case when r.shots >= 10 then round(100.0*r.shots_in_box/r.shots,1) end as box_share,
  case when r.shots >= 10 then round((r.shot_dist_sum/r.shots)::numeric,1) end as shot_dist,
  case when r.shots >= 12 then round(100.0*r.goals/r.shots,1) end     as conversion,
  case when r.shots >= 10 then round(100.0*r.sot/r.shots,1) end       as shot_acc,
  round(r.big_chance_shots / r.nineties, 3)                           as bigchance_90,
  case when (r.rf_shots + r.lf_shots) >= 10
       then round(100.0*least(r.rf_shots,r.lf_shots)/(r.rf_shots+r.lf_shots),1) end as weak_foot_share,
  round(r.tackle_att / r.nineties, 2)                                 as tackle_90,
  case when r.tackle_att >= 15 then round(100.0*r.tackle_won/r.tackle_att,1) end as tackle_pct,
  round(r.interceptions / r.nineties, 2)                              as int_90,
  round(r.clearances / r.nineties, 2)                                 as clear_90,
  round(r.blocks / r.nineties, 2)                                     as block_90,
  round(r.recoveries / r.nineties, 2)                                 as recov_90,
  round(r.aerial_att / r.nineties, 2)                                 as aerial_90,
  case when r.aerial_att >= 20 then round(100.0*r.aerial_won/r.aerial_att,1) end as aerial_pct,
  round((r.tackle_att+r.interceptions+r.clearances+r.blocks+r.recoveries) / r.nineties, 2) as def_action_90,
  r.def_action_x                                                      as def_height,
  round(r.takeon_att / r.nineties, 2)                                 as takeon_90,
  case when r.takeon_att >= 15 then round(100.0*r.takeon_won/r.takeon_att,1) end as takeon_pct,
  round(r.dispossessed / r.nineties, 2)                               as disp_90,
  round(r.bad_touches / r.nineties, 2)                                as badtouch_90,
  round(r.fouls_committed / r.nineties, 2)                            as foul_com_90,
  round(r.fouls_won / r.nineties, 2)                                  as foul_won_90,
  round(r.errors / r.nineties, 3)                                     as error_90
from mv_player_metrics_raw r
where r.nineties > 0;

create unique index on mv_player_metrics (player_id);
grant select on mv_player_metrics to anon, authenticated;
