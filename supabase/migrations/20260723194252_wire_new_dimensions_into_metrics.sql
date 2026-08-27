insert into public.metric_defs (key,label,grp,unit,higher_is_better,definition,grp_order,sort_order) values
 ('sca_90','Shot-creating actions','Creation',null,true,'The two offensive actions immediately preceding a shot, credited to distinct team-mates, per 90.',2,8),
 ('hs_passes_90','Half-space passes','Half-Spaces',null,true,'Passes played from the half-space strips in the attacking half, per 90.',10,1),
 ('hs_prog_90','Half-space prog. passes','Half-Spaces',null,true,'Completed progressive passes from the half-space, per 90.',10,2),
 ('hs_key_90','Half-space key passes','Half-Spaces',null,true,'Shot-creating passes from the half-space, per 90.',10,3),
 ('hs_shots_90','Half-space shots','Half-Spaces',null,true,'Shots taken from the half-space strips, per 90.',10,4),
 ('hs_takeons_90','Half-space take-ons','Half-Spaces',null,true,'Take-ons attempted in the half-space, per 90.',10,5),
 ('box_def_90','Box defending','Defending',null,true,'Defensive actions inside his own penalty area, per 90.',6,15),
 ('channel_def_90','Channel defending','Defending',null,true,'Defensive actions in the half-space channels of his own half, per 90.',6,16),
 ('flank_def_90','Flank defending','Defending',null,true,'Defensive actions in the wide areas of his own half, per 90.',6,17),
 ('counterpress_90','Counter-pressing','Defending',null,true,'Defensive actions made within five seconds of his team losing the ball, per 90.',6,18),
 ('holds_90','Hold-up episodes','Hold-Up',null,true,'Times he held the ball five seconds or more in the final third, per 90.',11,1),
 ('hold_retention','Hold retention','Hold-Up','%',true,'Share of hold-ups where his team kept the ball.',11,2),
 ('hold_prog_pct','Progressive release','Hold-Up','%',true,'Share of hold-ups he ended by carrying the ball meaningfully forward.',11,3),
 ('hold_shot_pct','Shot from hold','Hold-Up','%',true,'Share of hold-ups ending in his own shot.',11,4),
 ('sp_xg_90','Set-piece xG','Set Pieces',null,true,'Expected goals from set-piece phases, per 90. A phase is the ten seconds after a dead-ball delivery, which includes throw-ins.',12,1),
 ('sp_shots_90','Set-piece shots','Set Pieces',null,true,'Shots taken in set-piece phases, per 90.',12,2),
 ('sp_aerials_90','Set-piece aerials won','Set Pieces',null,true,'Aerial duels won in set-piece phases, per 90.',12,3),
 ('sp_key_90','Set-piece deliveries','Set Pieces',null,true,'Dead-ball deliveries that created a shot, per 90.',12,4)
on conflict (key) do nothing;

drop materialized view if exists mv_player_percentiles cascade;

create or replace view v_player_metrics_ext as
select
  m.*,
  round(z.hs_passes      / m.nineties, 2) as hs_passes_90,
  round(z.hs_prog_passes / m.nineties, 2) as hs_prog_90,
  round(z.hs_key_passes  / m.nineties, 2) as hs_key_90,
  round(z.hs_shots       / m.nineties, 2) as hs_shots_90,
  round(z.hs_takeons     / m.nineties, 2) as hs_takeons_90,
  round(z.box_def_actions     / m.nineties, 2) as box_def_90,
  round(z.channel_def_actions / m.nineties, 2) as channel_def_90,
  round(z.flank_def_actions   / m.nineties, 2) as flank_def_90,
  round(cp.counterpress / m.nineties, 2)  as counterpress_90,
  round(sca.sca / m.nineties, 2)          as sca_90,
  round(hu.holds / m.nineties, 2)         as holds_90,
  case when hu.holds >= 10 then round(100.0*hu.holds_retained/hu.holds,1) end   as hold_retention,
  case when hu.holds >= 10 then round(100.0*hu.holds_prog_carry/hu.holds,1) end as hold_prog_pct,
  case when hu.holds >= 10 then round(100.0*hu.holds_shot/hu.holds,1) end       as hold_shot_pct,
  round(coalesce(sp.sp_xg,0) / m.nineties, 3)      as sp_xg_90,
  round(sp.sp_shots / m.nineties, 2)               as sp_shots_90,
  round(sp.sp_aerials_won / m.nineties, 2)         as sp_aerials_90,
  round(sp.sp_key_passes / m.nineties, 2)          as sp_key_90
from mv_player_metrics m
left join mv_player_zones        z   on z.player_id  = m.player_id
left join mv_player_counterpress cp  on cp.player_id = m.player_id
left join mv_player_sca          sca on sca.player_id= m.player_id
left join mv_player_holdup       hu  on hu.player_id = m.player_id
left join mv_player_setpiece     sp  on sp.player_id = m.player_id;

grant select on v_player_metrics_ext to anon, authenticated;

