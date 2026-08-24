-- =====================================================================
-- 20260824_03_cup_isolation.sql
-- Project: xrsilhiffjoulyoqhdmp
-- Captured: 2026-08-24   Revised after review 2
-- Status:   FOR REVIEW. Do not execute until approved.
--
-- REQUIRES, in order:
--   20260824_01_stage2_db_objects.sql
--   20260824_02_competition_registry.sql
--
-- WHAT CHANGES SEMANTICALLY (8 of 21 objects)
--   mv_game_goals             excludes period 5, the penalty shootout
--   mv_team_league            resolves a club to its LEAGUE competition by
--                             event volume, not min(league) alphabetically
--   v_team_sample             resolves through mv_team_league; all counts
--                             scoped to the club league competition
--   v_seq_directness          gains s.league so directness can be scoped
--   mv_team_breakdown         MLS fallback removed, cup sequences excluded
--   mv_team_percentiles       MLS fallback removed
--   mv_team_stat_ranks        MLS fallback removed
--   v_team_directory          MLS fallback removed
--   mv_team_directness_state  MLS fallback removed, cup sequences excluded
--   v_cup_shootouts           new
--   All others are byte-identical recreations, dropped only because
--   PostgreSQL has no CREATE OR REPLACE MATERIALIZED VIEW.
--
-- THE SILENT MLS FALLBACK
--   Five objects carried coalesce(tl.league, 'USA-MLS'). Any club that
--   failed to resolve was silently filed as MLS. This is the same class
--   of defect as the old DEFAULT 'USA-MLS' on the league columns, which
--   tagged 1,573 La Liga sequences as MLS without any error. All five now
--   inner join mv_team_league, so an unresolved club is excluded rather
--   than misfiled, and invariant team_league_resolves fails loudly if any
--   club playing in a registered league competition fails to resolve.
--
-- WHAT THIS DOES NOT CHANGE
--   No row in events, matches, lineups or sequences is read, written or
--   deleted. Raw cup fixtures and events are preserved exactly, and the
--   transaction asserts their counts are unchanged before committing.
--
-- COMPETITION FILTER (the only rule used anywhere below)
--   leagues.competition_type = 'league'
--   Membership is read from the registry. Never inferred from team names.
--
-- PERIOD RULE
--   events.period = 5 is the penalty shootout, and is excluded from match
--   goal totals. events.period is NULLABLE, so the test is
--   IS DISTINCT FROM 5, which excludes period 5 only. A plain <> would
--   silently drop any future null-period goal as well.
--
-- KNOWN GAP, DELIBERATELY NOT FIXED HERE
--   mv_team_all aggregates per team across ALL competitions, so Arsenal's
--   season metric values still include cup fixtures. This migration fixes
--   which POOL a club is ranked in, not which matches feed its values.
--   mv_team_all sits outside this dependency set and changing it is a
--   separate cascade. Tracked, not silently accepted.
--
-- TRANSACTION MODEL: single atomic transaction, deliberately.
--   CREATE MATERIALIZED VIEW populates on creation because WITH NO DATA
--   is not used, so a post-commit refresh would repeat every scan for no
--   benefit and, worse, could not roll back alongside the schema change.
--   Everything therefore happens inside one transaction: drops, creates,
--   insight regeneration, summary refresh, assertions and verify_rebuild.
--   If any assertion fails, the entire migration is rolled back and the
--   database is left exactly as it was. The cost is one long-running
--   transaction and a brief period where these objects are locked, which
--   is acceptable for a one-off maintenance operation on a site with no
--   concurrent writers.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. PREFLIGHT. Aborts if the live dependency set differs from capture.
-- ---------------------------------------------------------------------
do $preflight$
declare
  captured text[] := array[
    'mv_league_availability','mv_league_summary','mv_player_leverage',
    'mv_player_state_output','mv_seq_state','mv_squad_role',
    'mv_state_segments','mv_team_breakdown','mv_team_directness_state',
    'mv_team_percentiles','mv_team_stat_ranks','v_league_availability',
    'v_league_summary','v_seq_directness','v_squad_role','v_team_directory',
    'v_team_sample','v_team_signature'
  ];
  actual text[]; missing text[]; extra text[];
begin
  with recursive deps as (
    select c.oid, c.relname::text as name, 1 as depth
    from pg_depend d
    join pg_rewrite r on r.oid = d.objid
    join pg_class c on c.oid = r.ev_class
    join pg_class src on src.oid = d.refobjid
    join pg_namespace sn on sn.oid = src.relnamespace and sn.nspname = 'public'
    where src.relname in ('mv_game_goals','mv_team_league')
      and c.relname not in ('mv_game_goals','mv_team_league')
    union all
    select c2.oid, c2.relname::text, deps.depth + 1
    from deps
    join pg_depend d2 on d2.refobjid = deps.oid
    join pg_rewrite r2 on r2.oid = d2.objid
    join pg_class c2 on c2.oid = r2.ev_class
    where c2.oid <> deps.oid and deps.depth < 10
  )
  select array_agg(distinct name order by name) into actual from deps;

  select array_agg(x) into missing from unnest(captured) x
   where not (x = any(coalesce(actual, '{}')));
  select array_agg(x) into extra from unnest(coalesce(actual, '{}')) x
   where not (x = any(captured));

  if missing is not null or extra is not null then
    raise exception
      'PREFLIGHT FAILED. Dependency set drifted since capture. Missing from live: %. Present but not captured: %. Re-capture before running.',
      coalesce(missing, '{}'), coalesce(extra, '{}');
  end if;

  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='leagues'
                   and column_name='competition_type') then
    raise exception 'PREFLIGHT FAILED. Run 20260824_02_competition_registry.sql first.';
  end if;

  if (select count(*) from leagues where competition_type='cup') <> 3 then
    raise exception 'PREFLIGHT FAILED. Expected 3 cup competitions, found %.',
      (select count(*) from leagues where competition_type='cup');
  end if;

  if not exists (select 1 from pg_constraint
                 where conrelid='public.team_names'::regclass and contype='p'
                   and pg_get_constraintdef(oid)='PRIMARY KEY (league, event_name)') then
    raise exception 'PREFLIGHT FAILED. team_names primary key is not (league, event_name).';
  end if;

  raise notice 'Preflight OK.';
end
$preflight$;

-- ---------------------------------------------------------------------
-- 1. SINGLE ATOMIC TRANSACTION
-- ---------------------------------------------------------------------
begin;

set local statement_timeout = '900s';

