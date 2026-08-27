
-- Percentile chain made league-aware. Only change: a league join and the partition key.
-- Pillars and metric examples are recreated in the same transaction so nothing dangles.
drop materialized view if exists public.mv_player_percentiles cascade;

create materialized view public.mv_player_percentiles as
 WITH base AS (
    SELECT m.*, p.team_possession,
       50.0 / NULLIF(100::numeric - p.team_possession, 0::numeric) AS padj
      FROM v_player_metrics_ext m
        LEFT JOIN mv_player_team_poss p USING (player_id)
 ), long AS (
    SELECT b.player_id, r.pool, b.nineties,
       COALESCE(pl.league, 'USA-MLS'::text) AS league,
       v.metric, v.value
      FROM base b
        JOIN mv_player_role r USING (player_id)
        LEFT JOIN mv_player_league pl ON pl.player_id = b.player_id
        CROSS JOIN LATERAL ( VALUES
          ('pass_cmp_90'::text,b.pass_cmp_90), ('pass_pct'::text,b.pass_pct),
          ('prog_cmp_90'::text,b.prog_cmp_90), ('prog_pct'::text,b.prog_pct),
          ('territory_90'::text,b.territory_90), ('into_box_90'::text,b.into_box_90),
          ('final_third_90'::text,b.final_third_90), ('through_90'::text,b.through_90),
          ('cross_90'::text,b.cross_90), ('cross_pct'::text,b.cross_pct),
          ('key_pass_90'::text,b.key_pass_90), ('assist_90'::text,b.assist_90),
          ('bcc_90'::text,b.bcc_90), ('xa_90'::text,b.xa_90), ('xt_90'::text,b.xt_90),
          ('xt_pass_90'::text,b.xt_pass_90), ('xt_carry_90'::text,b.xt_carry_90),
          ('sca_90'::text,b.sca_90), ('long_90'::text,b.long_90), ('long_pct'::text,b.long_pct),
          ('shots_90'::text,b.shots_90), ('sot_90'::text,b.sot_90), ('goals_90'::text,b.goals_90),
          ('blocked_90'::text,b.blocked_90), ('xg_90'::text,b.xg_90),
          ('xg_per_shot'::text,b.xg_per_shot), ('finishing'::text,b.finishing),
          ('box_share'::text,b.box_share), ('shot_dist'::text,b.shot_dist),
          ('conversion'::text,b.conversion), ('shot_acc'::text,b.shot_acc),
          ('bigchance_90'::text,b.bigchance_90), ('weak_foot_share'::text,b.weak_foot_share),
          ('tackle_90'::text,b.tackle_90), ('tackle_pct'::text,b.tackle_pct),
          ('int_90'::text,b.int_90), ('clear_90'::text,b.clear_90), ('block_90'::text,b.block_90),
          ('recov_90'::text,b.recov_90), ('aerial_90'::text,b.aerial_90),
          ('aerial_pct'::text,b.aerial_pct), ('def_action_90'::text,b.def_action_90),
          ('def_height'::text,b.def_height), ('box_def_90'::text,b.box_def_90),
          ('channel_def_90'::text,b.channel_def_90), ('flank_def_90'::text,b.flank_def_90),
          ('counterpress_90'::text,b.counterpress_90), ('takeon_90'::text,b.takeon_90),
          ('takeon_pct'::text,b.takeon_pct), ('disp_90'::text,b.disp_90),
          ('badtouch_90'::text,b.badtouch_90), ('foul_com_90'::text,b.foul_com_90),
          ('foul_won_90'::text,b.foul_won_90), ('error_90'::text,b.error_90),
          ('carries_90'::text,b.carries_90), ('prog_carries_90'::text,b.prog_carries_90),
          ('carry_box_90'::text,b.carry_box_90), ('mean_carry_m'::text,b.mean_carry_m),
          ('carry_pen_90'::text,b.carry_pen_90), ('median_ttr'::text,b.median_ttr),
          ('quick_pct'::text,b.quick_pct), ('one_touch_pct'::text,b.one_touch_pct),
          ('aq_per_duel'::text,b.aq_per_duel), ('duel_quality'::text,b.duel_quality),
          ('recov_retention'::text,b.recov_retention), ('recov_prog_90'::text,b.recov_prog_90),
          ('save_pct'::text,b.save_pct), ('goals_prevented_90'::text,b.goals_prevented_90),
          ('saves_90'::text,b.saves_90), ('claims_90'::text,b.claims_90),
          ('sweeps_90'::text,b.sweeps_90), ('sweep_x'::text,b.sweep_x),
          ('hs_passes_90'::text,b.hs_passes_90), ('hs_prog_90'::text,b.hs_prog_90),
          ('hs_key_90'::text,b.hs_key_90), ('hs_shots_90'::text,b.hs_shots_90),
          ('hs_takeons_90'::text,b.hs_takeons_90), ('holds_90'::text,b.holds_90),
          ('hold_retention'::text,b.hold_retention), ('hold_prog_pct'::text,b.hold_prog_pct),
          ('hold_shot_pct'::text,b.hold_shot_pct), ('sp_xg_90'::text,b.sp_xg_90),
          ('sp_shots_90'::text,b.sp_shots_90), ('sp_aerials_90'::text,b.sp_aerials_90),
          ('sp_key_90'::text,b.sp_key_90),
          ('padj_tackle_90'::text,round(b.tackle_90 * b.padj, 2)),
          ('padj_int_90'::text,round(b.int_90 * b.padj, 2)),
          ('padj_def_90'::text,round(b.def_action_90 * b.padj, 2)),
          ('padj_recov_90'::text,round(b.recov_90 * b.padj, 2))
        ) v(metric, value)
 ), ranked AS (
    SELECT l.player_id, l.pool, l.nineties, l.league, l.metric, l.value, d.higher_is_better,
       percent_rank() OVER (PARTITION BY l.league, l.pool, l.metric ORDER BY l.value) AS pr
      FROM long l JOIN metric_defs d ON d.key = l.metric
     WHERE l.nineties >= 6::numeric AND l.value IS NOT NULL
 )
 SELECT player_id, pool, metric, value,
    round((100::double precision * CASE WHEN higher_is_better THEN pr
           ELSE 1::double precision - pr END)::numeric, 0) AS pct,
    league
   FROM ranked;
