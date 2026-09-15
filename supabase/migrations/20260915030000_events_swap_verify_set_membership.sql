-- Row counts prove the copy is the right size, not that it is the right rows.
-- A correct total sitting on the wrong membership would be unrecoverable, and
-- the truncate is the one irreversible step in this brief, so the verify phase
-- now proves membership as well as arithmetic.
--
-- Four checks, all of which must pass:
--   a. archive + hold = baseline exactly
--   b. no game_id appears in both destinations
--   c. no live-scope fixture appears in the archive. If one did, the live season
--      would have been half moved into cold storage and the truncate would
--      destroy the only remaining copy of the other half.
--   d. every game currently in events is present in exactly one destination
--      with exactly as many rows, compared per game by full outer join.
--
-- (d) subsumes (a) and is the real proof. Totals are preserved by one game
-- copied twice against another missed entirely, which is exactly the failure
-- that leaves the arithmetic looking correct while the data is wrong. A per
-- game comparison cannot be fooled that way.
--
-- On failure the run stops at 'failed' with events completely intact and the
-- first ten offending games recorded in the note, so the disagreement is
-- diagnosable rather than just fatal.

create or replace function public.events_swap_tick()
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  v_phase text; v_base bigint;
  t0 timestamptz := clock_timestamp();
  n bigint; n_arch bigint; n_hold bigint; n_both bigint; n_back bigint;
  n_live_in_arch bigint; n_missing bigint; n_mismatch bigint; v_sample text;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('events-swap',0)) then
    return jsonb_build_object('status','busy');
  end if;
  select phase, baseline_rows into v_phase, v_base
    from public.events_swap_state where id = 1;

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

  elsif v_phase = 'hold' then
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

  elsif v_phase = 'verify' then
    select count(*) into n_arch from public.events_archive;
    select count(*) into n_hold from public.events_hold;

    -- 1. The two destinations must not overlap.
    select count(*) into n_both from (
      select game_id from public.events_archive
      intersect
      select game_id from public.events_hold) z;

    -- 2. The archive must contain no live-scope fixture. If it does, the live
    --    season has been half moved into cold storage and the truncate would
    --    destroy the only remaining copy of the other half.
    select count(*) into n_live_in_arch
      from (select distinct game_id from public.events_archive) a
      join public.matches m on m.game_id = a.game_id
     where m.is_live_scope;

    -- 3. Every game currently in events must be present in exactly one
    --    destination, with exactly as many rows. This is the real proof: it
    --    subsumes the total, and it catches one game copied twice against
    --    another missed entirely, which is the error that leaves a correct
    --    count sitting on the wrong rows.
    create temp table _swap_cmp on commit drop as
    with src as (
      select game_id, count(*) as n from public.events group by game_id
    ), dst as (
      select game_id, count(*) as n from (
        select game_id from public.events_archive
        union all
        select game_id from public.events_hold) u
      group by game_id
    )
    select coalesce(s.game_id, d.game_id) as game_id,
           s.n as src_n, d.n as dst_n
      from src s full outer join dst d on d.game_id = s.game_id
     where s.game_id is null or d.game_id is null or s.n <> d.n;

    select count(*) filter (where dst_n is null),
           count(*) filter (where dst_n is not null and src_n is not null and src_n <> dst_n)
      into n_missing, n_mismatch
      from _swap_cmp;
    select string_agg(format('%s src=%s dst=%s', game_id,
             coalesce(src_n::text,'-'), coalesce(dst_n::text,'-')), '; ')
      into v_sample from (select * from _swap_cmp limit 10) x;

    if n_hold = 0 then
      update public.events_swap_state set phase='failed',
        note='hold is empty; events untouched' where id=1;
      perform cron.unschedule('events-swap');
      raise exception 'events_swap: hold is empty, refusing to truncate';
    end if;

    if n_both <> 0 or n_live_in_arch <> 0 or n_missing <> 0 or n_mismatch <> 0
       or n_arch + n_hold <> v_base then
      update public.events_swap_state set phase='failed',
        note=format('REFUSED. overlap=%s live_in_archive=%s missing=%s per_game_mismatch=%s '
                    'archive=%s hold=%s sum=%s baseline=%s. events untouched. sample: %s',
                    n_both, n_live_in_arch, n_missing, n_mismatch,
                    n_arch, n_hold, n_arch+n_hold, v_base, coalesce(v_sample,'none'))
       where id=1;
      perform cron.unschedule('events-swap');
      raise exception 'events_swap refused to truncate: overlap=%, live_in_archive=%, missing=%, per_game_mismatch=%, sum=% vs baseline=%',
        n_both, n_live_in_arch, n_missing, n_mismatch, n_arch + n_hold, v_base;
    end if;

    update public.events_swap_state set phase='swap',
      note=format('verified: archive %s + hold %s = baseline %s, no overlap, '
                  'no live fixture in archive, per-game row counts identical across all games',
                  n_arch, n_hold, v_base) where id=1;
    return jsonb_build_object('phase','verify','archive',n_arch,'hold',n_hold,
      'baseline',v_base,'overlapping_games',n_both,'live_games_in_archive',n_live_in_arch,
      'games_missing',n_missing,'per_game_mismatches',n_mismatch,'verified',true,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));

  elsif v_phase = 'swap' then
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
