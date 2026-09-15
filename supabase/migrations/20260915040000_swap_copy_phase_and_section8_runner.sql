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
