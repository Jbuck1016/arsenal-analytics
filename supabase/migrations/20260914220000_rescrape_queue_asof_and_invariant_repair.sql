-- Re-scrape queue, published as-of date, section 5 invariant repair.
--
-- Three themes, all the same underlying point: the pipeline should notice and
-- repair its own damage rather than leaving a number that looks plausible.

-- ---------------------------------------------------------------------------
-- 1. Re-scrape queue
--
-- A truncated event feed is worse than a missing one. mv_match_length derives
-- length from the events themselves and mv_player_minutes scales each spell by
-- 90.0/length_min, so a feed stopping at minute 50 credits every player a full
-- 90 of exposure against a numerator that stopped halfway. Their per-90s are
-- diluted and the percentile pools they sit in are depressed with them.
--
-- Quarantining the events is what removes the fixture from metrics: everything
-- downstream inner joins mv_match_length, which is derived from events, so a
-- fixture with no events contributes nothing. No matview definition changes.
-- The sequences must go with them, or they are orphaned and every league check
-- trips over them, which is exactly what happened: 5 orphan sequences from the
-- first quarantine showed up the moment seq_league_matches_events became an
-- anti-join.

create table if not exists public.rescrape_queue (
  game_id         text primary key,
  league          text,
  reason          text not null,
  queued_at       timestamptz not null default now(),
  attempts        integer not null default 0,
  last_attempt_at timestamptz,
  last_error      text,
  status          text not null default 'queued'
                  check (status in ('queued','in_progress','done','exhausted'))
);
create index if not exists idx_rescrape_queue_open
  on public.rescrape_queue (queued_at) where status in ('queued','in_progress');
grant select on public.rescrape_queue to anon, authenticated;

create or replace function public.quarantine_truncated_fixtures(p_floor int default 60)
returns integer
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare r record; n integer := 0;
begin
  for r in
    select m.game_id, m.league, max(e.expanded_minute) as last_min, count(*) as n_events
    from public.matches m
    join public.events e on e.game_id = m.game_id
    where m.is_live_scope and m.home_score is not null
    group by m.game_id, m.league
    having max(e.expanded_minute) < p_floor
  loop
    insert into public.events_quarantine select * from public.events where game_id = r.game_id;
    delete from public.events where game_id = r.game_id;
    delete from public.sequences where game_id = r.game_id;
    insert into public.rescrape_queue (game_id, league, reason)
    values (r.game_id, r.league,
            format('event feed ended at minute %s with %s rows, under the %s minute floor',
                   r.last_min, r.n_events, p_floor))
    on conflict (game_id) do update
      set status = case when public.rescrape_queue.status='exhausted' then 'exhausted' else 'queued' end,
          queued_at = now(), reason = excluded.reason;
    n := n + 1;
  end loop;
  return n;
end $fn$;

-- attempts increments on claim, before the work starts, so a crash mid-fetch
-- still counts and a fixture cannot retry forever
create or replace function public.claim_rescrape_batch(p_limit int default 10)
returns table(game_id text, league text, attempts int)
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
begin
  return query
  update public.rescrape_queue q
     set status='in_progress', attempts=q.attempts+1, last_attempt_at=now()
   where q.game_id in (
     select g.game_id from public.rescrape_queue g
      where g.status in ('queued','in_progress') and g.attempts < 3
      order by g.queued_at limit p_limit for update skip locked)
  returning q.game_id, q.league, q.attempts;
end $fn$;

create or replace function public.record_rescrape_result(
  p_game_id text, p_ok boolean, p_error text default null)
returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_att int; v_events int;
begin
  select count(*) into v_events from public.events where game_id = p_game_id;
  if p_ok and v_events > 0 then
    update public.rescrape_queue set status='done', last_error=null where game_id=p_game_id;
    return 'done';
  end if;
  update public.rescrape_queue
     set last_error = coalesce(p_error, 'scrape returned no events'),
         status = case when attempts >= 3 then 'exhausted' else 'queued' end
   where game_id = p_game_id
  returning attempts into v_att;
  if v_att >= 3 then
    perform public.raise_alert('error','rescrape_exhausted', p_game_id,
      jsonb_build_object('attempts', v_att, 'error', coalesce(p_error,'no events returned')));
    return 'exhausted';
  end if;
  return 'requeued';
end $fn$;

-- ---------------------------------------------------------------------------
-- 2. Published as-of date
--
-- mv_site_summary.refreshed_at reports when refresh_site_summaries last ran,
-- which is independent of whether the analytics layer rebuilt. On 14 September
-- it read 17:41 while every metric matview was from 1 September. Surfacing that
-- would stamp "current" on thirteen-day-old numbers.

create or replace view public.v_analytics_as_of as
select
  (select max(finished_at) from public.analytics_rebuild_runs where status='complete') as as_of,
  (select round(extract(epoch from now() - max(finished_at))/3600, 1)
     from public.analytics_rebuild_runs where status='complete') as hours_old,
  (select max(finished_at) from public.analytics_rebuild_runs where status='complete')
    < now() - interval '48 hours' as is_stale,
  (select count(*) from public.analytics_rebuild_runs
    where status in ('failed','abandoned')
      and finished_at > (select coalesce(max(finished_at), '-infinity'::timestamptz)
                         from public.analytics_rebuild_runs where status='complete')) as failures_since;
grant select on public.v_analytics_as_of to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Section 9, enqueue on new data
--
-- events carries no timestamp, but its id is monotonic, so the highest id seen by
-- the last completed rebuild is an exact watermark for "new data has landed".
-- matches.updated_at does not exist, which the first attempt assumed.

alter table public.analytics_rebuild_runs add column if not exists high_event_id bigint;

create or replace function public.stamp_rebuild_watermark()
returns trigger language plpgsql as $fn$
begin
  if new.status = 'complete' and (old.status is distinct from 'complete') then
    new.high_event_id := (select max(id) from public.events);
  end if;
  return new;
end $fn$;
drop trigger if exists trg_rebuild_watermark on public.analytics_rebuild_runs;
create trigger trg_rebuild_watermark
  before update on public.analytics_rebuild_runs
  for each row execute function public.stamp_rebuild_watermark();

create or replace function public.enqueue_rebuild_if_new_data()
returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_mark bigint; v_now bigint;
begin
  if exists (select 1 from public.analytics_rebuild_runs where status in ('pending','running')) then
    return 'skipped: run already pending or running';
  end if;
  select high_event_id into v_mark from public.analytics_rebuild_runs
   where status='complete' order by finished_at desc limit 1;
  select max(id) into v_now from public.events;
  if v_mark is not null and v_now is not null and v_now <= v_mark then
    return format('skipped: no new events (watermark %s)', v_mark);
  end if;
  insert into public.analytics_rebuild_runs (run_id, status) values (gen_random_uuid(),'pending');
  return format('enqueued: events advanced from %s to %s', coalesce(v_mark,0), coalesce(v_now,0));
end $fn$;

select cron.schedule('analytics-enqueue-on-new-data','*/10 * * * *',
  $$select public.enqueue_rebuild_if_new_data();$$);

-- ---------------------------------------------------------------------------
-- 4. Section 5, invariant repair. Measured before and after on live.

update public.invariants set
 check_sql = $q$select count(*) from public.matches m
   join public.leagues l on l.league = m.league
  where m.is_live_scope <> (m.season = l.season and l.competition_type = 'league')$q$,
 description = 'The stored is_live_scope flag must agree with the season registry for every fixture, and live scope is league competitions only, so cup fixtures in the current season are correctly excluded. Rewritten at game level: the previous version made four full passes over 865k live events, sequences and lineups to test a condition the v_league_* views now guarantee structurally, since all of them filter on is_live_scope. What is worth checking is the flag itself, because if a trigger misses a season rollover the flag goes stale and every view built on it serves the wrong season silently. 110s+ to 28ms.'
