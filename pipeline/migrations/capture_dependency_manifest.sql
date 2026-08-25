-- =====================================================================
-- capture_dependency_manifest.sql
-- Read-only. Emits the complete capture needed to write the destructive
-- cup-isolation migration: dependency tree in topological order, plus
-- definitions, indexes, owners, ACLs, comments and reloptions.
--
-- Run and save the output before writing that migration. The tree has
-- grown at every recapture (18 dependents, then 23, now 36 objects), so
-- writing from a stale capture is the main risk.
--
--   psql "$DATABASE_URL" -f pipeline/migrations/capture_dependency_manifest.sql > manifest.txt
-- =====================================================================
with recursive seed(name) as (values
 ('mv_game_goals'),('mv_team_league'),('mv_team_match'),('mv_team_lanes'),
 ('mv_team_attackphase'),('mv_team_buildphase'),('mv_team_zones'),('mv_team_sequences'),
 ('v_season_stats'),('mv_squad_role'),('mv_state_segments'),('mv_league_summary'),
 ('mv_league_availability'),('mv_team_breakdown'),('v_seq_directness'),('v_team_sample'),
 ('v_team_directory'),('mv_player_state_output'),('mv_player_percentiles')),
deps as (
  select c.oid, c.relname::text as name, c.relkind, 1 as depth
  from pg_depend d join pg_rewrite r on r.oid=d.objid
  join pg_class c on c.oid=r.ev_class
  join pg_class src on src.oid=d.refobjid
  join pg_namespace sn on sn.oid=src.relnamespace and sn.nspname='public'
  where src.relname in (select name from seed) and c.relname not in (select name from seed)
  union all
  select c2.oid, c2.relname::text, c2.relkind, deps.depth+1
  from deps join pg_depend d2 on d2.refobjid=deps.oid
  join pg_rewrite r2 on r2.oid=d2.objid
  join pg_class c2 on c2.oid=r2.ev_class
  where c2.oid<>deps.oid and deps.depth<12
),
allobj as (
  select oid, name, relkind, max(depth) as create_order from deps group by oid, name, relkind
  union
  select c.oid, c.relname::text, c.relkind, 0
  from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where c.relname in (select name from seed)
)
select a.create_order,
       a.relkind,
       a.name,
       pg_get_userbyid(c.relowner)                          as owner,
       coalesce(array_to_string(c.reloptions, ', '), '')    as reloptions,
       coalesce(array_to_string(c.relacl, ' | '), 'default') as acl,
       coalesce(obj_description(c.oid,'pg_class'), '')      as comment,
       coalesce((select string_agg(i.indexdef, E';\n' order by i.indexname)
                 from pg_indexes i where i.schemaname='public' and i.tablename=a.name), '') as indexes,
       case when a.relkind='m'
            then (select definition from pg_matviews where matviewname=a.name)
            else (select definition from pg_views where viewname=a.name and schemaname='public')
       end as definition
from allobj a join pg_class c on c.oid = a.oid
order by a.create_order, a.relkind, a.name;
