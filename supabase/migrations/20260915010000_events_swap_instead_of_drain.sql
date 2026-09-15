-- Replace the delete-based archive drain with a copy, prove, then swap.
--
-- The drain moved 2.0M of 8.1M rows in about forty minutes, which is a five hour
-- finish, and it would not have delivered the speedup it exists for. Measured
-- rather than assumed:
--
--   events                  7,138 MB, 2,923,254 dead tuples
--   last autovacuum         12 September, two days before this ran
--   indexes                 twelve, 1,431 MB total
--   idx_events_qualifiers_gin  288 MB, 26 scans in the lifetime of the database
--   events_pkey             198 MB, 1 scan
--
-- Deleting is the expensive half. Every deleted row pays maintenance on twelve
-- indexes, and the GIN index on a large jsonb column is far worse than a btree
-- because each delete has to clean posting list entries for every key in the
-- document. Autovacuum was already two days behind and each tick made it worse.
--
-- Worse, archive_events_run had no COMMIT inside its batch loop, so a whole tick
-- was one transaction. The terminated tick had been running fifteen minutes,
-- which is fifteen minutes of dead tuples that autovacuum could not reclaim
-- while they accumulated.
--
-- And the finish line was not where it looked. A plain VACUUM does not shrink a
-- heap with holes through the middle of it, so after the last row moved events
-- would still have been a 7 GB file holding under a gigabyte of live rows, and
-- every matview reading v_league_events would still have traversed all of it.
-- The delete plan needed a VACUUM FULL rewrite afterwards that nobody had
-- costed.
--
-- Copy then truncate avoids both halves. The copy is append only, so no index
-- maintenance on events and no dead tuples. TRUNCATE is O(1), reclaims the file
-- immediately rather than leaving it to a second rewrite, and leaves the indexes
-- empty so refilling them from the live remainder is cheap.
--
-- Checked before choosing this: events has no triggers, no inbound foreign keys
-- and no constraints of its own, so nothing fires or blocks on truncate. RLS and
-- its single policy survive. id is GENERATED ALWAYS AS IDENTITY, so the reinsert
-- needs OVERRIDING SYSTEM VALUE and the truncate must not say RESTART IDENTITY,
-- or the next scrape writes ids that already exist in events_archive.
--
-- ---------------------------------------------------------------------------
-- The truncate is the only irreversible step in this brief, so it is gated on a
-- proof rather than on the absence of an error, and the two phases before it
-- each commit on their own.
--
--   baseline  count both tables and record the total. This is the number every
--             later check is measured against, taken from the live database
--             rather than from a constant remembered in a comment.
--   copy      append every non-live row to events_archive. Append only.
--   hold      write every live and every orphan row to events_hold, a normal
--             logged table, committed. The live remainder is durable on disk in
--             its own right before anything is destroyed, not sitting in a temp
--             table or a CTE inside the transaction that does the destroying.
--   verify    see 20260915030000_events_swap_verify_set_membership.sql, which
--             replaced this phase before it ran. Counting proves the copy is
--             the right size, not that it is the right rows.
--   swap      only now: truncate, reinsert from the committed hold table.
--
-- events_hold is deliberately not dropped. It is roughly a gigabyte and it is
-- the only independent copy of the live season; it goes when the rebuild after
-- this has passed its gate, not a moment before.

create table if not exists public.events_swap_state (
  id             integer primary key default 1 check (id = 1),
  phase          text not null default 'baseline'
                 check (phase in ('baseline','copy','hold','verify','swap','done','failed')),
  started_at     timestamptz not null default now(),
  baseline_rows  bigint,
  archive_start  bigint,
  copied_rows    bigint,
  held_rows      bigint,
  restored_rows  bigint,
  copy_seconds   numeric,
  hold_seconds   numeric,
  swap_seconds   numeric,
  note           text
);
insert into public.events_swap_state (id) values (1) on conflict (id) do nothing;
revoke all on public.events_swap_state from anon, authenticated;

