-- Make the active season in public.leagues the hard boundary for every live
-- analytical object. Raw tables retain historical and cup data; public
-- metrics, rankings, plots, directories, insights and summaries do not.
--
-- This transaction discovers every view/materialized view that reads a raw
-- match table, captures its dependency closure and metadata, rewrites those
-- sources to the canonical scoped views, and rebuilds the closure in
-- topological order. There is deliberately no CASCADE: an uncaptured
-- dependency aborts and rolls the transaction back.

begin;
set local statement_timeout = '21600s';

create temporary table _season_raw_baseline on commit drop as
select
  (select count(*) from public.events) as events,
  (select count(*) from public.matches) as matches,
  (select count(*) from public.sequences) as sequences,
  (select count(*) from public.lineups) as lineups;

-- Capture raw-reading analytical roots, excluding the four boundary views
-- whose definitions are replaced explicitly below.
create temporary table _season_seed(name text primary key) on commit drop;
insert into _season_seed(name)
select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('m','v')
  and c.relname not in (
    'v_league_events','v_league_matches',
    'v_league_sequences','v_league_lineups','v_match_season_scope'
  )
  and pg_get_viewdef(c.oid, true) ~*
      '\m(from|join)\s+(events|matches|sequences|lineups)\M';

create temporary table _season_edges on commit drop as
select distinct src.oid as source_oid, dep.oid as dependent_oid
from pg_depend d
join pg_rewrite r on r.oid = d.objid
join pg_class dep on dep.oid = r.ev_class and dep.relkind in ('m','v')
join pg_namespace dn on dn.oid = dep.relnamespace and dn.nspname = 'public'
join pg_class src on src.oid = d.refobjid and src.relkind in ('m','v')
join pg_namespace sn on sn.oid = src.relnamespace and sn.nspname = 'public'
where dep.oid <> src.oid;

create temporary table _season_closure on commit drop as
with recursive paths(oid,path) as (
  select c.oid, array[c.oid]
  from _season_seed s
  join pg_class c on c.relname = s.name
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  union all
  select e.dependent_oid, p.path || e.dependent_oid
  from paths p
  join _season_edges e on e.source_oid = p.oid
  where not e.dependent_oid = any(p.path)
)
select distinct oid from paths;

create temporary table _season_topology on commit drop as
with recursive paths(oid,depth,path) as (
  select oid, 0, array[oid] from _season_closure
  union all
  select e.dependent_oid, p.depth + 1, p.path || e.dependent_oid
  from paths p
  join _season_edges e on e.source_oid = p.oid
  join _season_closure c on c.oid = e.dependent_oid
  where not e.dependent_oid = any(p.path)
)
select oid, max(depth)::int as create_order
from paths group by oid;

create temporary table _season_objects on commit drop as
select t.create_order, c.oid, c.relname::text as name, c.relkind,
       obj_description(c.oid,'pg_class') as comment,
       rtrim(trim(coalesce(m.definition,v.definition)),';') as original_def,
       null::text as forward_def
from _season_topology t
join pg_class c on c.oid = t.oid
left join pg_matviews m
  on m.schemaname = 'public' and m.matviewname = c.relname
left join pg_views v
  on v.schemaname = 'public' and v.viewname = c.relname;

create temporary table _season_indexes on commit drop as
select o.name, i.indexname, i.indexdef
from _season_objects o
join pg_indexes i on i.schemaname = 'public' and i.tablename = o.name;

-- Preserve the current privilege surface exactly enough to restore every
-- explicit non-owner grant after recreation.
create temporary table _season_acl on commit drop as
select o.name,
       coalesce(pg_get_userbyid(nullif(a.grantee,0)),'PUBLIC') as grantee,
       a.privilege_type,
       a.is_grantable
from _season_objects o
join pg_class c on c.oid = o.oid
cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
where a.grantee <> c.relowner;

