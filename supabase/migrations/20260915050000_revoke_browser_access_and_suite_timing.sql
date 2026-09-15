-- Browser access to pipeline objects, found while verifying the section 8
-- runners against the live database, plus the invariant suite timing harness.
--
-- ---------------------------------------------------------------------------
-- 1. EXECUTE on SECURITY DEFINER functions.
--
-- Every function added during the pipeline repair ended with
-- "revoke all on function ... from anon, authenticated", and that did nothing.
-- Postgres grants EXECUTE to PUBLIC when a function is created, anon and
-- authenticated inherit it through PUBLIC, and a revoke naming those roles does
-- not touch a PUBLIC grant. has_function_privilege('anon', ...) was true for all
-- of them, so each was callable through /rest/v1/rpc with the site's public key.
--
-- replace_matview and prove_new_definition execute caller-supplied SQL text as
-- the owner, which made that arbitrary SQL execution for anyone holding the
-- public key. Of the rest, several are destructive in anonymous hands:
-- purge_fixture_events deletes a fixture's events and sequences;
-- enqueue_rescrape and quarantine_truncated_fixtures take a fixture out of live
-- scope; mark_rebuild_complete stamps stale analytics with a fresh as-of date.
--
-- Only pg_cron, running as the owner, and the scraper, running as service_role
-- with its own explicit grant, call any of these. Verified after the revoke:
-- the five RPCs the dashboard calls (get_starter_names, nl_query,
-- similar_players_chain, similar_sequences, top_sequences_by_type) are still
-- executable by anon, a live anon call to get_starter_names returned HTTP 200
-- with 22 rows, and the same key calling purge_fixture_events now gets
-- 401 "permission denied for function purge_fixture_events".
revoke execute on function public.replace_matview(text, text)                 from public, anon, authenticated;
revoke execute on function public.prove_new_definition(text, text)            from public, anon, authenticated;
revoke execute on function public.run_section8_apply()                        from public, anon, authenticated;
revoke execute on function public.run_section8_proof()                        from public, anon, authenticated;
revoke execute on function public.run_section8_same_data_proof()              from public, anon, authenticated;
revoke execute on function public.events_swap_copy_phase()                    from public, anon, authenticated;
revoke execute on function public.events_swap_tick()                          from public, anon, authenticated;
revoke execute on function public.advance_analytics_rebuild()                 from public, anon, authenticated;
revoke execute on function public.check_and_raise_alerts()                    from public, anon, authenticated;
revoke execute on function public.claim_rescrape_batch(integer)               from public, anon, authenticated;
revoke execute on function public.dispatch_pending_alerts()                   from public, anon, authenticated;
revoke execute on function public.enqueue_rebuild_if_new_data()               from public, anon, authenticated;
revoke execute on function public.enqueue_rescrape(text, text, text)          from public, anon, authenticated;
revoke execute on function public.mark_rebuild_complete(uuid)                 from public, anon, authenticated;
revoke execute on function public.purge_fixture_events(text, text)            from public, anon, authenticated;
revoke execute on function public.quarantine_truncated_fixtures(integer)      from public, anon, authenticated;
revoke execute on function public.raise_alert(text, text, text, jsonb)        from public, anon, authenticated;
revoke execute on function public.reap_abandoned_rebuilds()                   from public, anon, authenticated;
revoke execute on function public.record_rescrape_result(text, boolean, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Writes on pipeline tables.
--
-- Supabase default privileges grant anon and authenticated full access on
-- every new public table, and these were created with RLS off, so a browser
-- could insert, update and delete them. events_archive is now the only copy of
-- 8,091,571 historical event rows. No dashboard page references any of these
-- tables. SELECT is left as it is: v_match_season_scope reads rescrape_queue
-- and v_league_events reads v_match_season_scope, so a SELECT revoke there has
-- to be decided together with the view options, which is outside this brief.
revoke insert, update, delete, truncate, references, trigger on public.events_archive          from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.rescrape_queue          from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.scraper_runs            from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.rebuild_alerts          from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.analytics_rebuild_steps from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.events_quarantine       from anon, authenticated;

-- Pipeline-only tables browsers already could not reach: RLS on as a second
-- layer, per the project rule for new tables. The owner and service_role bypass
-- RLS, so nothing in the pipeline changes.
alter table public.events_hold        enable row level security;
alter table public.events_swap_state  enable row level security;
alter table public.section8_proof     enable row level security;
alter table public.section8_candidate enable row level security;
alter table public.alert_settings     enable row level security;

-- ---------------------------------------------------------------------------
-- 3. Guarded section 8 apply.
--
-- A raise inside run_section8_apply rolls back everything, including its own
-- cron.unschedule, so the job would re-run a heavy matview rebuild every minute.
-- Catching it here means the apply work still rolls back, because the inner
-- block is a subtransaction, while the unschedule and the failure record
-- commit.
create or replace function public.run_section8_apply_guarded()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare r jsonb;
begin
  begin
    r := public.run_section8_apply();
    return r;
  exception when others then
    perform cron.unschedule('section8-apply');
    insert into public.rebuild_alerts (severity, kind, subject, detail)
    values ('error', 'section8_apply_failed', 'matviews',
            jsonb_build_object('sqlstate', sqlstate, 'message', sqlerrm))
    on conflict (kind, subject) where notified_at is null do nothing;
    return jsonb_build_object('status', 'failed', 'message', sqlerrm);
  end;
end $fn$;
revoke execute on function public.run_section8_apply_guarded() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Invariant suite timing.
--
-- run_invariants reports violations but not where the time goes, and the
-- point of the events swap was that the suite had become a thirteen minute
-- scan of nine million rows. Each check runs on its own clock with its own
-- error caught, so one broken check is recorded as broken instead of hiding
-- every result after it.
create table if not exists public.invariant_timings (
  run_at      timestamptz not null,
  name        text not null,
  severity    text,
  violations  bigint,
  elapsed_ms  numeric,
  error       text,
  primary key (run_at, name)
);
alter table public.invariant_timings enable row level security;
revoke all on public.invariant_timings from anon, authenticated;

create or replace function public.time_invariant_suite()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  v_run  timestamptz := now();
  r      record;
  v_n    bigint;
  t0     timestamptz;
  t_all  timestamptz := clock_timestamp();
begin
  if not pg_try_advisory_xact_lock(hashtextextended('invariant-timing',0)) then
    return jsonb_build_object('status','busy');
  end if;

  for r in select name, severity, check_sql from public.invariants where enabled order by name loop
    t0 := clock_timestamp();
    begin
      execute r.check_sql into v_n;
      insert into public.invariant_timings (run_at, name, severity, violations, elapsed_ms)
      values (v_run, r.name, r.severity, v_n,
              round(extract(epoch from clock_timestamp() - t0)::numeric * 1000, 1));
    exception when others then
      insert into public.invariant_timings (run_at, name, severity, violations, elapsed_ms, error)
      values (v_run, r.name, r.severity, null,
              round(extract(epoch from clock_timestamp() - t0)::numeric * 1000, 1), sqlerrm);
    end;
  end loop;

  perform cron.unschedule('invariant-timing');
  return jsonb_build_object('run_at', v_run,
    'checks', (select count(*) from public.invariant_timings where run_at = v_run),
    'total_seconds', round(extract(epoch from clock_timestamp() - t_all)::numeric, 1));
end $fn$;
revoke execute on function public.time_invariant_suite() from public, anon, authenticated;
