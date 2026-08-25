-- GENERATED FILE. DO NOT HAND EDIT.
-- Source: pipeline/tools/generate_cup_isolation.sql
-- REVERSE: expects forward definitions and restores the exact captured baseline.

begin;
set local statement_timeout = '1800s';

do $preflight$
declare captured jsonb:='{"mv_team_all": {"hash": "459d13d615a17dc6eada75fb6c65db47", "kind": "m", "order": 2}, "mv_game_goals": {"hash": "689253a4f10b3990f213002ef1ecf21a", "kind": "m", "order": 0}, "mv_team_lanes": {"hash": "b3f83667f38d0a7decea0e96e913da33", "kind": "m", "order": 0}, "mv_team_match": {"hash": "93660f91104a3ffaa2aa002c534e2cad", "kind": "m", "order": 0}, "v_team_sample": {"hash": "2c7a5e3b9b2f363be465d9515c1fa36f", "kind": "v", "order": 0}, "mv_team_league": {"hash": "b285772da5a03d498e29763dbb9c5ee8", "kind": "m", "order": 0}, "v_season_stats": {"hash": "92d2c248034f822ecb582d9797a27013", "kind": "v", "order": 0}, "v_team_directory": {"hash": "dab4ce535bb9b052852879c2cdd379c2", "kind": "v", "order": 2}, "mv_state_segments": {"hash": "9ea100fc750329e9755e286c8194640b", "kind": "m", "order": 0}, "mv_team_breakdown": {"hash": "ca7351dbc0ed99485bd643aa7b91f7d6", "kind": "m", "order": 1}, "mv_team_percentiles": {"hash": "15da8cd38fec59ee34aa895c5bf36b3f", "kind": "m", "order": 1}, "mv_player_percentiles": {"hash": "ce3fa2555b1d0cbb734e1a6870fd3686", "kind": "m", "order": 1}}'::jsonb; actual jsonb; problem text;
begin
 create temp table _pf_seed(name text primary key) on commit drop;
 insert into _pf_seed select jsonb_array_elements_text('["mv_game_goals", "mv_player_percentiles", "mv_state_segments", "mv_team_breakdown", "mv_team_lanes", "mv_team_league", "mv_team_match", "v_season_stats", "v_team_directory", "v_team_sample"]'::jsonb);
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
 if problem is not null then raise exception 'PREFLIGHT FAILED. %',problem; end if;
 raise notice 'Preflight OK: % objects.',(select count(*) from jsonb_object_keys(captured));
end $preflight$;
create temp table _pre_raw on commit drop as select
 (select count(*) from events) events,(select count(*) from matches) matches,
 (select count(*) from sequences) sequences,(select count(*) from lineups) lineups,
 (select count(*) from events where period=5) period5;


-- TOPOLOGY
-- DEPTH mv_game_goals=0
-- DEPTH mv_state_segments=0
-- DEPTH mv_team_lanes=0
-- DEPTH mv_team_league=0
-- DEPTH mv_team_match=0
-- DEPTH v_season_stats=0
-- DEPTH v_team_sample=0
-- DEPTH mv_player_percentiles=1
-- DEPTH mv_team_breakdown=1
-- DEPTH mv_team_percentiles=1
-- DEPTH mv_team_all=2
-- DEPTH v_team_directory=2

-- DROP: reverse topological order, no CASCADE
drop view if exists public.v_team_directory;
drop materialized view if exists public.mv_team_all;
drop materialized view if exists public.mv_team_percentiles;
drop materialized view if exists public.mv_team_breakdown;
drop materialized view if exists public.mv_player_percentiles;
drop view if exists public.v_team_sample;
drop view if exists public.v_season_stats;
drop materialized view if exists public.mv_team_match;
drop materialized view if exists public.mv_team_league;
drop materialized view if exists public.mv_team_lanes;
drop materialized view if exists public.mv_state_segments;
drop materialized view if exists public.mv_game_goals;

-- CREATE: topological order
create materialized view public.mv_game_goals as
SELECT game_id,
    team AS scoring_team
   FROM events e
  WHERE is_goal;
