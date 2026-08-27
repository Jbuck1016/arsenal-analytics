create or replace function public.suppress_low_sample_insights()
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare n int; n_undeclared int; n_ineligible int;
begin
  delete from public.insights i
  using public.v_team_sample ts, public.detector_requirements r
  where ts.team = i.team and r.detector = i.detector and ts.matches < r.min_matches;
  get diagnostics n = row_count;

  delete from public.insights i
  where i.team is not null
    and not exists (select 1 from public.detector_requirements r where r.detector = i.detector);
  get diagnostics n_undeclared = row_count;

  -- Club must exist in the scoped evidence base AND clear the minimum
  -- declared for that specific detector. detector_requirements governs;
  -- no sample threshold is hardcoded here.
  delete from public.insights i
  where i.team is not null
    and not exists (
      select 1
      from public.v_team_sample ts
      join public.leagues l on l.league = ts.league and l.competition_type = 'league'
      join public.detector_requirements r on r.detector = i.detector
      where ts.team = i.team
        and ts.matches >= r.min_matches);
  get diagnostics n_ineligible = row_count;

  return format('%s suppressed below declared minimum, %s removed for having no declared requirement, %s removed as ineligible clubs',
                n, n_undeclared, n_ineligible);
end $function$;

revoke all on function public.suppress_low_sample_insights() from public, anon, authenticated;
grant execute on function public.suppress_low_sample_insights() to service_role;

select 'applied' as status;
