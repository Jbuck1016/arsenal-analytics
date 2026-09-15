-- team_sequence_style could not answer a single-team read inside PostgREST's
-- timeout, and no index could fix it.
--
-- The view z-scores every team against every other:
--   round((raw - avg(raw) over (partition by metric))
--         / nullif(stddev_samp(raw) over (partition by metric), 0), 2)
-- so a team filter cannot push below the window. teams.html reads it with
-- {team: 'eq.' + team}, and each request computed all 2,898 rows (126 teams by
-- 23 metrics) from a full scan of sequences first:
--   Seq Scan on sequences  Buffers: shared read=26977
--   Sort Method: external merge  Disk: 7808kB
--   Execution Time: 28958 ms
--
-- The result is stored in mv_team_sequence_style, indexed on (team, metric),
-- and the view the site reads now selects from it. The view name, columns and
-- column order are unchanged, so no page changes.
--
-- Applied as a one-shot that refused unless the materialization was identical
-- to the view, in both directions, before the swap and again after it. Result:
-- 2,898 rows, identical before swap, identical after swap, 147.8 s.
-- security_invoker is stated explicitly on the replaced view, because a
-- create or replace without it resets the option, which is how two views lost
-- it earlier this brief.
--
-- Measured after, as anon through the live API:
--   team_sequence_style?team=eq.Arsenal   HTTP 200, 23 rows, 0.15 s  (was 28.96 s)
--   in the database: Bitmap Index Scan on mv_team_sequence_style_uq, 23.7 ms
--
-- It is refreshed in the teamstyle rebuild step, directly after
-- mv_team_breakdown, so it cannot freeze at the data of 15 September.

-- The materialization, recorded as the definition the one-shot read live from
-- team_sequence_style immediately before replacing it.
create materialized view if not exists public.mv_team_sequence_style as
 WITH u AS (
         SELECT a.team,
            m.metric,
            m.raw
           FROM team_sequence_agg a
             CROSS JOIN LATERAL ( VALUES ('seqs_per_match'::text,a.seqs_per_match), ('passes_seq'::text,a.passes_seq), ('seconds_seq'::text,a.seconds_seq), ('players_seq'::text,a.players_seq), ('xt_seq'::text,a.xt_seq), ('low_build_pct'::text,a.low_build_pct), ('high_build_pct'::text,a.high_build_pct), ('structured_pct'::text,a.structured_pct), ('very_short_pct'::text,a.very_short_pct), ('long_pct'::text,a.long_pct), ('switches_pct'::text,a.switches_pct), ('wide_tri_pct'::text,a.wide_tri_pct), ('hold_up_pct'::text,a.hold_up_pct), ('ends_opp_half_pct'::text,a.ends_opp_half_pct), ('ends_def_third_pct'::text,a.ends_def_third_pct), ('end_att_third_pct'::text,a.end_att_third_pct), ('end_in_box_pct'::text,a.end_in_box_pct), ('end_around_box_pct'::text,a.end_around_box_pct), ('finds_central_pct'::text,a.finds_central_pct), ('finds_wide_pct'::text,a.finds_wide_pct), ('ends_in_shot_pct'::text,a.ends_in_shot_pct), ('central_prog_share'::text,a.central_prog_share), ('wide_pass_pct'::text,a.wide_pass_pct)) m(metric, raw)
        )
 SELECT team,
    metric,
    raw,
    round((raw - avg(raw) OVER (PARTITION BY metric)) / NULLIF(stddev_samp(raw) OVER (PARTITION BY metric), 0::numeric), 2) AS z
   FROM u
with data;

create unique index if not exists mv_team_sequence_style_uq
  on public.mv_team_sequence_style (team, metric);
grant select on public.mv_team_sequence_style to anon, authenticated;

create or replace view public.team_sequence_style with (security_invoker = true) as
select team, metric, raw, z from public.mv_team_sequence_style;

notify pgrst, 'reload schema';

-- Refresh it in the teamstyle rebuild step. Rewritten from the live definition
-- of rebuild_step, and refused unless the anchor appears exactly once.
do $hook$
declare
  v_def text := pg_get_functiondef('public.rebuild_step(text, text)'::regprocedure);
  v_anchor constant text := 'refresh materialized view concurrently public.mv_team_breakdown;';
  v_new text;
  n_anchor int;
  n_added int;
begin
  select count(*) into n_anchor from regexp_matches(v_def, 'refresh materialized view concurrently public\.mv_team_breakdown;', 'g');
  if n_anchor <> 1 then
    raise exception 'rebuild_step hook refused: mv_team_breakdown refresh found % times, expected 1', n_anchor;
  end if;
  if position('mv_team_sequence_style' in v_def) > 0 then
    raise notice 'rebuild_step already refreshes mv_team_sequence_style';
    return;
  end if;
  v_new := replace(v_def, v_anchor,
    v_anchor || ' refresh materialized view concurrently public.mv_team_sequence_style;');
  select count(*) into n_added from regexp_matches(v_new, 'refresh materialized view concurrently public\.mv_team_sequence_style;', 'g');
  if n_added <> 1 then
    raise exception 'rebuild_step hook refused: % mv_team_sequence_style refreshes after rewrite', n_added;
  end if;
  execute v_new;
end $hook$;