CREATE INDEX mv_game_goals_idx ON public.mv_game_goals USING btree (game_id);
alter materialized view public.mv_game_goals owner to postgres;
revoke all on public.mv_game_goals from public, anon, authenticated, service_role;
grant SELECT on public.mv_game_goals to anon;
grant SELECT on public.mv_game_goals to authenticated;
grant DELETE on public.mv_game_goals to service_role with grant option;
grant INSERT on public.mv_game_goals to service_role with grant option;
grant MAINTAIN on public.mv_game_goals to service_role with grant option;
grant REFERENCES on public.mv_game_goals to service_role with grant option;
grant SELECT on public.mv_game_goals to service_role with grant option;
grant TRIGGER on public.mv_game_goals to service_role with grant option;
grant TRUNCATE on public.mv_game_goals to service_role with grant option;
grant UPDATE on public.mv_game_goals to service_role with grant option;
comment on materialized view public.mv_game_goals is 'fixture: exact original comment';

create materialized view public.mv_state_segments as
SELECT game_id,
    team
   FROM events
  WHERE (team IS NOT NULL);
alter materialized view public.mv_state_segments owner to postgres;
revoke all on public.mv_state_segments from public, anon, authenticated, service_role;
grant SELECT on public.mv_state_segments to anon;
grant SELECT on public.mv_state_segments to authenticated;

create materialized view public.mv_team_lanes as
SELECT game_id,
    home_team AS team
   FROM matches m;
alter materialized view public.mv_team_lanes owner to postgres;
revoke all on public.mv_team_lanes from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_lanes to anon;
grant SELECT on public.mv_team_lanes to authenticated;

create materialized view public.mv_team_league as
SELECT team,
    min(league) AS league
   FROM events
  WHERE (team IS NOT NULL)
  GROUP BY team;
CREATE UNIQUE INDEX mv_team_league_pk ON public.mv_team_league USING btree (team);
alter materialized view public.mv_team_league owner to postgres;
revoke all on public.mv_team_league from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_league to anon;
grant SELECT on public.mv_team_league to authenticated;
grant SELECT on public.mv_team_league to service_role;

create materialized view public.mv_team_match as
SELECT game_id,
    team,
    count(*) AS n
   FROM events
  GROUP BY game_id, team;
alter materialized view public.mv_team_match owner to postgres;
revoke all on public.mv_team_match from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_match to anon;
grant SELECT on public.mv_team_match to authenticated;

create view public.v_season_stats as
SELECT m.game_id,
    e.team
   FROM (events e
     JOIN matches m ON ((m.game_id = e.game_id)));
alter view public.v_season_stats owner to postgres;
revoke all on public.v_season_stats from public, anon, authenticated, service_role;
grant SELECT on public.v_season_stats to anon;
grant SELECT on public.v_season_stats to authenticated;

create view public.v_team_sample as
SELECT team,
    min(league) AS league,
    count(*) AS matches
   FROM sequences s
  GROUP BY team;
alter view public.v_team_sample owner to postgres;
revoke all on public.v_team_sample from public, anon, authenticated, service_role;
grant SELECT on public.v_team_sample to anon;
grant SELECT on public.v_team_sample to authenticated;
alter view public.v_team_sample set (security_invoker=true);

create materialized view public.mv_player_percentiles as
SELECT p.team,
    COALESCE(pl.league, 'USA-MLS'::text) AS league
   FROM (mv_team_match p
     LEFT JOIN mv_team_league pl ON ((pl.team = p.team)));
alter materialized view public.mv_player_percentiles owner to postgres;
revoke all on public.mv_player_percentiles from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_percentiles to anon;
grant SELECT on public.mv_player_percentiles to authenticated;

create materialized view public.mv_team_breakdown as
SELECT b.team,
    COALESCE(zz.league, 'USA-MLS'::text) AS league,
    s.matches
   FROM ((mv_team_match b
     LEFT JOIN mv_team_league zz ON ((zz.team = b.team)))
     JOIN v_team_sample s ON ((s.team = b.team)));
alter materialized view public.mv_team_breakdown owner to postgres;
revoke all on public.mv_team_breakdown from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_breakdown to anon;
grant SELECT on public.mv_team_breakdown to authenticated;

create materialized view public.mv_team_percentiles as
SELECT t.team,
    COALESCE(tl.league, 'USA-MLS'::text) AS league
   FROM (mv_team_match t
     LEFT JOIN mv_team_league tl ON ((tl.team = t.team)));
alter materialized view public.mv_team_percentiles owner to postgres;
revoke all on public.mv_team_percentiles from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_percentiles to anon;
grant SELECT on public.mv_team_percentiles to authenticated;

create materialized view public.mv_team_all as
SELECT team
   FROM mv_team_percentiles a;
