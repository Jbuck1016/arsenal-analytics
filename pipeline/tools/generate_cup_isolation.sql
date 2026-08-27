-- Read-only generator for cup-isolation forward and reverse migrations.
-- Reverse is generated from the original database, but expects the forward
-- definitions at execution time and restores the originals.
\set ON_ERROR_STOP on
\if :{?direction} \else \set direction forward \endif
\if :{?expect_objects} \else \set expect_objects 36 \endif
\if :{?expect_matviews} \else \set expect_matviews 28 \endif
\if :{?expect_views} \else \set expect_views 8 \endif
set mig.expect_objects=:'expect_objects';
set mig.expect_matviews=:'expect_matviews';
set mig.expect_views=:'expect_views';

create function pg_temp._scope_definition(p_name text, p_def text)
returns text language plpgsql immutable as $fn$
declare q text:=p_def;
begin
  if p_name='mv_game_goals' then return regexp_replace(
    q, 'where[[:space:]]+([a-z_][a-z0-9_]*\.)?is_goal',
    E'where \\1is_goal and \\1period is distinct from 5', 'i'); end if;
  if p_name='mv_team_league' then return
    'select team, league, events from ('
    || ' select e.team, e.league, count(*) as events,'
    || ' row_number() over (partition by e.team order by count(*) desc, e.league) as rk'
    || ' from v_league_events e where e.team is not null'
    || ' group by e.team, e.league) ranked where rk = 1'; end if;
  q:=regexp_replace(q,
    'coalesce\([[:space:]]*([a-z_][a-z0-9_]*)\.league[[:space:]]*,[[:space:]]*''USA-MLS''(?:::text)?[[:space:]]*\)',
    E'\\1.league','gi');
  q:=regexp_replace(q,'\mleft[[:space:]]+join[[:space:]]+mv_team_league\M','join mv_team_league','gi');
  -- Preserve the raw table name as an alias. pg_get_viewdef qualifies columns
  -- with that implicit alias when the source had no explicit alias. Without
  -- it, replacing `from events` leaves references such as events.team broken.
  q:=regexp_replace(q,'(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)events\M',E'\\1\\2v_league_events as events','gi');
  q:=regexp_replace(q,'(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)matches\M',E'\\1\\2v_league_matches as matches','gi');
  q:=regexp_replace(q,'(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)sequences\M',E'\\1\\2v_league_sequences as sequences','gi');
  q:=regexp_replace(q,'(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)lineups\M',E'\\1\\2v_league_lineups as lineups','gi');
  -- If the original source already had an alias, retain that alias rather
  -- than emitting two. SQL clause keywords are excluded from this collapse.
  q:=regexp_replace(q,
    '\m(v_league_events|v_league_matches|v_league_sequences|v_league_lineups)[[:space:]]+as[[:space:]]+(events|matches|sequences|lineups)[[:space:]]+(?!where\M|join\M|left\M|right\M|full\M|inner\M|cross\M|group\M|order\M|having\M|limit\M|offset\M|union\M|intersect\M|except\M|on\M)([a-z_][a-z0-9_]*)',
    E'\\1 as \\3','gi');
  return q;
end
$fn$;

create temporary table _seed(name text primary key);
insert into _seed values
 ('mv_game_goals'),('mv_team_league'),('mv_team_match'),('mv_team_lanes'),
 ('mv_team_attackphase'),('mv_team_buildphase'),('mv_team_zones'),
 ('mv_team_sequences'),('v_season_stats'),('mv_squad_role'),
 ('mv_state_segments'),('mv_league_summary'),('mv_league_availability'),
 ('mv_team_breakdown'),('v_seq_directness'),('v_team_sample'),
 ('v_team_directory'),('mv_player_state_output'),('mv_player_percentiles');
delete from _seed s where not exists (
  select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname=s.name and c.relkind in ('m','v'));

-- Keep every path, including seed-to-seed edges. Deduplicate only after the
-- recursive walks have completed.
create temporary table _all_edges as
select distinct src.oid source_oid, dep.oid dependent_oid
from pg_depend d join pg_rewrite r on r.oid=d.objid
join pg_class dep on dep.oid=r.ev_class and dep.relkind in ('m','v')
join pg_namespace dn on dn.oid=dep.relnamespace and dn.nspname='public'
join pg_class src on src.oid=d.refobjid and src.relkind in ('m','v')
join pg_namespace sn on sn.oid=src.relnamespace and sn.nspname='public'
where dep.oid<>src.oid;

