-- Section 8. mv_team_buildphase and mv_player_xt, output byte identical.
--
-- Measured before: mv_team_buildphase did not complete in a 115 second window,
-- mv_player_xt took 71 seconds.
--
-- mv_team_buildphase made three separate full passes over v_league_events, one
-- for goalkeeper passes, one for deep passes and touches, one for centre-back
-- progression, and used jsonb containment inside FILTER clauses, which cannot
-- use the GIN index. Collapsed to a single pass with LEFT JOINs to
-- mv_player_pool and mv_player_role.
--
-- Safety check done first, because this rewrite is only valid if those joins
-- cannot multiply rows: mv_player_pool is 2,243 rows over 2,243 distinct
-- player_ids, mv_player_role is 1,792 over 1,792. One row per player each, so a
-- LEFT JOIN adds no duplicates and the FILTER counts are unchanged.
--
-- The one subtlety worth stating: the original deep CTE carried
-- "WHERE e.team IS NOT NULL AND e.x IS NOT NULL", which the gk and cb CTEs did
-- not. That filter therefore applies to all_passes and all_touches as well, so
-- in the single pass every deep-derived FILTER carries "e.x IS NOT NULL"
-- explicitly. Dropping it would silently change two denominators.
--
-- mv_player_xt called the SQL function xt_at() four times per row, each one a
-- lookup against xt_grid. Replaced with two joins to the grid.
--
-- Safety check: xt_grid is a complete 12 by 8 grid, 96 rows, one row per
-- (x_bin, y_bin), no null values, and the bin arithmetic clamps into [0,11] and
-- [0,7]. Every input therefore maps to exactly one existing row, so the join is
-- exactly equivalent to the function rather than approximately, and inner versus
-- left join makes no difference.

-- ---------------------------------------------------------------------------
-- Proof harness. Snapshot, rebuild, diff both directions, revert on any
-- difference. Run apply_section8() rather than the DDL by hand.

create table if not exists public.section8_proof (
  checked_at   timestamptz not null default now(),
  matview      text not null,
  rows_before  bigint,
  rows_after   bigint,
  only_before  bigint,
  only_after   bigint,
  identical    boolean
);

create or replace function public.prove_matview_identical(p_matview text, p_snapshot text)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare n_before bigint; n_after bigint; only_b bigint; only_a bigint;
begin
  execute format('select count(*) from %I', p_snapshot) into n_before;
  execute format('select count(*) from %I', p_matview) into n_after;
  execute format('select count(*) from (select * from %I except select * from %I) z',
                 p_snapshot, p_matview) into only_b;
  execute format('select count(*) from (select * from %I except select * from %I) z',
                 p_matview, p_snapshot) into only_a;
  insert into public.section8_proof (matview, rows_before, rows_after, only_before, only_after, identical)
  values (p_matview, n_before, n_after, only_b, only_a, (only_b = 0 and only_a = 0 and n_before = n_after));
  return jsonb_build_object('matview',p_matview,'rows_before',n_before,'rows_after',n_after,
    'only_in_before',only_b,'only_in_after',only_a,
    'identical',(only_b = 0 and only_a = 0 and n_before = n_after));
end $fn$;

-- ---------------------------------------------------------------------------
-- The candidate bodies live in a table so that the proof and the apply read the
-- same text. Proving one string and applying another is exactly the kind of gap
-- this brief exists to close.

create table if not exists public.section8_candidate (
  matview text primary key,
  body    text not null,
  note    text
);

