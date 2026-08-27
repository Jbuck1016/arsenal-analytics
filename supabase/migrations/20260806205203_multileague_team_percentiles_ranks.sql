
-- Team percentiles and league ranks scoped within league. "3rd of 30" must mean
-- 3rd in that league, not 3rd across every league on the platform.
drop materialized view if exists public.mv_team_percentiles cascade;
create materialized view public.mv_team_percentiles as
 WITH long AS (
    SELECT t.team, COALESCE(tl.league,'USA-MLS') AS league, v.metric, v.value
      FROM mv_team_all t
        LEFT JOIN mv_team_league tl ON tl.team = t.team
        CROSS JOIN LATERAL ( VALUES
          ('possession_pct'::text,t.possession_pct), ('field_tilt'::text,t.field_tilt),
          ('avg_touch_x'::text,t.avg_touch_x), ('directness'::text,t.directness),
          ('long_ball_pct'::text,t.long_ball_pct), ('build_from_back_pct'::text,t.build_from_back_pct),
          ('ppda'::text,t.ppda), ('def_height'::text,t.def_height),
          ('prog_passes_pg'::text,t.prog_passes_pg), ('box_entries_pg'::text,t.box_entries_pg),
          ('crosses_pg'::text,t.crosses_pg), ('shots_pg'::text,t.shots_pg),
          ('goals_pg'::text,t.goals_pg), ('open_play_shot_pct'::text,t.open_play_shot_pct),
          ('shots_against_pg'::text,t.shots_against_pg), ('goals_against_pg'::text,t.goals_against_pg),
          ('passes_per_seq'::text,t.passes_per_seq), ('secs_per_seq'::text,t.secs_per_seq),
          ('long_sequence_pct'::text,t.long_sequence_pct), ('pct_ending_in_shot'::text,t.pct_ending_in_shot),
          ('ground_gained'::text,t.ground_gained), ('sequences_pg'::text,t.sequences_pg),
          ('gk_long_pct'::text,t.gk_long_pct), ('d3_pass_share'::text,t.d3_pass_share),
          ('d3_accuracy'::text,t.d3_accuracy), ('d3_long_pct'::text,t.d3_long_pct),
          ('deep_circulation_pg'::text,t.deep_circulation_pg), ('cb_prog_pg'::text,t.cb_prog_pg),
          ('escape_pct'::text,t.escape_pct), ('deep_to_final_pct'::text,t.deep_to_final_pct),
          ('d3_touch_share'::text,t.d3_touch_share), ('att_directness'::text,t.att_directness),
          ('mid_release'::text,t.mid_release), ('ft_release'::text,t.ft_release),
          ('passes_per_shot'::text,t.passes_per_shot), ('ft_entries_pg'::text,t.ft_entries_pg),
          ('box_per_entry'::text,t.box_per_entry), ('final_to_shot_pct'::text,t.final_to_shot_pct),
          ('pct_left'::text,t.pct_left), ('pct_centre'::text,t.pct_centre),
          ('pct_right'::text,t.pct_right)) v(metric, value)
 ), r AS (
    SELECT l.team, l.league, l.metric, l.value, d.higher_is_better,
       percent_rank() OVER (PARTITION BY l.league, l.metric ORDER BY l.value) AS pr
      FROM long l JOIN team_metric_defs d ON d.key = l.metric
     WHERE l.value IS NOT NULL
 )
 SELECT team, metric, value,
    round((100::double precision * CASE WHEN higher_is_better THEN pr
           ELSE 1::double precision - pr END)::numeric, 0) AS pct,
    league
   FROM r;
create index mv_team_percentiles_tm on public.mv_team_percentiles (team, metric);
grant select on public.mv_team_percentiles to anon, authenticated;

drop materialized view if exists public.mv_team_stat_ranks cascade;
create materialized view public.mv_team_stat_ranks as
 WITH per AS (
    SELECT s.team, count(*) AS matches,
       avg(s.final_third_passes) AS final_third_passes,
       avg(s.zone14_passes) AS zone14_passes,
       avg(s.progressive_passes) AS progressive_passes,
       avg(s.passes_into_box) AS passes_into_box,
       avg(s.defensive_actions) AS defensive_actions,
       avg(s.defensive_actions_won) AS defensive_actions_won,
       avg(s.shots) AS shots, avg(s.shots_on_target) AS shots_on_target,
       avg(s.fwd_passes) AS fwd_passes, avg(s.lat_passes) AS lat_passes,
       avg(s.bwd_passes) AS bwd_passes
      FROM v_season_stats s GROUP BY s.team
 ), long AS (
    SELECT per.team, COALESCE(tl.league,'USA-MLS') AS league, v.metric, v.value
      FROM per
        LEFT JOIN mv_team_league tl ON tl.team = per.team
        CROSS JOIN LATERAL ( VALUES
          ('final_third_passes'::text,per.final_third_passes), ('zone14_passes'::text,per.zone14_passes),
          ('progressive_passes'::text,per.progressive_passes), ('passes_into_box'::text,per.passes_into_box),
          ('defensive_actions'::text,per.defensive_actions),
          ('defensive_actions_won'::text,per.defensive_actions_won),
          ('shots'::text,per.shots), ('shots_on_target'::text,per.shots_on_target),
          ('fwd_passes'::text,per.fwd_passes), ('lat_passes'::text,per.lat_passes),
          ('bwd_passes'::text,per.bwd_passes)) v(metric, value)
 )
 SELECT team, metric, round(value, 2) AS per_game,
    rank() OVER (PARTITION BY league, metric ORDER BY value DESC) AS league_rank,
    count(*) OVER (PARTITION BY league, metric) AS of_teams,
    league
   FROM long;
create index mv_team_stat_ranks_tm on public.mv_team_stat_ranks (team, metric);
grant select on public.mv_team_stat_ranks to anon, authenticated;
