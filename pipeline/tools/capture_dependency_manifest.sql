-- Read-only capture. Uses the same all-path topology as the generator,
-- including dependencies whose source and dependent are both seeds.
\set ON_ERROR_STOP on
create temporary table _manifest_seed(name text primary key);
insert into _manifest_seed values
 ('mv_game_goals'),('mv_team_league'),('mv_team_match'),('mv_team_lanes'),
 ('mv_team_attackphase'),('mv_team_buildphase'),('mv_team_zones'),('mv_team_sequences'),
 ('v_season_stats'),('mv_squad_role'),('mv_state_segments'),('mv_league_summary'),
 ('mv_league_availability'),('mv_team_breakdown'),('v_seq_directness'),('v_team_sample'),
 ('v_team_directory'),('mv_player_state_output'),('mv_player_percentiles');
delete from _manifest_seed s where not exists(select 1 from pg_class c join pg_namespace n
 on n.oid=c.relnamespace and n.nspname='public' where c.relname=s.name and c.relkind in('m','v'));

create temporary table _manifest_edges as
select distinct src.oid source_oid,dep.oid dependent_oid
from pg_depend d join pg_rewrite r on r.oid=d.objid
join pg_class dep on dep.oid=r.ev_class and dep.relkind in('m','v')
join pg_namespace dn on dn.oid=dep.relnamespace and dn.nspname='public'
join pg_class src on src.oid=d.refobjid and src.relkind in('m','v')
join pg_namespace sn on sn.oid=src.relnamespace and sn.nspname='public'
where dep.oid<>src.oid;

with recursive closure_paths(oid,path) as (
 select c.oid,array[c.oid] from _manifest_seed s join pg_class c on c.relname=s.name
 join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
 union all select e.dependent_oid,p.path||e.dependent_oid from closure_paths p
 join _manifest_edges e on e.source_oid=p.oid where not e.dependent_oid=any(p.path)),
closure as (select distinct oid from closure_paths),
topology_paths(oid,depth,path) as (
 select oid,0,array[oid] from closure
 union all select e.dependent_oid,p.depth+1,p.path||e.dependent_oid from topology_paths p
 join _manifest_edges e on e.source_oid=p.oid join closure c on c.oid=e.dependent_oid
 where not e.dependent_oid=any(p.path)),
topology as (select oid,max(depth)::int create_order from topology_paths group by oid)
select t.create_order,c.relkind,c.relname name,pg_get_userbyid(c.relowner) owner,
 coalesce((select jsonb_agg(x order by x) from unnest(c.reloptions)x),'[]'::jsonb) reloptions,
 obj_description(c.oid,'pg_class') comment,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.indexname,'definition',i.indexdef)
  order by i.indexname) from pg_indexes i where i.schemaname='public' and i.tablename=c.relname),'[]'::jsonb) indexes,
 coalesce((select jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(a.grantor),
  'grantee',coalesce(pg_get_userbyid(nullif(a.grantee,0)),'PUBLIC'),'privilege',a.privilege_type,
  'grantable',a.is_grantable) order by pg_get_userbyid(a.grantor),
  coalesce(pg_get_userbyid(nullif(a.grantee,0)),'PUBLIC'),a.privilege_type,a.is_grantable)
  from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner)))a),'[]'::jsonb) acl,
 coalesce(m.definition,v.definition) definition
from topology t join pg_class c on c.oid=t.oid
left join pg_matviews m on m.schemaname='public' and m.matviewname=c.relname
left join pg_views v on v.schemaname='public' and v.viewname=c.relname
order by t.create_order,c.relname;