create or replace function pg_temp._current_scope(p_def text)
returns text language plpgsql immutable as $fn$
declare q text := p_def;
begin
  q := regexp_replace(q,
    '(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)(public\.)?events\M',
    E'\\1\\2v_league_events as events','gi');
  q := regexp_replace(q,
    '(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)(public\.)?matches\M',
    E'\\1\\2v_league_matches as matches','gi');
  q := regexp_replace(q,
    '(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)(public\.)?sequences\M',
    E'\\1\\2v_league_sequences as sequences','gi');
  q := regexp_replace(q,
    '(\mfrom|\mjoin)([[:space:]]*\(*[[:space:]]*)(public\.)?lineups\M',
    E'\\1\\2v_league_lineups as lineups','gi');
  q := regexp_replace(q,
    '\m(v_league_events|v_league_matches|v_league_sequences|v_league_lineups)'
    || '[[:space:]]+as[[:space:]]+(events|matches|sequences|lineups)'
    || '[[:space:]]+(?!where\M|join\M|left\M|right\M|full\M|inner\M|cross\M|group\M|order\M|having\M|limit\M|offset\M|union\M|intersect\M|except\M|on\M)'
    || '([a-z_][a-z0-9_]*)',
    E'\\1 as \\3','gi');
  return q;
end
$fn$;

update _season_objects
set forward_def = pg_temp._current_scope(original_def);

-- The inherited xA definition windowed every eligible event solely to find
-- the event immediately before each shot. On production data that spilled to
-- temporary files and could not finish inside two hours. Drive the identical
-- previous-event rule from the much smaller shot set and use the existing
-- (game_id, ws_id) event index instead.
update _season_objects
set forward_def = $view$
select p.player_id,
       count(*) as chances_created,
       round(sum(x.xg),3) as xa
from public.mv_shot_xg x
join public.v_league_events shot
  on shot.game_id=x.game_id and shot.ws_id=x.ws_id and shot.is_shot
join lateral (
  select e.player_id,e.team,e.type,
         (e.qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb)
           as keypass,
         (e.qualifiers @> '[{"type":{"displayName":"ShotAssist"}}]'::jsonb)
           as shotassist
  from public.v_league_events e
  where e.game_id=shot.game_id
    and e.ws_id<shot.ws_id
    and e.type <> all(array[
      'Start','End','FormationSet','FormationChange','Card',
      'SubstitutionOn','SubstitutionOff','CornerAwarded',
      'OffsideGiven','OffsideProvoked'
    ]::text[])
  order by e.ws_id desc
  limit 1
) p on true
where p.team=shot.team
  and p.type='Pass'
  and (p.keypass or p.shotassist)
  and p.player_id is not null
group by p.player_id
$view$
where name='mv_player_xa';

-- Player exposure is league-scoped as well as season-scoped. Without this,
-- a player appearing in two active calendars (for example MLS before a move
-- to Europe) carries minutes from both into one league profile.
update _season_objects
set forward_def = $view$
select m.player_id,p.player_name,
       mode() within group(order by m.team) as team,
       count(*) as apps,
       count(*) filter(where m.is_starter) as starts,
       round(sum(m.minutes),0) as minutes,
       round(sum(m.minutes)/90.0,2) as nineties
from public.mv_player_minutes m
join public.mv_player_league pl on pl.player_id=m.player_id
join public.v_league_matches lm
  on lm.game_id=m.game_id and lm.league=pl.league
join public.players p on p.player_id=m.player_id
group by m.player_id,p.player_name
$view$
where name='mv_player_season';

