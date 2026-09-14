-- Why the MLS-Euro scrape exits 1, and the three things that were actually
-- wrong. The brief's hypothesis was that it "starts, partially lands, then
-- fails" on the same cause as the truncated fixtures. The logs say otherwise,
-- and there are two distinct causes, neither of them that one.
--
-- CAUSE 1, the database, 7 September. The run died at the first league having
-- written nothing:
--
--   GET /rest/v1/v_loaded_games?select=game_id  "HTTP/2 500 Internal Server Error"
--   postgrest.exceptions.APIError: {'message': 'canceling statement due to
--     statement timeout', 'code': '57014'}
--   File "pipeline/scrape_league.py", line 112, in loaded_game_ids
--
-- v_loaded_games was "SELECT DISTINCT game_id FROM v_league_events", a distinct
-- over nine million event rows, asked once per league, to answer a question
-- about 2,262 fixtures. This is the same root cause as everything else in this
-- brief: the events table outgrew every query that touched it. Rewritten below
-- to ask from the fixture side.
--
-- CAUSE 2, WhoScored, 13 September. This run did not die partway at all. It ran
-- to completion, took eight hours, and finished:
--
--   leagues: 6, succeeded: 126, failed: 5, remaining: 5
--   analytics rebuild skipped: live-ingestion gaps remain
--   Finished Mon 09/14/2026 5:37:19 with exit code 1
--
-- The five failures, from the log:
--   3x  Expecting value: line 2 column 1 (char 1)   <- HTML block page, not JSON
--   1x  'NoneType' object is not subscriptable      <- payload missing a key
--   1x  [WinError 10054] connection forcibly closed <- reset mid-fetch
-- plus a cluster of "the target machine actively refused it", which is the
-- undetected-chromedriver process having died and every later call to the local
-- driver port failing.
--
-- So: not one particular fixture, not the load path (every Supabase upsert in
-- that run returned 200 or 201), not soccerdata rate limiting as such. It is
-- WhoScored's anti-bot serving a block page, and the driver dying with it.
--
-- Per-fixture try/except was already there, and worked: 126 of 131 landed and
-- the run continued past every failure. The circuit breaker on consecutive
-- failures was already there too. Three real gaps remained.

-- ---------------------------------------------------------------------------
-- Gap 1. The fixture-side question, asked of fixtures.
create or replace view public.v_loaded_games as
select m.game_id
  from public.v_match_season_scope m
 where m.is_live_scope
   and exists (select 1 from public.events e
                where e.game_id = m.game_id and e.league = m.league);

-- ---------------------------------------------------------------------------
-- Gap 2. A failed fixture went nowhere. It was counted in the run summary, the
-- process exited 1, and the only record was a line in a log file on one PC. The
-- re-scrape queue already existed and was already drained at the start of every
-- run; nothing was feeding it scrape failures.
create or replace function public.enqueue_rescrape(
  p_game_id text, p_league text, p_reason text)
returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_status text;
begin
  insert into public.rescrape_queue (game_id, league, reason)
  values (p_game_id, coalesce(p_league, (select league from public.matches where game_id = p_game_id)), p_reason)
  on conflict (game_id) do update
    set reason = excluded.reason,
        queued_at = now(),
        status = case when public.rescrape_queue.status = 'exhausted'
                      then 'exhausted' else 'queued' end
  returning status into v_status;
  return v_status;
end $fn$;

revoke all on function public.enqueue_rescrape(text,text,text) from anon, authenticated;

-- An exhausted fixture is already excluded from live scope, so it contributes to
-- no metric. It must also stop counting as a gap, or a fixture WhoScored will
-- never serve keeps every run "incomplete" and keeps the analytics rebuild
-- permanently skipped. That is the shape of the failure that left the site on
-- 1 September data for thirteen days, and it should not be reachable again by a
-- different route.
create or replace view public.v_rescrape_exhausted as
select game_id, league, attempts, last_error, queued_at
  from public.rescrape_queue
 where status = 'exhausted';
grant select on public.v_rescrape_exhausted to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Gap 3. The exit code answered the wrong question, and the heartbeat only
-- noticed a total shutout.
alter table public.scraper_runs add column if not exists matches_failed integer;
alter table public.scraper_runs add column if not exists matches_remaining integer;

insert into public.invariants (name, description, check_sql, severity, enabled) values
('scraper_ran_recently',
 'A scraper run must have completed within the last 48 hours. The MLS-Euro task runs daily at 23:30 and the only record of its outcome was LastTaskResult on one PC, which nothing reads. A run that stops happening at all is invisible without this.',
 $q$select case when exists (
     select 1 from public.scraper_runs
      where status in ('success','partial')
        and finished_at > now() - interval '48 hours') then 0 else 1 end$q$,
 'warn', true),
('scraper_fixtures_failing',
 'No fixture may sit in the re-scrape queue exhausted. Exhausted means three scrape attempts failed, so it is excluded from live scope and excluded from the completeness count deliberately, to stop it blocking the analytics rebuild forever. That exclusion is the right call and it is also the reason this check has to exist: nothing else would ever mention the fixture again.',
 $q$select count(*) from public.rescrape_queue where status = 'exhausted'$q$,
 'warn', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;
