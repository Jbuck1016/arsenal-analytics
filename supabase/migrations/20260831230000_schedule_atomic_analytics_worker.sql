begin;

create extension if not exists pg_cron with schema extensions;

create or replace function public.process_analytics_rebuild_queue()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set statement_timeout = '0'
as $fn$
declare
  queued public.analytics_rebuild_runs%rowtype;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('analytics-rebuild-worker', 0)) then
    return jsonb_build_object('status','busy');
  end if;

  select * into queued
  from public.analytics_rebuild_runs
  where status = 'pending'
  order by created_at, run_id
  for update skip locked
  limit 1;

  if not found then
    return jsonb_build_object('status','idle');
  end if;

  return public.rebuild_all_verified(queued.run_id, queued.requested_league, null);
end
$fn$;

alter function public.process_analytics_rebuild_queue() owner to postgres;
revoke all on function public.process_analytics_rebuild_queue() from public, anon, authenticated;
grant execute on function public.process_analytics_rebuild_queue() to service_role;

comment on function public.process_analytics_rebuild_queue() is
  'Claims one pending analytics rebuild and executes it inside the rollback-safe database transaction. Scheduled once per minute; advisory locking prevents overlap.';

do $schedule$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname = 'analytics-rebuild-worker';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule(
    'analytics-rebuild-worker',
    '* * * * *',
    'select public.process_analytics_rebuild_queue();'
  );
end
$schedule$;

do $assert$
begin
  if has_function_privilege('anon','public.process_analytics_rebuild_queue()','execute')
     or has_function_privilege('authenticated','public.process_analytics_rebuild_queue()','execute') then
    raise exception 'browser role can execute analytics queue worker';
  end if;
  if not has_function_privilege('service_role','public.process_analytics_rebuild_queue()','execute') then
    raise exception 'service_role cannot execute analytics queue worker';
  end if;
  if (select count(*) from cron.job where jobname='analytics-rebuild-worker'
      and schedule='* * * * *' and active) <> 1 then
    raise exception 'analytics queue schedule missing or duplicated';
  end if;
end
$assert$;

commit;