-- Baseline for the raw-data assertion. Temp table so it dies with the
-- session and cannot be mistaken for a real object.
create temp table _pre_counts on commit drop as
select (select count(*) from events)    as events,
       (select count(*) from matches)   as matches,
       (select count(*) from sequences) as sequences,
       (select count(*) from lineups)   as lineups,
       (select count(*) from events where period = 5) as period5_events;

-- 1a. Drop dependents first, deepest last-created first.
drop view if exists v_squad_role;
drop view if exists v_league_availability;
drop materialized view if exists mv_team_directness_state;
drop materialized view if exists mv_squad_role;
drop materialized view if exists mv_league_availability;
drop view if exists v_team_signature;
drop view if exists v_team_sample;
drop view if exists v_seq_directness;
drop view if exists v_league_summary;
drop materialized view if exists mv_player_state_output;
drop materialized view if exists mv_player_leverage;
drop view if exists v_team_directory;
drop materialized view if exists mv_team_stat_ranks;
drop materialized view if exists mv_team_percentiles;
drop materialized view if exists mv_team_breakdown;
drop materialized view if exists mv_state_segments;
drop materialized view if exists mv_seq_state;
drop materialized view if exists mv_league_summary;

-- 1b. Drop the roots. No CASCADE anywhere in this file, by design:
--     if anything unexpected still depends on these, the drop fails and
--     the transaction rolls back rather than silently destroying it.
drop materialized view if exists mv_team_league;
drop materialized view if exists mv_game_goals;

-- =====================================================================
-- 2. ROOTS, RECREATED WITH CHANGED DEFINITIONS
-- =====================================================================

-- CHANGED: adds "and e.period is distinct from 5" to exclude shootout
-- Everything else is identical to the captured definition.
create materialized view mv_game_goals as
 with gteams as (
         select events.game_id,
            array_agg(distinct events.team) as tms
           from events
          where (events.team is not null)
          group by events.game_id
        ), g as (
         select e.game_id,
            e.expanded_minute,
            e.second,
            e.team,
                case
                    when (e.qualifiers is null) then false
                    else (exists ( select 1
                       from jsonb_array_elements(e.qualifiers) q(value)
                      where (((q.value -> 'type'::text) ->> 'displayName'::text) ~~* '%own%'::text)))
                end as is_og
           from events e
          where e.is_goal
            and e.period is distinct from 5   -- CHANGED: shootout only; period is nullable
        )
 select g.game_id,
    g.expanded_minute,
    g.second,
        case
            when g.is_og then ( select t.t
               from unnest(gt.tms) t(t)
              where (t.t <> g.team)
             limit 1)
            else g.team
        end as scoring_team,
    g.is_og
   from (g
     join gteams gt using (game_id))
  where ((not g.is_og) or (( select count(*) as count
           from unnest(gt.tms) t(t)
          where (t.t <> g.team)) = 1));

create index mv_game_goals_idx on public.mv_game_goals using btree (game_id, expanded_minute);
alter materialized view mv_game_goals owner to postgres;
grant all on mv_game_goals to anon, authenticated, service_role;
comment on materialized view mv_game_goals is
  'Match goals from event data. Excludes period 5, which is the penalty shootout. Shootout results are exposed separately by v_cup_shootouts.';

-- CHANGED: was min(league) alphabetically over all competitions, which
-- resolved Arsenal to ENG-FA Cup. Now restricted to registered LEAGUE
-- competitions and resolved by event volume, with ties broken by name
-- so the result is deterministic.
create materialized view mv_team_league as
 select team, league, events
   from ( select e.team,
            e.league,
            count(*) as events,
            row_number() over (partition by e.team
                               order by count(*) desc, e.league) as rk
           from events e
           join leagues l on l.league = e.league
          where e.team is not null
            and l.competition_type = 'league'
          group by e.team, e.league) z
  where rk = 1;

create unique index mv_team_league_pk on public.mv_team_league using btree (team);
alter materialized view mv_team_league owner to postgres;
grant all on mv_team_league to anon, authenticated, service_role;
comment on materialized view mv_team_league is
  'Resolves a club to its league competition by event volume. Cup competitions are excluded via leagues.competition_type. Clubs seen only in cup fixtures are absent by design.';

-- =====================================================================
-- 3. SHOOTOUT PRESERVATION (view, not a table: cannot drift from source)
-- =====================================================================
create or replace view v_cup_shootouts as
 with kicks as (
   select e.game_id, e.team, e.is_goal
   from events e
   where e.period = 5 and e.is_shot
 )
 select k.game_id,
        m.league,
        m.date,
        m.home_team,
        m.away_team,
        count(*) filter (where k.is_goal and k.team = coalesce(th.event_name, m.home_team)) as home_shootout_goals,
        count(*) filter (where k.is_goal and k.team = coalesce(ta.event_name, m.away_team)) as away_shootout_goals,
        count(*) as kicks_taken
   from kicks k
   join matches m on m.game_id = k.game_id
   left join team_names th on th.match_name = m.home_team and th.league = m.league
   left join team_names ta on ta.match_name = m.away_team and ta.league = m.league
  group by k.game_id, m.league, m.date, m.home_team, m.away_team;

alter view v_cup_shootouts owner to postgres;
grant all on v_cup_shootouts to anon, authenticated, service_role;
comment on view v_cup_shootouts is
  'Penalty shootout results, derived deterministically from raw period-5 events. A view rather than a table, so it is always consistent with events and needs no refresh.';

-- =====================================================================
-- 4. DEPENDENTS, RECREATED IN TOPOLOGICAL ORDER
--    All byte-identical to capture except v_team_sample, marked CHANGED.
-- =====================================================================

-- ---- order 1 --------------------------------------------------------
create materialized view mv_seq_state as
 select s.seq_uid, s.game_id, s.team, s.start_min,
    count(*) filter (where (gg.scoring_team = s.team)) as goals_for,
    count(*) filter (where ((gg.scoring_team is not null) and (gg.scoring_team <> s.team))) as goals_against,
    (count(*) filter (where (gg.scoring_team = s.team)) - count(*) filter (where ((gg.scoring_team is not null) and (gg.scoring_team <> s.team)))) as margin,
        case
            when (count(*) filter (where (gg.scoring_team = s.team)) > count(*) filter (where ((gg.scoring_team is not null) and (gg.scoring_team <> s.team)))) then 'winning'::text
            when (count(*) filter (where (gg.scoring_team = s.team)) < count(*) filter (where ((gg.scoring_team is not null) and (gg.scoring_team <> s.team)))) then 'losing'::text
            else 'drawing'::text
        end as state,
    (abs((count(*) filter (where (gg.scoring_team = s.team)) - count(*) filter (where ((gg.scoring_team is not null) and (gg.scoring_team <> s.team))))) <= 1) as is_close
   from (sequences s
     left join mv_game_goals gg on (((gg.game_id = s.game_id) and ((gg.expanded_minute < s.start_min) or ((gg.expanded_minute = s.start_min) and (gg.second <= coalesce(s.start_sec, 0)))))))
  group by s.seq_uid, s.game_id, s.team, s.start_min;

