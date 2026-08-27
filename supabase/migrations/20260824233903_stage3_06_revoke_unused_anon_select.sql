-- Revoke anon SELECT only where the table is internal and has no
-- anon-readable consumer. Conservative by design: tables that might be
-- read directly over REST by the dashboard keep SELECT until the
-- frontend can be inspected.
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

select count(*)::text as anon_readable_base_tables
from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
where c.relkind='r' and has_table_privilege('anon', c.oid,'SELECT');