alter materialized view public.mv_team_all owner to postgres;
revoke all on public.mv_team_all from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_all to anon;
grant SELECT on public.mv_team_all to authenticated;

create view public.v_team_directory as
SELECT team,
    league
   FROM mv_team_percentiles d;
alter view public.v_team_directory owner to postgres;
revoke all on public.v_team_directory from public, anon, authenticated, service_role;
grant SELECT on public.v_team_directory to anon;
grant SELECT on public.v_team_directory to authenticated;


delete from league_mart_entry_objects where object_name='mv_game_goals';
insert into league_mart_entry_objects
select (jsonb_populate_record(null::league_mart_entry_objects,'{"note": "fixture original registry note -- do not hardcode", "enabled": false, "object_name": "mv_game_goals"}'::jsonb)).*;
do $restore_severity$
declare item record; changed int; baseline jsonb:='{"team_league_resolves": "error", "league_mart_reads_scoped_sources": "warn", "no_non_league_fixture_in_metrics": "info", "no_non_league_row_in_league_outputs": "warn"}'::jsonb;
begin
 for item in select key,value#>>'{}' severity from jsonb_each(baseline) loop
  update invariants set severity=item.severity where name=item.key;
  get diagnostics changed=row_count;
  if changed<>1 then raise exception 'REVERSE RESTORE FAILED for invariant %',item.key; end if;
 end loop;
end $restore_severity$;


select build_insights();
select polish_insights();
select refresh_site_summaries();

do $metadata$
declare expected jsonb:='{"mv_team_all": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_game_goals": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": true, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": "fixture: exact original comment", "indexes": [{"name": "mv_game_goals_idx", "definition": "CREATE INDEX mv_game_goals_idx ON public.mv_game_goals USING btree (game_id)"}], "reloptions": []}, "mv_team_lanes": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_team_match": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "v_team_sample": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": ["security_invoker=true"]}, "mv_team_league": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_league_pk", "definition": "CREATE UNIQUE INDEX mv_team_league_pk ON public.mv_team_league USING btree (team)"}], "reloptions": []}, "v_season_stats": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "v_team_directory": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_state_segments": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_team_breakdown": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_team_percentiles": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_player_percentiles": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}}'::jsonb; actual jsonb; problem text;
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
 if problem is not null then raise exception 'METADATA ASSERT FAILED: %',problem; end if;
 raise notice 'Metadata exact: % objects.',(select count(*) from jsonb_object_keys(expected));
end $metadata$;


do $reverse_assert$
declare baseline_results jsonb:='[{"name": "goals_reconcile", "severity": "error", "violations": 1}, {"name": "league_mart_reads_scoped_sources", "severity": "warn", "violations": 1}, {"name": "no_non_league_fixture_in_metrics", "severity": "info", "violations": 1}, {"name": "no_non_league_row_in_league_outputs", "severity": "warn", "violations": 1}, {"name": "team_league_resolves", "severity": "error", "violations": 1}]'::jsonb; actual_results jsonb;
 baseline_registry jsonb:='{"note": "fixture original registry note -- do not hardcode", "enabled": false, "object_name": "mv_game_goals"}'::jsonb; actual_registry jsonb;
 baseline_severities jsonb:='{"team_league_resolves": "error", "league_mart_reads_scoped_sources": "warn", "no_non_league_fixture_in_metrics": "info", "no_non_league_row_in_league_outputs": "warn"}'::jsonb; actual_severities jsonb;
begin
 select coalesce(jsonb_agg(to_jsonb(x) order by x.name),'[]'::jsonb) into actual_results from run_invariants() x;
 select to_jsonb(x) into actual_registry from league_mart_entry_objects x where object_name='mv_game_goals';
 select coalesce(jsonb_object_agg(name,severity order by name),'{}'::jsonb) into actual_severities
 from invariants where baseline_severities?name;
 if actual_results is distinct from baseline_results then raise exception
  'REVERSE BASELINE FAILED. Invariant results differ. expected=% actual=%',baseline_results,actual_results; end if;
 if actual_registry is distinct from baseline_registry then raise exception 'REVERSE BASELINE FAILED. Registry row differs.'; end if;
 if actual_severities is distinct from baseline_severities then raise exception 'REVERSE BASELINE FAILED. Severities differ.'; end if;
 raise notice 'Reverse exact baseline restored; verify_rebuild intentionally not called.';
end $reverse_assert$;


commit;
