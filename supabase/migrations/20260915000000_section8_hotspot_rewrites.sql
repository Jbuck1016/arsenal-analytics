-- Section 8. mv_team_buildphase and mv_player_xt, output byte identical.
--
-- Measured before: mv_team_buildphase did not complete in a 115 second window,
-- mv_player_xt took 71 seconds.
--
-- mv_team_buildphase made three separate full passes over v_league_events, one
-- for goalkeeper passes, one for deep passes and touches, one for centre-back
-- progression, and used jsonb containment inside FILTER clauses, which cannot
-- use the GIN index. Collapsed to a single pass with LEFT JOINs to
-- mv_player_pool and mv_player_role.
--
-- Safety check done first, because this rewrite is only valid if those joins
-- cannot multiply rows: mv_player_pool is 2,243 rows over 2,243 distinct
-- player_ids, mv_player_role is 1,792 over 1,792. One row per player each, so a
-- LEFT JOIN adds no duplicates and the FILTER counts are unchanged.
--
-- The one subtlety worth stating: the original deep CTE carried
-- "WHERE e.team IS NOT NULL AND e.x IS NOT NULL", which the gk and cb CTEs did
-- not. That filter therefore applies to all_passes and all_touches as well, so
-- in the single pass every deep-derived FILTER carries "e.x IS NOT NULL"
-- explicitly. Dropping it would silently change two denominators.
--
-- mv_player_xt called the SQL function xt_at() four times per row, each one a
-- lookup against xt_grid. Replaced with two joins to the grid.
--
-- Safety check: xt_grid is a complete 12 by 8 grid, 96 rows, one row per
-- (x_bin, y_bin), no null values, and the bin arithmetic clamps into [0,11] and
-- [0,7]. Every input therefore maps to exactly one existing row, so the join is
-- exactly equivalent to the function rather than approximately, and inner versus
-- left join makes no difference.

-- ---------------------------------------------------------------------------
-- Proof harness. Snapshot, rebuild, diff both directions, revert on any
-- difference. Run apply_section8() rather than the DDL by hand.

create table if not exists public.section8_proof (
  checked_at   timestamptz not null default now(),
  matview      text not null,
  rows_before  bigint,
  rows_after   bigint,
  only_before  bigint,
  only_after   bigint,
  identical    boolean
);

create or replace function public.prove_matview_identical(p_matview text, p_snapshot text)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare n_before bigint; n_after bigint; only_b bigint; only_a bigint;
begin
  execute format('select count(*) from %I', p_snapshot) into n_before;
  execute format('select count(*) from %I', p_matview) into n_after;
  execute format('select count(*) from (select * from %I except select * from %I) z',
                 p_snapshot, p_matview) into only_b;
  execute format('select count(*) from (select * from %I except select * from %I) z',
                 p_matview, p_snapshot) into only_a;
  insert into public.section8_proof (matview, rows_before, rows_after, only_before, only_after, identical)
  values (p_matview, n_before, n_after, only_b, only_a, (only_b = 0 and only_a = 0 and n_before = n_after));
  return jsonb_build_object('matview',p_matview,'rows_before',n_before,'rows_after',n_after,
    'only_in_before',only_b,'only_in_after',only_a,
    'identical',(only_b = 0 and only_a = 0 and n_before = n_after));
end $fn$;
