-- Make a rebuild in flight legible, and stop a late failure discarding the work.
--
-- rebuild_all_verified was a FUNCTION, so all 19 steps and every status write
-- shared one transaction. Three consequences, all seen on live:
--
--   1. A run in flight was a black box. Run 2d2a9546 showed status 'pending'
--      with started_at null for its entire 1,310 second life while
--      cron.job_run_details showed the worker actively executing it.
--
--   2. A failure at the gate discarded every earlier step. The PL/pgSQL
--      begin/exception block is a subtransaction, so catching the failure rolled
--      back all 19 steps. The status write survived and committed, which is why
--      runs correctly read 'failed'. Two runs on 14 September threw away 21.8
--      and 23 minutes of correct refresh work apiece.
--
--   3. Every step's refresh lock was held until commit. A single run was
--      observed holding exclusive locks on 65 matviews at once.
--
-- IMPLEMENTATION NOTE, and it is not what the brief asked for.
--
-- The brief specified a PROCEDURE that COMMITs after each step. That was built
-- and it does not work under pg_cron: the job command runs inside a transaction,
-- so COMMIT inside a called procedure raises
--     ERROR: invalid transaction termination
-- which is what cron.job_run_details recorded on runids 19922 and 19923. dblink
-- would host it outside that transaction but needs stored credentials, which is
-- a secret in the database to solve a scheduling problem.
--
-- So the driver is a state machine instead: one step per tick, where the tick IS
-- the transaction. advance_analytics_rebuild() claims or resumes a run, executes
-- the first step not yet marked complete, records it, and returns. pg_cron then
-- commits. This gives exactly the properties the brief wanted, per-step
-- durability and per-step visibility, without needing transaction control, and
-- it drops the lock at each step boundary as a bonus. The tick runs every 15
-- seconds; a step longer than that simply holds the advisory lock and later
-- ticks return 'busy'.
--
-- Durability is now separate from publication. A failed gate no longer rolls the
-- refreshes back; it declines to advance the published as-of date, which is
-- derived from max(finished_at) where status = 'complete', and raises an alert.
--
-- REFRESH MATERIALIZED VIEW CONCURRENTLY is unchanged and still runs inside each
-- step's transaction.

alter table public.analytics_rebuild_runs
  add column if not exists worker_pid integer;

create table if not exists public.analytics_rebuild_steps (
  run_id      uuid        not null,
  step        text        not null,
  status      text        not null check (status in ('running','complete','failed')),
  started_at  timestamptz not null default now(),
  finished_at timestamptz,
  elapsed_ms  bigint,
  result      text,
  error       text,
  primary key (run_id, step)
);
create index if not exists idx_rebuild_steps_run
  on public.analytics_rebuild_steps (run_id, started_at);
grant select on public.analytics_rebuild_steps to anon, authenticated;

create or replace function public.advance_analytics_rebuild()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
set statement_timeout to '0'
set random_page_cost to '0.25'
set work_mem to '48MB'
as $fn$
declare
  steps constant text[] := array['preflight','metrics1','metrics2','metrics3','metrics4',
    'sequences','players','seqfz','lookups','state','chains','traj','profiles','usage',
    'teamstyle','search','percentiles','insights','verify'];
  v_run uuid; v_league text; v_status text;
  v_step text; v_res text; v_err text; v_t0 timestamptz; v_i int;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('analytics-rebuild-worker', 0)) then
    return jsonb_build_object('status','busy');
  end if;

  select run_id, requested_league, status into v_run, v_league, v_status
  from public.analytics_rebuild_runs
  where status in ('pending','running')
  order by created_at, run_id
  for update skip locked
  limit 1;

  if v_run is null then return jsonb_build_object('status','idle'); end if;

  if v_status = 'pending' then
    update public.analytics_rebuild_runs
       set status='running', started_at=now(), current_step='starting',
           error_message=null, messages='[]'::jsonb, worker_pid=pg_backend_pid()
     where run_id=v_run;
    delete from public.analytics_rebuild_steps where run_id=v_run;
  end if;

  v_step := null;
  foreach v_i in array array(select generate_series(1, array_length(steps,1))) loop
    if not exists (select 1 from public.analytics_rebuild_steps s
                    where s.run_id=v_run and s.step=steps[v_i] and s.status='complete') then
      v_step := steps[v_i];
      exit;
    end if;
  end loop;

  if v_step is null then
    update public.analytics_rebuild_runs
       set status='complete', current_step=null, finished_at=now(), worker_pid=null
     where run_id=v_run;
    return jsonb_build_object('status','complete','run_id',v_run);
  end if;

  v_t0 := clock_timestamp();
  -- written outside the exception block so it survives the subtransaction rollback
  insert into public.analytics_rebuild_steps (run_id, step, status, started_at)
    values (v_run, v_step, 'running', v_t0)
  on conflict (run_id, step) do update
    set status='running', started_at=excluded.started_at, error=null, finished_at=null;
  update public.analytics_rebuild_runs
     set current_step=v_step, worker_pid=pg_backend_pid() where run_id=v_run;

  v_err := null;
  begin
    v_res := public.rebuild_step(v_step, v_league);
  exception when others then
    v_err := sqlerrm;
  end;

  if v_err is null then
    update public.analytics_rebuild_steps
       set status='complete', finished_at=clock_timestamp(),
           elapsed_ms=round(extract(epoch from clock_timestamp()-v_t0)*1000), result=v_res
     where run_id=v_run and step=v_step;
    return jsonb_build_object('status','step_complete','run_id',v_run,'step',v_step,
      'elapsed_ms', round(extract(epoch from clock_timestamp()-v_t0)*1000));
  else
    update public.analytics_rebuild_steps
       set status='failed', finished_at=clock_timestamp(),
           elapsed_ms=round(extract(epoch from clock_timestamp()-v_t0)*1000), error=v_err
     where run_id=v_run and step=v_step;
    update public.analytics_rebuild_runs
       set status='failed', current_step=null, error_message=v_err,
           finished_at=now(), worker_pid=null
     where run_id=v_run;
    return jsonb_build_object('status','step_failed','run_id',v_run,'step',v_step,'error',v_err);
  end if;
end $fn$;

-- Stale claim reaper. Per-step commits make a run visible while it executes,
-- which also means a run left in 'running' by a killed backend stays that way
-- and blocks the queue. The tick driver uses a different backend each step, so
-- worker_pid liveness is meaningless between ticks; lack of step progress is the
-- real signal. Marked abandoned rather than silently re-claimed, so the kill is
-- recorded and alertable.
create or replace function public.reap_abandoned_rebuilds()
returns integer
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare n integer;
begin
  with dead as (
    update public.analytics_rebuild_runs r
       set status='abandoned', finished_at=now(), worker_pid=null,
           error_message=coalesce(r.error_message,
             'no step progress for 20 minutes; worker presumed killed mid-step')
     where r.status='running'
       and r.started_at < now() - interval '20 minutes'
       and coalesce(
             (select max(coalesce(s.finished_at, s.started_at))
                from public.analytics_rebuild_steps s where s.run_id = r.run_id),
             r.started_at) < now() - interval '20 minutes'
       and not exists (
             select 1 from pg_stat_activity a
              where a.pid = r.worker_pid and a.state <> 'idle')
    returning 1)
  select count(*) into n from dead;
  return n;
end $fn$;

select cron.alter_job(3, command := $$select public.advance_analytics_rebuild();$$);
select cron.alter_job(3, schedule := '15 seconds');
select cron.schedule('analytics-reaper', '*/2 * * * *',
  $$select public.reap_abandoned_rebuilds();$$);