-- Squad-role availability needs one row per team/match plus match length.
-- Express it directly from player stints and current-season matches. The
-- inherited multi-CTE definition rescanned events and self-joined player/team
-- windows, producing unstable multi-minute plans during a fresh rebuild.
update _season_objects
set forward_def = $view$
with team_games as materialized (
  select ps.game_id,ps.team,m.league,m.date,max(ps.match_len) as end_min
  from public.mv_player_stints ps
  join public.v_league_matches m on m.game_id=ps.game_id
  where ps.team is not null and m.date is not null
  group by ps.game_id,ps.team,m.league,m.date
), player_team as materialized (
  select ps.player_id,ps.team,min(g.league) as league,
         min(g.date) as first_date,max(g.date) as last_date,
         sum(ps.minutes) as minutes_played,count(*) as appearances,
         count(*) filter(where ps.is_starter) as starts
  from public.mv_player_stints ps
  join team_games g on g.game_id=ps.game_id and g.team=ps.team
  group by ps.player_id,ps.team
), team_last as (
  select team,max(date) as last_team_date
  from team_games group by team
), bounds as (
  select p.*,
         case
           when max(p.last_date) over(partition by p.player_id)>p.last_date
             then p.last_date
           else tl.last_team_date
         end as window_end
  from player_team p
  join team_last tl on tl.team=p.team
), avail as (
  select b.player_id,b.team,b.league,b.first_date,b.last_date,b.window_end,
         b.minutes_played,b.appearances,b.starts,
         count(g.game_id) as games_available,
         coalesce(sum(g.end_min),0::bigint) as minutes_available
  from bounds b
  left join team_games g
    on g.team=b.team and g.date>=b.first_date and g.date<=b.window_end
  group by b.player_id,b.team,b.league,b.first_date,b.last_date,b.window_end,
           b.minutes_played,b.appearances,b.starts
), scored as (
  select a.*,lv.leverage_pct,
         round(100.0*a.minutes_played::numeric/
               nullif(a.minutes_available,0)::numeric,1) as selection_pct,
         round(100.0*a.starts::numeric/
               nullif(a.games_available,0)::numeric,1) as start_pct
  from avail a
  left join public.mv_player_leverage lv
    on lv.player_id=a.player_id and lv.team=a.team
), ranked as (
  select s.*,
         rank() over(partition by s.team
                     order by s.selection_pct desc nulls last) as squad_rank,
         round(
           (s.leverage_pct-avg(s.leverage_pct) over(partition by s.team))/
           nullif(stddev_samp(s.leverage_pct) over(partition by s.team),0),
           2
         ) as leverage_z_in_squad
  from scored s
)
select r.player_id,r.team,r.league,r.first_date,r.last_date,r.window_end,
       r.minutes_played,r.appearances,r.starts,r.games_available,
       r.minutes_available,r.leverage_pct,r.selection_pct,r.start_pct,
       r.squad_rank,r.leverage_z_in_squad,pcr.player,pcr.pos,
       case
         when r.selection_pct>=70 then 'Key player'
         when r.selection_pct>=45 then 'Starter'
         when r.selection_pct>=20 then 'Rotation'
         else 'Fringe'
       end as squad_role
from ranked r
join public.player_chain_roles pcr on pcr.player_id=r.player_id
where r.games_available>=6
$view$
where name='mv_squad_role';

do $guard$
declare n int; nm int; nv int; bad text;
begin
  select count(*), count(*) filter(where relkind='m'),
         count(*) filter(where relkind='v')
    into n,nm,nv from _season_objects;
  if n <> 82 or nm <> 58 or nv <> 24 then
    raise exception
      'CURRENT-SEASON ABORT. Expected 82/58/24 objects/matviews/views; captured %/%/%.',
      n,nm,nv;
  end if;
  if (select count(*) from _season_seed) <> 34 then
    raise exception 'CURRENT-SEASON ABORT. Expected 34 raw-reading roots; captured %.',
      (select count(*) from _season_seed);
  end if;
  if exists (
    select 1 from _season_objects
    where original_def is null or forward_def is null
  ) then
    raise exception 'CURRENT-SEASON ABORT. Null definition captured.';
  end if;
  if exists (
    select 1 from _season_objects
    where name='mv_squad_role'
      and position('with team_games as materialized (' in forward_def)=0
  ) then
    raise exception 'CURRENT-SEASON ABORT. Squad-role optimization was not applied.';
  end if;
  select string_agg(name,', ' order by name) into bad
  from _season_objects
  where original_def ~*
    '(with|,)[[:space:]]+(recursive[[:space:]]+)?"?(events|matches|sequences|lineups)"?[[:space:]]+as[[:space:]]*\(';
  if bad is not null then
    raise exception 'CURRENT-SEASON ABORT. Raw-table CTE collision: %.',bad;
  end if;
  if exists (
    select 1 from _season_edges e
    join _season_closure s on s.oid=e.source_oid
    join _season_closure d on d.oid=e.dependent_oid
    where (select create_order from _season_topology where oid=e.source_oid) >=
          (select create_order from _season_topology where oid=e.dependent_oid)
  ) then
    raise exception 'CURRENT-SEASON ABORT. Invalid dependency topology.';
  end if;
