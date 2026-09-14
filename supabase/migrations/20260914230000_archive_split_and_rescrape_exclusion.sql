-- Section 13, the archive split, plus the exclusion mechanism it exposed.
--
-- events was 8,956,491 rows and 7,138 MB total, 5,700 MB of heap. Live scope was
-- 9.7% of it, interleaved throughout, and all 36 matviews reading v_league_events
-- traversed the whole table. That cost grew with the archive rather than with the
-- current season, and by the time this ran a bare count(*) on events no longer
-- completed inside a 110 second window. The invariant suite was the visible
-- casualty: the gate spent over 13 minutes in verify because check after check
-- scanned 9M rows. Sections 5 and 10 both depend on this landing first.

create table if not exists public.events_archive (like public.events including defaults including constraints);
create index if not exists idx_events_archive_game on public.events_archive (game_id);
grant select on public.events_archive to anon, authenticated;

-- Moved in resumable batches. A single move cannot fit any connector window on
-- this instance, and a half-finished move that rolls back after twenty minutes
-- is worse than no move at all.
create or replace function public.archive_events_batch(p_games int default 500)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare v_games text[]; v_moved bigint;
begin
  select array_agg(game_id) into v_games from (
    select m.game_id from public.matches m
    where not m.is_live_scope
      and exists (select 1 from public.events e where e.game_id = m.game_id)
    limit p_games) g;
  if v_games is null then return jsonb_build_object('done', true, 'moved', 0); end if;
  with moved as (delete from public.events e where e.game_id = any(v_games) returning e.*)
  insert into public.events_archive select * from moved;
  get diagnostics v_moved = row_count;
  return jsonb_build_object('done', false, 'games', array_length(v_games,1), 'moved', v_moved);
end $fn$;

