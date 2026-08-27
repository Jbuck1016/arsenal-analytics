
-- Registry of every percentile-able metric, so the frontend never hardcodes labels
-- and knows which direction is good.
drop table if exists public.metric_defs cascade;
create table public.metric_defs (
  metric text primary key, label text not null, grp text not null,
  higher_better boolean not null default true, unit text
);
insert into public.metric_defs (metric,label,grp,higher_better,unit) values
 ('xt_90','xT per 90','Threat',true,null),
 ('xt_pass_90','xT from passes','Threat',true,null),
 ('xt_carry_90','xT from carries','Threat',true,null),
 ('player_xt','Total chain xT','Threat',true,null),
 ('prog_att_90','Progressive passes attempted','Progression',true,'per 90'),
 ('prog_cmp_90','Progressive passes completed','Progression',true,'per 90'),
 ('prog_completion','Progressive pass completion','Progression',true,'%'),
 ('prog_tendency_pct','Progressive pass tendency','Progression',true,'%'),
 ('prog_into_final_90','Progressions into final third','Progression',true,'per 90'),
 ('into_box_90','Passes into box','Progression',true,'per 90'),
 ('final_third_90','Final-third passes','Progression',true,'per 90'),
 ('through_90','Through balls','Progression',true,'per 90'),
 ('long_90','Long passes','Progression',true,'per 90'),
 ('long_pct','Long pass accuracy','Progression',true,'%'),
 ('pass_cmp_90','Passes completed','Passing',true,'per 90'),
 ('pass_pct','Pass completion','Passing',true,'%'),
 ('pct_over','Forward passes over','Trajectory',true,'%'),
 ('pct_around','Forward passes around','Trajectory',true,'%'),
 ('pct_through','Forward passes through','Trajectory',true,'%'),
 ('pct_in_behind','Forward passes in behind','Trajectory',true,'%'),
 ('pct_inside','Forward passes inside','Trajectory',true,'%'),
 ('pct_outside','Forward passes outside','Trajectory',true,'%'),
 ('comp_through','Through-pass completion','Trajectory',true,'%'),
 ('comp_over','Over-pass completion','Trajectory',true,'%'),
 ('carries_90','Carries','Carrying',true,'per 90'),
 ('prog_carries_90','Progressive carries','Carrying',true,'per 90'),
 ('carry_box_90','Carries into box','Carrying',true,'per 90'),
 ('carry_pen_90','Carries into penalty area','Carrying',true,'per 90'),
 ('mean_carry_m','Average carry distance','Carrying',true,'m'),
 ('takeon_90','Take-ons','Carrying',true,'per 90'),
 ('takeon_pct','Take-on success','Carrying',true,'%'),
 ('disp_90','Dispossessed','Carrying',false,'per 90'),
 ('xa_90','xA per 90','Creation',true,null),
 ('key_pass_90','Key passes','Creation',true,'per 90'),
 ('sca_90','Shot-creating actions','Creation',true,'per 90'),
 ('bcc_90','Big chances created','Creation',true,'per 90'),
 ('assist_90','Assists','Creation',true,'per 90'),
 ('cross_90','Crosses','Creation',true,'per 90'),
 ('cross_pct','Cross accuracy','Creation',true,'%'),
 ('xg_90','xG per 90','Shooting',true,null),
 ('goals_90','Goals','Shooting',true,'per 90'),
 ('shots_90','Shots','Shooting',true,'per 90'),
 ('sot_90','Shots on target','Shooting',true,'per 90'),
 ('xg_per_shot','xG per shot','Shooting',true,null),
 ('conversion','Conversion rate','Shooting',true,'%'),
 ('finishing','Finishing over xG','Shooting',true,null),
 ('bigchance_90','Big chances','Shooting',true,'per 90'),
 ('early_shot_inv_90','Early involvement in shot chains','Chain value',true,'per 90'),
 ('shot_chain_pct','Share of touches in shot chains','Chain value',true,'%'),
 ('early_shot_pct','Share of touches early in shot chains','Chain value',true,'%'),
 ('mean_chain_xt','Average xT of chains involved in','Chain value',true,null),
 ('def_action_90','Defensive actions','Defending',true,'per 90'),
 ('tackle_90','Tackles','Defending',true,'per 90'),
 ('tackle_pct','Tackle success','Defending',true,'%'),
 ('int_90','Interceptions','Defending',true,'per 90'),
 ('recov_90','Recoveries','Defending',true,'per 90'),
 ('aerial_90','Aerials won','Defending',true,'per 90'),
 ('aerial_pct','Aerial success','Defending',true,'%'),
 ('counterpress_90','Counterpressures','Defending',true,'per 90'),
 ('box_def_90','Defensive actions in box','Defending',true,'per 90'),
 ('channel_def_90','Channel defending','Defending',true,'per 90'),
 ('flank_def_90','Flank defending','Defending',true,'per 90');
