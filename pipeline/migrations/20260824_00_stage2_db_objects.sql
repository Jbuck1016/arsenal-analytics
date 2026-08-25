-- =====================================================================
-- 20260824_00_stage2_db_objects.sql
-- Stage 2 database objects. APPLIED. Runs FIRST in the chain.
--
-- ORDERING MATTERS. This must run BEFORE the privilege lockdown, not
-- after it. CREATE OR REPLACE FUNCTION grants EXECUTE to PUBLIC by
-- default, so if this ran after migration 01 it would silently restore
-- public execution on refresh_site_summaries(), a SECURITY DEFINER
-- function. Every function created here revokes PUBLIC execute
-- immediately, so a clean sequential replay ends with the same
-- restricted ACLs as live regardless of ordering.
--
-- Browser grants here are SELECT only. Never GRANT ALL.
-- =====================================================================
begin;

create or replace view v_xg_model_support as
select
  (select sum(n) from mv_xg_bins)::int                                as training_shots,
  (select count(*) from mv_xg_bins)::int                              as lookup_bins,
  (select count(distinct xg) from mv_shot_xg
     where not is_pen and xg is not null)::int                        as distinct_values,
  (select min(xg) from mv_shot_xg where not is_pen and xg is not null) as xg_min,
  (select max(xg) from mv_shot_xg where not is_pen and xg is not null) as xg_max,
  20::int                                                             as sparse_threshold,
  (select count(*) from mv_xg_bins where n < 20)::int                 as sparse_bins,
  (select round(100.0 * sum(n) filter (where n < 20) / nullif(sum(n), 0), 2)
     from mv_xg_bins)::numeric                                        as sparse_shot_share_pct,
  false                                                               as holdout_run,
  false                                                               as out_of_sample_tested;

alter view v_xg_model_support owner to postgres;
revoke all on v_xg_model_support from public, anon, authenticated;
grant select on v_xg_model_support to anon, authenticated;
grant all on v_xg_model_support to service_role;

comment on view v_xg_model_support is
  'Support behind the binned shot model. Replaces a predicted-versus-actual band table, which measured only whether the lookup reproduces its own training data.';

create materialized view if not exists mv_invariant_status as
select name, severity, violations, description, now() as refreshed_at
from run_invariants();

create unique index if not exists mv_invariant_status_name_idx on mv_invariant_status (name);

alter materialized view mv_invariant_status owner to postgres;
revoke all on mv_invariant_status from public, anon, authenticated;
grant select on mv_invariant_status to anon, authenticated;
grant all on mv_invariant_status to service_role;

comment on materialized view mv_invariant_status is
  'Materialised output of run_invariants(). run_invariants() takes roughly 16 seconds, far beyond the anon statement timeout, so the trust pages cannot call it directly.';

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

-- CREATE OR REPLACE FUNCTION grants EXECUTE to PUBLIC. Close it here so
-- this migration can never re-expose a SECURITY DEFINER function.
revoke all on function public.refresh_site_summaries() from public, anon, authenticated;
grant execute on function public.refresh_site_summaries() to service_role;

insert into invariants (name, description, check_sql, severity, enabled)
values (
  'xg_bins_sparse',
  'Shot-model lookup bins holding fewer than 20 shots. Reported as a count, not a pass or fail, because no defensible sparse-bin ceiling has been established.',
  'select count(*) from mv_xg_bins where n < 20',
  'warn', true
)
on conflict (name) do update
  set description = excluded.description, check_sql = excluded.check_sql,
      severity = excluded.severity, enabled = excluded.enabled;

do $assert$
begin
  if (select count(*) from v_xg_model_support) <> 1 then
    raise exception 'ASSERT FAILED. v_xg_model_support did not return one row.';
  end if;
  if not exists (select 1 from invariants where name = 'xg_bins_sparse') then
    raise exception 'ASSERT FAILED. xg_bins_sparse not registered.';
  end if;
  if has_function_privilege('public','public.refresh_site_summaries()','EXECUTE')
  or has_function_privilege('anon','public.refresh_site_summaries()','EXECUTE') then
    raise exception 'ASSERT FAILED. refresh_site_summaries() is publicly executable.';
  end if;
  if has_table_privilege('anon','public.v_xg_model_support','INSERT') then
    raise exception 'ASSERT FAILED. v_xg_model_support granted more than SELECT to anon.';
  end if;
end
$assert$;

commit;