where name = 'league_outputs_current_season';

update public.invariants set
 check_sql = $q$select count(*) from public.matches m
   join public.leagues l on l.league = m.league and l.competition_type = 'league'
  where m.is_live_scope and m.home_score is not null
    and exists (select 1 from public.events e where e.game_id = m.game_id)
    and not exists (select 1 from public.sequences s where s.game_id = m.game_id)$q$,
 description = 'Every played live-scope fixture with events must have sequences built. Keyed on is_live_scope rather than the hardcoded season string 2627, which would have gone quietly wrong at the next rollover.'
where name = 'sequences_built_for_live_season';

update public.invariants set
 check_sql = $q$select
   (select count(*) from public.player_search ps
     where not exists (select 1 from public.player_chain_roles r where r.player_id = ps.player_id))
 + (select count(*) from public.player_chain_roles r
     where not exists (select 1 from public.player_search ps where ps.player_id = r.player_id))$q$,
 description = 'The searchable player set and the chain-role set must contain the same players, compared as sets in both directions. The previous version compared only abs(count - count), which passes whenever the two totals coincide even if the populations are completely disjoint.'
where name = 'search_matches_roles';

update public.invariants set
 check_sql = $q$select count(*) from public.insights i
   left join public.v_team_sample ts on ts.team = i.team
  where ts.team is null or not ts.meets_min_matches$q$,
 description = 'Every insight must be about a team that appears in the live sample and meets the minimum match count. Anti-join: the previous inner join silently skipped any insight whose team was missing from the sample entirely, which is the more serious case.'
where name = 'insight_meets_sample';

update public.invariants set
 check_sql = $q$select count(*) from public.mv_team_match tm
   left join public.matches m on m.game_id = tm.game_id
   left join public.leagues l on l.league = m.league
  where m.game_id is null or l.league is null or l.competition_type <> 'league'$q$,
 description = 'Team match metrics must come from league fixtures only. Anti-join: the previous inner joins dropped any metrics row whose fixture was missing from matches, or whose league was missing from the registry, so an orphan escaped entirely.'
where name = 'no_non_league_fixture_in_metrics';

update public.invariants set
 check_sql = $q$select count(*) from (select distinct game_id, league from public.sequences) sg
   left join public.matches m on m.game_id = sg.game_id
  where m.game_id is null
     or sg.league is distinct from m.league
     or not exists (select 1 from public.events e where e.game_id = sg.game_id)$q$,
 description = 'Every sequence must belong to a real fixture, carry that fixture league, and have events behind it. Compared at game level so it costs one pass over roughly 5,000 fixtures rather than a group-by over 9M event rows, 52s to 7.5s. Anti-join throughout: the previous inner join skipped sequences whose fixture has no events, which is how orphaned sequences survive a fixture being pulled. This is the check that caught 1,573 La Liga sequences written as MLS and 2,834 Premier League rows on 8 September.'
where name = 'seq_league_matches_events';

-- Section 7 guard. Nothing in the analytics layer trusts lineups.is_starter any
-- more: mv_player_minutes derives it from position and everything downstream
-- reads that. This fires if the raw column is ever wired back in, and records the
-- size of the upstream scraper bug meanwhile.
insert into public.invariants (name, description, check_sql, severity, enabled) values
('lineups_is_starter_disagrees_with_position',
 'lineups.is_starter must agree with position <> Sub. It does not: 114,251 of 246,400 rows disagree, and only 3,692 rows in the whole table are false, so the column is a scraper artefact rather than a fact. Warn, because the defect is upstream and blocking publication on it would punish the wrong thing.',
 $q$select count(*) from public.lineups
    where is_starter <> ("position" is distinct from 'Sub')$q$,
 'warn', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;
