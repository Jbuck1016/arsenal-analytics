-- Convert every remaining public view reported by the Supabase security
-- advisor to caller-rights semantics. Audited 2026-08-27: all direct public
-- relation dependencies are SELECT-readable by anon and authenticated; the
-- sole function dependency is public.xt_at(), which is SECURITY INVOKER and
-- executable by both roles.
begin;

create temp table _security_invoker_expected (
  view_name text primary key
) on commit drop;

insert into _security_invoker_expected (view_name) values
  ('pcr_z'),
  ('player_chain_pct'),
  ('team_sequence_agg'),
  ('team_sequence_style'),
  ('v_goal_fix'),
  ('v_league_availability'),
  ('v_league_summary'),
  ('v_loaded_games'),
  ('v_player_actions'),
  ('v_player_carries'),
  ('v_player_metrics_ext'),
  ('v_player_pct_all'),
  ('v_player_receipts'),
  ('v_player_sot_fix'),
  ('v_player_xt_actions'),
  ('v_press_profile'),
  ('v_season_stats'),
  ('v_seq_directness'),
  ('v_squad_role'),
  ('v_team_actions'),
  ('v_team_carries'),
  ('v_team_directory'),
  ('v_team_sample'),
  ('v_team_shots'),
  ('v_team_signature'),
  ('v_xg_model_support');

do $preflight$
declare
  missing_views text;
  blocked_relations text;
  blocked_functions text;
begin
  select string_agg(e.view_name, ', ' order by e.view_name)
  into missing_views
  from _security_invoker_expected e
  left join pg_class c on c.relname=e.view_name
  left join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where n.oid is null or c.relkind <> 'v';

  if missing_views is not null then
    raise exception 'SECURITY INVOKER PREFLIGHT: expected public views missing or wrong kind: %',
      missing_views;
  end if;

  with target_views as (
    select c.oid, c.relname
    from _security_invoker_expected e
    join pg_class c on c.relname=e.view_name
    join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  ), dependencies as (
    select distinct v.relname view_name, src.oid source_oid, src.relname source_name
    from target_views v
    join pg_rewrite r on r.ev_class=v.oid
    join pg_depend d on d.objid=r.oid
    join pg_class src on src.oid=d.refobjid and src.oid<>v.oid
    join pg_namespace sn on sn.oid=src.relnamespace and sn.nspname='public'
    where src.relkind in ('r','p','m','v')
  )
  select string_agg(format('%s -> %s', view_name, source_name), ', '
                    order by view_name, source_name)
  into blocked_relations
  from dependencies
  where not has_table_privilege('anon', source_oid, 'SELECT')
     or not has_table_privilege('authenticated', source_oid, 'SELECT');

  if blocked_relations is not null then
    raise exception 'SECURITY INVOKER PREFLIGHT: browser roles cannot read dependencies: %',
      blocked_relations;
  end if;

  with target_views as (
    select c.oid, c.relname
    from _security_invoker_expected e
    join pg_class c on c.relname=e.view_name
    join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  ), function_dependencies as (
    select distinct v.relname view_name, p.oid function_oid,
      format('%I.%I(%s)', pn.nspname, p.proname,
             pg_get_function_identity_arguments(p.oid)) function_name
    from target_views v
    join pg_rewrite r on r.ev_class=v.oid
    join pg_depend d on d.objid=r.oid
    join pg_proc p on p.oid=d.refobjid
    join pg_namespace pn on pn.oid=p.pronamespace
  )
  select string_agg(format('%s -> %s', view_name, function_name), ', '
                    order by view_name, function_name)
  into blocked_functions
  from function_dependencies
  where not has_function_privilege('anon', function_oid, 'EXECUTE')
     or not has_function_privilege('authenticated', function_oid, 'EXECUTE');

  if blocked_functions is not null then
    raise exception 'SECURITY INVOKER PREFLIGHT: browser roles cannot execute dependencies: %',
      blocked_functions;
  end if;
end
$preflight$;

create temp table _security_invoker_metadata_before on commit drop as
select c.relname as view_name,
       c.relowner,
       c.relacl,
       obj_description(c.oid, 'pg_class') as comment,
       coalesce((select array_agg(opt order by opt)
                 from unnest(c.reloptions) opt
                 where opt <> 'security_invoker=true'), array[]::text[]) as other_reloptions
from _security_invoker_expected e
join pg_class c on c.relname=e.view_name
join pg_namespace n on n.oid=c.relnamespace and n.nspname='public';

alter view public.pcr_z                 set (security_invoker = true);
alter view public.player_chain_pct      set (security_invoker = true);
alter view public.team_sequence_agg     set (security_invoker = true);
alter view public.team_sequence_style   set (security_invoker = true);
alter view public.v_goal_fix            set (security_invoker = true);
alter view public.v_league_availability set (security_invoker = true);
alter view public.v_league_summary      set (security_invoker = true);
alter view public.v_loaded_games        set (security_invoker = true);
alter view public.v_player_actions      set (security_invoker = true);
alter view public.v_player_carries      set (security_invoker = true);
alter view public.v_player_metrics_ext  set (security_invoker = true);
alter view public.v_player_pct_all      set (security_invoker = true);
alter view public.v_player_receipts     set (security_invoker = true);
alter view public.v_player_sot_fix      set (security_invoker = true);
alter view public.v_player_xt_actions   set (security_invoker = true);
alter view public.v_press_profile       set (security_invoker = true);
alter view public.v_season_stats        set (security_invoker = true);
alter view public.v_seq_directness      set (security_invoker = true);
alter view public.v_squad_role          set (security_invoker = true);
alter view public.v_team_actions        set (security_invoker = true);
alter view public.v_team_carries        set (security_invoker = true);
alter view public.v_team_directory      set (security_invoker = true);
alter view public.v_team_sample         set (security_invoker = true);
alter view public.v_team_shots          set (security_invoker = true);
alter view public.v_team_signature      set (security_invoker = true);
alter view public.v_xg_model_support    set (security_invoker = true);

do $assert$
declare
  bad_options text;
  metadata_drift text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
  into bad_options
  from _security_invoker_expected e
  join pg_class c on c.relname=e.view_name
  join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where not coalesce('security_invoker=true'=any(c.reloptions), false);

  if bad_options is not null then
    raise exception 'SECURITY INVOKER ASSERT: option missing on %', bad_options;
  end if;

  select string_agg(c.relname, ', ' order by c.relname)
  into metadata_drift
  from _security_invoker_metadata_before b
  join pg_class c on c.relname=b.view_name
  join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where c.relowner is distinct from b.relowner
     or c.relacl is distinct from b.relacl
     or obj_description(c.oid, 'pg_class') is distinct from b.comment
     or coalesce((select array_agg(opt order by opt)
                  from unnest(c.reloptions) opt
                  where opt <> 'security_invoker=true'), array[]::text[])
        is distinct from b.other_reloptions;

  if metadata_drift is not null then
    raise exception 'SECURITY INVOKER ASSERT: owner/ACL/comment/other reloptions drifted on %',
      metadata_drift;
  end if;
end
$assert$;

commit;