insert into public.section8_candidate (matview, body, note) values
('public.mv_team_buildphase', $body$
 WITH m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        ), ev AS (
         SELECT e.team,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.type = 'Pass'::text AND e.x < 33.3::double precision) AS d3_passes,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.type = 'Pass'::text AND e.x < 33.3::double precision AND e.outcome_type = 'Successful'::text) AS d3_ok,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.type = 'Pass'::text AND e.x < 33.3::double precision AND e.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb) AS d3_long,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.type = 'Pass'::text AND e.x < 33.3::double precision AND e.end_x < 33.3::double precision AND e.outcome_type = 'Successful'::text) AS d3_circulate,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.type = 'Pass'::text) AS all_passes,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.is_touch AND e.x < 33.3::double precision) AS d3_touches,
            count(*) FILTER (WHERE e.x IS NOT NULL AND e.is_touch) AS all_touches,
            count(*) FILTER (WHERE p.player_id IS NOT NULL AND e.type = 'Pass'::text) AS gk_passes,
            count(*) FILTER (WHERE p.player_id IS NOT NULL AND e.type = 'Pass'::text AND e.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb) AS gk_long,
            count(*) FILTER (WHERE r.player_id IS NOT NULL AND e.type = 'Pass'::text) AS cb_passes,
            count(*) FILTER (WHERE r.player_id IS NOT NULL AND e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND (e.x < 50::double precision AND e.end_x < 50::double precision AND (e.end_x - e.x) >= 30::double precision OR e.x < 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 15::double precision OR e.x >= 50::double precision AND e.end_x >= 50::double precision AND (e.end_x - e.x) >= 10::double precision)) AS cb_prog_raw
           FROM v_league_events e
             LEFT JOIN mv_player_pool p ON p.player_id = e.player_id AND p.modal_position = 'GK'::text
             LEFT JOIN mv_player_role r ON r.player_id = e.player_id AND r.pool = 'CB'::text
          WHERE e.team IS NOT NULL
          GROUP BY e.team
         HAVING count(*) FILTER (WHERE e.x IS NOT NULL) > 0
        ), exits AS (
         SELECT mv_team_sequences.team,
            count(*) FILTER (WHERE mv_team_sequences.start_x < 33.3::double precision) AS deep_starts,
            count(*) FILTER (WHERE mv_team_sequences.start_x < 33.3::double precision AND mv_team_sequences.max_x >= 66.7::double precision) AS deep_to_final,
            count(*) FILTER (WHERE mv_team_sequences.start_x < 33.3::double precision AND mv_team_sequences.max_x >= 50::double precision) AS deep_to_half
           FROM mv_team_sequences
          GROUP BY mv_team_sequences.team
        )
 SELECT d.team,
    round(100.0 * d.gk_long::numeric / NULLIF(d.gk_passes, 0)::numeric, 1) AS gk_long_pct,
    round(d.d3_passes::numeric / NULLIF(m.matches, 0)::numeric, 1) AS d3_passes_pg,
    round(100.0 * d.d3_passes::numeric / NULLIF(d.all_passes, 0)::numeric, 1) AS d3_pass_share,
    round(100.0 * d.d3_ok::numeric / NULLIF(d.d3_passes, 0)::numeric, 1) AS d3_accuracy,
    round(100.0 * d.d3_long::numeric / NULLIF(d.d3_passes, 0)::numeric, 1) AS d3_long_pct,
    round(d.d3_circulate::numeric / NULLIF(m.matches, 0)::numeric, 1) AS deep_circulation_pg,
    round(100.0 * d.d3_touches::numeric / NULLIF(d.all_touches, 0)::numeric, 1) AS d3_touch_share,
    round((CASE WHEN d.cb_passes > 0 THEN d.cb_prog_raw END)::numeric / NULLIF(m.matches, 0)::numeric, 1) AS cb_prog_pg,
    round(100.0 * e.deep_to_half::numeric / NULLIF(e.deep_starts, 0)::numeric, 1) AS escape_pct,
    round(100.0 * e.deep_to_final::numeric / NULLIF(e.deep_starts, 0)::numeric, 1) AS deep_to_final_pct
   FROM ev d
     JOIN m ON m.team = d.team
     LEFT JOIN exits e ON e.team = d.team
$body$,
 'Three full passes over v_league_events collapsed to one. Two details carry the '
 'equivalence and both were wrong in the first draft. The deep CTE filtered '
 'x IS NOT NULL and the gk and cb CTEs did not, so every deep-derived FILTER now '
 'carries that predicate explicitly while the gk and cb ones deliberately do not; '
 'dropping it would change all_passes and all_touches, which are denominators. '
 'And cb was an inner join, so a team with no centre-back passes produced no row '
 'and cb_prog_pg came out NULL; a plain count would make it 0.0, so cb_prog is '
 'wrapped in a CASE that reproduces the absent group. The HAVING reproduces the '
 'deep CTE group existence rule for a team whose rows all have x NULL.'),

