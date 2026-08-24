-- =====================================================================
-- 20260824_01_privilege_lockdown.sql
-- Stage 3, migration 01. APPLIED 2026-08-24.
-- Replayable from a clean schema. Explicitly transactional when run by
-- hand; Supabase wraps each migration in a transaction already.
--
-- WHY THIS EXISTS
--   Browser roles held INSERT, UPDATE and DELETE on 122 objects in the
--   public schema. Seventeen base tables, including sequences, insights,
--   invariants, team_names and player_chain_roles, had RLS disabled and
--   granted anon write access. The anon key ships in frontend JavaScript,
--   so any visitor could have issued "delete from sequences".
--   anon could also execute refresh_analytics(), triggering a full
--   analytics rebuild on demand.
--
--   SECURITY DEFINER functions execute as owner, so the LAFC tracker
--   (lafc_* functions, which have their own auth via lafc_tracker_auth)
--   is unaffected by removing browser table privileges. Those functions
--   are deliberately left executable and are NOT part of this change.
-- =====================================================================
begin;

-- 1. Browser roles lose every write privilege. SELECT is regranted, so
--    reads are unchanged and no page can break.
do $lockdown$
declare r record;
begin
  for r in
    select c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
    where c.relkind in ('r','m','v','p')
  loop
    execute format('revoke all on public.%I from public, anon, authenticated', r.relname);
    execute format('grant select on public.%I to anon, authenticated', r.relname);
    execute format('grant all on public.%I to service_role', r.relname);
  end loop;
end
$lockdown$;

-- 2. Refresh and verification entry points are administrative.
revoke all on function public.refresh_site_summaries() from public, anon, authenticated;
grant execute on function public.refresh_site_summaries() to service_role;
revoke all on function public.refresh_analytics() from public, anon, authenticated;
grant execute on function public.refresh_analytics() to service_role;
revoke all on function public.run_invariants() from public, anon, authenticated;
grant execute on function public.run_invariants() to service_role;
revoke all on function public.verify_rebuild() from public, anon, authenticated;
grant execute on function public.verify_rebuild() to service_role;

-- 3. Raising assertions, not printed results.
do $assert$
declare n int;
begin
  select count(*) into n
  from pg_class c join pg_namespace nn on nn.oid = c.relnamespace and nn.nspname = 'public'
  where c.relkind in ('r','m','v','p')
    and (has_table_privilege('anon', c.oid, 'INSERT')
      or has_table_privilege('anon', c.oid, 'UPDATE')
      or has_table_privilege('anon', c.oid, 'DELETE')
      or has_table_privilege('authenticated', c.oid, 'INSERT')
      or has_table_privilege('authenticated', c.oid, 'UPDATE')
      or has_table_privilege('authenticated', c.oid, 'DELETE'));
  if n <> 0 then raise exception 'ASSERT FAILED. % objects still writable by browser roles.', n; end if;

  select count(*) into n
  from pg_class c join pg_namespace nn on nn.oid = c.relnamespace and nn.nspname = 'public'
  where c.relname in ('mv_site_summary','mv_invariant_status','v_xg_model_support',
                      'mv_league_availability','player_search','insights')
    and not has_table_privilege('anon', c.oid, 'SELECT');
  if n <> 0 then raise exception 'ASSERT FAILED. % trust-page objects lost anon SELECT.', n; end if;

  if has_function_privilege('anon','public.refresh_site_summaries()','EXECUTE')
  or has_function_privilege('anon','public.refresh_analytics()','EXECUTE') then
    raise exception 'ASSERT FAILED. anon can still call a refresh function.';
  end if;
  if not has_function_privilege('service_role','public.refresh_site_summaries()','EXECUTE') then
    raise exception 'ASSERT FAILED. service_role lost refresh_site_summaries execute.';
  end if;
end
$assert$;

commit;

-- KNOWN REMAINING EXPOSURE, NOT ADDRESSED HERE
--   Seventeen base tables still have RLS disabled. Privileges now block
--   browser writes, so the immediate risk is closed, but enabling RLS
--   with explicit read policies is the belt-and-braces fix and belongs
--   in its own change.
