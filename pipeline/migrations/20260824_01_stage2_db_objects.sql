-- =====================================================================
-- 20260824_01_stage2_db_objects.sql
-- Project: xrsilhiffjoulyoqhdmp
-- Status:  ALREADY APPLIED to the live database. Captured here so the
--          schema can be reconstructed from source control.
--
-- These objects were created during the Stage 2 trust-surface work and
-- were never committed. They are prerequisites for the Methodology and
-- Validation pages, which read them directly.
--
-- Idempotent: safe to run against a database that already has them.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Shot-model support diagnostics, read live by both trust pages.
-- ---------------------------------------------------------------------
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
grant all on v_xg_model_support to anon, authenticated, service_role;

comment on view v_xg_model_support is
  'Support behind the binned shot model: training volume, bin count, assigned-value range and sparse-bin count. Replaces a predicted-versus-actual band table, which measured only whether the lookup reproduces its own training data.';

-- ---------------------------------------------------------------------
-- 2. Invariant results, materialised.
--    run_invariants() takes roughly 16 seconds, far beyond the anon
--    statement timeout, so the trust pages cannot call it directly.
-- ---------------------------------------------------------------------
create materialized view if not exists mv_invariant_status as
select name, severity, violations, description, now() as refreshed_at
from run_invariants();

create unique index if not exists mv_invariant_status_name_idx
  on mv_invariant_status (name);

alter materialized view mv_invariant_status owner to postgres;
grant all on mv_invariant_status to anon, authenticated, service_role;

comment on materialized view mv_invariant_status is
  'Materialised output of run_invariants(). Refreshed by refresh_site_summaries() as part of the normal rebuild. Read by the Methodology page so check results are reported rather than asserted.';

-- ---------------------------------------------------------------------
-- 3. Refresh path updated to include the invariant snapshot.
--    Ordered before mv_site_summary so the site check counts and the
--    check results come from the same moment.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 4. Sparse-bin diagnostic.
--    Reported as a count, not a pass or fail: no defensible sparse-bin
--    ceiling has been established, so this is warn level by design.
-- ---------------------------------------------------------------------
insert into invariants (name, description, check_sql, severity, enabled)
values (
  'xg_bins_sparse',
  'Shot-model lookup bins holding fewer than 20 shots. Rates in these bins are noise rather than signal, so any xG assigned from them is weakly supported. Reported as a count, not a pass or fail, because no defensible sparse-bin ceiling has been established.',
  'select count(*) from mv_xg_bins where n < 20',
  'warn',
  true
)
on conflict (name) do update
  set description = excluded.description,
      check_sql   = excluded.check_sql,
      severity    = excluded.severity,
      enabled     = excluded.enabled;

-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------
select 'v_xg_model_support' as object, count(*)::text as rows from v_xg_model_support
union all
select 'mv_invariant_status', count(*)::text from mv_invariant_status
union all
select 'xg_bins_sparse registered',
       (select count(*)::text from invariants where name = 'xg_bins_sparse');
