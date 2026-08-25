\set ON_ERROR_STOP on
with objects as (
 select c.relname name,jsonb_build_object(
  'definition',coalesce(m.definition,v.definition),
  'owner',pg_get_userbyid(c.relowner),
  'comment',obj_description(c.oid,'pg_class'),
  'reloptions',coalesce((select jsonb_agg(x order by x) from unnest(c.reloptions) x),'[]'::jsonb),
  'indexes',coalesce((select jsonb_agg(jsonb_build_object('name',i.indexname,'definition',i.indexdef)
    order by i.indexname) from pg_indexes i where i.schemaname='public' and i.tablename=c.relname),'[]'::jsonb),
  'acl',coalesce((select jsonb_agg(jsonb_build_object(
    'grantor',pg_get_userbyid(ax.grantor),'grantee',coalesce(pg_get_userbyid(nullif(ax.grantee,0)),'PUBLIC'),
    'privilege',ax.privilege_type,'grantable',ax.is_grantable)
    order by pg_get_userbyid(ax.grantor),coalesce(pg_get_userbyid(nullif(ax.grantee,0)),'PUBLIC'),
             ax.privilege_type,ax.is_grantable)
    from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) ax),'[]'::jsonb)) value
 from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
 left join pg_matviews m on m.schemaname='public' and m.matviewname=c.relname
 left join pg_views v on v.schemaname='public' and v.viewname=c.relname
 where c.relname in ('mv_game_goals','mv_team_league','mv_team_match','mv_team_lanes',
  'v_season_stats','mv_state_segments','v_team_sample','mv_team_percentiles',
  'mv_player_percentiles','mv_team_breakdown','v_team_directory','mv_team_all'))
select jsonb_build_object(
 'objects',(select jsonb_object_agg(name,value order by name) from objects),
 'registry',(select to_jsonb(x) from league_mart_entry_objects x where object_name='mv_game_goals'),
 'severities',(select jsonb_object_agg(name,severity order by name) from invariants),
 'invariant_results',(select jsonb_agg(to_jsonb(x) order by x.name) from run_invariants() x),
 'raw_counts',jsonb_build_object('events',(select count(*) from events),
  'matches',(select count(*) from matches),'sequences',(select count(*) from sequences),
  'lineups',(select count(*) from lineups),'period5',(select count(*) from events where period=5)))::text;
