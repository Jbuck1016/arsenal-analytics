-- The reaper killed a live rebuild, and nothing could say why the step it
-- killed was slow.
--
-- ---------------------------------------------------------------------------
-- 1. Reaper liveness.
--
-- Run fa76cceb was marked abandoned at 04:22:00 UTC on 15 September with "no
-- step progress for 20 minutes; worker presumed killed mid-step" while
-- metrics1 was still executing. The step completed about a minute later,
-- 1,371.8 seconds after it started.
--
-- The liveness guard checked analytics_rebuild_runs.worker_pid. That pid is
-- written once, by the tick that moves a run from pending to running, and every
-- later tick runs in a different pg_cron backend, so it is dead by the second
-- tick. The guard never protected anything; elapsed time alone decided, which
-- assumes no step ever takes 20 minutes. That held when it was written, the
-- slowest step being metrics3 at 439 seconds, and stopped holding here.
--
-- A run is now abandoned only when no rebuild tick is executing at all, as well
-- as no step progress for 20 minutes. A slow live step is left alone. A killed
-- or stopped worker still shows no executing tick and is still reaped, and
-- advance_analytics_rebuild separately counts a step left 'running' with no tick
-- holding the worker lock as an aborted attempt.
create or replace function public.reap_abandoned_rebuilds()
returns integer
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare n integer;
begin
  if exists (
    select 1 from pg_stat_activity a
     where a.pid <> pg_backend_pid()
       and a.state = 'active'
       and a.query ilike '%advance_analytics_rebuild%'
  ) then
    return 0;
  end if;

  with dead as (
    update public.analytics_rebuild_runs r
       set status='abandoned', finished_at=now(), worker_pid=null,
           error_message=coalesce(r.error_message,
             'no rebuild tick executing and no step progress for 20 minutes; worker stopped')
     where r.status='running'
       and r.started_at < now() - interval '20 minutes'
       and coalesce(
             (select max(coalesce(s.finished_at, s.started_at))
                from public.analytics_rebuild_steps s where s.run_id = r.run_id),
             r.started_at) < now() - interval '20 minutes'
    returning 1)
  select count(*) into n from dead;
  return n;
end $fn$;
revoke execute on function public.reap_abandoned_rebuilds() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Per-matview refresh timing.
--
-- metrics1 took 1,371.8 seconds against 71.9 seconds the day before, on an
-- events table one seventh the size, and preflight took 91.2 seconds against
-- 6.0. Nothing recorded which of metrics1's ten refreshes took the time.
-- pg_stat_statements tracks top-level statements only, and these refreshes run
-- nested inside refresh_analytics_batch; the slowest refresh it had tracked
-- averaged 92.5 seconds, nowhere near the step. Each refresh now records its
-- own duration against the running rebuild.
create table if not exists public.rebuild_refresh_timings (
  run_id    uuid,
  matview   text not null,
  started   timestamptz not null,
  seconds   numeric not null
);
alter table public.rebuild_refresh_timings enable row level security;
revoke all on public.rebuild_refresh_timings from anon, authenticated;

create or replace function public.timed_refresh_concurrently(p_matview text)
returns void
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare t0 timestamptz := clock_timestamp();
begin
  -- Exactly the statement it replaces. Errors propagate unchanged.
  execute format('refresh materialized view concurrently %s', p_matview);
  insert into public.rebuild_refresh_timings (run_id, matview, started, seconds)
  values ((select run_id from public.analytics_rebuild_runs
            where status = 'running' order by started_at desc limit 1),
          p_matview, t0, round(extract(epoch from clock_timestamp() - t0)::numeric, 1));
end $fn$;
revoke execute on function public.timed_refresh_concurrently(text) from public, anon, authenticated;

-- refresh_analytics_batch is rewritten from its live definition rather than
-- retyped: every "refresh materialized view concurrently X;" becomes
-- "perform public.timed_refresh_concurrently('X');". Same statements, same
-- order, same transaction. It refuses unless every refresh was converted and
-- none remain unwrapped, so a definition this migration did not anticipate
-- cannot be half rewritten.
do $rewrite$
declare
  v_def  text := pg_get_functiondef('public.refresh_analytics_batch(integer)'::regprocedure);
  v_new  text;
  n_before int;
  n_after  int;
  n_left   int;
begin
  select count(*) into n_before
    from regexp_matches(v_def, 'refresh materialized view concurrently ([A-Za-z_0-9.]+);', 'g');
  v_new := regexp_replace(v_def,
             'refresh materialized view concurrently ([A-Za-z_0-9.]+);',
             'perform public.timed_refresh_concurrently(''\1'');', 'g');
  select count(*) into n_after
    from regexp_matches(v_new, 'perform public\.timed_refresh_concurrently\(''[A-Za-z_0-9.]+''\);', 'g');
  select count(*) into n_left
    from regexp_matches(v_new, 'refresh materialized view concurrently', 'gi');
  if n_before = 0 or n_after <> n_before or n_left <> 0 then
    raise exception 'refresh_analytics_batch rewrite refused: % refreshes found, % converted, % left unwrapped',
      n_before, n_after, n_left;
  end if;
  execute v_new;
  raise notice 'refresh_analytics_batch: % refreshes now timed', n_after;
end $rewrite$;