-- Rows whose game_id is not in matches at all stay with the live remainder
-- rather than moving to the archive. That is what the delete-based drain did,
-- since it only ever selected game_ids it found in matches, and this is a
-- mechanical replacement, not a change of policy. The invariant at the bottom
-- counts them so they stop being invisible.
create or replace function public.events_swap_tick()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  v_phase text; v_base bigint; v_arch0 bigint;
  t0 timestamptz := clock_timestamp();
  n bigint; n_arch bigint; n_hold bigint; n_both bigint; n_back bigint;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('events-swap',0)) then
    return jsonb_build_object('status','busy');
  end if;
  select phase, baseline_rows, archive_start into v_phase, v_base, v_arch0
    from public.events_swap_state where id = 1;

  -- -------------------------------------------------------------------------
  if v_phase = 'baseline' then
    select count(*) into n from public.events;
    select count(*) into n_arch from public.events_archive;
    update public.events_swap_state
       set phase='copy', baseline_rows = n + n_arch, archive_start = n_arch,
           note = format('events %s, archive %s at baseline', n, n_arch)
     where id = 1;
    return jsonb_build_object('phase','baseline','events',n,'archive',n_arch,
      'baseline_total', n + n_arch,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));

  -- -------------------------------------------------------------------------
  elsif v_phase = 'copy' then
    insert into public.events_archive
    select e.*
      from public.events e
      join public.matches m on m.game_id = e.game_id
     where not m.is_live_scope
       and not exists (select 1 from public.events_archive a where a.game_id = e.game_id);
    get diagnostics n = row_count;
    update public.events_swap_state
       set phase='hold', copied_rows = n,
           copy_seconds = round(extract(epoch from clock_timestamp()-t0)::numeric,1)
     where id = 1;
    return jsonb_build_object('phase','copy','copied',n,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));

  -- -------------------------------------------------------------------------
  elsif v_phase = 'hold' then
    -- A normal logged table, not unlogged and not temp. This has to survive an
    -- unclean shutdown on its own, because between the truncate and the reinsert
    -- it is the only copy of the live season that exists.
    drop table if exists public.events_hold;
    create table public.events_hold as
    select e.* from public.events e
     where exists (select 1 from public.matches m
                    where m.game_id = e.game_id and m.is_live_scope)
        or not exists (select 1 from public.matches m where m.game_id = e.game_id);
    get diagnostics n = row_count;
    create index idx_events_hold_game on public.events_hold (game_id);
    revoke all on public.events_hold from anon, authenticated;
    update public.events_swap_state
       set phase='verify', held_rows = n,
           hold_seconds = round(extract(epoch from clock_timestamp()-t0)::numeric,1)
     where id = 1;
    return jsonb_build_object('phase','hold','held',n,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));

  -- -------------------------------------------------------------------------
  elsif v_phase = 'verify' then
    select count(*) into n_arch from public.events_archive;
    select count(*) into n_hold from public.events_hold;
    select count(*) into n_both from (
      select game_id from public.events_archive
      intersect
      select game_id from public.events_hold) z;

    if n_hold = 0 then
      update public.events_swap_state set phase='failed',
        note='hold is empty; events untouched' where id=1;
      perform public.raise_alert('error','events_swap_failed','events',
        jsonb_build_object('reason','hold is empty'));
      perform cron.unschedule('events-swap');
      raise exception 'events_swap: hold is empty, refusing to truncate';
    end if;

    if n_both <> 0 then
      update public.events_swap_state set phase='failed',
        note=format('%s game_ids in both archive and hold; events untouched', n_both) where id=1;
      perform public.raise_alert('error','events_swap_failed','events',
        jsonb_build_object('reason','archive and hold overlap','games',n_both));
      perform cron.unschedule('events-swap');
      raise exception 'events_swap: % game_ids appear in both archive and hold', n_both;
    end if;

    if n_arch + n_hold <> v_base then
      update public.events_swap_state set phase='failed',
        note=format('archive %s + hold %s = %s, baseline %s; events untouched',
                    n_arch, n_hold, n_arch+n_hold, v_base) where id=1;
      perform public.raise_alert('error','events_swap_failed','events',
        jsonb_build_object('archive',n_arch,'hold',n_hold,
                           'sum',n_arch+n_hold,'baseline',v_base));
      perform cron.unschedule('events-swap');
      raise exception 'events_swap: archive % + hold % = %, baseline was %. Refusing to truncate.',
        n_arch, n_hold, n_arch + n_hold, v_base;
    end if;

    update public.events_swap_state set phase='swap',
      note=format('verified: archive %s + hold %s = baseline %s, no overlap',
                  n_arch, n_hold, v_base) where id=1;
    return jsonb_build_object('phase','verify','archive',n_arch,'hold',n_hold,
      'baseline',v_base,'overlapping_games',n_both,'verified',true);

  -- -------------------------------------------------------------------------
  elsif v_phase = 'swap' then
    -- No RESTART IDENTITY. The sequence has to keep counting or the next scrape
    -- writes ids that already exist in events_archive.
    truncate table public.events;
    insert into public.events overriding system value select * from public.events_hold;
    get diagnostics n_back = row_count;
    select held_rows into n_hold from public.events_swap_state where id=1;
    if n_back <> n_hold then
      raise exception 'events_swap: held % rows but restored %, rolling back', n_hold, n_back;
    end if;
    analyze public.events;

    update public.events_swap_state
       set phase='done', restored_rows = n_back,
           swap_seconds = round(extract(epoch from clock_timestamp()-t0)::numeric,1),
           note = note || '; events_hold retained until the next rebuild passes its gate'
     where id = 1;

    perform cron.alter_job(3, active := true);
    perform cron.alter_job(4, active := true);
    perform cron.alter_job(5, active := true);
    perform cron.alter_job(6, active := true);
    perform cron.unschedule('events-swap');
    insert into public.rebuild_alerts (severity, kind, subject, detail)
    values ('warn','archive_split_complete','events',
            jsonb_build_object('restored',n_back,'note','events swap finished, cron restored'))
    on conflict (kind, subject) where notified_at is null do nothing;

    return jsonb_build_object('phase','swap','restored',n_back,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));
  end if;

  perform cron.unschedule('events-swap');
  return jsonb_build_object('phase', v_phase, 'status','nothing to do');
end $fn$;

revoke all on function public.events_swap_tick() from anon, authenticated;

-- The old drain is superseded. Leaving a second, slower path to the same
-- outcome around is how someone reaches for the wrong one later.
drop function if exists public.archive_events_run(int);
drop function if exists public.archive_events_batch(int);
drop function if exists public.archive_drain_watchdog();

-- Orphan event rows, previously invisible because the drain simply never
-- selected them and nothing else looked.
insert into public.invariants (name, description, check_sql, severity, enabled) values
('events_without_fixture',
 'Every event row must belong to a fixture in matches. The archive drain only ever moved game_ids it found in matches, so an orphan row was never moved and never counted; it just sat in the live table forever. Warn rather than error, because an orphan is a scraper artefact that harms nothing downstream, every live view joins matches, but it should not be invisible.',
 $q$select count(*) from (select distinct game_id from public.events) e
    where not exists (select 1 from public.matches m where m.game_id = e.game_id)$q$,
 'warn', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;