create unique index mv_seq_state_pk on public.mv_seq_state using btree (seq_uid);
create index mv_seq_state_team on public.mv_seq_state using btree (team, state);
alter materialized view mv_seq_state owner to postgres;
grant all on mv_seq_state to anon, authenticated, service_role;

create materialized view mv_state_segments as
 with mlen as (
         select events.game_id, (max(events.expanded_minute) + 1) as end_min
           from events group by events.game_id
        ), tg as (
         select distinct events.game_id, events.team
           from events where (events.team is not null)
        ), ev as (
         select tg.game_id, tg.team, g.expanded_minute as t,
                case when (g.scoring_team = tg.team) then 1 else '-1'::integer end as d
           from (tg join mv_game_goals g on ((g.game_id = tg.game_id)))
        ), run as (
         select ev.game_id, ev.team, ev.t,
            sum(ev.d) over (partition by ev.game_id, ev.team order by ev.t rows between unbounded preceding and current row) as margin
           from ev
        ), after_goals as (
         select r.game_id, r.team, r.t as seg_start,
            coalesce(lead(r.t) over (partition by r.game_id, r.team order by r.t), m.end_min) as seg_end,
            r.margin
           from (run r join mlen m on ((m.game_id = r.game_id)))
        ), before_first as (
         select tg.game_id, tg.team, 0 as seg_start,
            coalesce(( select min(e.t) as min from ev e
                  where ((e.game_id = tg.game_id) and (e.team = tg.team))), m.end_min) as seg_end,
            0 as margin
           from (tg join mlen m on ((m.game_id = tg.game_id)))
        )
 select after_goals.game_id, after_goals.team, after_goals.seg_start, after_goals.seg_end, after_goals.margin
   from after_goals
union all
 select before_first.game_id, before_first.team, before_first.seg_start, before_first.seg_end, before_first.margin
   from before_first;

create index mv_state_segments_gt on public.mv_state_segments using btree (game_id, team);
alter materialized view mv_state_segments owner to postgres;
grant all on mv_state_segments to anon, authenticated, service_role;

create materialized view mv_team_breakdown as
 with routes as (
         select s.team, tl.league,
            r.route, r.used, s.ended_shot, s.ended_in_box, s.xt_sum
           from ((sequences s
             join mv_team_league tl on ((tl.team = s.team) and (s.league = tl.league)))
             cross join lateral ( values ('Through the middle'::text,s.finds_central), ('Around the outside'::text,s.finds_wide), ('Switch of play'::text,s.has_switch), ('Over the top'::text,s.long_ball), ('Wide combinations'::text,s.wide_triangles), ('Hold-up and lay'::text,s.hold_up), ('Patient build'::text,s.structured), ('From deep'::text,s.low_build), ('High regain'::text,s.high_build)) r(route, used))
          where s.is_open_play
        ), agg as (
         select routes.team, routes.league, routes.route,
            count(*) filter (where routes.used) as seqs,
            round((100.0 * avg((routes.used)::integer)), 1) as share_pct,
            round((100.0 * avg((routes.ended_shot)::integer) filter (where routes.used)), 1) as shot_pct,
            round((100.0 * avg((routes.ended_in_box)::integer) filter (where routes.used)), 1) as box_pct,
            round(avg(routes.xt_sum) filter (where routes.used), 4) as xt_per_seq
           from routes group by routes.team, routes.league, routes.route
        ), lg as (
         select agg.league, agg.route,
            avg(agg.shot_pct) as lg_shot, stddev_samp(agg.shot_pct) as sd_shot,
            avg(agg.share_pct) as lg_share, stddev_samp(agg.share_pct) as sd_share
           from agg group by agg.league, agg.route
        )
 select a.team, a.league, a.route, a.seqs, a.share_pct, a.shot_pct, a.box_pct, a.xt_per_seq,
    rank() over (partition by a.league, a.route order by a.share_pct desc) as share_rank,
    rank() over (partition by a.league, a.route order by a.shot_pct desc) as productivity_rank,
    round(((a.share_pct - lg.lg_share) / nullif(lg.sd_share, (0)::numeric)), 2) as z_share,
    round(((a.shot_pct - lg.lg_shot) / nullif(lg.sd_shot, (0)::numeric)), 2) as z_productivity
   from (agg a join lg on (((lg.league = a.league) and (lg.route = a.route))));

create index mv_team_breakdown_team on public.mv_team_breakdown using btree (team);
alter materialized view mv_team_breakdown owner to postgres;
grant all on mv_team_breakdown to anon, authenticated, service_role;

create materialized view mv_team_percentiles as
 with long as (
         select t.team, tl.league, v.metric, v.value
           from ((mv_team_all t
             join mv_team_league tl on ((tl.team = t.team)))
             cross join lateral ( values ('possession_pct'::text,t.possession_pct), ('field_tilt'::text,t.field_tilt), ('avg_touch_x'::text,t.avg_touch_x), ('directness'::text,t.directness), ('long_ball_pct'::text,t.long_ball_pct), ('build_from_back_pct'::text,t.build_from_back_pct), ('ppda'::text,t.ppda), ('def_height'::text,t.def_height), ('prog_passes_pg'::text,t.prog_passes_pg), ('box_entries_pg'::text,t.box_entries_pg), ('crosses_pg'::text,t.crosses_pg), ('shots_pg'::text,t.shots_pg), ('goals_pg'::text,t.goals_pg), ('open_play_shot_pct'::text,t.open_play_shot_pct), ('shots_against_pg'::text,t.shots_against_pg), ('goals_against_pg'::text,t.goals_against_pg), ('passes_per_seq'::text,t.passes_per_seq), ('secs_per_seq'::text,t.secs_per_seq), ('long_sequence_pct'::text,t.long_sequence_pct), ('pct_ending_in_shot'::text,t.pct_ending_in_shot), ('ground_gained'::text,t.ground_gained), ('sequences_pg'::text,t.sequences_pg), ('gk_long_pct'::text,t.gk_long_pct), ('d3_pass_share'::text,t.d3_pass_share), ('d3_accuracy'::text,t.d3_accuracy), ('d3_long_pct'::text,t.d3_long_pct), ('deep_circulation_pg'::text,t.deep_circulation_pg), ('cb_prog_pg'::text,t.cb_prog_pg), ('escape_pct'::text,t.escape_pct), ('deep_to_final_pct'::text,t.deep_to_final_pct), ('d3_touch_share'::text,t.d3_touch_share), ('att_directness'::text,t.att_directness), ('mid_release'::text,t.mid_release), ('ft_release'::text,t.ft_release), ('passes_per_shot'::text,t.passes_per_shot), ('ft_entries_pg'::text,t.ft_entries_pg), ('box_per_entry'::text,t.box_per_entry), ('final_to_shot_pct'::text,t.final_to_shot_pct), ('pct_left'::text,t.pct_left), ('pct_centre'::text,t.pct_centre), ('pct_right'::text,t.pct_right)) v(metric, value))
        ), r as (
         select l.team, l.league, l.metric, l.value, d.higher_is_better,
            percent_rank() over (partition by l.league, l.metric order by l.value) as pr
           from (long l join team_metric_defs d on ((d.key = l.metric)))
          where (l.value is not null)
        )
 select team, metric, value,
    round((((100)::double precision *
        case when higher_is_better then pr else ((1)::double precision - pr) end))::numeric, 0) as pct,
    league
   from r;

