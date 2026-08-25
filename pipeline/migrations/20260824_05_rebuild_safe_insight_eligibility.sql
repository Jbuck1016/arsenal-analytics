-- =====================================================================
-- 20260824_05_rebuild_safe_insight_eligibility.sql
-- Stage 3, migration 05. APPLIED 2026-08-24. Requires 01 to 04.
--
-- THE DEFECT
--   suppress_low_sample_insights() deleted USING v_team_sample, an inner
--   join. A club absent from the evidence base entirely matched nothing
--   and survived. After cup scoping removed cup-only clubs from
--   v_team_sample, that is exactly how Mansfield, Port Vale, Bayern and
--   nine other cup-only clubs kept insights through a full rebuild.
--
--   A one-off DELETE would have been undone by the next scheduled scrape.
--   The eligibility rule therefore lives in the production polishing path.
--
-- REVISION 2026-08-24, NOT YET APPLIED LIVE.
--   The eligibility delete originally tested ts.meets_min_matches, which
--   hardcodes the six-match rule and bypasses detector_requirements. It
--   now joins the insight's own detector requirement and compares
--   ts.matches >= r.min_matches, so detector_requirements governs
--   eligibility for every detector, as it does everywhere else.
--   The live database still carries the previous body. Apply this file
--   to bring live into line with source control.
-- =====================================================================
begin;

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

commit;