create temporary table _closure as
with recursive paths(oid,path) as (
  select c.oid,array[c.oid] from _seed s join pg_class c on c.relname=s.name
  join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  union all
  select e.dependent_oid,p.path||e.dependent_oid from paths p
  join _all_edges e on e.source_oid=p.oid where not e.dependent_oid=any(p.path))
select distinct oid from paths;

create temporary table _topology as
with recursive paths(oid,depth,path) as (
  select oid,0,array[oid] from _closure
  union all
  select e.dependent_oid,p.depth+1,p.path||e.dependent_oid from paths p
  join _all_edges e on e.source_oid=p.oid join _closure c on c.oid=e.dependent_oid
  where not e.dependent_oid=any(p.path))
select oid,max(depth)::int create_order from paths group by oid;

create temporary table _mig_objs as
select t.create_order,c.oid,c.relname::text name,c.relkind,
 pg_get_userbyid(c.relowner) owner,
 coalesce((select jsonb_agg(x order by x) from unnest(c.reloptions) x),'[]'::jsonb) reloptions,
 obj_description(c.oid,'pg_class') comment,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.indexname,'definition',i.indexdef)
   order by i.indexname) from pg_indexes i where i.schemaname='public' and i.tablename=c.relname),'[]'::jsonb) indexes,
 coalesce((select jsonb_agg(jsonb_build_object(
   'grantor',pg_get_userbyid(ax.grantor),
   'grantee',coalesce(pg_get_userbyid(nullif(ax.grantee,0)),'PUBLIC'),
   'privilege',ax.privilege_type,'grantable',ax.is_grantable)
   order by pg_get_userbyid(ax.grantor),coalesce(pg_get_userbyid(nullif(ax.grantee,0)),'PUBLIC'),
            ax.privilege_type,ax.is_grantable)
   from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) ax),'[]'::jsonb) acl,
 rtrim(trim(coalesce(m.definition,v.definition)),';') original_def
from _topology t join pg_class c on c.oid=t.oid
left join pg_matviews m on m.schemaname='public' and m.matviewname=c.relname
left join pg_views v on v.schemaname='public' and v.viewname=c.relname;
alter table _mig_objs add column forward_def text;
alter table _mig_objs add column forward_canonical text;
update _mig_objs set forward_def=pg_temp._scope_definition(name,original_def);

-- Ask PostgreSQL to parse and deparse each transformed query now. Reverse
-- preflight therefore compares the installed forward catalog definition with
-- the exact normalized form PostgreSQL will produce, not with rewrite text.
do $normalize$
declare item record; normalized text;
begin
 for item in select name,forward_def from _mig_objs order by create_order,name loop
  execute 'create view pg_temp._definition_probe as '||item.forward_def;
  select rtrim(trim(pg_get_viewdef('pg_temp._definition_probe'::regclass,false)),';') into normalized;
  drop view pg_temp._definition_probe;
  update _mig_objs set forward_canonical=normalized where name=item.name;
 end loop;
end $normalize$;

create temporary table _baseline as
select
 (select to_jsonb(x) from league_mart_entry_objects x where object_name='mv_game_goals') registry_row,
 coalesce((select jsonb_object_agg(name,severity order by name) from invariants where name in
  ('league_mart_reads_scoped_sources','no_non_league_fixture_in_metrics',
   'no_non_league_row_in_league_outputs','team_league_resolves')),'{}'::jsonb) severities,
 coalesce((select jsonb_agg(to_jsonb(x) order by x.name) from run_invariants() x),'[]'::jsonb) invariant_results;