create or replace function public.archive_events_run(p_seconds int default 120)
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare t0 timestamptz := clock_timestamp(); r jsonb; total bigint := 0; batches int := 0;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('archive-drain',0)) then
    return jsonb_build_object('status','busy');
  end if;
  loop
    r := public.archive_events_batch(500);
    batches := batches + 1;
    total := total + coalesce((r->>'moved')::bigint,0);
    exit when (r->>'done')::boolean;
    exit when extract(epoch from clock_timestamp()-t0) > p_seconds;
  end loop;
  -- Put the pipeline back on its feet without anyone having to remember to. The
  -- cron jobs were paused to get a quiet window; leaving them paused would be
  -- worse than not splitting at all.
  if (r->>'done')::boolean then
    perform cron.alter_job(3, active := true);
    perform cron.alter_job(4, active := true);
    perform cron.alter_job(5, active := true);
    perform cron.alter_job(6, active := true);
    perform cron.unschedule('archive-drain');
    insert into public.rebuild_alerts (severity, kind, subject, detail)
    values ('warn','archive_split_complete','events',
            jsonb_build_object('note','archive split finished, cron restored'))
    on conflict (kind, subject) where notified_at is null do nothing;
  end if;
  return jsonb_build_object('batches',batches,'moved',total,'done',(r->>'done')::boolean,
    'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));
end $fn$;

-- ---------------------------------------------------------------------------
-- Excluding a fixture without deleting it.
--
-- The first attempt excluded truncated fixtures by deleting their events, which
-- routed around the very queue built to handle them and threw away 844 and 860
-- rows of genuine event data to clear a check. Every live view gates on exactly
-- one flag, so the honest exclusion point is that flag. The stored
-- matches.is_live_scope is deliberately untouched, so the archive split and the
-- season registry still see a queued fixture as current season.

create or replace view public.v_match_season_scope as
select m.game_id, m.season, m.competition, m.date, m.home_team, m.away_team,
       m.home_score, m.away_score, m.matchday, m.venue, m.league,
       l.season as registered_season, l.competition_type,
       (m.is_live_scope
        and not exists (select 1 from public.rescrape_queue q
                         where q.game_id = m.game_id
                           and q.status in ('queued','in_progress','exhausted'))) as is_live_scope
from matches m
left join leagues l on l.league = m.league;

-- One sanctioned path for taking a fixture's events out of circulation, and it
-- takes the sequences with them. Deliberately NOT a trigger on events: the
-- archive split deletes 8.1M rows from events while moving them, and a cascading
-- trigger would take every archived season's sequences with it.
create or replace function public.purge_fixture_events(p_game_id text, p_reason text)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_events bigint; v_seqs bigint; v_league text;
begin
  select league into v_league from public.matches where game_id = p_game_id;
  insert into public.events_quarantine overriding system value
  select * from public.events e where e.game_id = p_game_id
    and not exists (select 1 from public.events_quarantine q
                     where q.game_id=e.game_id and q.ws_id=e.ws_id);
  delete from public.events where game_id = p_game_id;
  get diagnostics v_events = row_count;
  delete from public.sequences where game_id = p_game_id;
  get diagnostics v_seqs = row_count;
  insert into public.rescrape_queue (game_id, league, reason)
  values (p_game_id, v_league, p_reason)
  on conflict (game_id) do update
    set status = case when public.rescrape_queue.status='exhausted' then 'exhausted' else 'queued' end,
        queued_at = now(), reason = excluded.reason;
  return jsonb_build_object('game_id',p_game_id,'events_quarantined',v_events,'sequences_removed',v_seqs);
end $fn$;

-- Queue rather than delete. A queued fixture is already invisible to every live
-- view, so there is nothing to gain by removing its rows.
create or replace function public.quarantine_truncated_fixtures(p_floor int default 60)
returns integer
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare r record; n integer := 0;
begin
  for r in
    select m.game_id, max(e.expanded_minute) as last_min, count(*) as n_events
    from public.matches m
    join public.events e on e.game_id = m.game_id
    where m.is_live_scope and m.home_score is not null
      and not exists (select 1 from public.rescrape_queue q where q.game_id = m.game_id)
    group by m.game_id
    having max(e.expanded_minute) < p_floor
  loop
    insert into public.rescrape_queue (game_id, league, reason)
    select r.game_id, m.league,
           format('event feed ended at minute %s with %s rows, under the %s minute floor',
                  r.last_min, r.n_events, p_floor)
    from public.matches m where m.game_id = r.game_id
    on conflict (game_id) do nothing;
    n := n + 1;
  end loop;
  return n;
end $fn$;

insert into public.invariants (name, description, check_sql, severity, enabled) values
('sequences_without_events',
 'A sequence whose fixture has no events in either events or events_archive is orphaned. This fires if anything removes a fixture from events without going through purge_fixture_events, which is the one path that takes the sequences with it. The first hand-rolled quarantine left exactly 5 such orphans.',
 $q$select count(*) from (select distinct game_id from public.sequences) s
    where not exists (select 1 from public.events e where e.game_id = s.game_id)
      and not exists (select 1 from public.events_archive a where a.game_id = s.game_id)$q$,
 'error', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;

-- 'abandoned' was never a permitted status, so the reaper written earlier would
-- have failed its own check constraint the first time it fired.
alter table public.analytics_rebuild_runs drop constraint if exists analytics_rebuild_runs_status_check;
alter table public.analytics_rebuild_runs add constraint analytics_rebuild_runs_status_check
  check (status = any (array['pending','running','complete','failed','abandoned']));

-- Watchdog, independent of the drain's own restore path. If the drain
-- unschedules itself but its alter_job calls do not land, or it dies outright,
-- the cron jobs stay paused and the pipeline is silently dead, which is a worse
-- outcome than never having split the table. This notices and puts them back.
create or replace function public.archive_drain_watchdog()
returns text
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_drain int;
begin
  select count(*) into v_drain from cron.job where jobname='archive-drain';
  if v_drain > 0 then
    return 'drain still scheduled, nothing to do';
  end if;
  if exists (select 1 from cron.job where jobid in (3,4,5,6) and not active) then
    perform cron.alter_job(3, active := true);
    perform cron.alter_job(4, active := true);
    perform cron.alter_job(5, active := true);
    perform cron.alter_job(6, active := true);
    insert into public.rebuild_alerts (severity, kind, subject, detail)
    values ('warn','cron_restored_by_watchdog','analytics',
            jsonb_build_object('note','drain finished without restoring cron; watchdog did it'))
    on conflict (kind, subject) where notified_at is null do nothing;
    perform cron.unschedule('archive-watchdog');
    return 'cron restored by watchdog';
  end if;
  perform cron.unschedule('archive-watchdog');
  return 'cron already active, watchdog retiring';
end $fn$;
