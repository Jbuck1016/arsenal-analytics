-- =====================================================================
-- REGRESSION_CHECKS.sql
-- Executable security and scoping regression suite. Read-only.
-- Every check raises on failure. Run after any migration or rebuild.
--   psql "$DATABASE_URL" -f pipeline/migrations/REGRESSION_CHECKS.sql
-- =====================================================================
do $checks$
declare n int; bad text;
begin
  -- 1. No browser-role write privilege of any kind, anywhere in public.
  --    Covers INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER
  --    for both anon and authenticated. Narrower checks let privilege
  --    drift on the rarer grants pass unnoticed.
  select count(*) into n
  from pg_class c
  join pg_namespace nn on nn.oid = c.relnamespace and nn.nspname = 'public'
  cross join unnest(array['anon','authenticated']) as role_name
  cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) as priv
  where c.relkind in ('r','m','v','p')
    and has_table_privilege(role_name, c.oid, priv);
  if n <> 0 then
    raise exception 'CHECK 1 FAILED. % role/privilege/object combinations writable by browser roles.', n;
  end if;

  -- 2. Administrative RPCs are unreachable from browser roles.
  select string_agg(f, ', ') into bad from unnest(array[
    'public.refresh_site_summaries()','public.refresh_analytics()',
    'public.run_invariants()','public.verify_rebuild()',
    'public.suppress_low_sample_insights()',
    'public.rebuild_step(text,text)']) f
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

  -- 5b. Public views must enforce caller rights rather than their owner's.
  select count(*) into n
  from pg_class c join pg_namespace nn on nn.oid=c.relnamespace and nn.nspname='public'
  where c.relkind='v'
    and not coalesce('security_invoker=true'=any(c.reloptions),false);
  if n <> 0 then raise exception 'CHECK 5b FAILED. % public views lack security_invoker.', n; end if;

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

-- =====================================================================
-- CHECK 7 is a REPOSITORY PREREQUISITE, not a SQL check.
--
-- SQL cannot see filenames, so migration ordering cannot be asserted from
-- inside the database. It matters because CREATE OR REPLACE FUNCTION
-- grants EXECUTE to PUBLIC: if the Stage 2 prerequisite ever sorted after
-- the privilege lockdown, a clean replay would re-expose
-- refresh_site_summaries() to PUBLIC.
--
-- Run this before applying the chain. Exits non-zero on failure:
--
--   python3 pipeline/migrations/check_migration_order.py
--
-- Or as a one-liner:
--
--   ls pipeline/migrations/20260824_*.sql | sort | head -1 \
--     | grep -q '00_stage2_db_objects' || echo 'MIGRATION ORDER BROKEN'
-- =====================================================================
