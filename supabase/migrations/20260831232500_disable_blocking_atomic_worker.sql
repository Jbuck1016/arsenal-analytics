begin;

-- The first worker proved rollback safety but held materialized-view locks long
-- enough for Player and Match API reads to time out. Keep the queue functions
-- for audit/recovery, but do not schedule the blocking implementation.
do $unschedule$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname='analytics-rebuild-worker';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
end
$unschedule$;

do $assert$
begin
  if exists(select 1 from cron.job where jobname='analytics-rebuild-worker') then
    raise exception 'blocking analytics worker remains scheduled';
  end if;
end
$assert$;

commit;
