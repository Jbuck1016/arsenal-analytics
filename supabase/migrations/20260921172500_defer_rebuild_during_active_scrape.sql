-- Do not snapshot the event watermark while a scraper is still writing.
--
-- A targeted Bundesliga recovery on 21 September overlapped the ten-minute
-- analytics enqueue cron. The rebuild captured five of six fixtures, then
-- correctly failed verification when the sixth arrived after its sequence
-- stage. scraper_runs is the ingestion transaction boundary available to the
-- database, so rebuild enqueue must respect it. The six-hour bound prevents a
-- stale row from a crashed host from suppressing analytics indefinitely.

create or replace function public.enqueue_rebuild_if_new_data()
returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_mark bigint; v_now bigint;
begin
  if exists (
    select 1
    from public.scraper_runs
    where status = 'running'
      and finished_at is null
      and started_at >= now() - interval '6 hours'
  ) then
    return 'skipped: scraper still running';
  end if;

  if exists (select 1 from public.analytics_rebuild_runs where status in ('pending','running')) then
    return 'skipped: run already pending or running';
  end if;

  select high_event_id into v_mark
  from public.analytics_rebuild_runs
  where status='complete'
  order by finished_at desc
  limit 1;

  select max(id) into v_now from public.events;
  if v_mark is not null and v_now is not null and v_now <= v_mark then
    return format('skipped: no new events (watermark %s)', v_mark);
  end if;

  insert into public.analytics_rebuild_runs (run_id, status)
  values (gen_random_uuid(),'pending');
  return format('enqueued: events advanced from %s to %s', coalesce(v_mark,0), coalesce(v_now,0));
end $fn$;

comment on function public.enqueue_rebuild_if_new_data() is
  'Queues analytics only after event ingestion is quiescent; active scraper_runs defer watermark capture.';
