-- Cron one-shots must be safe to launch again after they have finished.
--
-- What happened. Section 8 applied successfully at 02:13 UTC and
-- run_section8_apply unscheduled job 12 in the same transaction. pg_cron kept
-- launching job 12 regardless, for about ninety minutes, even though its row in
-- cron.job no longer existed (cron.alter_job(12) later reported "Job 12 does not
-- exist"). Every extra launch re-executed the whole apply: a fresh refresh and a
-- drop-and-recreate of both matview trees, holding ACCESS EXCLUSIVE on the
-- player and team matviews for most of each ten minute cycle, which blocked
-- PostgREST schema introspection and returned 503s to the site. Each launch then
-- failed at cron.unschedule('section8-apply'), "could not find valid entry",
-- inside the guard's own exception handler, so the failure escaped the guard and
-- rolled the repeated work back. The same self-unschedule worked for jobs 10 and
-- 11, which ran for about four minutes; job 12 ran for about ten.
--
-- Why pg_cron launched a deleted job is not provable from inside the database,
-- and the fix does not depend on it. The damage came from two properties of the
-- runner, both fixed for every one-shot:
--
--   1. Completion is recorded durably in one_shot_runs, in the same transaction
--      as the work, and checked first. A launch after completion returns
--      immediately and does nothing.
--   2. Retiring the job goes through retire_cron_job, which swallows its own
--      error. An unschedule that fails can no longer roll back finished work.

-- The section 8 runner is retired outright: its work is done and the job that
-- called it could not be unscheduled.
create or replace function public.run_section8_apply_guarded()
returns jsonb
language sql security definer set search_path to 'public','pg_temp'
as $fn$ select jsonb_build_object('status','retired','note','section 8 applied 2026-09-15 02:13 UTC') $fn$;
revoke execute on function public.run_section8_apply_guarded() from public, anon, authenticated;

create table if not exists public.one_shot_runs (
  name        text primary key,
  started_at  timestamptz,
  finished_at timestamptz,
  result      jsonb
);
alter table public.one_shot_runs enable row level security;
revoke all on public.one_shot_runs from anon, authenticated;

create or replace function public.retire_cron_job(p_name text)
returns boolean
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
as $fn$
begin
  begin
    perform cron.unschedule(p_name);
    return true;
  exception when others then
    -- Already gone, or the scheduler disagrees. Either way the caller's work
    -- must survive, which it cannot if this raises.
    return false;
  end;
end $fn$;
revoke execute on function public.retire_cron_job(text) from public, anon, authenticated;

create or replace function public.time_invariant_suite()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  k      constant text := 'invariant-timing:post-swap';
  v_run  timestamptz := now();
  r      record;
  v_n    bigint;
  t0     timestamptz;
  t_all  timestamptz := clock_timestamp();
  v_res  jsonb;
begin
  if exists (select 1 from public.one_shot_runs where name = k and finished_at is not null) then
    perform public.retire_cron_job('invariant-timing');
    return jsonb_build_object('status','already finished');
  end if;
  if not pg_try_advisory_xact_lock(hashtextextended(k,0)) then
    return jsonb_build_object('status','busy');
  end if;

  insert into public.one_shot_runs (name, started_at) values (k, clock_timestamp())
  on conflict (name) do update set started_at = excluded.started_at;

  for r in select name, severity, check_sql from public.invariants where enabled order by name loop
    t0 := clock_timestamp();
    begin
      execute r.check_sql into v_n;
      insert into public.invariant_timings (run_at, name, severity, violations, elapsed_ms)
      values (v_run, r.name, r.severity, v_n,
              round(extract(epoch from clock_timestamp() - t0)::numeric * 1000, 1));
    exception when others then
      insert into public.invariant_timings (run_at, name, severity, violations, elapsed_ms, error)
      values (v_run, r.name, r.severity, null,
              round(extract(epoch from clock_timestamp() - t0)::numeric * 1000, 1), sqlerrm);
    end;
  end loop;

  v_res := jsonb_build_object('run_at', v_run,
    'checks', (select count(*) from public.invariant_timings where run_at = v_run),
    'total_seconds', round(extract(epoch from clock_timestamp() - t_all)::numeric, 1));
  update public.one_shot_runs set finished_at = clock_timestamp(), result = v_res where name = k;
  perform public.retire_cron_job('invariant-timing');
  return v_res;
end $fn$;
revoke execute on function public.time_invariant_suite() from public, anon, authenticated;