do $guard$
declare n int; nm int; nv int; bad text;
begin
 select count(*),count(*) filter(where relkind='m'),count(*) filter(where relkind='v')
 into n,nm,nv from _mig_objs;
 if n<>current_setting('mig.expect_objects')::int
 or nm<>current_setting('mig.expect_matviews')::int
 or nv<>current_setting('mig.expect_views')::int then
  raise exception 'GENERATOR ABORT. Expected %/%/% objects/matviews/views, captured %/%/%.',
   current_setting('mig.expect_objects'),current_setting('mig.expect_matviews'),
   current_setting('mig.expect_views'),n,nm,nv; end if;
 if exists(select 1 from _mig_objs group by name having count(*)>1) then
  raise exception 'GENERATOR ABORT. Duplicate object rows.'; end if;
 if exists(select 1 from _mig_objs where original_def is null or forward_def is null or forward_canonical is null) then
  raise exception 'GENERATOR ABORT. Null definition captured.'; end if;
 if exists(select 1 from _all_edges e join _closure s on s.oid=e.source_oid
  join _closure d on d.oid=e.dependent_oid
  where (select create_order from _topology where oid=e.source_oid)>=
        (select create_order from _topology where oid=e.dependent_oid)) then
  raise exception 'GENERATOR ABORT. Dependency graph is cyclic or topology is invalid.'; end if;
 select string_agg(name,', ' order by name) into bad from _mig_objs
 where name<>'mv_game_goals' and original_def ~*
  '(with|,)[[:space:]]+(recursive[[:space:]]+)?"?(events|matches|sequences|lineups)"?[[:space:]]+as[[:space:]]*\(';
 if bad is not null then raise exception
  'GENERATOR ABORT. Raw-table CTE collision requires manual handling: %',bad; end if;
 if (select registry_row from _baseline) is null then
  raise exception 'GENERATOR ABORT. mv_game_goals registry baseline row is missing.'; end if;
 if (select count(*) from jsonb_object_keys((select severities from _baseline)))<>4 then
  raise exception 'GENERATOR ABORT. Expected four captured scoping invariant severities.'; end if;
end $guard$;

\echo '-- GENERATED FILE. DO NOT HAND EDIT.'
\echo '-- Source: pipeline/tools/generate_cup_isolation.sql'
select case when :'direction'='reverse'
 then '-- REVERSE: expects forward definitions and restores the exact captured baseline.'
 else '-- FORWARD: isolates league marts without changing raw rows.' end;
select E'\nbegin;\nset local statement_timeout = ''1800s'';';

-- Reverse uses forward_def hashes for preflight; forward uses original_def.
select format($sql$
do $preflight$
declare captured jsonb:=%L::jsonb; actual jsonb; problem text;
begin
 create temp table _pf_seed(name text primary key) on commit drop;
 insert into _pf_seed select jsonb_array_elements_text(%L::jsonb);
 create temp table _pf_edges on commit drop as
 select distinct src.oid source_oid,dep.oid dependent_oid
 from pg_depend d join pg_rewrite r on r.oid=d.objid
 join pg_class dep on dep.oid=r.ev_class and dep.relkind in ('m','v')
 join pg_namespace dn on dn.oid=dep.relnamespace and dn.nspname='public'
 join pg_class src on src.oid=d.refobjid and src.relkind in ('m','v')
 join pg_namespace sn on sn.oid=src.relnamespace and sn.nspname='public'
 where dep.oid<>src.oid;
 create temp table _pf_closure on commit drop as
 with recursive paths(oid,path) as (
  select c.oid,array[c.oid] from _pf_seed s join pg_class c on c.relname=s.name
  join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  union all select e.dependent_oid,p.path||e.dependent_oid from paths p
  join _pf_edges e on e.source_oid=p.oid where not e.dependent_oid=any(p.path))
 select distinct oid from paths;
 with recursive paths(oid,depth,path) as (
  select oid,0,array[oid] from _pf_closure
  union all select e.dependent_oid,p.depth+1,p.path||e.dependent_oid from paths p
  join _pf_edges e on e.source_oid=p.oid join _pf_closure c on c.oid=e.dependent_oid
  where not e.dependent_oid=any(p.path)),
 topo as (select oid,max(depth)::int create_order from paths group by oid)
 select jsonb_object_agg(c.relname,jsonb_build_object('kind',c.relkind::text,
  'order',t.create_order,'hash',md5(rtrim(trim(coalesce(m.definition,v.definition)),';')))) into actual
 from topo t join pg_class c on c.oid=t.oid
 left join pg_matviews m on m.schemaname='public' and m.matviewname=c.relname
 left join pg_views v on v.schemaname='public' and v.viewname=c.relname;
 select string_agg(msg,'; ') into problem from (
  select 'MISSING from live: '||k msg from jsonb_object_keys(captured) k where not actual?k
  union all select 'EXTRA in live: '||k from jsonb_object_keys(actual) k where not captured?k
  union all select 'KIND CHANGED: '||k from jsonb_object_keys(captured) k
   where actual?k and actual->k->>'kind' is distinct from captured->k->>'kind'
  union all select 'DEPTH CHANGED: '||k from jsonb_object_keys(captured) k
   where actual?k and actual->k->>'order' is distinct from captured->k->>'order'
  union all select 'DEFINITION DRIFTED: '||k from jsonb_object_keys(captured) k
   where actual?k and actual->k->>'hash' is distinct from captured->k->>'hash') q;
 if problem is not null then raise exception 'PREFLIGHT FAILED. %%',problem; end if;
 raise notice 'Preflight OK: %% objects.',(select count(*) from jsonb_object_keys(captured));
end $preflight$;
create temp table _pre_raw on commit drop as select
 (select count(*) from events) events,(select count(*) from matches) matches,
 (select count(*) from sequences) sequences,(select count(*) from lineups) lineups,
 (select count(*) from events where period=5) period5;
$sql$,
 (select jsonb_object_agg(name,jsonb_build_object('kind',relkind::text,'order',create_order,
  'hash',md5(case when :'direction'='reverse' then forward_canonical else original_def end)) order by name)
  from _mig_objs),(select jsonb_agg(name order by name) from _seed));

