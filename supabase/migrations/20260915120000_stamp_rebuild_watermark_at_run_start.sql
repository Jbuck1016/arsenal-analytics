-- The rebuild watermark was never written, which turned the new-data enqueue
-- into a rebuild loop.
--
-- enqueue_rebuild_if_new_data compares max(events.id) with the high_event_id of
-- the latest completed run and queues a rebuild when events have advanced past
-- it. 20260914220000 created a stamp_rebuild_watermark trigger to write that
-- value at completion. Checked live on 15 September: neither the trigger nor
-- the function exists, and the tick-driven worker, advance_analytics_rebuild,
-- never calls mark_rebuild_complete either. Both completed runs, 1 September
-- and 15 September, carry a NULL watermark.
--
-- A NULL watermark reads as "new data". Run 9e5f7990 completed at 07:29:04 UTC
-- and analytics-enqueue-on-new-data queued run 6d095b87 at 07:30:00, 56 seconds
-- later. On a disk where a full rebuild takes about three hours, that would have
-- rebuilt continuously. The enqueue job was paused on discovery; 6d095b87 is
-- the one run allowed to proceed, because it publishes three played fixtures
-- that landed after 9e5f7990 read its events (Inter v Udinese, Colorado Rapids v
-- CF Montreal, Philadelphia Union v FC Cincinnati).
--
-- The watermark is now stamped when a run starts, as the newest event id the
-- run could read. A completion stamp, as the missing trigger intended, is wrong
-- as well as missing: it claims events that landed mid-run and were never read.
-- On 15 September the metrics steps read events from 04:27 and the nightly
-- scrape landed three fixtures at 06:30 to 06:45; a completion stamp would have
-- marked them published when they were not.
--
-- Run 6d095b87 was already past its start when this was applied, so its
-- watermark was set directly to max(events.id). The scrape's last write was at
-- 06:45 and the run started at 07:30, so that is exactly what it could read.
-- That update waits behind the running tick's row lock and lands when the tick
-- commits.
--
-- Rewritten from the live definition of advance_analytics_rebuild and refused
-- unless the start anchor appears exactly once.
do $stamp$
declare
  v_def text := pg_get_functiondef('public.advance_analytics_rebuild()'::regprocedure);
  v_anchor constant text := 'set status=''running'', started_at=now(),';
  v_new text;
  n_anchor int;
begin
  select count(*) into n_anchor from regexp_matches(v_def, 'set status=''running'', started_at=now\(\),', 'g');
  if n_anchor <> 1 then
    raise exception 'watermark rewrite refused: start anchor found % times, expected 1', n_anchor;
  end if;
  if position('high_event_id' in v_def) > 0 then
    raise notice 'advance_analytics_rebuild already stamps a watermark';
    return;
  end if;
  v_new := replace(v_def, v_anchor,
    v_anchor || ' high_event_id=(select id from public.events order by id desc limit 1),');
  if (select count(*) from regexp_matches(v_new, 'high_event_id=\(select id from public\.events order by id desc limit 1\)', 'g')) <> 1 then
    raise exception 'watermark rewrite refused: stamp not inserted exactly once';
  end if;
  execute v_new;
end $stamp$;
