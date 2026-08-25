-- =====================================================================
-- 20260824_06_revoke_unused_anon_select.sql
-- Stage 3, migration 06. APPLIED 2026-08-24. Requires 01.
--
-- Revokes anon SELECT only where a table is internal AND has no
-- anon-readable consumer. Deliberately conservative: matviews store
-- their own rows and views execute with the view owner's privileges,
-- so anonymous reads of the dashboard do not require base-table SELECT.
-- Tables that might be queried directly over REST keep SELECT until the
-- frontend can be inspected.
-- =====================================================================
begin;

revoke select on public._ml_baseline              from anon, authenticated;
revoke select on public._replay_log               from anon, authenticated;
revoke select on public.league_mart_entry_objects from anon, authenticated;

do $assert$
begin
  if has_table_privilege('anon','public._ml_baseline','SELECT')
  or has_table_privilege('anon','public._replay_log','SELECT')
  or has_table_privilege('anon','public.league_mart_entry_objects','SELECT') then
    raise exception 'ASSERT FAILED. Internal table still anon readable.';
  end if;
  if not has_table_privilege('anon','public.insights','SELECT') then
    raise exception 'ASSERT FAILED. insights lost anon SELECT.';
  end if;
end
$assert$;

commit;