select E'\n-- TOPOLOGY';
select format('-- DEPTH %s=%s',name,create_order) from _mig_objs order by create_order,name;
select E'\n-- DROP: reverse topological order, no CASCADE';
select format('drop %s if exists public.%I;',case when relkind='m' then 'materialized view' else 'view' end,name)
from _mig_objs order by create_order desc,name desc;
select E'\n-- CREATE: topological order';
select format(E'create %s public.%I as\n%s;\n%s%s%s%s%s',
 case when relkind='m' then 'materialized view' else 'view' end,name,
 case when :'direction'='reverse' then original_def else forward_def end,
 coalesce((select string_agg((x->>'definition')||';',E'\n' order by x->>'name')
  from jsonb_array_elements(indexes) x)||E'\n',''),
 format(E'alter %s public.%I owner to %I;\n',case when relkind='m' then 'materialized view' else 'view' end,name,owner),
 format(E'revoke all on public.%I from public, anon, authenticated, service_role;\n',name)
 ||coalesce((select string_agg(format('grant %s on public.%I to %s%s;',x->>'privilege',name,
   case when x->>'grantee'='PUBLIC' then 'PUBLIC' else format('%I',x->>'grantee') end,
   case when (x->>'grantable')::boolean then ' with grant option' else '' end),E'\n'
   order by x->>'grantee',x->>'privilege') from jsonb_array_elements(acl) x
   where x->>'grantee'<>owner)||E'\n',''),
 case when comment is null then '' else format(E'comment on %s public.%I is %L;\n',
  case when relkind='m' then 'materialized view' else 'view' end,name,comment) end,
 case when jsonb_array_length(reloptions)=0 then '' else format(E'alter %s public.%I set (%s);\n',
  case when relkind='m' then 'materialized view' else 'view' end,name,
  (select string_agg(x,', ' order by x) from jsonb_array_elements_text(reloptions) x)) end)
from _mig_objs order by create_order,name;

select case when :'direction'='reverse' then format($r$
delete from league_mart_entry_objects where object_name='mv_game_goals';
insert into league_mart_entry_objects
select (jsonb_populate_record(null::league_mart_entry_objects,%L::jsonb)).*;
do $restore_severity$
declare item record; changed int; baseline jsonb:=%L::jsonb;
begin
 for item in select key,value#>>'{}' severity from jsonb_each(baseline) loop
  update invariants set severity=item.severity where name=item.key;
  get diagnostics changed=row_count;
  if changed<>1 then raise exception 'REVERSE RESTORE FAILED for invariant %%',item.key; end if;
 end loop;
end $restore_severity$;
$r$,(select registry_row from _baseline),(select severities from _baseline)) else
$f$delete from league_mart_entry_objects where object_name='mv_game_goals';$f$ end;

select E'\nselect build_insights();\nselect polish_insights();\nselect refresh_site_summaries();';

-- Exact runtime metadata assertion after both forward and reverse.
select format($m$
do $metadata$
declare expected jsonb:=%L::jsonb; actual jsonb; problem text;
begin
 select jsonb_object_agg(c.relname,jsonb_build_object(
  'kind',c.relkind::text,'owner',pg_get_userbyid(c.relowner),
  'reloptions',coalesce((select jsonb_agg(x order by x) from unnest(c.reloptions) x),'[]'::jsonb),
  'comment',obj_description(c.oid,'pg_class'),
  'indexes',coalesce((select jsonb_agg(jsonb_build_object('name',i.indexname,'definition',i.indexdef)
   order by i.indexname) from pg_indexes i where i.schemaname='public' and i.tablename=c.relname),'[]'::jsonb),
  'acl',coalesce((select jsonb_agg(jsonb_build_object(
   'grantor',pg_get_userbyid(ax.grantor),'grantee',coalesce(pg_get_userbyid(nullif(ax.grantee,0)),'PUBLIC'),
   'privilege',ax.privilege_type,'grantable',ax.is_grantable)
   order by pg_get_userbyid(ax.grantor),coalesce(pg_get_userbyid(nullif(ax.grantee,0)),'PUBLIC'),
            ax.privilege_type,ax.is_grantable)
   from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) ax),'[]'::jsonb)) order by c.relname)
 into actual from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
 where expected?c.relname;
 select string_agg(k,', ' order by k) into problem from jsonb_object_keys(expected) k
 where actual->k is distinct from expected->k;
 if problem is not null then raise exception 'METADATA ASSERT FAILED: %%',problem; end if;
 raise notice 'Metadata exact: %% objects.',(select count(*) from jsonb_object_keys(expected));