end
$guard$;

-- Parse every transformed definition before any destructive DDL.
do $parse$
declare item record;
begin
  for item in select name,forward_def from _season_objects
              order by create_order,name loop
    execute 'create view pg_temp._season_probe as ' || item.forward_def;
    drop view pg_temp._season_probe;
  end loop;
end
$parse$;

-- One inspectable source identifies the season of every raw match and whether
-- that row is eligible for the live platform. It is internal to service_role:
-- browser pages use the four filtered sources below, not this catalogue.
create or replace view public.v_match_season_scope
with (security_invoker=true) as
select m.game_id,m.season,m.competition,m.date,m.home_team,m.away_team,
       m.home_score,m.away_score,m.matchday,m.venue,m.league,
       l.season as registered_season,
       l.competition_type,
       (l.competition_type='league' and m.season=l.season) as is_live_scope
from public.matches m
left join public.leagues l on l.league=m.league;

alter view public.v_match_season_scope owner to postgres;
revoke all on public.v_match_season_scope from public,anon,authenticated;
grant all on public.v_match_season_scope to service_role;
comment on view public.v_match_season_scope is
  'Internal match-season catalogue. is_live_scope is the sole eligibility flag for public analytics.';

-- The four canonical sources retain their existing output schemas. A row is
-- eligible only when its match belongs to the season registered for that
-- league. Events, lineups and derived sequences resolve season through the
-- match rather than trusting a seasonless row.
create or replace view public.v_league_matches
with (security_invoker=true) as
select m.game_id,m.season,m.competition,m.date,m.home_team,m.away_team,
       m.home_score,m.away_score,m.matchday,m.venue,m.league
from public.v_match_season_scope m
where m.is_live_scope;

create or replace view public.v_league_events
with (security_invoker=true) as
select e.id,e.game_id,e.ws_id,e.event_id,e.period,e.minute,e.second,
       e.expanded_minute,e.team_id,e.team,e.player_id,e.player,e.type,
       e.outcome_type,e.x,e.y,e.end_x,e.end_y,e.is_touch,e.is_shot,
       e.is_goal,e.card_type,e.qualifiers,e.is_open_play,e.league
from public.events e
join public.v_match_season_scope m
  on m.game_id=e.game_id and m.league=e.league and m.is_live_scope;

create or replace view public.v_league_sequences
with (security_invoker=true) as
select s.seq_uid,s.game_id,s.seq_no,s.team_id,s.team,s.period,s.start_min,
       s.start_sec,s.dur_s,s.n_events,s.n_pass,s.n_players,s.start_x,
       s.start_y,s.end_x,s.end_y,s.start_third,s.end_third,s.ended_in_box,
       s.ended_shot,s.ended_goal,s.started_setpiece,s.is_open_play,s.xt_sum,
       s.mean_pass_len,s.low_build,s.high_build,s.structured,s.has_switch,
       s.wide_triangles,s.hold_up,s.very_short,s.long_ball,s.ends_opp_half,
       s.end_around_box,s.finds_central,s.finds_wide,s.n_wide_pass,s.n_prog,
       s.n_prog_central,s.n_prog_wide,s.path,s.cx,s.cy,s.minx,s.maxx,s.miny,
       s.maxy,s.att_share,s.league
from public.sequences s
join public.v_match_season_scope m
  on m.game_id=s.game_id and m.league=s.league and m.is_live_scope;

create or replace view public.v_league_lineups
with (security_invoker=true) as
select li.id,li.game_id,li.player_id,li.team,li.is_starter,li.position,
       li.shirt_number,li.league
from public.lineups li
join public.v_match_season_scope m
  on m.game_id=li.game_id and m.league=li.league and m.is_live_scope;

