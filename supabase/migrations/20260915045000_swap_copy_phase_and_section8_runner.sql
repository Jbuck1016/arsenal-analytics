-- Two functions applied live during the events swap and the section 8 proof,
-- recorded here so the repository matches the database.

-- ---------------------------------------------------------------------------
-- events_swap_copy_phase. The first copy tick wrote its anti-join as
-- "not exists (select 1 from events_archive a where a.game_id = e.game_id)".
-- The planner hashed all 2.77M archive rows, spilled to temp files, and read
-- those batches back for every one of 6.19M event rows: thirty three minutes in
-- it was still on BuffileRead. The question is only which games are already
-- archived, about five thousand of them, so the archive side is collapsed to
-- its distinct game_ids first and the hash fits in memory.
--
-- Terminating the slow tick was not free. Its rolled-back insert left about
-- 3.4M dead tuples in events_archive, and autovacuum spent the next half hour
-- cleaning them while the retry ran. The retry copied 5,324,080 rows in
-- 2,935.8 seconds. Recorded because a second kill would have cost more than it
-- saved, and the next person tempted to restart a slow copy should know that.
create or replace function public.events_swap_copy_phase()
returns bigint
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare n bigint;
begin
  create temp table _archived_games on commit drop as
  select distinct game_id from public.events_archive;
  create index on _archived_games (game_id);
  analyze _archived_games;

  insert into public.events_archive
  select e.*
    from public.events e
    join public.matches m on m.game_id = e.game_id
   where not m.is_live_scope
     and not exists (select 1 from _archived_games d where d.game_id = e.game_id);
  get diagnostics n = row_count;
  return n;
end $fn$;
revoke all on function public.events_swap_copy_phase() from anon, authenticated;

-- ---------------------------------------------------------------------------
-- run_section8_proof. The proof reads v_league_events for each candidate and
-- compares the result to the live matview in both directions. Run through the
-- connector it outlives the request window, and a timed-out request leaves its
-- backend running, which is how two orphaned counts earlier in this brief
-- ended up fighting the swap for IO. So it runs as a one-shot cron job that
-- records into section8_proof and unschedules itself.
create or replace function public.run_section8_proof()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare c record; out_j jsonb := '[]'::jsonb;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('section8-proof',0)) then
    return jsonb_build_object('status','busy');
  end if;
  for c in select matview, body from public.section8_candidate order by matview loop
    out_j := out_j || jsonb_build_array(public.prove_new_definition(c.matview, c.body));
  end loop;
  perform cron.unschedule('section8-proof');
  return out_j;
end $fn$;
revoke all on function public.run_section8_proof() from anon, authenticated;