create index mv_team_percentiles_tm on public.mv_team_percentiles using btree (team, metric);
alter materialized view mv_team_percentiles owner to postgres;
grant all on mv_team_percentiles to anon, authenticated, service_role;

create materialized view mv_team_stat_ranks as
 with per as (
         select s.team, count(*) as matches,
            avg(s.final_third_passes) as final_third_passes,
            avg(s.zone14_passes) as zone14_passes,
            avg(s.progressive_passes) as progressive_passes,
            avg(s.passes_into_box) as passes_into_box,
            avg(s.defensive_actions) as defensive_actions,
            avg(s.defensive_actions_won) as defensive_actions_won,
            avg(s.shots) as shots,
            avg(s.shots_on_target) as shots_on_target,
            avg(s.fwd_passes) as fwd_passes,
            avg(s.lat_passes) as lat_passes,
            avg(s.bwd_passes) as bwd_passes
           from v_season_stats s group by s.team
        ), long as (
         select per.team, tl.league, v.metric, v.value
           from ((per join mv_team_league tl on ((tl.team = per.team)))
             cross join lateral ( values ('final_third_passes'::text,per.final_third_passes), ('zone14_passes'::text,per.zone14_passes), ('progressive_passes'::text,per.progressive_passes), ('passes_into_box'::text,per.passes_into_box), ('defensive_actions'::text,per.defensive_actions), ('defensive_actions_won'::text,per.defensive_actions_won), ('shots'::text,per.shots), ('shots_on_target'::text,per.shots_on_target), ('fwd_passes'::text,per.fwd_passes), ('lat_passes'::text,per.lat_passes), ('bwd_passes'::text,per.bwd_passes)) v(metric, value))
        )
 select team, metric, round(value, 2) as per_game,
    rank() over (partition by league, metric order by value desc) as league_rank,
    count(*) over (partition by league, metric) as of_teams,
    league
   from long;

create index mv_team_stat_ranks_tm on public.mv_team_stat_ranks using btree (team, metric);
alter materialized view mv_team_stat_ranks owner to postgres;
grant all on mv_team_stat_ranks to anon, authenticated, service_role;

create materialized view mv_league_summary as
 with ev as (
         select events.league, count(distinct events.game_id) as matches,
            count(distinct events.team) as teams
           from events group by events.league
        ), seq as (
         select sequences.league, count(*) as sequences
           from sequences group by sequences.league
        ), pl as (
         select player_search.league, count(*) as players_profiled
           from player_search group by player_search.league
        ), ins as (
         select tl.league, count(*) as insights
           from (insights i join mv_team_league tl on ((tl.team = i.team)))
          group by tl.league
        )
 select l.league, l.display_name, l.country, l.season,
    coalesce(ev.matches, (0)::bigint) as matches,
    coalesce(ev.teams, (0)::bigint) as teams,
    coalesce(pl.players_profiled, (0)::bigint) as players_profiled,
    coalesce(seq.sequences, (0)::bigint) as sequences,
    coalesce(ins.insights, (0)::bigint) as insights
   from ((((leagues l
     left join ev on ((ev.league = l.league)))
     left join seq on ((seq.league = l.league)))
     left join pl on ((pl.league = l.league)))
     left join ins on ((ins.league = l.league)))
  where l.is_active;

create unique index mv_league_summary_pk on public.mv_league_summary using btree (league);
alter materialized view mv_league_summary owner to postgres;
grant all on mv_league_summary to anon, authenticated, service_role;

create view v_team_directory as
 select t.team,
    tl.league,
    l.display_name as league_name,
    l.country,
    count(*) over (partition by tl.league) as teams_in_league,
    ( select count(*) as count
           from matches m
          where ((m.league = tl.league) and (m.home_score is not null) and ((m.home_team = t.team) or (m.away_team = t.team)))) as matches_played
   from ((mv_team_all t
     join mv_team_league tl on ((tl.team = t.team)))
     join leagues l on ((l.league = tl.league)));

alter view v_team_directory owner to postgres;
grant all on v_team_directory to anon, authenticated, service_role;

-- ---- order 2 --------------------------------------------------------
create materialized view mv_player_leverage as
 select pm.player_id, pm.team, sum(pm.minutes) as minutes_total,
    round(((100.0 * (sum(greatest(0, (least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start)))) filter (where (abs(sg.margin) <= 1)))::numeric) / (nullif(sum(greatest(0, (least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start)))), 0))::numeric), 1) as leverage_pct
   from (mv_player_stints pm
     join mv_state_segments sg on (((sg.game_id = pm.game_id) and (sg.team = pm.team) and (sg.seg_start < pm.end_min) and (sg.seg_end > pm.start_min))))
  group by pm.player_id, pm.team;

create index mv_player_leverage_p on public.mv_player_leverage using btree (player_id);
alter materialized view mv_player_leverage owner to postgres;
grant all on mv_player_leverage to anon, authenticated, service_role;