grant select on public.metric_defs to anon, authenticated;

-- Long-format percentiles for every metric, within position pool AND within archetype.
drop materialized view if exists public.mv_player_pct cascade;
create materialized view public.mv_player_pct as
with u as (
  select ps.player_id, ps.player, ps.pool, ps.archetype_primary, m.metric, m.raw
  from public.player_search ps
  cross join lateral (values
    ('xt_90',ps.xt_90),('xt_pass_90',ps.xt_pass_90),('xt_carry_90',ps.xt_carry_90),
    ('player_xt',ps.player_xt),
    ('prog_att_90',ps.prog_att_90),('prog_cmp_90',ps.prog_cmp_90),
    ('prog_completion',ps.prog_completion),('prog_tendency_pct',ps.prog_tendency_pct),
    ('prog_into_final_90',ps.prog_into_final_90),('into_box_90',ps.into_box_90),
    ('final_third_90',ps.final_third_90),('through_90',ps.through_90),
    ('long_90',ps.long_90),('long_pct',ps.long_pct),
    ('pass_cmp_90',ps.pass_cmp_90),('pass_pct',ps.pass_pct),
    ('pct_over',ps.pct_over),('pct_around',ps.pct_around),('pct_through',ps.pct_through),
    ('pct_in_behind',ps.pct_in_behind),('pct_inside',ps.pct_inside),('pct_outside',ps.pct_outside),
    ('comp_through',ps.comp_through),('comp_over',ps.comp_over),
    ('carries_90',ps.carries_90),('prog_carries_90',ps.prog_carries_90),
    ('carry_box_90',ps.carry_box_90),('carry_pen_90',ps.carry_pen_90),
    ('mean_carry_m',ps.mean_carry_m),('takeon_90',ps.takeon_90),
    ('takeon_pct',ps.takeon_pct),('disp_90',ps.disp_90),
    ('xa_90',ps.xa_90),('key_pass_90',ps.key_pass_90),('sca_90',ps.sca_90),
    ('bcc_90',ps.bcc_90),('assist_90',ps.assist_90),
    ('cross_90',ps.cross_90),('cross_pct',ps.cross_pct),
    ('xg_90',ps.xg_90),('goals_90',ps.goals_90),('shots_90',ps.shots_90),
    ('sot_90',ps.sot_90),('xg_per_shot',ps.xg_per_shot),('conversion',ps.conversion),
    ('finishing',ps.finishing),('bigchance_90',ps.bigchance_90),
    ('early_shot_inv_90',ps.early_shot_inv_90),('shot_chain_pct',ps.shot_chain_pct),
    ('early_shot_pct',ps.early_shot_pct),('mean_chain_xt',ps.mean_chain_xt),
    ('def_action_90',ps.def_action_90),('tackle_90',ps.tackle_90),('tackle_pct',ps.tackle_pct),
    ('int_90',ps.int_90),('recov_90',ps.recov_90),('aerial_90',ps.aerial_90),
    ('aerial_pct',ps.aerial_pct),('counterpress_90',ps.counterpress_90),
    ('box_def_90',ps.box_def_90),('channel_def_90',ps.channel_def_90),('flank_def_90',ps.flank_def_90)
  ) m(metric, raw)
  where ps.nineties >= 3
),
ranked as (
  select u.*, d.higher_better,
    percent_rank() over (partition by u.pool, u.metric order by u.raw) pr_pool,
    percent_rank() over (partition by u.archetype_primary, u.metric order by u.raw) pr_arch,
    count(*) over (partition by u.archetype_primary, u.metric) arch_n
  from u join public.metric_defs d on d.metric = u.metric
  where u.raw is not null
)
select player_id, player, pool, archetype_primary, metric, raw, higher_better,
  round(100*(case when higher_better then pr_pool else 1-pr_pool end))::int as pct_pool,
  case when arch_n >= 15
       then round(100*(case when higher_better then pr_arch else 1-pr_arch end))::int end as pct_archetype,
  arch_n as archetype_cohort
from ranked;
create index mv_player_pct_player on public.mv_player_pct (player_id);
create index mv_player_pct_metric on public.mv_player_pct (metric);
grant select on public.mv_player_pct to anon, authenticated;
