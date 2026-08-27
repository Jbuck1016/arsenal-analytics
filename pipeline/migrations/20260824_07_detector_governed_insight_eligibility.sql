-- =====================================================================
-- 20260824_07_detector_governed_insight_eligibility.sql
-- APPLIED LIVE 2026-08-24. Requires 00 to 06.
--
-- Supersedes the eligibility body shipped in migration 05 and brings the
-- live function into line with source control. Migration 05 remains in
-- the Stage 2/3 delta chain; this file is the final state.
--
-- Eligibility is governed by detector_requirements. No sample threshold
-- is hardcoded. Proven live: the function definition contains
-- "ts.matches >= r.min_matches" and no longer references
-- meets_min_matches.
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

do $assert$
begin
  if (select pg_get_functiondef(p.oid) from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='suppress_low_sample_insights')
     not like '%ts.matches >= r.min_matches%' then
    raise exception 'ASSERT FAILED. Eligibility is not detector governed.';
  end if;
  if has_function_privilege('anon','public.suppress_low_sample_insights()','EXECUTE') then
    raise exception 'ASSERT FAILED. anon can execute the suppression function.';
  end if;
end
$assert$;

commit;