create materialized view mv_player_state_output as
 with ev_state as (
         select e.game_id, e.team, e.player_id, e.ws_id, e.type, e.x, e.y, e.end_x, e.end_y,
            e.outcome_type, (sg.margin)::numeric as margin
           from (events e
             join mv_state_segments sg on (((sg.game_id = e.game_id) and (sg.team = e.team) and (e.expanded_minute >= sg.seg_start) and (e.expanded_minute < sg.seg_end))))
          where (e.player_id is not null)
        ), shots as (
         select s_1.player_id, s_1.xg, state_weight(es.margin) as w
           from (mv_shot_xg s_1 join ev_state es on (((es.game_id = s_1.game_id) and (es.ws_id = s_1.ws_id))))
          where (s_1.is_pen = false)
        ), xt as (
         select es.player_id,
            (coalesce(xt_val(es.end_x, es.end_y), (0)::numeric) - coalesce(xt_val(es.x, es.y), (0)::numeric)) as xt_delta,
            state_weight(es.margin) as w
           from ev_state es
          where ((es.type = 'Pass'::text) and (es.outcome_type = 'Successful'::text) and (es.end_x is not null))
        ), wmin as (
         select pm.player_id,
            sum(greatest(0, (least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start)))) as raw_min,
            sum(((greatest(0, (least(pm.end_min, sg.seg_end) - greatest(pm.start_min, sg.seg_start))))::numeric * state_weight((sg.margin)::numeric))) as weighted_min
           from (mv_player_stints pm
             join mv_state_segments sg on (((sg.game_id = pm.game_id) and (sg.team = pm.team) and (sg.seg_start < pm.end_min) and (sg.seg_end > pm.start_min))))
          group by pm.player_id
        ), sh_agg as (
         select shots.player_id, sum(shots.xg) as raw_xg, sum((shots.xg * shots.w)) as live_xg
           from shots group by shots.player_id
        ), xt_agg as (
         select xt.player_id, sum(xt.xt_delta) as raw_xt, sum((xt.xt_delta * xt.w)) as live_xt
           from xt group by xt.player_id
        )
 select w.player_id, pcr.player, pcr.team, pcr.pos,
    round(((w.raw_min)::numeric / 90.0), 2) as nineties_raw,
    round((w.weighted_min / 90.0), 2) as nineties_live,
    round(((100.0 * w.weighted_min) / (nullif(w.raw_min, 0))::numeric), 1) as live_minute_pct,
    round((coalesce(s.raw_xg, (0)::numeric) / nullif(((w.raw_min)::numeric / 90.0), (0)::numeric)), 3) as xg_90_raw,
    round((coalesce(s.live_xg, (0)::numeric) / nullif((w.weighted_min / 90.0), (0)::numeric)), 3) as xg_90_live,
    round(((coalesce(s.live_xg, (0)::numeric) / nullif((w.weighted_min / 90.0), (0)::numeric)) - (coalesce(s.raw_xg, (0)::numeric) / nullif(((w.raw_min)::numeric / 90.0), (0)::numeric))), 3) as xg_90_delta,
    round((coalesce(x.raw_xt, (0)::numeric) / nullif(((w.raw_min)::numeric / 90.0), (0)::numeric)), 3) as xt_90_raw,
    round((coalesce(x.live_xt, (0)::numeric) / nullif((w.weighted_min / 90.0), (0)::numeric)), 3) as xt_90_live,
    round(((coalesce(x.live_xt, (0)::numeric) / nullif((w.weighted_min / 90.0), (0)::numeric)) - (coalesce(x.raw_xt, (0)::numeric) / nullif(((w.raw_min)::numeric / 90.0), (0)::numeric))), 3) as xt_90_delta
   from (((wmin w
     join player_chain_roles pcr on ((pcr.player_id = w.player_id)))
     left join sh_agg s on ((s.player_id = w.player_id)))
     left join xt_agg x on ((x.player_id = w.player_id)))
  where (w.raw_min >= 540);

create unique index mv_player_state_output_pk on public.mv_player_state_output using btree (player_id);
alter materialized view mv_player_state_output owner to postgres;
grant all on mv_player_state_output to anon, authenticated, service_role;

create view v_league_summary as
 select league, display_name, country, season, matches, teams, players_profiled, sequences, insights
   from mv_league_summary;
alter view v_league_summary owner to postgres;
grant all on v_league_summary to anon, authenticated, service_role;

create view v_seq_directness as
 select s.seq_uid, s.game_id, s.team, s.league, s.n_pass, s.dur_s,
    greatest('-1.0'::numeric, least(1.0, (((s.end_x - s.start_x))::numeric / nullif((s.mean_pass_len * (s.n_pass)::numeric), (0)::numeric)))) as directness,
    st.state, st.margin, st.is_close
   from (sequences s join mv_seq_state st using (seq_uid))
  where (s.is_open_play and (s.n_pass >= 2) and (coalesce(s.mean_pass_len, (0)::numeric) > (0)::numeric));
alter view v_seq_directness owner to postgres;
grant all on v_seq_directness to anon, authenticated, service_role;

-- CHANGED: league was min(s.league) across all competitions, which made
-- Arsenal an ENG-FA Cup club. Now resolved from mv_team_league, which is
-- registry-filtered. Clubs with no league competition are excluded, so
-- cup-only clubs cannot reach league-scoped insight generation.
create view v_team_sample as
 select s.team,
    tl.league,
    count(distinct s.game_id) filter (where s.league = tl.league) as matches,
    count(*) filter (where s.is_open_play and s.league = tl.league) as open_play_seqs,
    count(*) filter (where (s.is_open_play and s.league = tl.league and (s.start_x < (33.3)::double precision))) as deep_start_seqs,
    count(*) filter (where (s.is_open_play and s.league = tl.league and (st.state = 'winning'::text))) as seqs_winning,
    count(*) filter (where (s.is_open_play and s.league = tl.league and (st.state = 'losing'::text))) as seqs_losing,
    (count(distinct s.game_id) filter (where s.league = tl.league) >= 6) as meets_min_matches
   from ((sequences s
     join mv_team_league tl on (tl.team = s.team))
     left join mv_seq_state st on ((st.seq_uid = s.seq_uid)))
  group by s.team, tl.league;

alter view v_team_sample owner to postgres;
grant all on v_team_sample to anon, authenticated, service_role;
comment on view v_team_sample is
  'Team evidence base, scoped to the club league competition only. Cup fixtures are excluded from every count. Source of truth for the six-match minimum.';

create view v_team_signature as
 select distinct on (team) team, route as signature_route, share_pct, z_share, shot_pct, z_productivity,
        case
            when (z_productivity >= 0.5) then 'effective'::text
            when (z_productivity <= '-0.5'::numeric) then 'unproductive'::text
            else 'league average'::text
        end as signature_verdict,
    league
   from mv_team_breakdown
  order by team, z_share desc;