('public.mv_player_xt', $body$
 WITH pass_xt AS (
         SELECT e.player_id,
            sum(ge.v - gs.v) AS xt_pass,
            sum(GREATEST(ge.v - gs.v, 0::numeric)) AS xt_pass_pos
           FROM v_league_events e
             LEFT JOIN xt_grid gs ON gs.x_bin = LEAST(11, GREATEST(0, floor(e.x / 100::double precision * 12::double precision)::integer))
                                 AND gs.y_bin = LEAST(7, GREATEST(0, floor(e.y / 100::double precision * 8::double precision)::integer))
             LEFT JOIN xt_grid ge ON ge.x_bin = LEAST(11, GREATEST(0, floor(e.end_x / 100::double precision * 12::double precision)::integer))
                                 AND ge.y_bin = LEAST(7, GREATEST(0, floor(e.end_y / 100::double precision * 8::double precision)::integer))
          WHERE e.type = 'Pass'::text AND e.outcome_type = 'Successful'::text AND e.is_open_play AND e.x IS NOT NULL AND e.y IS NOT NULL AND e.end_x IS NOT NULL AND e.end_y IS NOT NULL
          GROUP BY e.player_id
        ), carry_xt AS (
         SELECT c.player_id,
            sum(ge.v - gs.v) AS xt_carry,
            sum(GREATEST(ge.v - gs.v, 0::numeric)) AS xt_carry_pos
           FROM mv_receipt_events c
             LEFT JOIN xt_grid gs ON gs.x_bin = LEAST(11, GREATEST(0, floor(c.start_x::double precision / 100::double precision * 12::double precision)::integer))
                                 AND gs.y_bin = LEAST(7, GREATEST(0, floor(c.start_y::double precision / 100::double precision * 8::double precision)::integer))
             LEFT JOIN xt_grid ge ON ge.x_bin = LEAST(11, GREATEST(0, floor(c.end_x::double precision / 100::double precision * 12::double precision)::integer))
                                 AND ge.y_bin = LEAST(7, GREATEST(0, floor(c.end_y::double precision / 100::double precision * 8::double precision)::integer))
          WHERE c.is_carry
          GROUP BY c.player_id
        )
 SELECT COALESCE(p.player_id, c.player_id) AS player_id,
    COALESCE(p.xt_pass, 0::numeric) AS xt_pass,
    COALESCE(c.xt_carry, 0::numeric) AS xt_carry,
    COALESCE(p.xt_pass, 0::numeric) + COALESCE(c.xt_carry, 0::numeric) AS xt_total,
    COALESCE(p.xt_pass_pos, 0::numeric) + COALESCE(c.xt_carry_pos, 0::numeric) AS xt_positive
   FROM pass_xt p
     FULL JOIN carry_xt c ON c.player_id = p.player_id
$body$,
 'xt_at was called four times per row. It is an IMMUTABLE SQL function whose body '
 'is a single scalar SELECT, so the planner inlines it to a correlated subquery '
 'and runs four index lookups per row over roughly nine hundred thousand passes. '
 'Two hash joins against a ninety six row grid replace all of them. LEFT rather '
 'than INNER join on purpose: the grid is complete today, and an inner join would '
 'be equivalent today, but if a bin were ever missing an inner join would silently '
 'drop the row while a left join yields NULL, which sum ignores, which is exactly '
 'what xt_at returning no row already does. The bin arithmetic is copied verbatim '
 'from the function, including the double precision casts, because floor then cast '
 'to integer is only exact if the division happens in the same type.')
on conflict (matview) do update set body = excluded.body, note = excluded.note;

-- apply_section8 proves first, then replaces, then proves again inside the same
-- transaction as the replace. Nothing here is safe to run twice by accident: the
-- second run proves the new body against itself and finds it identical, which is
-- true and harmless.
create or replace function public.apply_section8()
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare c record; out_j jsonb := '[]'::jsonb; r jsonb;
begin
  for c in select matview, body from public.section8_candidate order by matview loop
    r := public.replace_matview(c.matview, c.body);
    out_j := out_j || jsonb_build_array(r);
  end loop;
  return out_j;