end $metadata$;
$m$,(select jsonb_object_agg(name,jsonb_build_object('kind',relkind::text,'owner',owner,
 'reloptions',reloptions,'comment',comment,'indexes',indexes,'acl',acl) order by name) from _mig_objs));

select case when :'direction'='reverse' then format($r$
do $reverse_assert$
declare baseline_results jsonb:=%L::jsonb; actual_results jsonb;
 baseline_registry jsonb:=%L::jsonb; actual_registry jsonb;
 baseline_severities jsonb:=%L::jsonb; actual_severities jsonb;
begin
 select coalesce(jsonb_agg(to_jsonb(x) order by x.name),'[]'::jsonb) into actual_results from run_invariants() x;
 select to_jsonb(x) into actual_registry from league_mart_entry_objects x where object_name='mv_game_goals';
 select coalesce(jsonb_object_agg(name,severity order by name),'{}'::jsonb) into actual_severities
 from invariants where baseline_severities?name;
 if actual_results is distinct from baseline_results then raise exception
  'REVERSE BASELINE FAILED. Invariant results differ. expected=%% actual=%%',baseline_results,actual_results; end if;
 if actual_registry is distinct from baseline_registry then raise exception 'REVERSE BASELINE FAILED. Registry row differs.'; end if;
 if actual_severities is distinct from baseline_severities then raise exception 'REVERSE BASELINE FAILED. Severities differ.'; end if;
 raise notice 'Reverse exact baseline restored; verify_rebuild intentionally not called.';
end $reverse_assert$;
$r$,(select invariant_results from _baseline),(select registry_row from _baseline),(select severities from _baseline)) else $f$
do $forward_assert$
declare p record; n bigint;
begin
 select * into p from _pre_raw;
 if (select count(*) from events)<>p.events or (select count(*) from matches)<>p.matches
 or (select count(*) from sequences)<>p.sequences or (select count(*) from lineups)<>p.lineups
 or (select count(*) from events where period=5)<>p.period5 then raise exception 'FORWARD ASSERT FAILED. Raw data changed.'; end if;
 select count(*) into n from v_league_sequences s where not exists
  (select 1 from mv_seq_state st where st.seq_uid=s.seq_uid);
 if n<>0 then raise exception 'FORWARD ASSERT FAILED. mv_seq_state misses % league sequences.',n; end if;
 select count(*) into n from (select distinct game_id,team from v_league_events where team is not null) e
 where not exists(select 1 from mv_state_segments ss where ss.game_id=e.game_id and ss.team=e.team);
 if n<>0 then raise exception 'FORWARD ASSERT FAILED. mv_state_segments misses % league pairs.',n; end if;
 if (select league from mv_team_league where team='Arsenal') is distinct from 'ENG-Premier League' then
  raise exception 'FORWARD ASSERT FAILED. Arsenal league resolution.'; end if;
 select count(*) into n from mv_team_match tm join matches m on m.game_id=tm.game_id
 join leagues l on l.league=m.league where l.competition_type<>'league';
 if n<>0 then raise exception 'FORWARD ASSERT FAILED. % non-league fixtures in team metrics.',n; end if;
end $forward_assert$;
do $promote$
declare n int;
begin
 select coalesce(sum(violations),0) into n from run_invariants() where name in
 ('league_mart_reads_scoped_sources','no_non_league_fixture_in_metrics',
  'no_non_league_row_in_league_outputs','team_league_resolves');
 if n<>0 then raise exception 'FORWARD ASSERT FAILED. Scoping violations=%.',n; end if;
 update invariants set severity='error' where name in
 ('league_mart_reads_scoped_sources','no_non_league_fixture_in_metrics',
  'no_non_league_row_in_league_outputs','team_league_resolves');
end $promote$;
select verify_rebuild();
$f$ end;
select E'\ncommit;';