alter view v_team_signature owner to postgres;
grant all on v_team_signature to anon, authenticated, service_role;

-- ---- order 3 --------------------------------------------------------
create materialized view mv_league_availability as
 with ev as (
         select events.league, count(distinct events.game_id) as matches
           from events group by events.league
        ), ts as (
         select v_team_sample.league,
            count(*) filter (where v_team_sample.meets_min_matches) as qualifying,
            count(*) as total
           from v_team_sample group by v_team_sample.league
        ), ins as (
         select tl.league, count(*) as n
           from (insights i join mv_team_league tl on ((tl.team = i.team)))
          group by tl.league
        )
 select l.league, l.display_name,
    coalesce(ev.matches, (0)::bigint) as matches,
    coalesce(ts.qualifying, (0)::bigint) as clubs_at_threshold,
    coalesce(ts.total, (0)::bigint) as clubs,
    coalesce(ins.n, (0)::bigint) as insights,
    ( select detector_requirements.min_matches from detector_requirements
          where (detector_requirements.detector = 'team_profile'::text)) as min_matches_required,
        case
            when (coalesce(ts.qualifying, (0)::bigint) > 0) then 'available'::text
            when (coalesce(ev.matches, (0)::bigint) = 0) then 'no data yet'::text
            else 'below sample threshold'::text
        end as insight_status
   from (((leagues l
     left join ev on ((ev.league = l.league)))
     left join ts on ((ts.league = l.league)))
     left join ins on ((ins.league = l.league)))
  where l.is_active;

create unique index mv_league_availability_pk on public.mv_league_availability using btree (league);
alter materialized view mv_league_availability owner to postgres;
grant all on mv_league_availability to anon, authenticated, service_role;

create materialized view mv_squad_role as
 with mlen as (
         select events.game_id, (max(events.expanded_minute) + 1) as end_min
           from events group by events.game_id
        ), tg as (
         select distinct e.game_id, e.team, e.league, m.date, ml.end_min
           from ((events e join matches m on ((m.game_id = e.game_id)))
             join mlen ml on ((ml.game_id = e.game_id)))
          where ((e.team is not null) and (m.date is not null))
        ), team_last as (
         select tg.team, max(tg.date) as last_team_date from tg group by tg.team
        ), pt as (
         select pm.player_id, pm.team, min(t.league) as league,
            min(t.date) as first_date, max(t.date) as last_date,
            sum(pm.minutes) as minutes_played, count(*) as appearances,
            count(*) filter (where pm.is_starter) as starts
           from (mv_player_stints pm
             join tg t on (((t.game_id = pm.game_id) and (t.team = pm.team))))
          group by pm.player_id, pm.team
        ), moved as (
         select a.player_id, a.team, max(b.last_date) as later_elsewhere
           from (pt a join pt b on (((b.player_id = a.player_id) and (b.team <> a.team) and (b.last_date > a.last_date))))
          group by a.player_id, a.team
        ), bounds as (
         select p.player_id, p.team, p.league, p.first_date, p.last_date,
            p.minutes_played, p.appearances, p.starts,
                case when (mv.later_elsewhere is not null) then p.last_date else tl.last_team_date end as window_end
           from ((pt p
             left join moved mv on (((mv.player_id = p.player_id) and (mv.team = p.team))))
             join team_last tl on ((tl.team = p.team)))
        ), avail as (
         select b.player_id, b.team, b.league, b.first_date, b.last_date, b.window_end,
            b.minutes_played, b.appearances, b.starts,
            count(t.game_id) as games_available,
            coalesce(sum(t.end_min), (0)::bigint) as minutes_available
           from (bounds b
             left join tg t on (((t.team = b.team) and ((t.date >= b.first_date) and (t.date <= b.window_end)))))
          group by b.player_id, b.team, b.league, b.first_date, b.last_date, b.window_end, b.minutes_played, b.appearances, b.starts
        ), scored as (
         select a.player_id, a.team, a.league, a.first_date, a.last_date, a.window_end,
            a.minutes_played, a.appearances, a.starts, a.games_available, a.minutes_available,
            lv.leverage_pct,
            round(((100.0 * (a.minutes_played)::numeric) / (nullif(a.minutes_available, 0))::numeric), 1) as selection_pct,
            round(((100.0 * (a.starts)::numeric) / (nullif(a.games_available, 0))::numeric), 1) as start_pct
           from (avail a
             left join mv_player_leverage lv on (((lv.player_id = a.player_id) and (lv.team = a.team))))
        ), ranked as (
         select s.player_id, s.team, s.league, s.first_date, s.last_date, s.window_end,
            s.minutes_played, s.appearances, s.starts, s.games_available, s.minutes_available,
            s.leverage_pct, s.selection_pct, s.start_pct,
            rank() over (partition by s.team order by s.selection_pct desc nulls last) as squad_rank,
            round(((s.leverage_pct - avg(s.leverage_pct) over (partition by s.team)) / nullif(stddev_samp(s.leverage_pct) over (partition by s.team), (0)::numeric)), 2) as leverage_z_in_squad
           from scored s
        )
 select r.player_id, r.team, r.league, r.first_date, r.last_date, r.window_end,
    r.minutes_played, r.appearances, r.starts, r.games_available, r.minutes_available,
    r.leverage_pct, r.selection_pct, r.start_pct, r.squad_rank, r.leverage_z_in_squad,
    pcr.player, pcr.pos,
        case
            when (r.selection_pct >= (70)::numeric) then 'Key player'::text
            when (r.selection_pct >= (45)::numeric) then 'Starter'::text
            when (r.selection_pct >= (20)::numeric) then 'Rotation'::text
            else 'Fringe'::text
        end as squad_role
   from (ranked r join player_chain_roles pcr on ((pcr.player_id = r.player_id)))
  where (r.games_available >= 6);

create index mv_squad_role_player on public.mv_squad_role using btree (player_id);
alter materialized view mv_squad_role owner to postgres;
grant all on mv_squad_role to anon, authenticated, service_role;

