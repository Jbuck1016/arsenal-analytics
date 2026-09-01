begin;

-- Hosted Cron applies its timeout to the top-level scheduled statement before
-- a called function can change it. Make the timeout change its own statement,
-- so the following queue call starts without the gateway/cron deadline.
do $schedule$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname = 'analytics-rebuild-worker';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule(
    'analytics-rebuild-worker',
    '* * * * *',
    'set statement_timeout = 0; select public.process_analytics_rebuild_queue();'
  );
end
$schedule$;

do $assert$
begin
  if (select count(*) from cron.job
      where jobname='analytics-rebuild-worker'
        and schedule='* * * * *'
        and active
        and command like 'set statement_timeout = 0;%') <> 1 then
    raise exception 'timeout-safe analytics queue schedule missing or duplicated';
  end if;
end
$assert$;

commit;
