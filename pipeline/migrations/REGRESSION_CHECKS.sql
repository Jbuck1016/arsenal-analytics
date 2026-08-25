-- =====================================================================
-- REGRESSION_CHECKS.sql
-- Executable security and scoping regression suite. Read-only.
-- Every check raises on failure. Run after any migration or rebuild.
--   psql "$DATABASE_URL" -f pipeline/migrations/REGRESSION_CHECKS.sql
-- =====================================================================
do $checks$
declare n int; bad text;
begin
  -- 1. No browser-role writes anywhere in the public schema.
  select count(*) into n
  from pg_class c join pg_namespace nn on nn.oid = c.relnamespace and nn.nspname = 'public'
  where c.relkind in ('r','m','v','p')
    and (has_table_privilege('anon', c.oid,'INSERT') or has_table_privilege('anon', c.oid,'UPDATE')
      or has_table_privilege('anon', c.oid,'DELETE') or has_table_privilege('anon', c.oid,'TRUNCATE')
      or has_table_privilege('authenticated', c.oid,'INSERT') or has_table_privilege('authenticated', c.oid,'UPDATE')
      or has_table_privilege('authenticated', c.oid,'DELETE'));
  if n <> 0 then raise exception 'CHECK 1 FAILED. % objects writable by browser roles.', n; end if;

  -- 2. Administrative RPCs are unreachable from browser roles.
  select string_agg(f, ', ') into bad from unnest(array[
    'public.refresh_site_summaries()','public.refresh_analytics()',
    'public.run_invariants()','public.verify_rebuild()',
    'public.suppress_low_sample_insights()']) f
  where has_function_privilege('anon', f, 'EXECUTE')
     or has_function_privilege('authenticated', f, 'EXECUTE')
     or has_function_privilege('public', f, 'EXECUTE');
  if bad is not null then raise exception 'CHECK 2 FAILED. Browser-reachable admin RPCs: %', bad; end if;

  -- 3. No ineligible insight team.
  select count(*) into n from insights i
   where i.team is not null
     and not exists (select 1 from v_team_sample ts
                     join leagues l on l.league = ts.league and l.competition_type = 'league'
                     where ts.team = i.team and ts.meets_min_matches);
  if n <> 0 then raise exception 'CHECK 3 FAILED. % insights belong to ineligible clubs.', n; end if;

  -- 4. No non-league competition inside the canonical scoped sources.
  if exists (select 1 from v_league_events e join leagues l on l.league = e.league
             where l.competition_type <> 'league')
  or exists (select 1 from v_league_matches m join leagues l on l.league = m.league
             where l.competition_type <> 'league')
  or exists (select 1 from v_league_sequences s join leagues l on l.league = s.league
             where l.competition_type <> 'league')
  or exists (select 1 from v_league_lineups li join leagues l on l.league = li.league
             where l.competition_type <> 'league') then
    raise exception 'CHECK 4 FAILED. A scoped source leaked a non-league competition.';
  end if;

  -- 5. Trust pages can still read what they need anonymously.
  select count(*) into n from unnest(array[
    'public.mv_site_summary','public.mv_invariant_status','public.v_xg_model_support',
    'public.mv_league_availability','public.insights']) t
  where not has_table_privilege('anon', t, 'SELECT');
  if n <> 0 then raise exception 'CHECK 5 FAILED. % trust-page objects lost anon SELECT.', n; end if;

  -- 6. Every registered competition is classified, and league scoping is real.
  if exists (select 1 from leagues where competition_type not in ('league','domestic_cup','continental')) then
    raise exception 'CHECK 6 FAILED. Unclassified competition in the registry.';
  end if;
  if (select count(*) from v_league_events) >= (select count(*) from events) then
    raise exception 'CHECK 6 FAILED. v_league_events excludes nothing.';
  end if;

  raise notice 'All regression checks passed.';
end
$checks$;

-- 7. Migration ordering: the Stage 2 prerequisite must sort before the
--    privilege lockdown, or a clean replay re-exposes SECURITY DEFINER
--    functions. Filename ordering is the guarantee; verified in CI by:
--      ls pipeline/migrations/*.sql | sort | head -2
--    must yield 20260824_00_stage2_db_objects.sql then
--    20260824_01_privilege_lockdown.sql.