create materialized view mv_team_directness_state as
 with base as (
         select d.team, tl.league, d.state,
            round(avg(d.directness), 4) as directness, count(*) as n
           from (v_seq_directness d
             join mv_team_league tl on ((tl.team = d.team) and (d.league = tl.league)))
          group by d.team, tl.league, d.state
        ), piv as (
         select base.team, base.league,
            max(base.directness) filter (where (base.state = 'winning'::text)) as dir_winning,
            max(base.directness) filter (where (base.state = 'drawing'::text)) as dir_drawing,
            max(base.directness) filter (where (base.state = 'losing'::text)) as dir_losing,
            sum(base.n) filter (where (base.state = 'winning'::text)) as n_winning,
            sum(base.n) filter (where (base.state = 'drawing'::text)) as n_drawing,
            sum(base.n) filter (where (base.state = 'losing'::text)) as n_losing,
            round(avg(base.directness), 4) as dir_overall
           from base group by base.team, base.league
        )
 select team, league, dir_winning, dir_drawing, dir_losing,
    n_winning, n_drawing, n_losing, dir_overall,
    round((dir_losing - dir_winning), 4) as swing_l_minus_w,
    rank() over (partition by league order by (dir_losing - dir_winning) desc) as swing_rank
   from piv;

create unique index mv_team_directness_state_pk on public.mv_team_directness_state using btree (team);
alter materialized view mv_team_directness_state owner to postgres;
grant all on mv_team_directness_state to anon, authenticated, service_role;

-- ---- order 4 --------------------------------------------------------
create view v_league_availability as
 select league, display_name, matches, clubs_at_threshold, clubs, insights,
    min_matches_required, insight_status
   from mv_league_availability;
alter view v_league_availability owner to postgres;
grant all on v_league_availability to anon, authenticated, service_role;

create view v_squad_role as
 with lg as (
         select mv_squad_role.league,
            percentile_cont((0.25)::double precision) within group (order by ((mv_squad_role.leverage_pct)::double precision)) as p25,
            percentile_cont((0.50)::double precision) within group (order by ((mv_squad_role.leverage_pct)::double precision)) as p50
           from mv_squad_role
          where (mv_squad_role.leverage_pct is not null)
          group by mv_squad_role.league
        )
 select r.player_id, r.player, r.team, r.pos, r.squad_role, r.squad_rank,
    r.selection_pct, r.start_pct, r.leverage_pct, r.leverage_z_in_squad,
    r.minutes_played, r.minutes_available, r.appearances, r.starts, r.games_available,
    (round(((100.0)::double precision * percent_rank() over (partition by r.league order by r.leverage_pct))))::integer as leverage_pct_rank,
    ((r.selection_pct >= (40)::numeric) and ((r.leverage_pct)::double precision < lg.p25)) as minutes_inflated,
    r.league
   from (mv_squad_role r join lg on ((lg.league = r.league)));
alter view v_squad_role owner to postgres;
grant all on v_squad_role to anon, authenticated, service_role;

-- ---------------------------------------------------------------------

-- =====================================================================
-- 5. REGENERATE DERIVED CONTENT, STILL INSIDE THE TRANSACTION
--    Insights are built from v_team_sample, so they must be rebuilt
--    before the summaries that count them.
-- =====================================================================
select build_insights();
select polish_insights();
select refresh_site_summaries();

-- =====================================================================
-- 6. ASSERTIONS. Every one raises on failure, rolling back everything.
--    Relational wherever a snapshot total could legitimately drift.
-- =====================================================================

-- 6a. All 21 objects exist.
do $a_exists$
declare expected text[] := array[
  'mv_game_goals','mv_team_league','mv_seq_state','mv_state_segments',
  'mv_team_breakdown','mv_team_percentiles','mv_team_stat_ranks','mv_league_summary',
  'v_team_directory','mv_player_leverage','mv_player_state_output','v_league_summary',
  'v_seq_directness','v_team_sample','v_team_signature','mv_league_availability',
  'mv_squad_role','mv_team_directness_state','v_league_availability','v_squad_role',
  'v_cup_shootouts'];
  missing text[];
begin
  select array_agg(x) into missing from unnest(expected) x
  where not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                    where n.nspname='public' and c.relname = x);
  if missing is not null then
    raise exception 'ASSERT FAILED. Objects not recreated: %', missing;
  end if;
end
$a_exists$;

-- 6b. Metadata preserved: owner, ACL and index count on every object.
do $a_meta$
declare bad text;
begin
  select string_agg(c.relname, ', ') into bad
  from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where c.relname in ('mv_game_goals','mv_team_league','mv_seq_state','mv_state_segments',
        'mv_team_breakdown','mv_team_percentiles','mv_team_stat_ranks','mv_league_summary',
        'v_team_directory','mv_player_leverage','mv_player_state_output','v_league_summary',
        'v_seq_directness','v_team_sample','v_team_signature','mv_league_availability',
        'mv_squad_role','mv_team_directness_state','v_league_availability','v_squad_role')
    and (pg_get_userbyid(c.relowner) <> 'postgres'
         or not has_table_privilege('anon', c.oid, 'SELECT')
         or not has_table_privilege('authenticated', c.oid, 'SELECT')
         or not has_table_privilege('service_role', c.oid, 'SELECT'));
  if bad is not null then
    raise exception 'ASSERT FAILED. Owner or grants not restored on: %', bad;
  end if;

  if (select count(*) from pg_indexes where schemaname='public'
        and tablename in ('mv_game_goals','mv_team_league','mv_seq_state','mv_state_segments',
            'mv_team_breakdown','mv_team_percentiles','mv_team_stat_ranks','mv_league_summary',
            'mv_player_leverage','mv_player_state_output','mv_league_availability',
            'mv_squad_role','mv_team_directness_state')) <> 14 then
    raise exception 'ASSERT FAILED. Expected 14 indexes across the recreated matviews, found %.',
      (select count(*) from pg_indexes where schemaname='public'
        and tablename in ('mv_game_goals','mv_team_league','mv_seq_state','mv_state_segments',
            'mv_team_breakdown','mv_team_percentiles','mv_team_stat_ranks','mv_league_summary',
            'mv_player_leverage','mv_player_state_output','mv_league_availability',
            'mv_squad_role','mv_team_directness_state'));
  end if;
end
$a_meta$;

-- 6c. Raw data untouched. Compared against the baseline captured at the
--     top of this transaction, so it cannot be defeated by a scrape.
do $a_raw$
declare p record;
begin
  select * into p from _pre_counts;
  if (select count(*) from events)    <> p.events
  or (select count(*) from matches)   <> p.matches
  or (select count(*) from sequences) <> p.sequences
  or (select count(*) from lineups)   <> p.lineups
  or (select count(*) from events where period = 5) <> p.period5_events then
    raise exception 'ASSERT FAILED. Raw data changed during migration. This migration must not write to raw tables.';
  end if;