create index mv_player_percentiles_pm on public.mv_player_percentiles (player_id, metric);
create index mv_player_percentiles_metric on public.mv_player_percentiles (metric);
grant select on public.mv_player_percentiles to anon, authenticated;

create materialized view public.mv_player_pillars as
 SELECT p.player_id, p.pool, d.pillar, min(d.ord) AS ord,
    round(sum(p.pct * d.weight) / NULLIF(sum(d.weight), 0::numeric), 1) AS score,
    count(*) AS markers_used, p.league
   FROM mv_player_percentiles p
     JOIN pillar_defs d ON d.metric = p.metric
  WHERE p.pool <> 'GK'::text
  GROUP BY p.player_id, p.pool, d.pillar, p.league;
create index mv_player_pillars_p on public.mv_player_pillars (player_id);
grant select on public.mv_player_pillars to anon, authenticated;

-- league min/median/max and the high/low exemplar must be WITHIN league
create materialized view public.mv_metric_examples as
 WITH q AS (
    SELECT p.metric, p.pool, p.player_id, p.value, p.pct, p.league,
       s.player_name, s.team, s.nineties
      FROM mv_player_percentiles p
        JOIN mv_player_season s USING (player_id)
     WHERE s.nineties >= 8::numeric
 ), stat AS (
    SELECT q.metric, q.league, count(*) AS n,
       round(min(q.value), 3) AS min_v,
       round(percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (q.value::double precision))::numeric, 3) AS med_v,
       round(max(q.value), 3) AS max_v
      FROM q GROUP BY q.metric, q.league
 ), hi AS (
    SELECT DISTINCT ON (q.metric, q.league) q.metric, q.league, q.player_id,
       q.player_name, q.team, q.pool, q.value, q.nineties
      FROM q ORDER BY q.metric, q.league, q.value DESC
 ), lo AS (
    SELECT DISTINCT ON (q.metric, q.league) q.metric, q.league, q.player_id,
       q.player_name, q.team, q.pool, q.value, q.nineties
      FROM q ORDER BY q.metric, q.league, q.value
 )
 SELECT st.metric, st.n, st.min_v, st.med_v, st.max_v,
    hi.player_name AS hi_name, hi.team AS hi_team, hi.pool AS hi_pool,
    round(hi.value, 3) AS hi_value, hi.player_id AS hi_id,
    lo.player_name AS lo_name, lo.team AS lo_team, lo.pool AS lo_pool,
    round(lo.value, 3) AS lo_value, lo.player_id AS lo_id,
    st.league
   FROM stat st
     LEFT JOIN hi ON hi.metric = st.metric AND hi.league = st.league
     LEFT JOIN lo ON lo.metric = st.metric AND lo.league = st.league;
create index mv_metric_examples_metric_idx on public.mv_metric_examples (metric);
grant select on public.mv_metric_examples to anon, authenticated;