-- ---------------------------------------------------------------------------
-- run_section8_same_data_proof. The first proof, above, compared each candidate
-- on today's data against matview rows last refreshed on 14 September, and both
-- came back different: mv_team_buildphase 8 rows each way on 126, mv_player_xt
-- 105 against 109 on 2,810 against 2,814. That comparison cannot tell a changed
-- definition from changed data, and the data had changed. The metrics steps of
-- the 14 September rebuild finished by 21:11 UTC, and all three re-scrape queue
-- entries arrived afterwards, Como and Torino at 21:20:56 and 1952894 at 22:27.
-- A queued fixture leaves live scope, so today's v_league_events excludes three
-- fixtures the stored rows include.
--
-- This proof runs the current stored definition and the candidate on the same
-- data in one transaction, which isolates the definition, and separately
-- measures stored rows against their own definition run today, which is the
-- drift. Both land in section8_proof under labelled names.
create or replace function public.run_section8_same_data_proof()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  c record; v_old text;
  n_stored bigint; n_old bigint; n_new bigint;
  def_ob bigint; def_oa bigint; drift_sb bigint; drift_ob bigint;
  out_j jsonb := '[]'::jsonb;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('section8-samedata',0)) then
    return jsonb_build_object('status','busy');
  end if;

  for c in select matview, body from public.section8_candidate order by matview loop
    v_old := rtrim(rtrim(pg_get_viewdef(c.matview::regclass, true)), ';');
    execute format('create temp table _s8_old on commit drop as %s', v_old);
    execute format('create temp table _s8_new on commit drop as %s', rtrim(rtrim(c.body), ';'));

    execute format('select count(*) from %s', c.matview) into n_stored;
    select count(*) into n_old from _s8_old;
    select count(*) into n_new from _s8_new;
    select count(*) into def_ob from (select * from _s8_old except select * from _s8_new) z;
    select count(*) into def_oa from (select * from _s8_new except select * from _s8_old) z;
    execute format('select count(*) from (select * from %s except select * from _s8_old) z', c.matview) into drift_sb;
    execute format('select count(*) from (select * from _s8_old except select * from %s) z', c.matview) into drift_ob;

    insert into public.section8_proof (matview, rows_before, rows_after, only_before, only_after, identical)
    values (c.matview || ' [same data: current def vs candidate]', n_old, n_new, def_ob, def_oa,
            def_ob = 0 and def_oa = 0 and n_old = n_new),
           (c.matview || ' [drift: stored rows vs current def today]', n_stored, n_old, drift_sb, drift_ob,
            drift_sb = 0 and drift_ob = 0 and n_stored = n_old);

    out_j := out_j || jsonb_build_array(jsonb_build_object(
      'matview', c.matview,
      'definition', jsonb_build_object('current_def_rows', n_old, 'candidate_rows', n_new,
                     'only_current', def_ob, 'only_candidate', def_oa),
      'drift', jsonb_build_object('stored_rows', n_stored, 'current_def_rows', n_old,
                     'only_stored', drift_sb, 'only_today', drift_ob)));

    drop table _s8_old;
    drop table _s8_new;
  end loop;

  perform cron.unschedule('section8-samedata');
  return out_j;
end $fn$;
revoke all on function public.run_section8_same_data_proof() from anon, authenticated;

-- ---------------------------------------------------------------------------
-- run_section8_apply. Gated on the same-data proof, never on its absence: for
-- every candidate the latest "[same data: current def vs candidate]" row must
-- say identical, or it refuses and unschedules itself. It deliberately does not
-- read the first proof, which compared against stale rows.
--
-- Each target is refreshed with its current definition first, inside the same
-- transaction. replace_matview snapshots the stored rows and compares them with
-- the rebuilt matview; against rows left over from 14 September that comparison
-- would fail on data drift alone and refuse a correct rewrite, which is exactly
-- what the first draft of this runner would have done. After the refresh,
-- snapshot and rebuild read identical data, so any difference is the
-- definition, and replace_matview raises, rolling back the refresh, the targets
-- and every recreated dependent together.
create or replace function public.run_section8_apply()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare c record; out_j jsonb := '[]'::jsonb; v_ok boolean;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('section8-apply',0)) then
    return jsonb_build_object('status','busy');
  end if;

  for c in select matview from public.section8_candidate loop
    select identical into v_ok from public.section8_proof
     where matview = c.matview || ' [same data: current def vs candidate]'
     order by checked_at desc limit 1;
    if v_ok is distinct from true then
      perform cron.unschedule('section8-apply');
      raise exception 'section8 apply refused: same-data proof for % is %',
        c.matview, coalesce(v_ok::text, 'missing');
    end if;
  end loop;

  for c in select matview, body from public.section8_candidate order by matview loop
    execute format('refresh materialized view %s', c.matview);
    out_j := out_j || jsonb_build_array(public.replace_matview(c.matview, c.body));
  end loop;

  perform cron.unschedule('section8-apply');
  insert into public.rebuild_alerts (severity, kind, subject, detail)
  values ('warn','section8_applied','matviews', out_j)
  on conflict (kind, subject) where notified_at is null do nothing;
  return out_j;
end $fn$;
revoke all on function public.run_section8_apply() from anon, authenticated;