end
$a_raw$;

-- 6d. Coverage, relational rather than a snapshot total.
do $a_cover$
declare n bigint;
begin
  select count(*) into n from sequences s
   where not exists (select 1 from mv_seq_state st where st.seq_uid = s.seq_uid);
  if n <> 0 then raise exception 'ASSERT FAILED. mv_seq_state misses % sequences.', n; end if;

  select count(*) into n from (select distinct game_id, team from events where team is not null) g
   where not exists (select 1 from mv_state_segments sg
                     where sg.game_id = g.game_id and sg.team = g.team);
  if n <> 0 then raise exception 'ASSERT FAILED. mv_state_segments misses % game-team pairs.', n; end if;

  select count(*) into n from mv_seq_state where state is null;
  if n <> 0 then raise exception 'ASSERT FAILED. % sequences have a null game state.', n; end if;
end
$a_cover$;

-- 6e. Match 1951511 reconciles at 1-1, and the shootout survives at 8-7.
do $a_shootout$
declare h int; a int; sh record;
begin
  with ev as (
    select g.game_id,
      count(*) filter (where g.scoring_team = x.home_ev) h,
      count(*) filter (where g.scoring_team = x.away_ev) a
    from mv_game_goals g
    join (select m.game_id,
            coalesce(th.event_name, m.home_team) home_ev,
            coalesce(ta.event_name, m.away_team) away_ev
          from matches m
          left join team_names th on th.match_name = m.home_team and th.league = m.league
          left join team_names ta on ta.match_name = m.away_team and ta.league = m.league) x
      on x.game_id = g.game_id
    group by g.game_id)
  select coalesce(ev.h,0), coalesce(ev.a,0) into h, a
  from matches m left join ev on ev.game_id = m.game_id where m.game_id = '1951511';

  if h <> 1 or a <> 1 then
    raise exception 'ASSERT FAILED. 1951511 goals from events are %-%, expected 1-1.', h, a;
  end if;

  select * into sh from v_cup_shootouts where game_id = '1951511';
  if sh is null then raise exception 'ASSERT FAILED. Shootout for 1951511 not preserved.'; end if;
  if sh.home_shootout_goals <> 8 or sh.away_shootout_goals <> 7 or sh.kicks_taken <> 16 then
    raise exception 'ASSERT FAILED. Shootout reads %-% over % kicks, expected 8-7 over 16.',
      sh.home_shootout_goals, sh.away_shootout_goals, sh.kicks_taken;
  end if;
end
$a_shootout$;

-- 6f. Arsenal resolves to the Premier League, and no cup competition
--     reaches any league-scoped object.
do $a_league$
declare v text; n bigint;
begin
  select league into v from mv_team_league where team = 'Arsenal';
  if v is distinct from 'ENG-Premier League' then
    raise exception 'ASSERT FAILED. mv_team_league resolves Arsenal to %, expected ENG-Premier League.', v;
  end if;

  select league into v from v_team_sample where team = 'Arsenal';
  if v is distinct from 'ENG-Premier League' then
    raise exception 'ASSERT FAILED. v_team_sample resolves Arsenal to %, expected ENG-Premier League.', v;
  end if;

  select
    (select count(*) from v_team_sample where league in (select league from leagues where competition_type='cup'))
  + (select count(*) from mv_team_league where league in (select league from leagues where competition_type='cup'))
  + (select count(*) from mv_team_percentiles where league in (select league from leagues where competition_type='cup'))
  + (select count(*) from mv_team_stat_ranks where league in (select league from leagues where competition_type='cup'))
  + (select count(*) from mv_team_breakdown where league in (select league from leagues where competition_type='cup'))
  + (select count(*) from mv_team_directness_state where league in (select league from leagues where competition_type='cup'))
  + (select count(*) from v_team_directory where league in (select league from leagues where competition_type='cup'))
  into n;
  if n <> 0 then
    raise exception 'ASSERT FAILED. % rows in league-scoped objects carry a cup competition.', n;
  end if;

  -- No club may be silently filed as MLS. Every club must resolve to a
  -- league it actually played in.
  select count(*) into n from mv_team_league tl
   where not exists (select 1 from events e
                     where e.team = tl.team and e.league = tl.league);
  if n <> 0 then
    raise exception 'ASSERT FAILED. % clubs resolve to a league they never played in.', n;
  end if;
end
$a_league$;

-- 6g. Arsenal insights must no longer rest on the cross-competition pool.
--     Not asserted as zero: Arsenal has 6 Premier League fixtures and may
--     legitimately qualify. What must not survive is the 54-match pool.
do $a_insights$
declare m bigint; lg text;
begin
  select matches, league into m, lg from v_team_sample where team = 'Arsenal';
  if lg is distinct from 'ENG-Premier League' then
    raise exception 'ASSERT FAILED. Arsenal evidence base is scoped to %.', lg;
  end if;
  if m > (select count(*) from matches
          where league = 'ENG-Premier League'
            and (home_team = 'Arsenal' or away_team = 'Arsenal')
            and home_score is not null) then
    raise exception 'ASSERT FAILED. Arsenal evidence base covers % matches, more than its played Premier League fixtures.', m;
  end if;
end
$a_insights$;

-- 6h. The full invariant battery. Raises on any error-level failure.
select verify_rebuild();

commit;

-- =====================================================================
-- 7. POST-MIGRATION REPORT (read-only, nothing depends on it)
-- =====================================================================
select 'mv_game_goals' o, count(*) n from mv_game_goals
union all select 'mv_team_league', count(*) from mv_team_league
union all select 'mv_seq_state', count(*) from mv_seq_state
union all select 'mv_state_segments', count(*) from mv_state_segments
union all select 'mv_team_breakdown', count(*) from mv_team_breakdown
union all select 'mv_team_percentiles', count(*) from mv_team_percentiles
union all select 'mv_team_stat_ranks', count(*) from mv_team_stat_ranks
union all select 'mv_league_summary', count(*) from mv_league_summary
union all select 'mv_player_leverage', count(*) from mv_player_leverage
union all select 'mv_player_state_output', count(*) from mv_player_state_output
union all select 'mv_league_availability', count(*) from mv_league_availability
union all select 'mv_squad_role', count(*) from mv_squad_role
union all select 'mv_team_directness_state', count(*) from mv_team_directness_state
union all select 'insights_total', count(*) from insights
union all select 'insights_arsenal', count(*) from insights where team = 'Arsenal'
order by 1;

select name, severity, violations from run_invariants() order by severity, name;