create materialized view mv_player_percentiles as
with base as (
  select m.*, p.team_possession, (50.0/nullif(100-p.team_possession,0)) as padj
  from v_player_metrics_ext m left join mv_player_team_poss p using (player_id)
),
long as (
  select b.player_id, r.pool, b.nineties, v.metric, v.value
  from base b join mv_player_role r using (player_id)
  cross join lateral (values
    ('pass_cmp_90',b.pass_cmp_90),('pass_pct',b.pass_pct),
    ('prog_cmp_90',b.prog_cmp_90),('prog_pct',b.prog_pct),
    ('territory_90',b.territory_90),('into_box_90',b.into_box_90),
    ('final_third_90',b.final_third_90),('through_90',b.through_90),
    ('cross_90',b.cross_90),('cross_pct',b.cross_pct),
    ('key_pass_90',b.key_pass_90),('assist_90',b.assist_90),('bcc_90',b.bcc_90),
    ('xa_90',b.xa_90),('xt_90',b.xt_90),('xt_pass_90',b.xt_pass_90),('xt_carry_90',b.xt_carry_90),
    ('sca_90',b.sca_90),
    ('long_90',b.long_90),('long_pct',b.long_pct),
    ('shots_90',b.shots_90),('sot_90',b.sot_90),('goals_90',b.goals_90),
    ('xg_90',b.xg_90),('xg_per_shot',b.xg_per_shot),('finishing',b.finishing),
    ('box_share',b.box_share),('shot_dist',b.shot_dist),('conversion',b.conversion),
    ('shot_acc',b.shot_acc),('bigchance_90',b.bigchance_90),('weak_foot_share',b.weak_foot_share),
    ('tackle_90',b.tackle_90),('tackle_pct',b.tackle_pct),('int_90',b.int_90),
    ('clear_90',b.clear_90),('block_90',b.block_90),('recov_90',b.recov_90),
    ('aerial_90',b.aerial_90),('aerial_pct',b.aerial_pct),
    ('def_action_90',b.def_action_90),('def_height',b.def_height),
    ('box_def_90',b.box_def_90),('channel_def_90',b.channel_def_90),
    ('flank_def_90',b.flank_def_90),('counterpress_90',b.counterpress_90),
    ('takeon_90',b.takeon_90),('takeon_pct',b.takeon_pct),
    ('disp_90',b.disp_90),('badtouch_90',b.badtouch_90),
    ('foul_com_90',b.foul_com_90),('foul_won_90',b.foul_won_90),('error_90',b.error_90),
    ('carries_90',b.carries_90),('prog_carries_90',b.prog_carries_90),
    ('carry_box_90',b.carry_box_90),('mean_carry_m',b.mean_carry_m),('carry_pen_90',b.carry_pen_90),
    ('median_ttr',b.median_ttr),('quick_pct',b.quick_pct),('one_touch_pct',b.one_touch_pct),
    ('aq_per_duel',b.aq_per_duel),('duel_quality',b.duel_quality),
    ('recov_retention',b.recov_retention),('recov_prog_90',b.recov_prog_90),
    ('save_pct',b.save_pct),('goals_prevented_90',b.goals_prevented_90),
    ('saves_90',b.saves_90),('claims_90',b.claims_90),('sweeps_90',b.sweeps_90),('sweep_x',b.sweep_x),
    ('hs_passes_90',b.hs_passes_90),('hs_prog_90',b.hs_prog_90),('hs_key_90',b.hs_key_90),
    ('hs_shots_90',b.hs_shots_90),('hs_takeons_90',b.hs_takeons_90),
    ('holds_90',b.holds_90),('hold_retention',b.hold_retention),
    ('hold_prog_pct',b.hold_prog_pct),('hold_shot_pct',b.hold_shot_pct),
    ('sp_xg_90',b.sp_xg_90),('sp_shots_90',b.sp_shots_90),
    ('sp_aerials_90',b.sp_aerials_90),('sp_key_90',b.sp_key_90),
    ('padj_tackle_90', round((b.tackle_90    *b.padj)::numeric,2)),
    ('padj_int_90',    round((b.int_90       *b.padj)::numeric,2)),
    ('padj_def_90',    round((b.def_action_90*b.padj)::numeric,2)),
    ('padj_recov_90',  round((b.recov_90     *b.padj)::numeric,2))
  ) as v(metric,value)
),
ranked as (
  select l.*, d.higher_is_better,
    percent_rank() over (partition by l.pool, l.metric order by l.value) as pr
  from long l join public.metric_defs d on d.key=l.metric
  where l.nineties >= 6 and l.value is not null
)
select player_id, pool, metric, value,
       round((100*case when higher_is_better then pr else 1-pr end)::numeric,0) as pct
from ranked;
create index on mv_player_percentiles (player_id);
create index on mv_player_percentiles (pool, metric);
grant select on mv_player_percentiles to anon, authenticated;
notify pgrst, 'reload schema';