comment on view public.v_league_matches is
  'Canonical current-season league match source. Raw history remains in matches.';
comment on view public.v_league_events is
  'Canonical current-season league event source. Excludes cups, continental fixtures and prior seasons.';
comment on view public.v_league_sequences is
  'Canonical current-season league sequence source. Season resolves through matches.';
comment on view public.v_league_lineups is
  'Canonical current-season league lineup source. Season resolves through matches.';

-- Drop and recreate the captured closure without CASCADE.
do $recreate$
declare item record; ix record; acl record; kind text;
begin
  for item in select * from _season_objects
              order by create_order desc,name desc loop
    kind := case when item.relkind='m' then 'materialized view' else 'view' end;
    execute format('drop %s public.%I',kind,item.name);
  end loop;

  for item in select * from _season_objects
              order by create_order,name loop
    raise log 'CURRENT-SEASON create % (kind %, order %)',
      item.name,item.relkind,item.create_order;
    if item.relkind='m' then
      execute format('create materialized view public.%I as %s',
                     item.name,item.forward_def);
    else
      execute format('create view public.%I with (security_invoker=true) as %s',
                     item.name,item.forward_def);
    end if;
    execute format('alter %s public.%I owner to postgres',
      case when item.relkind='m' then 'materialized view' else 'view' end,
      item.name);
    execute format('revoke all on public.%I from public,anon,authenticated,service_role',
                   item.name);
    for acl in select * from _season_acl where name=item.name loop
      execute format('grant %s on public.%I to %s%s',
        acl.privilege_type,item.name,
        case when acl.grantee='PUBLIC' then 'PUBLIC' else quote_ident(acl.grantee) end,
        case when acl.is_grantable then ' with grant option' else '' end);
    end loop;
    for ix in select * from _season_indexes where name=item.name
              order by indexname loop
      execute ix.indexdef;
    end loop;
    if item.relkind='m' then
      execute format('analyze public.%I',item.name);
    end if;
    if item.comment is not null then
      execute format('comment on %s public.%I is %L',
        case when item.relkind='m' then 'materialized view' else 'view' end,
        item.name,item.comment);
    end if;
  end loop;
end
$recreate$;

-- Persistent builders and public sequence RPCs are not represented in the
-- view dependency graph, so scope the three analytical bypasses explicitly.
do $functions$
declare fn record; body text;
begin
  for fn in
    select p.oid,p.proname,pg_get_functiondef(p.oid) as definition
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'build_player_chain_roles','build_insights_extra','top_sequences_by_type'
      )
  loop
    body := pg_temp._current_scope(fn.definition);
    execute body;
  end loop;
end
$functions$;

-- Rebuild the persistent chain-role table. It is not a view and therefore is
-- invisible to the recreation topology. Only its materialized consumers need
-- a second refresh; refreshing all 58 objects again would double the lock
-- window without changing any other result.
select public.build_player_chain_roles();
select public.stamp_sequence_leagues();

refresh materialized view public.mv_player_chain_value;
refresh materialized view public.mv_player_progression;
refresh materialized view public.mv_player_state_output;
refresh materialized view public.mv_squad_role;
refresh materialized view public.mv_player_archetype;
refresh materialized view public.player_search;
refresh materialized view public.mv_player_pct;

insert into public.invariants(name,description,check_sql,severity,enabled)
values (
  'league_outputs_current_season',
  'Canonical league sources must contain only the season registered as current for each league.',
  $check$
  select count(*) from (
    select m.game_id::text as row_id
    from public.v_league_matches m
    join public.leagues l on l.league=m.league
    where m.season is distinct from l.season
    union all
    select e.id::text
    from public.v_league_events e
    join public.matches m on m.game_id=e.game_id
    join public.leagues l on l.league=e.league
    where m.season is distinct from l.season
    union all
    select s.seq_uid
    from public.v_league_sequences s
    join public.matches m on m.game_id=s.game_id
    join public.leagues l on l.league=s.league
    where m.season is distinct from l.season
    union all
    select li.id::text
    from public.v_league_lineups li
    join public.matches m on m.game_id=li.game_id
    join public.leagues l on l.league=li.league
    where m.season is distinct from l.season
  ) leaked
  $check$,
  'error',true
)
on conflict(name) do update set
  description=excluded.description,
  check_sql=excluded.check_sql,
  severity='error',enabled=true;

