-- A correct rebuild that leaves the API returning 503 is indistinguishable from
-- a broken one.
--
-- After the section 8 lock storm cleared, the site kept returning 503 until a
-- manual notify pgrst, 'reload schema'. The cause was PostgREST's schema cache,
-- not data or grants.
--
-- Supabase already installs pgrst_ddl_watch (ddl_command_end) and
-- pgrst_drop_watch (sql_drop), so every committed DROP and CREATE, including
-- every one inside replace_matview, already sends a reload at commit. The
-- success path was never missing a notify. What wedged the cache was the path
-- no event trigger can reach: ghost launches of job 12 and terminated backends
-- each held ACCESS EXCLUSIVE on public matviews for minutes and then rolled back
-- or died. PostgREST's schema introspection blocked behind those locks, and a
-- NOTIFY issued inside a transaction that rolls back is discarded, so nothing
-- told PostgREST to reload once the locks cleared.
--
-- Two changes:
--   1. replace_matview and events_swap_tick issue the reload explicitly on
--      every path that commits. On success this duplicates the event triggers,
--      harmlessly. The swap's verify refusal now records its failure and
--      returns instead of raising, so the failure record, the unschedule and the
--      reload all commit; nothing has been truncated at that point.
--   2. schema_reload_watch, run every 30 seconds in its own committing
--      transaction, sends the reload on the transition from "some backend holds
--      ACCESS EXCLUSIVE on a public relation" to "none does". This is the one
--      that covers rollback and termination, and it does not care how the
--      lock-holding work ended.

-- ---------------------------------------------------------------------------
-- 1a. replace_matview: explicit reload before returning.
create or replace function public.replace_matview(p_target text, p_new_body text)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  v_oid oid := p_target::regclass::oid;
  v_snap text := 'zz_snap_' || replace(replace(p_target,'.','_'),'"','');
  v_deps jsonb := '[]'::jsonb; v_pending jsonb; v_next jsonb; v_idx jsonb;
  v_made int; d jsonb; s text; r record;
  n_before bigint; n_after bigint; only_b bigint; only_a bigint;
  t0 timestamptz := clock_timestamp();