end $fn$;

-- prove_new_definition takes no locks and changes nothing. It runs the candidate
-- query and compares it to what the matview currently holds, in both directions,
-- so the rewrite is proven before anything is dropped rather than after.
create or replace function public.prove_new_definition(p_target text, p_new_body text)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare n_before bigint; n_after bigint; only_b bigint; only_a bigint; t0 timestamptz := clock_timestamp();
begin
  execute format('select count(*) from %s', p_target) into n_before;
  execute format('select count(*) from (%s) z', p_new_body) into n_after;
  execute format('select count(*) from (select * from %s except select * from (%s) q) z', p_target, p_new_body) into only_b;
  execute format('select count(*) from (select * from (%s) q except select * from %s) z', p_new_body, p_target) into only_a;
  insert into public.section8_proof (matview, rows_before, rows_after, only_before, only_after, identical)
  values (p_target, n_before, n_after, only_b, only_a, (only_b = 0 and only_a = 0 and n_before = n_after));
  return jsonb_build_object('matview',p_target,'rows_before',n_before,'rows_after',n_after,
    'only_in_current',only_b,'only_in_candidate',only_a,
    'identical',(only_b = 0 and only_a = 0 and n_before = n_after),
    'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));
end $fn$;

-- ---------------------------------------------------------------------------
-- replace_matview. A matview definition cannot be replaced in place, so the
-- dependent tree has to come down with it. Written as a general helper rather
-- than two hand-rolled scripts, because this is the third time in this brief a
-- matview body has needed to change and it will not be the last.
--
-- Dependents are recreated WITH DATA, deliberately. WITH NO DATA would finish in
-- seconds, but it leaves every dependent empty until the next rebuild, and an
-- empty matview answers queries with a confident wrong number. A blocked reader
-- waits and then gets the right answer. That is the whole point of the brief.
--
-- Recreate order is resolved by repeated passes rather than by computing tree
-- depth: the dependency graph has diamonds, and the recursive depth query on
-- mv_player_xt did not finish in sixty seconds because the paths multiply. A
-- loop that retries what failed and stops when a pass makes no progress needs no
-- ordering at all.
create or replace function public.replace_matview(p_target text, p_new_body text)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
set statement_timeout to '0'
as $fn$
declare
  v_oid       oid := p_target::regclass::oid;
  v_snap      text := 'zz_snap_' || replace(replace(p_target,'.','_'),'"','');
  v_deps      jsonb := '[]'::jsonb;
  v_pending   jsonb;
  v_next      jsonb;
  v_idx       jsonb;
  v_made      int;
  d           jsonb;
  s           text;
  r           record;
  n_before bigint; n_after bigint; only_b bigint; only_a bigint;
  t0 timestamptz := clock_timestamp();
begin
  execute format('drop table if exists %I', v_snap);
  execute format('create table %I as select * from %s', v_snap, p_target);
  execute format('select count(*) from %I', v_snap) into n_before;

  -- Transitive closure by oid. Deduplicating on oid rather than on (oid, depth)
  -- is what keeps this finite on a diamond.
  for r in
    with recursive tree as (
      select v_oid as oid
      union
      select dc.oid
      from tree t
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
    v_deps := v_deps || jsonb_build_array(jsonb_build_object('kind', r.relkind, 'nsp', r.nspname,
      'name', r.relname, 'def', r.def, 'idx', r.idx, 'grants', r.grants));
  end loop;

  -- Indexes and grants on the target itself, which CASCADE also removes.
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

  -- Recreate dependents, retrying until a pass makes no progress.
  v_next := v_deps;
  loop
    v_pending := v_next;
    v_next := '[]'::jsonb;
    v_made := 0;
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

  -- Prove it after the fact as well as before. If this fails the exception rolls
  -- the whole transaction back, target and dependents together, so there is no
  -- half-applied state to clean up.
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
  return jsonb_build_object('matview', p_target, 'rows', n_after,
    'dependents_recreated', jsonb_array_length(v_deps), 'identical', true,
    'seconds', round(extract(epoch from clock_timestamp()-t0)::numeric,1));
end $fn$;