insert into public.invariants(name,description,check_sql,severity,enabled)
values (
  'player_exposure_within_current_season',
  'No player can accumulate materially more nineties than the largest current-season team sample in that player league.',
  $check$
  with league_max as (
    select league,max(matches)::numeric as matches
    from public.v_team_sample group by league
  )
  select count(*)
  from public.mv_player_season ps
  join public.mv_player_league pl on pl.player_id=ps.player_id
  join league_max lm on lm.league=pl.league
  where ps.nineties > lm.matches*1.20
  $check$,
  'error',true
)
on conflict(name) do update set
  description=excluded.description,
  check_sql=excluded.check_sql,
  severity='error',enabled=true;

-- Reconciliation must test the same published population as mv_game_goals.
-- Historical raw matches remain auditable but are not missing from a
-- current-season mart.
update public.invariants
set check_sql = $check$
with ev as (
  select g.game_id,
         count(*) filter(where g.scoring_team=x.home_ev) as h,
         count(*) filter(where g.scoring_team=x.away_ev) as a
  from public.mv_game_goals g
  join (
    select m.game_id,
           coalesce(th.event_name,m.home_team) as home_ev,
           coalesce(ta.event_name,m.away_team) as away_ev
    from public.v_league_matches m
    left join public.team_names th
      on th.match_name=m.home_team and th.league=m.league
    left join public.team_names ta
      on ta.match_name=m.away_team and ta.league=m.league
  ) x on x.game_id=g.game_id
  group by g.game_id
)
select count(*)
from public.v_league_matches m
left join ev on ev.game_id=m.game_id
where m.home_score is not null
  and exists (
    select 1 from public.v_league_events e where e.game_id=m.game_id
  )
  and (
    m.home_score<>coalesce(ev.h,0)
    or m.away_score<>coalesce(ev.a,0)
  )
$check$,
    description =
      'Current-season league goals parsed from events must equal the published scoreline.',
    severity='error',
    enabled=true
where name='goals_reconcile';

-- Rebuild insights after every metric is current-season scoped. Publication
-- remains held until verify_rebuild passes, then summaries are refreshed.
select public.build_insights();
select public.polish_insights();

do $assert$
declare b record; bad bigint; arsenal_matches int; details text;
begin
  select * into b from _season_raw_baseline;
  if (select count(*) from public.events)<>b.events
     or (select count(*) from public.matches)<>b.matches
     or (select count(*) from public.sequences)<>b.sequences
     or (select count(*) from public.lineups)<>b.lineups then
    raise exception 'CURRENT-SEASON ASSERT FAILED. Raw history changed.';
  end if;

  select count(*) into bad
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('m','v')
    and c.relname not in (
      'v_league_events','v_league_matches',
      'v_league_sequences','v_league_lineups','v_match_season_scope'
    )
    and pg_get_viewdef(c.oid,true) ~*
        '\m(from|join)\s+(events|matches|sequences|lineups)\M';
  if bad<>0 then
    raise exception 'CURRENT-SEASON ASSERT FAILED. % analytical objects still bypass scoped sources.',bad;
  end if;

  select coalesce(matches,0) into arsenal_matches
  from public.v_team_sample where team='Arsenal';
  if arsenal_matches is distinct from 1 then
    raise exception 'CURRENT-SEASON ASSERT FAILED. Arsenal has % matches; expected 1 at this cut.',arsenal_matches;
  end if;

  select coalesce(sum(violations),0),
         string_agg(name||'='||violations,', ' order by name)
           filter(where violations<>0)
    into bad,details
  from public.run_invariants()
  where severity='error';
  if bad<>0 then
    raise exception
      'CURRENT-SEASON ASSERT FAILED. Error-level invariant violations=% (%).',
      bad,details;
  end if;
end
$assert$;

select public.verify_rebuild();
select public.refresh_site_summaries();

commit;