begin
  execute format('drop table if exists %I', v_snap);
  execute format('create table %I as select * from %s', v_snap, p_target);
  execute format('select count(*) from %I', v_snap) into n_before;

  for r in
    with recursive tree as (
      select v_oid as oid
      union
      select dc.oid from tree t
      join pg_depend dp on dp.refobjid = t.oid
                       and dp.refclassid = 'pg_class'::regclass
                       and dp.classid = 'pg_rewrite'::regclass
      join pg_rewrite rw on rw.oid = dp.objid
      join pg_class dc on dc.oid = rw.ev_class and dc.oid <> t.oid
    )
    select c.oid, c.relkind, n.nspname, c.relname,
           pg_get_viewdef(c.oid, true) as def,
           coalesce((select jsonb_agg(pg_get_indexdef(i.indexrelid))
                       from pg_index i where i.indrelid = c.oid), '[]'::jsonb) as idx,
           coalesce((select jsonb_agg(distinct format('grant %s on %I.%I to %I',
                       a.privilege_type, n.nspname, c.relname, a.grantee::regrole::text))
                       from aclexplode(c.relacl) a
                      where a.grantee <> 0 and a.grantee <> c.relowner), '[]'::jsonb) as grants
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where c.oid in (select oid from tree) and c.oid <> v_oid
  loop
    v_deps := v_deps || jsonb_build_array(jsonb_build_object('kind', r.relkind,
      'nsp', r.nspname, 'name', r.relname, 'def', r.def, 'idx', r.idx, 'grants', r.grants));
  end loop;

  select coalesce(jsonb_agg(pg_get_indexdef(i.indexrelid)), '[]'::jsonb) into v_idx
    from pg_index i where i.indrelid = v_oid;
  select coalesce(jsonb_agg(distinct format('grant %s on %s to %I',
           a.privilege_type, p_target, a.grantee::regrole::text)), '[]'::jsonb)
    into v_pending
    from pg_class c, aclexplode(c.relacl) a
   where c.oid = v_oid and a.grantee <> 0 and a.grantee <> c.relowner;

  execute format('drop materialized view %s cascade', p_target);
  execute format('create materialized view %s as %s with data', p_target, rtrim(rtrim(p_new_body), ';'));
  for s in select jsonb_array_elements_text(v_idx) loop execute s; end loop;
  for s in select jsonb_array_elements_text(v_pending) loop execute s; end loop;

  v_next := v_deps;
  loop
    v_pending := v_next; v_next := '[]'::jsonb; v_made := 0;
    for d in select jsonb_array_elements(v_pending) loop
      begin
        if d->>'kind' = 'm' then
          execute format('create materialized view %I.%I as %s with data',
                         d->>'nsp', d->>'name', rtrim(rtrim(d->>'def'), ';'));
        else
          execute format('create view %I.%I as %s',
                         d->>'nsp', d->>'name', rtrim(rtrim(d->>'def'), ';'));
        end if;
        for s in select jsonb_array_elements_text(d->'idx') loop execute s; end loop;
        for s in select jsonb_array_elements_text(d->'grants') loop execute s; end loop;
        v_made := v_made + 1;
      exception when others then
        v_next := v_next || jsonb_build_array(d);
      end;
    end loop;
    exit when jsonb_array_length(v_next) = 0;
    if v_made = 0 then
      raise exception 'replace_matview: % dependents could not be recreated: %',
        jsonb_array_length(v_next),
        (select string_agg(x->>'name', ', ') from jsonb_array_elements(v_next) x);
    end if;
  end loop;

  execute format('select count(*) from %s', p_target) into n_after;
  execute format('select count(*) from (select * from %I except select * from %s) z', v_snap, p_target) into only_b;
  execute format('select count(*) from (select * from %s except select * from %I) z', p_target, v_snap) into only_a;
  insert into public.section8_proof (matview, rows_before, rows_after, only_before, only_after, identical)
  values (p_target, n_before, n_after, only_b, only_a, (only_b = 0 and only_a = 0 and n_before = n_after));
  if only_b <> 0 or only_a <> 0 or n_before <> n_after then
    raise exception 'replace_matview: % is not byte identical. before %, after %, only_before %, only_after %',
      p_target, n_before, n_after, only_b, only_a;
  end if;

  execute format('drop table if exists %I', v_snap);
  -- Relations were dropped and recreated with new oids. Delivered at commit.
  perform pg_notify('pgrst', 'reload schema');
  return jsonb_build_object('matview', p_target, 'rows', n_after,
    'dependents_recreated', jsonb_array_length(v_deps), 'identical', true,
    'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));
end $fn$;
revoke execute on function public.replace_matview(text, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1b. events_swap_tick: reload after hold and swap; verify refusal commits.
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
    n := public.events_swap_copy_phase();
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
    perform pg_notify('pgrst', 'reload schema');
    return jsonb_build_object('phase','hold','held',n,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));

  elsif v_phase = 'verify' then
    select count(*) into n_arch from public.events_archive;
    select count(*) into n_hold from public.events_hold;

    select count(*) into n_both from (
      select game_id from public.events_archive
      intersect
      select game_id from public.events_hold) z;

    select count(*) into n_live_in_arch
      from (select distinct game_id from public.events_archive) a
      join public.matches m on m.game_id = a.game_id
     where m.is_live_scope;

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

    -- A refusal records itself and returns rather than raising, so the failure
    -- record, the unschedule and the schema reload all commit. Nothing has been
    -- truncated at this point, so there is no work to roll back.
    if n_hold = 0 or n_both <> 0 or n_live_in_arch <> 0 or n_missing <> 0 or n_mismatch <> 0
       or n_arch + n_hold <> v_base then
      update public.events_swap_state set phase='failed',
        note=format('REFUSED. hold=%s overlap=%s live_in_archive=%s missing=%s per_game_mismatch=%s '
                    'archive=%s sum=%s baseline=%s. events untouched. sample: %s',
                    n_hold, n_both, n_live_in_arch, n_missing, n_mismatch,
                    n_arch, n_arch+n_hold, v_base, coalesce(v_sample,'none'))
       where id=1;
      perform public.raise_alert('error', 'events_swap_refused', 'events',
        jsonb_build_object('hold', n_hold, 'overlap', n_both, 'live_in_archive', n_live_in_arch,
                           'missing', n_missing, 'per_game_mismatch', n_mismatch,
                           'sum', n_arch + n_hold, 'baseline', v_base));
      perform public.retire_cron_job('events-swap');
      perform pg_notify('pgrst', 'reload schema');
      return jsonb_build_object('phase','verify','verified',false,
        'overlapping_games',n_both,'live_games_in_archive',n_live_in_arch,
        'games_missing',n_missing,'per_game_mismatches',n_mismatch);
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
      -- Must raise: this rolls the truncate back, which is the point. The reload
      -- cannot ride on a rollback; schema_reload_watch covers this path.
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
    perform public.retire_cron_job('events-swap');
    insert into public.rebuild_alerts (severity, kind, subject, detail)
    values ('warn','archive_split_complete','events',
            jsonb_build_object('restored',n_back,'note','events swap finished, cron restored'))
    on conflict (kind, subject) where notified_at is null do nothing;
    perform pg_notify('pgrst', 'reload schema');

    return jsonb_build_object('phase','swap','restored',n_back,
      'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));
  end if;

  perform public.retire_cron_job('events-swap');
  return jsonb_build_object('phase', v_phase, 'status','nothing to do');
end $fn$;
revoke execute on function public.events_swap_tick() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Reload when exclusive locks clear, however the lock-holding work ended.
create table if not exists public.schema_reload_watch (
  id             integer primary key default 1 check (id = 1),
  exclusive_seen boolean not null default false,
  last_reload_at timestamptz,
  reloads        bigint not null default 0
);
insert into public.schema_reload_watch (id) values (1) on conflict (id) do nothing;
alter table public.schema_reload_watch enable row level security;
revoke all on public.schema_reload_watch from anon, authenticated;

-- The first version of this watcher joined pg_locks to pg_class to filter to
-- the public schema, and a cron probe that created a table and held ACCESS
-- EXCLUSIVE on it for 75 seconds was never seen. A relation created and locked
-- inside one uncommitted transaction has no pg_class row visible to any other
-- snapshot, so the inner join dropped its lock. That is also exactly what
-- replace_matview does while recreating a matview. A lock whose relation is not
-- yet visible in pg_class now counts. Autovacuum is excluded, because its
-- truncate phase takes ACCESS EXCLUSIVE briefly and would cause pointless
-- reloads. Every transition is logged, so a reload can be attributed to the
-- work that caused it instead of inferred.
create table if not exists public.schema_reload_log (
  at      timestamptz not null default clock_timestamp(),
  kind    text not null,
  detail  jsonb
);
alter table public.schema_reload_log enable row level security;
revoke all on public.schema_reload_log from anon, authenticated;

create or replace function public.reload_schema_after_exclusive_locks()
returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_held jsonb; v_prev boolean;
begin
  select jsonb_agg(jsonb_build_object(
           'pid', l.pid,
           'relation', coalesce(c.relname, 'uncommitted oid ' || l.relation::text),
           'query', left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 80)))
    into v_held
    from pg_locks l
    left join pg_class c on c.oid = l.relation
    left join pg_stat_activity a on a.pid = l.pid
   where l.locktype = 'relation'
     and l.mode = 'AccessExclusiveLock' and l.granted
     and l.database = (select oid from pg_database where datname = current_database())
     and l.pid <> pg_backend_pid()
     and coalesce(a.backend_type, '') <> 'autovacuum worker'
     and (c.oid is null or c.relnamespace = 'public'::regnamespace);

  select exclusive_seen into v_prev from public.schema_reload_watch where id = 1;

  if v_held is not null then
    if not v_prev then
      insert into public.schema_reload_log (kind, detail) values ('exclusive_seen', v_held);
    end if;
    update public.schema_reload_watch set exclusive_seen = true where id = 1;
    return 'exclusive locks held';
  end if;

  if v_prev then
    perform pg_notify('pgrst', 'reload schema');
    update public.schema_reload_watch
       set exclusive_seen = false, last_reload_at = now(), reloads = reloads + 1
     where id = 1;
    insert into public.schema_reload_log (kind, detail) values ('reload_sent', null);
    return 'locks cleared: schema reload sent';
  end if;

  return 'quiet';
end $fn$;
revoke execute on function public.reload_schema_after_exclusive_locks() from public, anon, authenticated;

select cron.schedule('schema-reload-watch', '30 seconds',
  $$select public.reload_schema_after_exclusive_locks();$$);
