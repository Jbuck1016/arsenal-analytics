-- Old "Build-up" group was possession-shape, not first phase. Rename it and give
-- Build-up and Attack their own phase-specific metrics.
update public.team_metric_defs set grp='Possession', grp_order=7
  where key in ('passes_per_seq','secs_per_seq','long_sequence_pct','sequences_pg',
                'ground_gained','pct_ending_in_shot');
delete from public.team_metric_defs where key in ('direct_attack_pct','passes_before_shot');

insert into public.team_metric_defs (key,label,grp,unit,higher_is_better,definition,grp_order,sort_order) values
 -- FIRST PHASE
 ('gk_long_pct','Keeper goes long','Build-up','%',false,'Share of the goalkeeper''s passes hit long. Low means they play out.',3,1),
 ('d3_pass_share','Own-third pass share','Build-up','%',true,'Share of all their passes played from their own third. High means they spend real time building.',3,2),
 ('d3_accuracy','Own-third accuracy','Build-up','%',true,'Completion rate of passes from their own third. The pressure test on playing out.',3,3),
 ('d3_long_pct','Own-third long balls','Build-up','%',false,'Share of own-third passes hit long, bypassing the phase rather than playing through it.',3,4),
 ('deep_circulation_pg','Deep circulation','Build-up',null,true,'Completed passes that both start and end in their own third, per game. Sideways build-up.',3,5),
 ('cb_prog_pg','Centre-back progression','Build-up',null,true,'Progressive passes played by centre-backs per game. Whether defenders break lines themselves.',3,6),
 ('escape_pct','Escape rate','Build-up','%',true,'Of possessions starting in their own third, the share reaching at least the halfway line.',3,7),
 ('deep_to_final_pct','Deep to final third','Build-up','%',true,'Of possessions starting in their own third, the share reaching the final third.',3,8),
 ('d3_touch_share','Own-third touch share','Build-up','%',true,'Share of all their touches taken in their own third.',3,9),
 -- FINAL PHASE
 ('att_directness','Attacking directness','Attack','m',true,'Metres of forward progress per completed pass in the attacking half. High means vertical once they are up.',5,1),
 ('mid_release','Middle-third release','Attack','s',false,'Median seconds on the ball in the middle third. Low means quick circulation through midfield.',5,2),
 ('ft_release','Final-third release','Attack','s',false,'Median seconds on the ball in the final third. Low means they move it quickly near the box.',5,3),
 ('passes_per_shot','Passes per shot','Attack',null,false,'Completed passes for every shot taken. Low means efficient; high means they circulate without threatening.',5,4),
 ('ft_entries_pg','Final-third entries','Attack',null,true,'Passes and carries entering the final third, per game.',5,5),
 ('box_per_entry','Entries reaching the box','Attack','%',true,'Of final-third entries, the share that become a completed pass into the penalty area. Territory converted into penetration.',5,6),
 ('final_to_shot_pct','Final third to shot','Attack','%',true,'Of possessions reaching the final third, the share ending in a shot.',5,7)
on conflict (key) do nothing;

update public.team_metric_defs set grp_order=6 where grp='Attacking';
update public.team_metric_defs set grp_order=8 where grp='Defending';
update public.team_metric_defs set grp_order=9 where grp='Channels';

drop materialized view if exists mv_team_all cascade;
create materialized view mv_team_all as
select
  s.*,
  b2.passes_per_seq, b2.secs_per_seq, b2.long_sequence_pct,
  b2.pct_ending_in_shot, b2.ground_gained, b2.sequences_pg,
  bp.gk_long_pct, bp.d3_pass_share, bp.d3_accuracy, bp.d3_long_pct,
  bp.deep_circulation_pg, bp.cb_prog_pg, bp.escape_pct, bp.deep_to_final_pct, bp.d3_touch_share,
  ap.att_directness, ap.mid_release, ap.ft_release, ap.passes_per_shot,
  ap.ft_entries_pg, ap.box_per_entry, ap.final_to_shot_pct,
  coalesce(l.pct_left,0) as pct_left, coalesce(l.pct_centre,0) as pct_centre,
  coalesce(l.pct_right,0) as pct_right
from mv_team_season s
left join mv_team_buildup     b2 on b2.team = s.team
left join mv_team_buildphase  bp on bp.team = s.team
left join mv_team_attackphase ap on ap.team = s.team
left join (
  select team,
    max(pct_of_final_third) filter (where lane='L') as pct_left,
    max(pct_of_final_third) filter (where lane='C') as pct_centre,
    max(pct_of_final_third) filter (where lane='R') as pct_right
  from mv_team_lanes group by team
) l on l.team = s.team;
create unique index on mv_team_all (team);
grant select on mv_team_all to anon, authenticated;
