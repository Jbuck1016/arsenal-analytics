create materialized view if not exists mv_invariant_status as
select name, severity, violations, description, now() as refreshed_at
from run_invariants();

create unique index if not exists mv_invariant_status_name_idx on mv_invariant_status (name);

grant select on mv_invariant_status to anon, authenticated, service_role;

create or replace function public.refresh_site_summaries()
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  refresh materialized view public.mv_league_summary;
  refresh materialized view public.mv_league_availability;
  refresh materialized view public.mv_invariant_status;
  refresh materialized view public.mv_site_summary;
  return 'site summaries refreshed';
end $function$;

select name, severity, violations from mv_invariant_status
where severity = 'error' and violations > 0 order by name;
