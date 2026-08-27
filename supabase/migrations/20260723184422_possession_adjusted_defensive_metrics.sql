-- Possession adjustment: a defender at a possession-dominant side gets fewer
-- chances to defend, so raw defensive volume understates him (and vice versa).
-- Scale to a neutral 50% opponent-possession baseline.
--   padj = raw * (50 / opponent_possession)
create materialized view mv_player_team_poss as
select
  m.player_id,
  round(sum(t.possession_pct * m.minutes) / nullif(sum(m.minutes),0), 2) as team_possession
from mv_player_minutes m
join mv_team_match t on t.game_id = m.game_id and t.team = m.team
group by m.player_id;
create unique index on mv_player_team_poss (player_id);

insert into public.metric_defs (key,label,grp,unit,higher_is_better,definition,grp_order,sort_order) values
 ('padj_tackle_90','Tackles (padj)','Defending',null,true,'Tackles per 90, adjusted for how much possession his team concedes. Neutralises the advantage of playing for a low-possession side.',6,11),
 ('padj_int_90','Interceptions (padj)','Defending',null,true,'Interceptions per 90, possession-adjusted.',6,12),
 ('padj_def_90','Defensive actions (padj)','Defending',null,true,'All defensive actions per 90, possession-adjusted.',6,13),
 ('padj_recov_90','Recoveries (padj)','Defending',null,true,'Ball recoveries per 90, possession-adjusted.',6,14)
on conflict (key) do nothing;

drop materialized view if exists mv_player_percentiles cascade;

create materialized view mv_player_percentiles as
with base as (
  select m.*, p.team_possession,
         (50.0 / nullif(100 - p.team_possession, 0)) as padj_factor
  from mv_player_metrics m
  left join mv_player_team_poss p using (player_id)
),
long as (
  select b.player_id, r.pool, b.nineties, v.metric, v.value
  from base b
  join mv_player_role r using (player_id)
  cross join lateral (values
    ('pass_cmp_90',b.pass_cmp_90),('pass_pct',b.pass_pct),
    ('prog_cmp_90',b.prog_cmp_90),('prog_pct',b.prog_pct),
    ('territory_90',b.territory_90),('into_box_90',b.into_box_90),
    ('final_third_90',b.final_third_90),('through_90',b.through_90),
    ('cross_90',b.cross_90),('cross_pct',b.cross_pct),
    ('key_pass_90',b.key_pass_90),('assist_90',b.assist_90),('bcc_90',b.bcc_90),
    ('long_90',b.long_90),('long_pct',b.long_pct),
    ('shots_90',b.shots_90),('sot_90',b.sot_90),('goals_90',b.goals_90),
    ('box_share',b.box_share),('shot_dist',b.shot_dist),('conversion',b.conversion),
    ('shot_acc',b.shot_acc),('bigchance_90',b.bigchance_90),('weak_foot_share',b.weak_foot_share),
    ('tackle_90',b.tackle_90),('tackle_pct',b.tackle_pct),('int_90',b.int_90),
    ('clear_90',b.clear_90),('block_90',b.block_90),('recov_90',b.recov_90),
    ('aerial_90',b.aerial_90),('aerial_pct',b.aerial_pct),
    ('def_action_90',b.def_action_90),('def_height',b.def_height),
    ('takeon_90',b.takeon_90),('takeon_pct',b.takeon_pct),
    ('disp_90',b.disp_90),('badtouch_90',b.badtouch_90),
    ('foul_com_90',b.foul_com_90),('foul_won_90',b.foul_won_90),('error_90',b.error_90),
    ('carries_90',b.carries_90),('prog_carries_90',b.prog_carries_90),
    ('carry_box_90',b.carry_box_90),('mean_carry_m',b.mean_carry_m),('carry_pen_90',b.carry_pen_90),
    ('median_ttr',b.median_ttr),('quick_pct',b.quick_pct),('one_touch_pct',b.one_touch_pct),
    ('aq_per_duel',b.aq_per_duel),('duel_quality',b.duel_quality),
    ('recov_retention',b.recov_retention),('recov_prog_90',b.recov_prog_90),
    ('padj_tackle_90',  round((b.tackle_90     * b.padj_factor)::numeric,2)),
    ('padj_int_90',     round((b.int_90        * b.padj_factor)::numeric,2)),
    ('padj_def_90',     round((b.def_action_90 * b.padj_factor)::numeric,2)),
    ('padj_recov_90',   round((b.recov_90      * b.padj_factor)::numeric,2))
  ) as v(metric, value)
),
ranked as (
  select l.*, d.higher_is_better,
    percent_rank() over (partition by l.pool, l.metric order by l.value) as pr
  from long l
  join public.metric_defs d on d.key = l.metric
  where l.nineties >= 6 and l.value is not null
)
select player_id, pool, metric, value,
       round((100 * case when higher_is_better then pr else 1-pr end)::numeric,0) as pct
from ranked;

create index on mv_player_percentiles (player_id);
create index on mv_player_percentiles (pool, metric);
grant select on mv_player_percentiles, mv_player_team_poss to anon, authenticated;
notify pgrst, 'reload schema';
