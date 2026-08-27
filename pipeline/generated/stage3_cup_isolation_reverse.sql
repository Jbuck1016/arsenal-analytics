-- GENERATED FILE. DO NOT HAND EDIT.
-- Source: pipeline/tools/generate_cup_isolation.sql
-- REVERSE: expects forward definitions and restores the exact captured baseline.

begin;
set local statement_timeout = '1800s';

do $preflight$
declare captured jsonb:='{"mv_team_all": {"hash": "c11f7fe0b2921e7a4c767ece990689a6", "kind": "m", "order": 2}, "mv_seq_state": {"hash": "51b9dc1cc5ef64d5fc7e3d96e81fc60d", "kind": "m", "order": 1}, "v_squad_role": {"hash": "60ee33ae248e1c15ff224ea3978ae848", "kind": "v", "order": 4}, "mv_game_goals": {"hash": "578f86c1b8d9ce958c24a901bbbb01ba", "kind": "m", "order": 0}, "mv_player_dna": {"hash": "b49901e743b16dff06368cffa478c38b", "kind": "m", "order": 4}, "mv_squad_role": {"hash": "4fc842a5f86cf8d15ce4e8018f936624", "kind": "m", "order": 3}, "mv_team_lanes": {"hash": "c9250a0da7f35676f106c22fd6f18494", "kind": "m", "order": 0}, "mv_team_match": {"hash": "c0719f2506842058a9a60c339e683330", "kind": "m", "order": 0}, "mv_team_zones": {"hash": "59ba23126806273a932b9c0c551b3409", "kind": "m", "order": 1}, "v_team_sample": {"hash": "1b3384f6312fee5c6cb18f084f33c0fd", "kind": "v", "order": 2}, "mv_team_league": {"hash": "b285772da5a03d498e29763dbb9c5ee8", "kind": "m", "order": 0}, "mv_team_season": {"hash": "1d255af4a3766e1ed6b8731d58b94c75", "kind": "m", "order": 1}, "v_season_stats": {"hash": "9ac5d631c82eae4b1a5fb3ab5b71e01d", "kind": "v", "order": 0}, "mv_team_buildup": {"hash": "00cf332c3dede42e33129e452e2744fd", "kind": "m", "order": 1}, "v_league_summary": {"hash": "e438185e60916329df9279272c04a402", "kind": "v", "order": 2}, "v_seq_directness": {"hash": "af50b49ccfb1ebbf9a5763721957a3e8", "kind": "v", "order": 2}, "v_team_directory": {"hash": "41ffc308acb1b43677dd514a47df1e47", "kind": "v", "order": 3}, "v_team_signature": {"hash": "d39381c8ede106b958d8ba96b363e2a4", "kind": "v", "order": 2}, "mv_league_summary": {"hash": "9a6a4b55eda991c44faf95417080c0ff", "kind": "m", "order": 1}, "mv_player_pillars": {"hash": "357785db1b14462e4081f7f720855e8c", "kind": "m", "order": 3}, "mv_state_segments": {"hash": "619ca8322d2570ec843328977837526d", "kind": "m", "order": 1}, "mv_team_breakdown": {"hash": "6869d17cd017ef8309f692ab6c8e244c", "kind": "m", "order": 1}, "mv_team_sequences": {"hash": "f2c7fdf3a44d98990922cee81568daf9", "kind": "m", "order": 0}, "mv_metric_examples": {"hash": "649715f1cdf2d0098ef4d22141046b71", "kind": "m", "order": 3}, "mv_player_leverage": {"hash": "a14b653283d9747a526bf9ae381e7896", "kind": "m", "order": 2}, "mv_team_buildphase": {"hash": "01dd66db9362874403c7a677b7e3f847", "kind": "m", "order": 1}, "mv_team_stat_ranks": {"hash": "a97b82bef28a011da1df5664f561ebc5", "kind": "m", "order": 1}, "mv_player_team_poss": {"hash": "e9a085d668362a00b12e35966287da3d", "kind": "m", "order": 1}, "mv_team_attackphase": {"hash": "941a5b108404538278b38e68e6485d7e", "kind": "m", "order": 1}, "mv_team_carry_zones": {"hash": "b8860eb483785897adf36b3f5a6677b0", "kind": "m", "order": 1}, "mv_team_percentiles": {"hash": "feba1267576d911fb0ebfa26952e954c", "kind": "m", "order": 3}, "mv_player_percentiles": {"hash": "0409503a881ee0152a765e14c0ebb264", "kind": "m", "order": 2}, "v_league_availability": {"hash": "03589a42a087c37078c0ec441dcb571e", "kind": "v", "order": 4}, "mv_league_availability": {"hash": "628abdb6008aca919bb9a51de89dc12c", "kind": "m", "order": 3}, "mv_player_state_output": {"hash": "89f0bd9848fe195939b1b5e4fba52e5e", "kind": "m", "order": 2}, "mv_team_directness_state": {"hash": "bc5f6b61961d3aa41cd17331fd37b99a", "kind": "m", "order": 3}}'::jsonb; actual jsonb; problem text;
begin
 create temp table _pf_seed(name text primary key) on commit drop;
 insert into _pf_seed select jsonb_array_elements_text('["mv_game_goals", "mv_league_availability", "mv_league_summary", "mv_player_percentiles", "mv_player_state_output", "mv_squad_role", "mv_state_segments", "mv_team_attackphase", "mv_team_breakdown", "mv_team_buildphase", "mv_team_lanes", "mv_team_league", "mv_team_match", "mv_team_sequences", "mv_team_zones", "v_season_stats", "v_seq_directness", "v_team_directory", "v_team_sample"]'::jsonb);
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
-- DEPTH mv_team_lanes=0
-- DEPTH mv_team_league=0
-- DEPTH mv_team_match=0
-- DEPTH mv_team_sequences=0
-- DEPTH v_season_stats=0
-- DEPTH mv_league_summary=1
-- DEPTH mv_player_team_poss=1
-- DEPTH mv_seq_state=1
-- DEPTH mv_state_segments=1
-- DEPTH mv_team_attackphase=1
-- DEPTH mv_team_breakdown=1
-- DEPTH mv_team_buildphase=1
-- DEPTH mv_team_buildup=1
-- DEPTH mv_team_carry_zones=1
-- DEPTH mv_team_season=1
-- DEPTH mv_team_stat_ranks=1
-- DEPTH mv_team_zones=1
-- DEPTH mv_player_leverage=2
-- DEPTH mv_player_percentiles=2
-- DEPTH mv_player_state_output=2
-- DEPTH mv_team_all=2
-- DEPTH v_league_summary=2
-- DEPTH v_seq_directness=2
-- DEPTH v_team_sample=2
-- DEPTH v_team_signature=2
-- DEPTH mv_league_availability=3
-- DEPTH mv_metric_examples=3
-- DEPTH mv_player_pillars=3
-- DEPTH mv_squad_role=3
-- DEPTH mv_team_directness_state=3
-- DEPTH mv_team_percentiles=3
-- DEPTH v_team_directory=3
-- DEPTH mv_player_dna=4
-- DEPTH v_league_availability=4
-- DEPTH v_squad_role=4

-- DROP: reverse topological order, no CASCADE
drop view if exists public.v_squad_role;
drop view if exists public.v_league_availability;
drop materialized view if exists public.mv_player_dna;
drop view if exists public.v_team_directory;
drop materialized view if exists public.mv_team_percentiles;
drop materialized view if exists public.mv_team_directness_state;
drop materialized view if exists public.mv_squad_role;
drop materialized view if exists public.mv_player_pillars;
drop materialized view if exists public.mv_metric_examples;
drop materialized view if exists public.mv_league_availability;
drop view if exists public.v_team_signature;
drop view if exists public.v_team_sample;
drop view if exists public.v_seq_directness;
drop view if exists public.v_league_summary;
drop materialized view if exists public.mv_team_all;
drop materialized view if exists public.mv_player_state_output;
drop materialized view if exists public.mv_player_percentiles;
drop materialized view if exists public.mv_player_leverage;
drop materialized view if exists public.mv_team_zones;
drop materialized view if exists public.mv_team_stat_ranks;
drop materialized view if exists public.mv_team_season;
drop materialized view if exists public.mv_team_carry_zones;
drop materialized view if exists public.mv_team_buildup;
drop materialized view if exists public.mv_team_buildphase;
drop materialized view if exists public.mv_team_breakdown;
drop materialized view if exists public.mv_team_attackphase;
drop materialized view if exists public.mv_state_segments;
drop materialized view if exists public.mv_seq_state;
drop materialized view if exists public.mv_player_team_poss;
drop materialized view if exists public.mv_league_summary;
drop view if exists public.v_season_stats;
drop materialized view if exists public.mv_team_sequences;
drop materialized view if exists public.mv_team_match;
drop materialized view if exists public.mv_team_league;
drop materialized view if exists public.mv_team_lanes;
drop materialized view if exists public.mv_game_goals;

-- CREATE: topological order
create materialized view public.mv_game_goals as
WITH gteams AS (
         SELECT events.game_id,
            array_agg(DISTINCT events.team) AS tms
           FROM events
          WHERE (events.team IS NOT NULL)
          GROUP BY events.game_id
        ), g AS (
         SELECT e.game_id,
            e.expanded_minute,
            e.second,
            e.team,
                CASE
                    WHEN (e.qualifiers IS NULL) THEN false
                    ELSE (EXISTS ( SELECT 1
                       FROM jsonb_array_elements(e.qualifiers) q(value)
                      WHERE (((q.value -> 'type'::text) ->> 'displayName'::text) ~~* '%own%'::text)))
                END AS is_og
           FROM events e
          WHERE e.is_goal
        )
 SELECT g.game_id,
    g.expanded_minute,
    g.second,
        CASE
            WHEN g.is_og THEN ( SELECT t.t
               FROM unnest(gt.tms) t(t)
              WHERE (t.t <> g.team)
             LIMIT 1)
            ELSE g.team
        END AS scoring_team,
    g.is_og
   FROM (g
     JOIN gteams gt USING (game_id))
  WHERE ((NOT g.is_og) OR (( SELECT count(*) AS count
           FROM unnest(gt.tms) t(t)
          WHERE (t.t <> g.team)) = 1));
CREATE INDEX mv_game_goals_idx ON public.mv_game_goals USING btree (game_id, expanded_minute);
alter materialized view public.mv_game_goals owner to postgres;
revoke all on public.mv_game_goals from public, anon, authenticated, service_role;
grant SELECT on public.mv_game_goals to anon;
grant SELECT on public.mv_game_goals to authenticated;
grant DELETE on public.mv_game_goals to service_role;
grant INSERT on public.mv_game_goals to service_role;
grant MAINTAIN on public.mv_game_goals to service_role;
grant REFERENCES on public.mv_game_goals to service_role;
grant SELECT on public.mv_game_goals to service_role;
grant TRIGGER on public.mv_game_goals to service_role;
grant TRUNCATE on public.mv_game_goals to service_role;
grant UPDATE on public.mv_game_goals to service_role;

create materialized view public.mv_team_lanes as
WITH a AS (
         SELECT events.team,
                CASE
                    WHEN (events.y < (33.3)::double precision) THEN 'R'::text
                    WHEN (events.y < (66.7)::double precision) THEN 'C'::text
                    ELSE 'L'::text
                END AS lane,
            (events.x >= (66.7)::double precision) AS final_third,
            ((events.type = 'Pass'::text) AND (events.end_x >= (83)::double precision) AND ((events.end_y >= (21)::double precision) AND (events.end_y <= (79)::double precision))) AS into_box,
            events.is_shot
           FROM events
          WHERE ((events.team IS NOT NULL) AND (events.x IS NOT NULL) AND (events.y IS NOT NULL) AND ((events.is_open_play AND (events.type = ANY (ARRAY['Pass'::text, 'TakeOn'::text, 'BallTouch'::text, 'Dispossessed'::text]))) OR events.is_shot))
        )
 SELECT team,
    lane,
    count(*) AS touches,
    count(*) FILTER (WHERE final_third) AS final_third_touches,
    count(*) FILTER (WHERE into_box) AS box_entries,
    count(*) FILTER (WHERE is_shot) AS shots,
    round(((100.0 * (count(*) FILTER (WHERE final_third))::numeric) / NULLIF(sum(count(*) FILTER (WHERE final_third)) OVER (PARTITION BY team), (0)::numeric)), 1) AS pct_of_final_third
   FROM a
  GROUP BY team, lane;
CREATE INDEX mv_team_lanes_team_idx ON public.mv_team_lanes USING btree (team);
alter materialized view public.mv_team_lanes owner to postgres;
revoke all on public.mv_team_lanes from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_lanes to anon;
grant SELECT on public.mv_team_lanes to authenticated;
grant DELETE on public.mv_team_lanes to service_role;
grant INSERT on public.mv_team_lanes to service_role;
grant MAINTAIN on public.mv_team_lanes to service_role;
grant REFERENCES on public.mv_team_lanes to service_role;
grant SELECT on public.mv_team_lanes to service_role;
grant TRIGGER on public.mv_team_lanes to service_role;
grant TRUNCATE on public.mv_team_lanes to service_role;
grant UPDATE on public.mv_team_lanes to service_role;

create materialized view public.mv_team_league as
SELECT team,
    min(league) AS league,
    count(*) AS events
   FROM events
  WHERE (team IS NOT NULL)
  GROUP BY team;
CREATE UNIQUE INDEX mv_team_league_pk ON public.mv_team_league USING btree (team);
alter materialized view public.mv_team_league owner to postgres;
revoke all on public.mv_team_league from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_league to anon;
grant SELECT on public.mv_team_league to authenticated;
grant DELETE on public.mv_team_league to service_role;
grant INSERT on public.mv_team_league to service_role;
grant MAINTAIN on public.mv_team_league to service_role;
grant REFERENCES on public.mv_team_league to service_role;
grant SELECT on public.mv_team_league to service_role;
grant TRIGGER on public.mv_team_league to service_role;
grant TRUNCATE on public.mv_team_league to service_role;
grant UPDATE on public.mv_team_league to service_role;

create materialized view public.mv_team_match as
WITH ev AS (
         SELECT e.game_id,
            e.team,
            e.type,
            e.x,
            e.y,
            e.end_x,
            e.end_y,
            e.is_shot,
            e.is_open_play,
            (e.outcome_type = 'Successful'::text) AS ok,
            ((e.type = 'Pass'::text) AND (e.x IS NOT NULL) AND (e.end_x IS NOT NULL) AND (((e.x < (50)::double precision) AND (e.end_x < (50)::double precision) AND ((e.end_x - e.x) >= (30)::double precision)) OR ((e.x < (50)::double precision) AND (e.end_x >= (50)::double precision) AND ((e.end_x - e.x) >= (15)::double precision)) OR ((e.x >= (50)::double precision) AND (e.end_x >= (50)::double precision) AND ((e.end_x - e.x) >= (10)::double precision)))) AS prog,
            (e.qualifiers @> '[{"type": {"displayName": "Cross"}}]'::jsonb) AS q_cross,
            (e.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb) AS q_long
           FROM events e
          WHERE (e.team IS NOT NULL)
        ), t AS (
         SELECT z.game_id,
            z.team,
            count(*) FILTER (WHERE (z.type = 'Pass'::text)) AS passes,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND z.ok)) AS passes_cmp,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND z.is_open_play AND z.q_long)) AS long_balls,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND z.prog AND z.ok)) AS prog_passes,
            COALESCE(sum((GREATEST((0)::double precision, (z.end_x - z.x)) * (1.05)::double precision)) FILTER (WHERE ((z.type = 'Pass'::text) AND z.ok)), (0)::double precision) AS territory,
            count(*) FILTER (WHERE (z.is_touch_proxy AND (z.x >= (66.7)::double precision))) AS ft_touches,
            count(*) FILTER (WHERE z.is_touch_proxy) AS touches,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND (z.x < (33.3)::double precision))) AS passes_from_def_third,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND z.is_open_play AND z.ok AND (z.end_x >= (83)::double precision) AND ((z.end_y >= (21)::double precision) AND (z.end_y <= (79)::double precision)))) AS box_entries_pass,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND z.is_open_play AND z.q_cross)) AS crosses,
            count(*) FILTER (WHERE z.is_shot) AS shots,
            count(*) FILTER (WHERE (z.is_shot AND z.is_open_play)) AS shots_open,
            count(*) FILTER (WHERE (z.type = 'Goal'::text)) AS goals,
            count(*) FILTER (WHERE (z.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text]))) AS def_actions,
            count(*) FILTER (WHERE ((z.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text])) AND (z.x > (40)::double precision))) AS def_actions_high,
            count(*) FILTER (WHERE ((z.type = 'Pass'::text) AND (z.x < (60)::double precision))) AS passes_own60,
            round((avg(z.x) FILTER (WHERE (z.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Challenge'::text]))))::numeric, 2) AS def_height,
            round((avg(z.x) FILTER (WHERE z.is_touch_proxy))::numeric, 2) AS avg_touch_x
           FROM ( SELECT ev.game_id,
                    ev.team,
                    ev.type,
                    ev.x,
                    ev.y,
                    ev.end_x,
                    ev.end_y,
                    ev.is_shot,
                    ev.is_open_play,
                    ev.ok,
                    ev.prog,
                    ev.q_cross,
                    ev.q_long,
                    ((ev.type <> ALL (ARRAY['SubstitutionOn'::text, 'SubstitutionOff'::text, 'Card'::text, 'FormationChange'::text, 'FormationSet'::text, 'Start'::text, 'End'::text, 'CornerAwarded'::text, 'OffsideGiven'::text, 'OffsideProvoked'::text])) AND (ev.x IS NOT NULL)) AS is_touch_proxy
                   FROM ev) z
          GROUP BY z.game_id, z.team
        ), paired AS (
         SELECT a.game_id,
            a.team,
            a.passes,
            a.passes_cmp,
            a.long_balls,
            a.prog_passes,
            a.territory,
            a.ft_touches,
            a.touches,
            a.passes_from_def_third,
            a.box_entries_pass,
            a.crosses,
            a.shots,
            a.shots_open,
            a.goals,
            a.def_actions,
            a.def_actions_high,
            a.passes_own60,
            a.def_height,
            a.avg_touch_x,
            b.team AS opp,
            b.passes AS opp_passes,
            b.passes_own60 AS opp_passes_own60,
            b.ft_touches AS opp_ft_touches,
            b.touches AS opp_touches,
            b.shots AS opp_shots,
            b.goals AS opp_goals
           FROM (t a
             JOIN t b ON (((b.game_id = a.game_id) AND (b.team <> a.team))))
        )
 SELECT game_id,
    team,
    opp,
    passes,
    passes_cmp,
    shots,
    shots_open,
    goals,
    opp_shots,
    opp_goals,
    round(((100.0 * (passes)::numeric) / (NULLIF((passes + opp_passes), 0))::numeric), 1) AS possession_pct,
    round(((100.0 * (ft_touches)::numeric) / (NULLIF((ft_touches + opp_ft_touches), 0))::numeric), 1) AS field_tilt,
    round(((opp_passes_own60)::numeric / (NULLIF(def_actions_high, 0))::numeric), 2) AS ppda,
    def_height,
    avg_touch_x,
    round(((100.0 * (long_balls)::numeric) / (NULLIF(passes, 0))::numeric), 1) AS long_ball_pct,
    round(((100.0 * (passes_from_def_third)::numeric) / (NULLIF(passes, 0))::numeric), 1) AS build_from_back_pct,
    round(((territory)::numeric / (NULLIF(passes_cmp, 0))::numeric), 2) AS directness,
    prog_passes,
    box_entries_pass,
    crosses,
    def_actions,
    round(((100.0 * (shots_open)::numeric) / (NULLIF(shots, 0))::numeric), 1) AS open_play_shot_pct
   FROM paired;
CREATE UNIQUE INDEX mv_team_match_game_id_team_idx ON public.mv_team_match USING btree (game_id, team);
alter materialized view public.mv_team_match owner to postgres;
revoke all on public.mv_team_match from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_match to anon;
grant SELECT on public.mv_team_match to authenticated;
grant DELETE on public.mv_team_match to service_role;
grant INSERT on public.mv_team_match to service_role;
grant MAINTAIN on public.mv_team_match to service_role;
grant REFERENCES on public.mv_team_match to service_role;
grant SELECT on public.mv_team_match to service_role;
grant TRIGGER on public.mv_team_match to service_role;
grant TRUNCATE on public.mv_team_match to service_role;
grant UPDATE on public.mv_team_match to service_role;

create materialized view public.mv_team_sequences as
WITH base AS (
         SELECT events.game_id,
            events.ws_id,
            events.team,
            events.type,
            events.x,
            events.y,
            events.end_x,
            events.is_shot,
            events.period,
            ((events.minute * 60) + events.second) AS sec,
            lag(events.team) OVER w AS prev_team,
            lag(events.period) OVER w AS prev_period,
            (((events.minute * 60) + events.second) - lag(((events.minute * 60) + events.second)) OVER w) AS gap
           FROM events
          WHERE ((events.team IS NOT NULL) AND (events.x IS NOT NULL) AND (events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'OffsideProvoked'::text, 'CornerAwarded'::text])))
          WINDOW w AS (PARTITION BY events.game_id ORDER BY events.ws_id)
        ), flagged AS (
         SELECT base.game_id,
            base.ws_id,
            base.team,
            base.type,
            base.x,
            base.y,
            base.end_x,
            base.is_shot,
            base.period,
            base.sec,
            base.prev_team,
            base.prev_period,
            base.gap,
                CASE
                    WHEN ((base.prev_team IS DISTINCT FROM base.team) OR (base.prev_period IS DISTINCT FROM base.period) OR (COALESCE(base.gap, 99) > 8)) THEN 1
                    ELSE 0
                END AS newseq
           FROM base
        ), numbered AS (
         SELECT flagged.game_id,
            flagged.ws_id,
            flagged.team,
            flagged.type,
            flagged.x,
            flagged.y,
            flagged.end_x,
            flagged.is_shot,
            flagged.period,
            flagged.sec,
            flagged.prev_team,
            flagged.prev_period,
            flagged.gap,
            flagged.newseq,
            sum(flagged.newseq) OVER (PARTITION BY flagged.game_id ORDER BY flagged.ws_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS seq_id
           FROM flagged
        )
 SELECT game_id,
    seq_id,
    team,
    count(*) AS actions,
    count(*) FILTER (WHERE (type = 'Pass'::text)) AS passes,
    GREATEST((max(sec) - min(sec)), 0) AS duration_s,
    min(x) AS start_x,
    max(COALESCE(end_x, x)) AS max_x,
    bool_or(is_shot) AS ended_in_shot
   FROM numbered
  GROUP BY game_id, seq_id, team
 HAVING (count(*) >= 2);
CREATE INDEX mv_team_sequences_team_idx ON public.mv_team_sequences USING btree (team);
alter materialized view public.mv_team_sequences owner to postgres;
revoke all on public.mv_team_sequences from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_sequences to anon;
grant SELECT on public.mv_team_sequences to authenticated;
grant DELETE on public.mv_team_sequences to service_role;
grant INSERT on public.mv_team_sequences to service_role;
grant MAINTAIN on public.mv_team_sequences to service_role;
grant REFERENCES on public.mv_team_sequences to service_role;
grant SELECT on public.mv_team_sequences to service_role;
grant TRIGGER on public.mv_team_sequences to service_role;
grant TRUNCATE on public.mv_team_sequences to service_role;
grant UPDATE on public.mv_team_sequences to service_role;

create view public.v_season_stats as
WITH ev AS (
         SELECT e.game_id,
            e.team,
            ((e.type = 'Pass'::text) AND (e.end_x IS NOT NULL) AND (e.end_x >= (66)::double precision)) AS ft,
            ((e.type = 'Pass'::text) AND (e.end_x IS NOT NULL) AND ((e.end_x >= (66)::double precision) AND (e.end_x <= (83)::double precision)) AND ((e.end_y >= (21)::double precision) AND (e.end_y <= (79)::double precision))) AS z14,
            ((e.type = 'Pass'::text) AND (e.end_x IS NOT NULL) AND (e.end_x >= (83)::double precision) AND ((e.end_y >= (21)::double precision) AND (e.end_y <= (79)::double precision))) AS box,
            ((e.type = 'Pass'::text) AND (e.x IS NOT NULL) AND (e.end_x IS NOT NULL) AND (((e.x < (50)::double precision) AND (e.end_x < (50)::double precision) AND ((e.end_x - e.x) >= (30)::double precision)) OR ((e.x < (50)::double precision) AND (e.end_x >= (50)::double precision) AND ((e.end_x - e.x) >= (15)::double precision)) OR ((e.x >= (50)::double precision) AND (e.end_x >= (50)::double precision) AND ((e.end_x - e.x) >= (10)::double precision)))) AS prog,
            ((e.type = 'Pass'::text) AND (e.end_x IS NOT NULL) AND (e.end_x > (e.x + (3)::double precision))) AS fwd,
            ((e.type = 'Pass'::text) AND (e.end_x IS NOT NULL) AND (abs((e.end_x - e.x)) <= (3)::double precision)) AS lat,
            ((e.type = 'Pass'::text) AND (e.end_x IS NOT NULL) AND (e.end_x < (e.x - (3)::double precision))) AS bwd,
            (e.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Aerial'::text, 'Challenge'::text])) AS defa,
            ((e.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'Clearance'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Aerial'::text, 'Challenge'::text])) AND (e.outcome_type = 'Successful'::text)) AS defw,
            e.is_shot AS shot,
            (e.is_shot AND ((e.outcome_type = 'Saved'::text) OR e.is_goal)) AS sot
           FROM events e
        ), agg AS (
         SELECT ev.game_id,
            ev.team,
            count(*) FILTER (WHERE ev.ft) AS final_third_passes,
            count(*) FILTER (WHERE ev.z14) AS zone14_passes,
            count(*) FILTER (WHERE ev.prog) AS progressive_passes,
            count(*) FILTER (WHERE ev.box) AS passes_into_box,
            count(*) FILTER (WHERE ev.defa) AS defensive_actions,
            count(*) FILTER (WHERE ev.defw) AS defensive_actions_won,
            count(*) FILTER (WHERE ev.shot) AS shots,
            count(*) FILTER (WHERE ev.sot) AS shots_on_target,
            count(*) FILTER (WHERE ev.fwd) AS fwd_passes,
            count(*) FILTER (WHERE ev.lat) AS lat_passes,
            count(*) FILTER (WHERE ev.bwd) AS bwd_passes
           FROM ev
          GROUP BY ev.game_id, ev.team
        )
 SELECT a.game_id,
    a.team,
        CASE
            WHEN (a.team = m.home_team) THEN m.away_team
            ELSE m.home_team
        END AS opponent,
        CASE
            WHEN (a.team = m.home_team) THEN 'H'::text
            ELSE 'A'::text
        END AS ha,
        CASE
            WHEN (a.team = m.home_team) THEN m.home_score
            ELSE m.away_score
        END AS team_score,
        CASE
            WHEN (a.team = m.home_team) THEN m.away_score
            ELSE m.home_score
        END AS opp_score,
    a.final_third_passes,
    a.zone14_passes,
    a.progressive_passes,
    a.passes_into_box,
    a.defensive_actions,
    a.defensive_actions_won,
    a.shots,
    a.shots_on_target,
    a.fwd_passes,
    a.lat_passes,
    a.bwd_passes
   FROM (agg a
     JOIN matches m ON ((m.game_id = a.game_id)));
alter view public.v_season_stats owner to postgres;
revoke all on public.v_season_stats from public, anon, authenticated, service_role;
grant SELECT on public.v_season_stats to anon;
grant SELECT on public.v_season_stats to authenticated;
grant DELETE on public.v_season_stats to service_role;
grant INSERT on public.v_season_stats to service_role;
grant MAINTAIN on public.v_season_stats to service_role;
grant REFERENCES on public.v_season_stats to service_role;
grant SELECT on public.v_season_stats to service_role;
grant TRIGGER on public.v_season_stats to service_role;
grant TRUNCATE on public.v_season_stats to service_role;
grant UPDATE on public.v_season_stats to service_role;

create materialized view public.mv_league_summary as
WITH ev AS (
         SELECT events.league,
            count(DISTINCT events.game_id) AS matches,
            count(DISTINCT events.team) AS teams
           FROM events
          GROUP BY events.league
        ), seq AS (
         SELECT sequences.league,
            count(*) AS sequences
           FROM sequences
          GROUP BY sequences.league
        ), pl AS (
         SELECT player_search.league,
            count(*) AS players_profiled
           FROM player_search
          GROUP BY player_search.league
        ), ins AS (
         SELECT tl.league,
            count(*) AS insights
           FROM (insights i
             JOIN mv_team_league tl ON ((tl.team = i.team)))
          GROUP BY tl.league
        )
 SELECT l.league,
    l.display_name,
    l.country,
    l.season,
    COALESCE(ev.matches, (0)::bigint) AS matches,
    COALESCE(ev.teams, (0)::bigint) AS teams,
    COALESCE(pl.players_profiled, (0)::bigint) AS players_profiled,
    COALESCE(seq.sequences, (0)::bigint) AS sequences,
    COALESCE(ins.insights, (0)::bigint) AS insights
   FROM ((((leagues l
     LEFT JOIN ev ON ((ev.league = l.league)))
     LEFT JOIN seq ON ((seq.league = l.league)))
     LEFT JOIN pl ON ((pl.league = l.league)))
     LEFT JOIN ins ON ((ins.league = l.league)))
  WHERE l.is_active;
CREATE UNIQUE INDEX mv_league_summary_pk ON public.mv_league_summary USING btree (league);
alter materialized view public.mv_league_summary owner to postgres;
revoke all on public.mv_league_summary from public, anon, authenticated, service_role;
grant SELECT on public.mv_league_summary to anon;
grant SELECT on public.mv_league_summary to authenticated;
grant DELETE on public.mv_league_summary to service_role;
grant INSERT on public.mv_league_summary to service_role;
grant MAINTAIN on public.mv_league_summary to service_role;
grant REFERENCES on public.mv_league_summary to service_role;
grant SELECT on public.mv_league_summary to service_role;
grant TRIGGER on public.mv_league_summary to service_role;
grant TRUNCATE on public.mv_league_summary to service_role;
grant UPDATE on public.mv_league_summary to service_role;

create materialized view public.mv_player_team_poss as
SELECT m.player_id,
    round((sum((t.possession_pct * m.minutes)) / NULLIF(sum(m.minutes), (0)::numeric)), 2) AS team_possession
   FROM (mv_player_minutes m
     JOIN mv_team_match t ON (((t.game_id = m.game_id) AND (t.team = m.team))))
  GROUP BY m.player_id;
CREATE UNIQUE INDEX mv_player_team_poss_player_id_idx ON public.mv_player_team_poss USING btree (player_id);
alter materialized view public.mv_player_team_poss owner to postgres;
revoke all on public.mv_player_team_poss from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_team_poss to anon;
grant SELECT on public.mv_player_team_poss to authenticated;
grant DELETE on public.mv_player_team_poss to service_role;
grant INSERT on public.mv_player_team_poss to service_role;
grant MAINTAIN on public.mv_player_team_poss to service_role;
grant REFERENCES on public.mv_player_team_poss to service_role;
grant SELECT on public.mv_player_team_poss to service_role;
grant TRIGGER on public.mv_player_team_poss to service_role;
grant TRUNCATE on public.mv_player_team_poss to service_role;
grant UPDATE on public.mv_player_team_poss to service_role;

create materialized view public.mv_seq_state as
SELECT s.seq_uid,
    s.game_id,
    s.team,
    s.start_min,
    count(*) FILTER (WHERE (gg.scoring_team = s.team)) AS goals_for,
    count(*) FILTER (WHERE ((gg.scoring_team IS NOT NULL) AND (gg.scoring_team <> s.team))) AS goals_against,
    (count(*) FILTER (WHERE (gg.scoring_team = s.team)) - count(*) FILTER (WHERE ((gg.scoring_team IS NOT NULL) AND (gg.scoring_team <> s.team)))) AS margin,
        CASE
            WHEN (count(*) FILTER (WHERE (gg.scoring_team = s.team)) > count(*) FILTER (WHERE ((gg.scoring_team IS NOT NULL) AND (gg.scoring_team <> s.team)))) THEN 'winning'::text
            WHEN (count(*) FILTER (WHERE (gg.scoring_team = s.team)) < count(*) FILTER (WHERE ((gg.scoring_team IS NOT NULL) AND (gg.scoring_team <> s.team)))) THEN 'losing'::text
            ELSE 'drawing'::text
        END AS state,
    (abs((count(*) FILTER (WHERE (gg.scoring_team = s.team)) - count(*) FILTER (WHERE ((gg.scoring_team IS NOT NULL) AND (gg.scoring_team <> s.team))))) <= 1) AS is_close
   FROM (sequences s
     LEFT JOIN mv_game_goals gg ON (((gg.game_id = s.game_id) AND ((gg.expanded_minute < s.start_min) OR ((gg.expanded_minute = s.start_min) AND (gg.second <= COALESCE(s.start_sec, 0)))))))
  GROUP BY s.seq_uid, s.game_id, s.team, s.start_min;
CREATE UNIQUE INDEX mv_seq_state_pk ON public.mv_seq_state USING btree (seq_uid);
CREATE INDEX mv_seq_state_team ON public.mv_seq_state USING btree (team, state);
alter materialized view public.mv_seq_state owner to postgres;
revoke all on public.mv_seq_state from public, anon, authenticated, service_role;
grant SELECT on public.mv_seq_state to anon;
grant SELECT on public.mv_seq_state to authenticated;
grant DELETE on public.mv_seq_state to service_role;
grant INSERT on public.mv_seq_state to service_role;
grant MAINTAIN on public.mv_seq_state to service_role;
grant REFERENCES on public.mv_seq_state to service_role;
grant SELECT on public.mv_seq_state to service_role;
grant TRIGGER on public.mv_seq_state to service_role;
grant TRUNCATE on public.mv_seq_state to service_role;
grant UPDATE on public.mv_seq_state to service_role;

create materialized view public.mv_state_segments as
WITH mlen AS (
         SELECT events.game_id,
            (max(events.expanded_minute) + 1) AS end_min
           FROM events
          GROUP BY events.game_id
        ), tg AS (
         SELECT DISTINCT events.game_id,
            events.team
           FROM events
          WHERE (events.team IS NOT NULL)
        ), ev AS (
         SELECT tg.game_id,
            tg.team,
            g.expanded_minute AS t,
                CASE
                    WHEN (g.scoring_team = tg.team) THEN 1
                    ELSE '-1'::integer
                END AS d
           FROM (tg
             JOIN mv_game_goals g ON ((g.game_id = tg.game_id)))
        ), run AS (
         SELECT ev.game_id,
            ev.team,
            ev.t,
            sum(ev.d) OVER (PARTITION BY ev.game_id, ev.team ORDER BY ev.t ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS margin
           FROM ev
        ), after_goals AS (
         SELECT r.game_id,
            r.team,
            r.t AS seg_start,
            COALESCE(lead(r.t) OVER (PARTITION BY r.game_id, r.team ORDER BY r.t), m.end_min) AS seg_end,
            r.margin
           FROM (run r
             JOIN mlen m ON ((m.game_id = r.game_id)))
        ), before_first AS (
         SELECT tg.game_id,
            tg.team,
            0 AS seg_start,
            COALESCE(( SELECT min(e.t) AS min
                   FROM ev e
                  WHERE ((e.game_id = tg.game_id) AND (e.team = tg.team))), m.end_min) AS seg_end,
            0 AS margin
           FROM (tg
             JOIN mlen m ON ((m.game_id = tg.game_id)))
        )
 SELECT after_goals.game_id,
    after_goals.team,
    after_goals.seg_start,
    after_goals.seg_end,
    after_goals.margin
   FROM after_goals
UNION ALL
 SELECT before_first.game_id,
    before_first.team,
    before_first.seg_start,
    before_first.seg_end,
    before_first.margin
   FROM before_first;
CREATE INDEX mv_state_segments_gt ON public.mv_state_segments USING btree (game_id, team);
alter materialized view public.mv_state_segments owner to postgres;
revoke all on public.mv_state_segments from public, anon, authenticated, service_role;
grant SELECT on public.mv_state_segments to anon;
grant SELECT on public.mv_state_segments to authenticated;
grant DELETE on public.mv_state_segments to service_role;
grant INSERT on public.mv_state_segments to service_role;
grant MAINTAIN on public.mv_state_segments to service_role;
grant REFERENCES on public.mv_state_segments to service_role;
grant SELECT on public.mv_state_segments to service_role;
grant TRIGGER on public.mv_state_segments to service_role;
grant TRUNCATE on public.mv_state_segments to service_role;
grant UPDATE on public.mv_state_segments to service_role;

create materialized view public.mv_team_attackphase as
WITH m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        ), att AS (
         SELECT e.team,
            count(*) FILTER (WHERE ((e.type = 'Pass'::text) AND (e.x >= (50)::double precision) AND (e.outcome_type = 'Successful'::text))) AS att_passes,
            COALESCE(sum((GREATEST((0)::double precision, (e.end_x - e.x)) * (1.05)::double precision)) FILTER (WHERE ((e.type = 'Pass'::text) AND (e.x >= (50)::double precision) AND (e.outcome_type = 'Successful'::text))), (0)::double precision) AS att_territory,
            count(*) FILTER (WHERE ((e.type = 'Pass'::text) AND (e.outcome_type = 'Successful'::text) AND (e.x < (66.7)::double precision) AND (e.end_x >= (66.7)::double precision))) AS ft_entries,
            count(*) FILTER (WHERE ((e.type = 'Pass'::text) AND (e.outcome_type = 'Successful'::text) AND (e.end_x >= (83)::double precision) AND ((e.end_y >= (21)::double precision) AND (e.end_y <= (79)::double precision)))) AS box_entries,
            count(*) FILTER (WHERE e.is_shot) AS shots,
            count(*) FILTER (WHERE ((e.type = 'Pass'::text) AND (e.outcome_type = 'Successful'::text))) AS all_ok_passes
           FROM events e
          WHERE ((e.team IS NOT NULL) AND (e.x IS NOT NULL))
          GROUP BY e.team
        ), tempo AS (
         SELECT mv_receipt_events.team,
            percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((mv_receipt_events.ttr)::double precision)) FILTER (WHERE (mv_receipt_events.end_x >= 66.7)) AS ft_ttr,
            percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((mv_receipt_events.ttr)::double precision)) FILTER (WHERE ((mv_receipt_events.end_x >= 33.3) AND (mv_receipt_events.end_x < 66.7))) AS mid_ttr
           FROM mv_receipt_events
          GROUP BY mv_receipt_events.team
        ), carries AS (
         SELECT mv_receipt_events.team,
            count(*) FILTER (WHERE ((mv_receipt_events.start_x < 66.7) AND (mv_receipt_events.end_x >= 66.7))) AS carry_entries
           FROM mv_receipt_events
          WHERE mv_receipt_events.is_carry
          GROUP BY mv_receipt_events.team
        ), seq AS (
         SELECT mv_team_sequences.team,
            count(*) FILTER (WHERE (mv_team_sequences.max_x >= (66.7)::double precision)) AS reached_final,
            count(*) FILTER (WHERE ((mv_team_sequences.max_x >= (66.7)::double precision) AND mv_team_sequences.ended_in_shot)) AS final_to_shot
           FROM mv_team_sequences
          GROUP BY mv_team_sequences.team
        )
 SELECT a.team,
    round(((a.att_territory / (NULLIF(a.att_passes, 0))::double precision))::numeric, 2) AS att_directness,
    round((t.ft_ttr)::numeric, 2) AS ft_release,
    round((t.mid_ttr)::numeric, 2) AS mid_release,
    round(((a.all_ok_passes)::numeric / (NULLIF(a.shots, 0))::numeric), 1) AS passes_per_shot,
    round((((a.ft_entries + COALESCE(c.carry_entries, (0)::bigint)))::numeric / (NULLIF(m.matches, 0))::numeric), 1) AS ft_entries_pg,
    round(((a.box_entries)::numeric / (NULLIF(m.matches, 0))::numeric), 1) AS box_entries_pg2,
    round(((100.0 * (a.box_entries)::numeric) / (NULLIF((a.ft_entries + COALESCE(c.carry_entries, (0)::bigint)), 0))::numeric), 1) AS box_per_entry,
    round(((100.0 * (s.final_to_shot)::numeric) / (NULLIF(s.reached_final, 0))::numeric), 1) AS final_to_shot_pct
   FROM ((((att a
     JOIN m ON ((m.team = a.team)))
     LEFT JOIN tempo t ON ((t.team = a.team)))
     LEFT JOIN carries c ON ((c.team = a.team)))
     LEFT JOIN seq s ON ((s.team = a.team)));
CREATE UNIQUE INDEX mv_team_attackphase_team_idx ON public.mv_team_attackphase USING btree (team);
alter materialized view public.mv_team_attackphase owner to postgres;
revoke all on public.mv_team_attackphase from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_attackphase to anon;
grant SELECT on public.mv_team_attackphase to authenticated;
grant DELETE on public.mv_team_attackphase to service_role;
grant INSERT on public.mv_team_attackphase to service_role;
grant MAINTAIN on public.mv_team_attackphase to service_role;
grant REFERENCES on public.mv_team_attackphase to service_role;
grant SELECT on public.mv_team_attackphase to service_role;
grant TRIGGER on public.mv_team_attackphase to service_role;
grant TRUNCATE on public.mv_team_attackphase to service_role;
grant UPDATE on public.mv_team_attackphase to service_role;

create materialized view public.mv_team_breakdown as
WITH routes AS (
         SELECT s.team,
            COALESCE(tl.league, 'USA-MLS'::text) AS league,
            r.route,
            r.used,
            s.ended_shot,
            s.ended_in_box,
            s.xt_sum
           FROM ((sequences s
             LEFT JOIN mv_team_league tl ON ((tl.team = s.team)))
             CROSS JOIN LATERAL ( VALUES ('Through the middle'::text,s.finds_central), ('Around the outside'::text,s.finds_wide), ('Switch of play'::text,s.has_switch), ('Over the top'::text,s.long_ball), ('Wide combinations'::text,s.wide_triangles), ('Hold-up and lay'::text,s.hold_up), ('Patient build'::text,s.structured), ('From deep'::text,s.low_build), ('High regain'::text,s.high_build)) r(route, used))
          WHERE s.is_open_play
        ), agg AS (
         SELECT routes.team,
            routes.league,
            routes.route,
            count(*) FILTER (WHERE routes.used) AS seqs,
            round((100.0 * avg((routes.used)::integer)), 1) AS share_pct,
            round((100.0 * avg((routes.ended_shot)::integer) FILTER (WHERE routes.used)), 1) AS shot_pct,
            round((100.0 * avg((routes.ended_in_box)::integer) FILTER (WHERE routes.used)), 1) AS box_pct,
            round(avg(routes.xt_sum) FILTER (WHERE routes.used), 4) AS xt_per_seq
           FROM routes
          GROUP BY routes.team, routes.league, routes.route
        ), lg AS (
         SELECT agg.league,
            agg.route,
            avg(agg.shot_pct) AS lg_shot,
            stddev_samp(agg.shot_pct) AS sd_shot,
            avg(agg.share_pct) AS lg_share,
            stddev_samp(agg.share_pct) AS sd_share
           FROM agg
          GROUP BY agg.league, agg.route
        )
 SELECT a.team,
    a.league,
    a.route,
    a.seqs,
    a.share_pct,
    a.shot_pct,
    a.box_pct,
    a.xt_per_seq,
    rank() OVER (PARTITION BY a.league, a.route ORDER BY a.share_pct DESC) AS share_rank,
    rank() OVER (PARTITION BY a.league, a.route ORDER BY a.shot_pct DESC) AS productivity_rank,
    round(((a.share_pct - lg.lg_share) / NULLIF(lg.sd_share, (0)::numeric)), 2) AS z_share,
    round(((a.shot_pct - lg.lg_shot) / NULLIF(lg.sd_shot, (0)::numeric)), 2) AS z_productivity
   FROM (agg a
     JOIN lg ON (((lg.league = a.league) AND (lg.route = a.route))));
CREATE INDEX mv_team_breakdown_team ON public.mv_team_breakdown USING btree (team);
alter materialized view public.mv_team_breakdown owner to postgres;
revoke all on public.mv_team_breakdown from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_breakdown to anon;
grant SELECT on public.mv_team_breakdown to authenticated;
grant DELETE on public.mv_team_breakdown to service_role;
grant INSERT on public.mv_team_breakdown to service_role;
grant MAINTAIN on public.mv_team_breakdown to service_role;
grant REFERENCES on public.mv_team_breakdown to service_role;
grant SELECT on public.mv_team_breakdown to service_role;
grant TRIGGER on public.mv_team_breakdown to service_role;
grant TRUNCATE on public.mv_team_breakdown to service_role;
grant UPDATE on public.mv_team_breakdown to service_role;

create materialized view public.mv_team_buildphase as
WITH m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        ), gk AS (
         SELECT e_1.team,
            count(*) FILTER (WHERE (e_1.type = 'Pass'::text)) AS gk_passes,
            count(*) FILTER (WHERE ((e_1.type = 'Pass'::text) AND (e_1.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb))) AS gk_long
           FROM (events e_1
             JOIN mv_player_pool p ON (((p.player_id = e_1.player_id) AND (p.modal_position = 'GK'::text))))
          GROUP BY e_1.team
        ), deep AS (
         SELECT e_1.team,
            count(*) FILTER (WHERE ((e_1.type = 'Pass'::text) AND (e_1.x < (33.3)::double precision))) AS d3_passes,
            count(*) FILTER (WHERE ((e_1.type = 'Pass'::text) AND (e_1.x < (33.3)::double precision) AND (e_1.outcome_type = 'Successful'::text))) AS d3_ok,
            count(*) FILTER (WHERE ((e_1.type = 'Pass'::text) AND (e_1.x < (33.3)::double precision) AND (e_1.qualifiers @> '[{"type": {"displayName": "Longball"}}]'::jsonb))) AS d3_long,
            count(*) FILTER (WHERE ((e_1.type = 'Pass'::text) AND (e_1.x < (33.3)::double precision) AND (e_1.end_x < (33.3)::double precision) AND (e_1.outcome_type = 'Successful'::text))) AS d3_circulate,
            count(*) FILTER (WHERE (e_1.type = 'Pass'::text)) AS all_passes,
            count(*) FILTER (WHERE (e_1.is_touch AND (e_1.x < (33.3)::double precision))) AS d3_touches,
            count(*) FILTER (WHERE e_1.is_touch) AS all_touches
           FROM events e_1
          WHERE ((e_1.team IS NOT NULL) AND (e_1.x IS NOT NULL))
          GROUP BY e_1.team
        ), cb AS (
         SELECT e_1.team,
            count(*) FILTER (WHERE ((e_1.outcome_type = 'Successful'::text) AND (((e_1.x < (50)::double precision) AND (e_1.end_x < (50)::double precision) AND ((e_1.end_x - e_1.x) >= (30)::double precision)) OR ((e_1.x < (50)::double precision) AND (e_1.end_x >= (50)::double precision) AND ((e_1.end_x - e_1.x) >= (15)::double precision)) OR ((e_1.x >= (50)::double precision) AND (e_1.end_x >= (50)::double precision) AND ((e_1.end_x - e_1.x) >= (10)::double precision))))) AS cb_prog
           FROM (events e_1
             JOIN mv_player_role r ON (((r.player_id = e_1.player_id) AND (r.pool = 'CB'::text))))
          WHERE (e_1.type = 'Pass'::text)
          GROUP BY e_1.team
        ), exits AS (
         SELECT mv_team_sequences.team,
            count(*) FILTER (WHERE (mv_team_sequences.start_x < (33.3)::double precision)) AS deep_starts,
            count(*) FILTER (WHERE ((mv_team_sequences.start_x < (33.3)::double precision) AND (mv_team_sequences.max_x >= (66.7)::double precision))) AS deep_to_final,
            count(*) FILTER (WHERE ((mv_team_sequences.start_x < (33.3)::double precision) AND (mv_team_sequences.max_x >= (50)::double precision))) AS deep_to_half
           FROM mv_team_sequences
          GROUP BY mv_team_sequences.team
        )
 SELECT d.team,
    round(((100.0 * (g.gk_long)::numeric) / (NULLIF(g.gk_passes, 0))::numeric), 1) AS gk_long_pct,
    round(((d.d3_passes)::numeric / (NULLIF(m.matches, 0))::numeric), 1) AS d3_passes_pg,
    round(((100.0 * (d.d3_passes)::numeric) / (NULLIF(d.all_passes, 0))::numeric), 1) AS d3_pass_share,
    round(((100.0 * (d.d3_ok)::numeric) / (NULLIF(d.d3_passes, 0))::numeric), 1) AS d3_accuracy,
    round(((100.0 * (d.d3_long)::numeric) / (NULLIF(d.d3_passes, 0))::numeric), 1) AS d3_long_pct,
    round(((d.d3_circulate)::numeric / (NULLIF(m.matches, 0))::numeric), 1) AS deep_circulation_pg,
    round(((100.0 * (d.d3_touches)::numeric) / (NULLIF(d.all_touches, 0))::numeric), 1) AS d3_touch_share,
    round(((c.cb_prog)::numeric / (NULLIF(m.matches, 0))::numeric), 1) AS cb_prog_pg,
    round(((100.0 * (e.deep_to_half)::numeric) / (NULLIF(e.deep_starts, 0))::numeric), 1) AS escape_pct,
    round(((100.0 * (e.deep_to_final)::numeric) / (NULLIF(e.deep_starts, 0))::numeric), 1) AS deep_to_final_pct
   FROM ((((deep d
     JOIN m ON ((m.team = d.team)))
     LEFT JOIN gk g ON ((g.team = d.team)))
     LEFT JOIN cb c ON ((c.team = d.team)))
     LEFT JOIN exits e ON ((e.team = d.team)));
CREATE UNIQUE INDEX mv_team_buildphase_team_idx ON public.mv_team_buildphase USING btree (team);
alter materialized view public.mv_team_buildphase owner to postgres;
revoke all on public.mv_team_buildphase from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_buildphase to anon;
grant SELECT on public.mv_team_buildphase to authenticated;
grant DELETE on public.mv_team_buildphase to service_role;
grant INSERT on public.mv_team_buildphase to service_role;
grant MAINTAIN on public.mv_team_buildphase to service_role;
grant REFERENCES on public.mv_team_buildphase to service_role;
grant SELECT on public.mv_team_buildphase to service_role;
grant TRIGGER on public.mv_team_buildphase to service_role;
grant TRUNCATE on public.mv_team_buildphase to service_role;
grant UPDATE on public.mv_team_buildphase to service_role;

create materialized view public.mv_team_buildup as
WITH s AS (
         SELECT mv_team_sequences.game_id,
            mv_team_sequences.seq_id,
            mv_team_sequences.team,
            mv_team_sequences.actions,
            mv_team_sequences.passes,
            mv_team_sequences.duration_s,
            mv_team_sequences.start_x,
            mv_team_sequences.max_x,
            mv_team_sequences.ended_in_shot
           FROM mv_team_sequences
        ), m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        )
 SELECT s.team,
    count(*) AS sequences,
    round(((count(*))::numeric / (NULLIF(m.matches, 0))::numeric), 1) AS sequences_pg,
    round(avg(s.passes), 2) AS passes_per_seq,
    round(avg(s.duration_s), 1) AS secs_per_seq,
    round(((100.0 * (count(*) FILTER (WHERE s.ended_in_shot))::numeric) / (count(*))::numeric), 1) AS pct_ending_in_shot,
    round(((100.0 * (count(*) FILTER (WHERE ((s.start_x < (50)::double precision) AND s.ended_in_shot AND (s.duration_s <= 15))))::numeric) / (NULLIF(count(*) FILTER (WHERE (s.start_x < (50)::double precision)), 0))::numeric), 2) AS direct_attack_pct,
    round(((100.0 * (count(*) FILTER (WHERE (s.passes >= 6)))::numeric) / (count(*))::numeric), 1) AS long_sequence_pct,
    round((avg((s.max_x - s.start_x)))::numeric, 1) AS ground_gained,
    round(avg(s.passes) FILTER (WHERE s.ended_in_shot), 2) AS passes_before_shot,
    round(avg(s.duration_s) FILTER (WHERE s.ended_in_shot), 1) AS secs_before_shot
   FROM (s
     JOIN m ON ((m.team = s.team)))
  GROUP BY s.team, m.matches;
CREATE UNIQUE INDEX mv_team_buildup_team_idx ON public.mv_team_buildup USING btree (team);
alter materialized view public.mv_team_buildup owner to postgres;
revoke all on public.mv_team_buildup from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_buildup to anon;
grant SELECT on public.mv_team_buildup to authenticated;
grant DELETE on public.mv_team_buildup to service_role;
grant INSERT on public.mv_team_buildup to service_role;
grant MAINTAIN on public.mv_team_buildup to service_role;
grant REFERENCES on public.mv_team_buildup to service_role;
grant SELECT on public.mv_team_buildup to service_role;
grant TRIGGER on public.mv_team_buildup to service_role;
grant TRUNCATE on public.mv_team_buildup to service_role;
grant UPDATE on public.mv_team_buildup to service_role;

create materialized view public.mv_team_carry_zones as
WITH c AS (
         SELECT r.team,
            LEAST(11, GREATEST(0, (floor(((r.start_x / (100)::numeric) * (12)::numeric)))::integer)) AS zx,
            LEAST(7, GREATEST(0, (floor(((r.start_y / (100)::numeric) * (8)::numeric)))::integer)) AS zy,
            r.is_progressive,
            r.into_box,
            r.carry_m
           FROM mv_receipt_events r
          WHERE r.is_carry
        ), m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        )
 SELECT c.team,
    c.zx,
    c.zy,
    count(*) AS carries,
    count(*) FILTER (WHERE c.is_progressive) AS prog_carries,
    count(*) FILTER (WHERE c.into_box) AS carries_into_box,
    round(avg(c.carry_m), 1) AS mean_m,
    round(((count(*))::numeric / (NULLIF(m.matches, 0))::numeric), 2) AS carries_pg
   FROM (c
     JOIN m ON ((m.team = c.team)))
  GROUP BY c.team, c.zx, c.zy, m.matches;
CREATE INDEX mv_team_carry_zones_team_idx ON public.mv_team_carry_zones USING btree (team);
alter materialized view public.mv_team_carry_zones owner to postgres;
revoke all on public.mv_team_carry_zones from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_carry_zones to anon;
grant SELECT on public.mv_team_carry_zones to authenticated;
grant DELETE on public.mv_team_carry_zones to service_role;
grant INSERT on public.mv_team_carry_zones to service_role;
grant MAINTAIN on public.mv_team_carry_zones to service_role;
grant REFERENCES on public.mv_team_carry_zones to service_role;
grant SELECT on public.mv_team_carry_zones to service_role;
grant TRIGGER on public.mv_team_carry_zones to service_role;
grant TRUNCATE on public.mv_team_carry_zones to service_role;
grant UPDATE on public.mv_team_carry_zones to service_role;

create materialized view public.mv_team_season as
SELECT team,
    count(*) AS matches,
    round(avg(possession_pct), 1) AS possession_pct,
    round(avg(field_tilt), 1) AS field_tilt,
    round(avg(ppda), 2) AS ppda,
    round(avg(def_height), 1) AS def_height,
    round(avg(avg_touch_x), 1) AS avg_touch_x,
    round(avg(long_ball_pct), 1) AS long_ball_pct,
    round(avg(build_from_back_pct), 1) AS build_from_back_pct,
    round(avg(directness), 2) AS directness,
    round(avg(prog_passes), 1) AS prog_passes_pg,
    round(avg(box_entries_pass), 1) AS box_entries_pg,
    round(avg(crosses), 1) AS crosses_pg,
    round(avg(shots), 1) AS shots_pg,
    round(avg(opp_shots), 1) AS shots_against_pg,
    round(avg(goals), 2) AS goals_pg,
    round(avg(opp_goals), 2) AS goals_against_pg,
    round(avg(open_play_shot_pct), 1) AS open_play_shot_pct
   FROM mv_team_match
  GROUP BY team;
CREATE UNIQUE INDEX mv_team_season_team_idx ON public.mv_team_season USING btree (team);
alter materialized view public.mv_team_season owner to postgres;
revoke all on public.mv_team_season from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_season to anon;
grant SELECT on public.mv_team_season to authenticated;
grant DELETE on public.mv_team_season to service_role;
grant INSERT on public.mv_team_season to service_role;
grant MAINTAIN on public.mv_team_season to service_role;
grant REFERENCES on public.mv_team_season to service_role;
grant SELECT on public.mv_team_season to service_role;
grant TRIGGER on public.mv_team_season to service_role;
grant TRUNCATE on public.mv_team_season to service_role;
grant UPDATE on public.mv_team_season to service_role;

create materialized view public.mv_team_stat_ranks as
WITH per AS (
         SELECT s.team,
            count(*) AS matches,
            avg(s.final_third_passes) AS final_third_passes,
            avg(s.zone14_passes) AS zone14_passes,
            avg(s.progressive_passes) AS progressive_passes,
            avg(s.passes_into_box) AS passes_into_box,
            avg(s.defensive_actions) AS defensive_actions,
            avg(s.defensive_actions_won) AS defensive_actions_won,
            avg(s.shots) AS shots,
            avg(s.shots_on_target) AS shots_on_target,
            avg(s.fwd_passes) AS fwd_passes,
            avg(s.lat_passes) AS lat_passes,
            avg(s.bwd_passes) AS bwd_passes
           FROM v_season_stats s
          GROUP BY s.team
        ), long AS (
         SELECT per.team,
            COALESCE(tl.league, 'USA-MLS'::text) AS league,
            v.metric,
            v.value
           FROM ((per
             LEFT JOIN mv_team_league tl ON ((tl.team = per.team)))
             CROSS JOIN LATERAL ( VALUES ('final_third_passes'::text,per.final_third_passes), ('zone14_passes'::text,per.zone14_passes), ('progressive_passes'::text,per.progressive_passes), ('passes_into_box'::text,per.passes_into_box), ('defensive_actions'::text,per.defensive_actions), ('defensive_actions_won'::text,per.defensive_actions_won), ('shots'::text,per.shots), ('shots_on_target'::text,per.shots_on_target), ('fwd_passes'::text,per.fwd_passes), ('lat_passes'::text,per.lat_passes), ('bwd_passes'::text,per.bwd_passes)) v(metric, value))
        )
 SELECT team,
    metric,
    round(value, 2) AS per_game,
    rank() OVER (PARTITION BY league, metric ORDER BY value DESC) AS league_rank,
    count(*) OVER (PARTITION BY league, metric) AS of_teams,
    league
   FROM long;
CREATE INDEX mv_team_stat_ranks_tm ON public.mv_team_stat_ranks USING btree (team, metric);
alter materialized view public.mv_team_stat_ranks owner to postgres;
revoke all on public.mv_team_stat_ranks from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_stat_ranks to anon;
grant SELECT on public.mv_team_stat_ranks to authenticated;
grant DELETE on public.mv_team_stat_ranks to service_role;
grant INSERT on public.mv_team_stat_ranks to service_role;
grant MAINTAIN on public.mv_team_stat_ranks to service_role;
grant REFERENCES on public.mv_team_stat_ranks to service_role;
grant SELECT on public.mv_team_stat_ranks to service_role;
grant TRIGGER on public.mv_team_stat_ranks to service_role;
grant TRUNCATE on public.mv_team_stat_ranks to service_role;
grant UPDATE on public.mv_team_stat_ranks to service_role;

create materialized view public.mv_team_zones as
WITH e AS (
         SELECT events.team,
            LEAST(11, GREATEST(0, (floor(((events.x / (100)::double precision) * (12)::double precision)))::integer)) AS zx,
            LEAST(7, GREATEST(0, (floor(((events.y / (100)::double precision) * (8)::double precision)))::integer)) AS zy,
            events.type,
            events.is_shot,
            events.is_open_play,
            (events.outcome_type = 'Successful'::text) AS ok,
            ((events.type = 'Pass'::text) AND (events.x IS NOT NULL) AND (events.end_x IS NOT NULL) AND (((events.x < (50)::double precision) AND (events.end_x < (50)::double precision) AND ((events.end_x - events.x) >= (30)::double precision)) OR ((events.x < (50)::double precision) AND (events.end_x >= (50)::double precision) AND ((events.end_x - events.x) >= (15)::double precision)) OR ((events.x >= (50)::double precision) AND (events.end_x >= (50)::double precision) AND ((events.end_x - events.x) >= (10)::double precision)))) AS prog
           FROM events
          WHERE ((events.team IS NOT NULL) AND (events.x IS NOT NULL) AND (events.y IS NOT NULL) AND (events.type <> ALL (ARRAY['Start'::text, 'End'::text, 'FormationSet'::text, 'FormationChange'::text, 'Card'::text, 'SubstitutionOn'::text, 'SubstitutionOff'::text, 'CornerAwarded'::text, 'OffsideProvoked'::text])))
        ), m AS (
         SELECT mv_team_match.team,
            count(*) AS matches
           FROM mv_team_match
          GROUP BY mv_team_match.team
        )
 SELECT e.team,
    e.zx,
    e.zy,
    count(*) AS touches,
    count(*) FILTER (WHERE ((e.type = 'Pass'::text) AND e.ok)) AS passes,
    count(*) FILTER (WHERE (e.prog AND e.ok)) AS prog_passes,
    count(*) FILTER (WHERE e.is_shot) AS shots,
    count(*) FILTER (WHERE (e.type = ANY (ARRAY['Tackle'::text, 'Interception'::text, 'BallRecovery'::text, 'BlockedPass'::text, 'Clearance'::text, 'Challenge'::text]))) AS def_actions,
    round(((count(*))::numeric / (NULLIF(m.matches, 0))::numeric), 2) AS touches_pg
   FROM (e
     JOIN m ON ((m.team = e.team)))
  GROUP BY e.team, e.zx, e.zy, m.matches;
CREATE INDEX mv_team_zones_team_idx ON public.mv_team_zones USING btree (team);
alter materialized view public.mv_team_zones owner to postgres;
revoke all on public.mv_team_zones from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_zones to anon;
grant SELECT on public.mv_team_zones to authenticated;
grant DELETE on public.mv_team_zones to service_role;
grant INSERT on public.mv_team_zones to service_role;
grant MAINTAIN on public.mv_team_zones to service_role;
grant REFERENCES on public.mv_team_zones to service_role;
grant SELECT on public.mv_team_zones to service_role;
grant TRIGGER on public.mv_team_zones to service_role;
grant TRUNCATE on public.mv_team_zones to service_role;
grant UPDATE on public.mv_team_zones to service_role;

create materialized view public.mv_player_leverage as
SELECT pm.player_id,
    pm.team,
    sum(pm.minutes) AS minutes_total,
    round(((100.0 * (sum(GREATEST(0, (LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start)))) FILTER (WHERE (abs(sg.margin) <= 1)))::numeric) / (NULLIF(sum(GREATEST(0, (LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start)))), 0))::numeric), 1) AS leverage_pct
   FROM (mv_player_stints pm
     JOIN mv_state_segments sg ON (((sg.game_id = pm.game_id) AND (sg.team = pm.team) AND (sg.seg_start < pm.end_min) AND (sg.seg_end > pm.start_min))))
  GROUP BY pm.player_id, pm.team;
CREATE INDEX mv_player_leverage_p ON public.mv_player_leverage USING btree (player_id);
alter materialized view public.mv_player_leverage owner to postgres;
revoke all on public.mv_player_leverage from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_leverage to anon;
grant SELECT on public.mv_player_leverage to authenticated;
grant DELETE on public.mv_player_leverage to service_role;
grant INSERT on public.mv_player_leverage to service_role;
grant MAINTAIN on public.mv_player_leverage to service_role;
grant REFERENCES on public.mv_player_leverage to service_role;
grant SELECT on public.mv_player_leverage to service_role;
grant TRIGGER on public.mv_player_leverage to service_role;
grant TRUNCATE on public.mv_player_leverage to service_role;
grant UPDATE on public.mv_player_leverage to service_role;

create materialized view public.mv_player_percentiles as
WITH base AS (
         SELECT m.player_id,
            m.player_name,
            m.team,
            m.nineties,
            m.pass_cmp_90,
            m.pass_pct,
            m.prog_cmp_90,
            m.prog_pct,
            m.territory_90,
            m.into_box_90,
            m.final_third_90,
            m.through_90,
            m.cross_90,
            m.cross_pct,
            m.key_pass_90,
            m.assist_90,
            m.bcc_90,
            m.long_90,
            m.long_pct,
            m.shots_90,
            m.sot_90,
            m.blocked_90,
            m.goals_90,
            m.box_share,
            m.shot_dist,
            m.conversion,
            m.shot_acc,
            m.bigchance_90,
            m.weak_foot_share,
            m.tackle_90,
            m.tackle_pct,
            m.int_90,
            m.clear_90,
            m.block_90,
            m.recov_90,
            m.aerial_90,
            m.aerial_pct,
            m.def_action_90,
            m.def_height,
            m.takeon_90,
            m.takeon_pct,
            m.disp_90,
            m.badtouch_90,
            m.foul_com_90,
            m.foul_won_90,
            m.error_90,
            m.carries_90,
            m.prog_carries_90,
            m.carry_box_90,
            m.mean_carry_m,
            m.carry_pen_90,
            m.median_ttr,
            m.quick_pct,
            m.one_touch_pct,
            m.aq_per_duel,
            m.duel_quality,
            m.recov_retention,
            m.recov_prog_90,
            m.xg_90,
            m.xg_per_shot,
            m.finishing,
            m.xa_90,
            m.xt_90,
            m.xt_pass_90,
            m.xt_carry_90,
            m.save_pct,
            m.goals_prevented_90,
            m.saves_90,
            m.claims_90,
            m.sweeps_90,
            m.sweep_x,
            m.hs_passes_90,
            m.hs_prog_90,
            m.hs_key_90,
            m.hs_shots_90,
            m.hs_takeons_90,
            m.box_def_90,
            m.channel_def_90,
            m.flank_def_90,
            m.counterpress_90,
            m.sca_90,
            m.holds_90,
            m.hold_retention,
            m.hold_prog_pct,
            m.hold_shot_pct,
            m.sp_xg_90,
            m.sp_shots_90,
            m.sp_aerials_90,
            m.sp_key_90,
            p.team_possession,
            (50.0 / NULLIF(((100)::numeric - p.team_possession), (0)::numeric)) AS padj
           FROM (v_player_metrics_ext m
             LEFT JOIN mv_player_team_poss p USING (player_id))
        ), long AS (
         SELECT b.player_id,
            r.pool,
            b.nineties,
            COALESCE(pl.league, 'USA-MLS'::text) AS league,
            v.metric,
            v.value
           FROM (((base b
             JOIN mv_player_role r USING (player_id))
             LEFT JOIN mv_player_league pl ON ((pl.player_id = b.player_id)))
             CROSS JOIN LATERAL ( VALUES ('pass_cmp_90'::text,b.pass_cmp_90), ('pass_pct'::text,b.pass_pct), ('prog_cmp_90'::text,b.prog_cmp_90), ('prog_pct'::text,b.prog_pct), ('territory_90'::text,b.territory_90), ('into_box_90'::text,b.into_box_90), ('final_third_90'::text,b.final_third_90), ('through_90'::text,b.through_90), ('cross_90'::text,b.cross_90), ('cross_pct'::text,b.cross_pct), ('key_pass_90'::text,b.key_pass_90), ('assist_90'::text,b.assist_90), ('bcc_90'::text,b.bcc_90), ('xa_90'::text,b.xa_90), ('xt_90'::text,b.xt_90), ('xt_pass_90'::text,b.xt_pass_90), ('xt_carry_90'::text,b.xt_carry_90), ('sca_90'::text,b.sca_90), ('long_90'::text,b.long_90), ('long_pct'::text,b.long_pct), ('shots_90'::text,b.shots_90), ('sot_90'::text,b.sot_90), ('goals_90'::text,b.goals_90), ('blocked_90'::text,b.blocked_90), ('xg_90'::text,b.xg_90), ('xg_per_shot'::text,b.xg_per_shot), ('finishing'::text,b.finishing), ('box_share'::text,b.box_share), ('shot_dist'::text,b.shot_dist), ('conversion'::text,b.conversion), ('shot_acc'::text,b.shot_acc), ('bigchance_90'::text,b.bigchance_90), ('weak_foot_share'::text,b.weak_foot_share), ('tackle_90'::text,b.tackle_90), ('tackle_pct'::text,b.tackle_pct), ('int_90'::text,b.int_90), ('clear_90'::text,b.clear_90), ('block_90'::text,b.block_90), ('recov_90'::text,b.recov_90), ('aerial_90'::text,b.aerial_90), ('aerial_pct'::text,b.aerial_pct), ('def_action_90'::text,b.def_action_90), ('def_height'::text,b.def_height), ('box_def_90'::text,b.box_def_90), ('channel_def_90'::text,b.channel_def_90), ('flank_def_90'::text,b.flank_def_90), ('counterpress_90'::text,b.counterpress_90), ('takeon_90'::text,b.takeon_90), ('takeon_pct'::text,b.takeon_pct), ('disp_90'::text,b.disp_90), ('badtouch_90'::text,b.badtouch_90), ('foul_com_90'::text,b.foul_com_90), ('foul_won_90'::text,b.foul_won_90), ('error_90'::text,b.error_90), ('carries_90'::text,b.carries_90), ('prog_carries_90'::text,b.prog_carries_90), ('carry_box_90'::text,b.carry_box_90), ('mean_carry_m'::text,b.mean_carry_m), ('carry_pen_90'::text,b.carry_pen_90), ('median_ttr'::text,b.median_ttr), ('quick_pct'::text,b.quick_pct), ('one_touch_pct'::text,b.one_touch_pct), ('aq_per_duel'::text,b.aq_per_duel), ('duel_quality'::text,b.duel_quality), ('recov_retention'::text,b.recov_retention), ('recov_prog_90'::text,b.recov_prog_90), ('save_pct'::text,b.save_pct), ('goals_prevented_90'::text,b.goals_prevented_90), ('saves_90'::text,b.saves_90), ('claims_90'::text,b.claims_90), ('sweeps_90'::text,b.sweeps_90), ('sweep_x'::text,b.sweep_x), ('hs_passes_90'::text,b.hs_passes_90), ('hs_prog_90'::text,b.hs_prog_90), ('hs_key_90'::text,b.hs_key_90), ('hs_shots_90'::text,b.hs_shots_90), ('hs_takeons_90'::text,b.hs_takeons_90), ('holds_90'::text,b.holds_90), ('hold_retention'::text,b.hold_retention), ('hold_prog_pct'::text,b.hold_prog_pct), ('hold_shot_pct'::text,b.hold_shot_pct), ('sp_xg_90'::text,b.sp_xg_90), ('sp_shots_90'::text,b.sp_shots_90), ('sp_aerials_90'::text,b.sp_aerials_90), ('sp_key_90'::text,b.sp_key_90), ('padj_tackle_90'::text,round((b.tackle_90 * b.padj), 2)), ('padj_int_90'::text,round((b.int_90 * b.padj), 2)), ('padj_def_90'::text,round((b.def_action_90 * b.padj), 2)), ('padj_recov_90'::text,round((b.recov_90 * b.padj), 2))) v(metric, value))
        ), ranked AS (
         SELECT l.player_id,
            l.pool,
            l.nineties,
            l.league,
            l.metric,
            l.value,
            d.higher_is_better,
            percent_rank() OVER (PARTITION BY l.league, l.pool, l.metric ORDER BY l.value) AS pr
           FROM (long l
             JOIN metric_defs d ON ((d.key = l.metric)))
          WHERE ((l.nineties >= (6)::numeric) AND (l.value IS NOT NULL))
        )
 SELECT player_id,
    pool,
    metric,
    value,
    round((((100)::double precision *
        CASE
            WHEN higher_is_better THEN pr
            ELSE ((1)::double precision - pr)
        END))::numeric, 0) AS pct,
    league
   FROM ranked;
CREATE INDEX mv_player_percentiles_metric ON public.mv_player_percentiles USING btree (metric);
CREATE INDEX mv_player_percentiles_pm ON public.mv_player_percentiles USING btree (player_id, metric);
alter materialized view public.mv_player_percentiles owner to postgres;
revoke all on public.mv_player_percentiles from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_percentiles to anon;
grant SELECT on public.mv_player_percentiles to authenticated;
grant DELETE on public.mv_player_percentiles to service_role;
grant INSERT on public.mv_player_percentiles to service_role;
grant MAINTAIN on public.mv_player_percentiles to service_role;
grant REFERENCES on public.mv_player_percentiles to service_role;
grant SELECT on public.mv_player_percentiles to service_role;
grant TRIGGER on public.mv_player_percentiles to service_role;
grant TRUNCATE on public.mv_player_percentiles to service_role;
grant UPDATE on public.mv_player_percentiles to service_role;

create materialized view public.mv_player_state_output as
WITH ev_state AS (
         SELECT e.game_id,
            e.team,
            e.player_id,
            e.ws_id,
            e.type,
            e.x,
            e.y,
            e.end_x,
            e.end_y,
            e.outcome_type,
            (sg.margin)::numeric AS margin
           FROM (events e
             JOIN mv_state_segments sg ON (((sg.game_id = e.game_id) AND (sg.team = e.team) AND (e.expanded_minute >= sg.seg_start) AND (e.expanded_minute < sg.seg_end))))
          WHERE (e.player_id IS NOT NULL)
        ), shots AS (
         SELECT s_1.player_id,
            s_1.xg,
            state_weight(es.margin) AS w
           FROM (mv_shot_xg s_1
             JOIN ev_state es ON (((es.game_id = s_1.game_id) AND (es.ws_id = s_1.ws_id))))
          WHERE (s_1.is_pen = false)
        ), xt AS (
         SELECT es.player_id,
            (COALESCE(xt_val(es.end_x, es.end_y), (0)::numeric) - COALESCE(xt_val(es.x, es.y), (0)::numeric)) AS xt_delta,
            state_weight(es.margin) AS w
           FROM ev_state es
          WHERE ((es.type = 'Pass'::text) AND (es.outcome_type = 'Successful'::text) AND (es.end_x IS NOT NULL))
        ), wmin AS (
         SELECT pm.player_id,
            sum(GREATEST(0, (LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start)))) AS raw_min,
            sum(((GREATEST(0, (LEAST(pm.end_min, sg.seg_end) - GREATEST(pm.start_min, sg.seg_start))))::numeric * state_weight((sg.margin)::numeric))) AS weighted_min
           FROM (mv_player_stints pm
             JOIN mv_state_segments sg ON (((sg.game_id = pm.game_id) AND (sg.team = pm.team) AND (sg.seg_start < pm.end_min) AND (sg.seg_end > pm.start_min))))
          GROUP BY pm.player_id
        ), sh_agg AS (
         SELECT shots.player_id,
            sum(shots.xg) AS raw_xg,
            sum((shots.xg * shots.w)) AS live_xg
           FROM shots
          GROUP BY shots.player_id
        ), xt_agg AS (
         SELECT xt.player_id,
            sum(xt.xt_delta) AS raw_xt,
            sum((xt.xt_delta * xt.w)) AS live_xt
           FROM xt
          GROUP BY xt.player_id
        )
 SELECT w.player_id,
    pcr.player,
    pcr.team,
    pcr.pos,
    round(((w.raw_min)::numeric / 90.0), 2) AS nineties_raw,
    round((w.weighted_min / 90.0), 2) AS nineties_live,
    round(((100.0 * w.weighted_min) / (NULLIF(w.raw_min, 0))::numeric), 1) AS live_minute_pct,
    round((COALESCE(s.raw_xg, (0)::numeric) / NULLIF(((w.raw_min)::numeric / 90.0), (0)::numeric)), 3) AS xg_90_raw,
    round((COALESCE(s.live_xg, (0)::numeric) / NULLIF((w.weighted_min / 90.0), (0)::numeric)), 3) AS xg_90_live,
    round(((COALESCE(s.live_xg, (0)::numeric) / NULLIF((w.weighted_min / 90.0), (0)::numeric)) - (COALESCE(s.raw_xg, (0)::numeric) / NULLIF(((w.raw_min)::numeric / 90.0), (0)::numeric))), 3) AS xg_90_delta,
    round((COALESCE(x.raw_xt, (0)::numeric) / NULLIF(((w.raw_min)::numeric / 90.0), (0)::numeric)), 3) AS xt_90_raw,
    round((COALESCE(x.live_xt, (0)::numeric) / NULLIF((w.weighted_min / 90.0), (0)::numeric)), 3) AS xt_90_live,
    round(((COALESCE(x.live_xt, (0)::numeric) / NULLIF((w.weighted_min / 90.0), (0)::numeric)) - (COALESCE(x.raw_xt, (0)::numeric) / NULLIF(((w.raw_min)::numeric / 90.0), (0)::numeric))), 3) AS xt_90_delta
   FROM (((wmin w
     JOIN player_chain_roles pcr ON ((pcr.player_id = w.player_id)))
     LEFT JOIN sh_agg s ON ((s.player_id = w.player_id)))
     LEFT JOIN xt_agg x ON ((x.player_id = w.player_id)))
  WHERE (w.raw_min >= 540);
CREATE UNIQUE INDEX mv_player_state_output_pk ON public.mv_player_state_output USING btree (player_id);
alter materialized view public.mv_player_state_output owner to postgres;
revoke all on public.mv_player_state_output from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_state_output to anon;
grant SELECT on public.mv_player_state_output to authenticated;
grant DELETE on public.mv_player_state_output to service_role;
grant INSERT on public.mv_player_state_output to service_role;
grant MAINTAIN on public.mv_player_state_output to service_role;
grant REFERENCES on public.mv_player_state_output to service_role;
grant SELECT on public.mv_player_state_output to service_role;
grant TRIGGER on public.mv_player_state_output to service_role;
grant TRUNCATE on public.mv_player_state_output to service_role;
grant UPDATE on public.mv_player_state_output to service_role;

create materialized view public.mv_team_all as
SELECT s.team,
    s.matches,
    s.possession_pct,
    s.field_tilt,
    s.ppda,
    s.def_height,
    s.avg_touch_x,
    s.long_ball_pct,
    s.build_from_back_pct,
    s.directness,
    s.prog_passes_pg,
    s.box_entries_pg,
    s.crosses_pg,
    s.shots_pg,
    s.shots_against_pg,
    s.goals_pg,
    s.goals_against_pg,
    s.open_play_shot_pct,
    b2.passes_per_seq,
    b2.secs_per_seq,
    b2.long_sequence_pct,
    b2.pct_ending_in_shot,
    b2.ground_gained,
    b2.sequences_pg,
    bp.gk_long_pct,
    bp.d3_pass_share,
    bp.d3_accuracy,
    bp.d3_long_pct,
    bp.deep_circulation_pg,
    bp.cb_prog_pg,
    bp.escape_pct,
    bp.deep_to_final_pct,
    bp.d3_touch_share,
    ap.att_directness,
    ap.mid_release,
    ap.ft_release,
    ap.passes_per_shot,
    ap.ft_entries_pg,
    ap.box_per_entry,
    ap.final_to_shot_pct,
    COALESCE(l.pct_left, (0)::numeric) AS pct_left,
    COALESCE(l.pct_centre, (0)::numeric) AS pct_centre,
    COALESCE(l.pct_right, (0)::numeric) AS pct_right
   FROM ((((mv_team_season s
     LEFT JOIN mv_team_buildup b2 ON ((b2.team = s.team)))
     LEFT JOIN mv_team_buildphase bp ON ((bp.team = s.team)))
     LEFT JOIN mv_team_attackphase ap ON ((ap.team = s.team)))
     LEFT JOIN ( SELECT mv_team_lanes.team,
            max(mv_team_lanes.pct_of_final_third) FILTER (WHERE (mv_team_lanes.lane = 'L'::text)) AS pct_left,
            max(mv_team_lanes.pct_of_final_third) FILTER (WHERE (mv_team_lanes.lane = 'C'::text)) AS pct_centre,
            max(mv_team_lanes.pct_of_final_third) FILTER (WHERE (mv_team_lanes.lane = 'R'::text)) AS pct_right
           FROM mv_team_lanes
          GROUP BY mv_team_lanes.team) l ON ((l.team = s.team)));
CREATE UNIQUE INDEX mv_team_all_team_idx ON public.mv_team_all USING btree (team);
alter materialized view public.mv_team_all owner to postgres;
revoke all on public.mv_team_all from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_all to anon;
grant SELECT on public.mv_team_all to authenticated;
grant DELETE on public.mv_team_all to service_role;
grant INSERT on public.mv_team_all to service_role;
grant MAINTAIN on public.mv_team_all to service_role;
grant REFERENCES on public.mv_team_all to service_role;
grant SELECT on public.mv_team_all to service_role;
grant TRIGGER on public.mv_team_all to service_role;
grant TRUNCATE on public.mv_team_all to service_role;
grant UPDATE on public.mv_team_all to service_role;

create view public.v_league_summary as
SELECT league,
    display_name,
    country,
    season,
    matches,
    teams,
    players_profiled,
    sequences,
    insights
   FROM mv_league_summary;
alter view public.v_league_summary owner to postgres;
revoke all on public.v_league_summary from public, anon, authenticated, service_role;
grant SELECT on public.v_league_summary to anon;
grant SELECT on public.v_league_summary to authenticated;
grant DELETE on public.v_league_summary to service_role;
grant INSERT on public.v_league_summary to service_role;
grant MAINTAIN on public.v_league_summary to service_role;
grant REFERENCES on public.v_league_summary to service_role;
grant SELECT on public.v_league_summary to service_role;
grant TRIGGER on public.v_league_summary to service_role;
grant TRUNCATE on public.v_league_summary to service_role;
grant UPDATE on public.v_league_summary to service_role;

create view public.v_seq_directness as
SELECT s.seq_uid,
    s.game_id,
    s.team,
    s.n_pass,
    s.dur_s,
    GREATEST('-1.0'::numeric, LEAST(1.0, (((s.end_x - s.start_x))::numeric / NULLIF((s.mean_pass_len * (s.n_pass)::numeric), (0)::numeric)))) AS directness,
    st.state,
    st.margin,
    st.is_close
   FROM (v_league_sequences s
     JOIN mv_seq_state st USING (seq_uid))
  WHERE (s.is_open_play AND (s.n_pass >= 2) AND (COALESCE(s.mean_pass_len, (0)::numeric) > (0)::numeric));
alter view public.v_seq_directness owner to postgres;
revoke all on public.v_seq_directness from public, anon, authenticated, service_role;
grant SELECT on public.v_seq_directness to anon;
grant SELECT on public.v_seq_directness to authenticated;
grant DELETE on public.v_seq_directness to service_role;
grant INSERT on public.v_seq_directness to service_role;
grant MAINTAIN on public.v_seq_directness to service_role;
grant REFERENCES on public.v_seq_directness to service_role;
grant SELECT on public.v_seq_directness to service_role;
grant TRIGGER on public.v_seq_directness to service_role;
grant TRUNCATE on public.v_seq_directness to service_role;
grant UPDATE on public.v_seq_directness to service_role;

create view public.v_team_sample as
SELECT s.team,
    min(s.league) AS league,
    count(DISTINCT s.game_id) AS matches,
    count(*) FILTER (WHERE s.is_open_play) AS open_play_seqs,
    count(*) FILTER (WHERE (s.is_open_play AND (s.start_x < (33.3)::double precision))) AS deep_start_seqs,
    count(*) FILTER (WHERE (s.is_open_play AND (st.state = 'winning'::text))) AS seqs_winning,
    count(*) FILTER (WHERE (s.is_open_play AND (st.state = 'losing'::text))) AS seqs_losing,
    (count(DISTINCT s.game_id) >= 6) AS meets_min_matches
   FROM (v_league_sequences s
     LEFT JOIN mv_seq_state st ON ((st.seq_uid = s.seq_uid)))
  GROUP BY s.team;
alter view public.v_team_sample owner to postgres;
revoke all on public.v_team_sample from public, anon, authenticated, service_role;
grant SELECT on public.v_team_sample to anon;
grant SELECT on public.v_team_sample to authenticated;
grant DELETE on public.v_team_sample to service_role;
grant INSERT on public.v_team_sample to service_role;
grant MAINTAIN on public.v_team_sample to service_role;
grant REFERENCES on public.v_team_sample to service_role;
grant SELECT on public.v_team_sample to service_role;
grant TRIGGER on public.v_team_sample to service_role;
grant TRUNCATE on public.v_team_sample to service_role;
grant UPDATE on public.v_team_sample to service_role;
comment on view public.v_team_sample is 'Team evidence base, league competitions only via v_league_sequences. Source of truth for the six-match minimum.';

create view public.v_team_signature as
SELECT DISTINCT ON (team) team,
    route AS signature_route,
    share_pct,
    z_share,
    shot_pct,
    z_productivity,
        CASE
            WHEN (z_productivity >= 0.5) THEN 'effective'::text
            WHEN (z_productivity <= '-0.5'::numeric) THEN 'unproductive'::text
            ELSE 'league average'::text
        END AS signature_verdict,
    league
   FROM mv_team_breakdown
  ORDER BY team, z_share DESC;
alter view public.v_team_signature owner to postgres;
revoke all on public.v_team_signature from public, anon, authenticated, service_role;
grant SELECT on public.v_team_signature to anon;
grant SELECT on public.v_team_signature to authenticated;
grant DELETE on public.v_team_signature to service_role;
grant INSERT on public.v_team_signature to service_role;
grant MAINTAIN on public.v_team_signature to service_role;
grant REFERENCES on public.v_team_signature to service_role;
grant SELECT on public.v_team_signature to service_role;
grant TRIGGER on public.v_team_signature to service_role;
grant TRUNCATE on public.v_team_signature to service_role;
grant UPDATE on public.v_team_signature to service_role;

create materialized view public.mv_league_availability as
WITH ev AS (
         SELECT events.league,
            count(DISTINCT events.game_id) AS matches
           FROM events
          GROUP BY events.league
        ), ts AS (
         SELECT v_team_sample.league,
            count(*) FILTER (WHERE v_team_sample.meets_min_matches) AS qualifying,
            count(*) AS total
           FROM v_team_sample
          GROUP BY v_team_sample.league
        ), ins AS (
         SELECT tl.league,
            count(*) AS n
           FROM (insights i
             JOIN mv_team_league tl ON ((tl.team = i.team)))
          GROUP BY tl.league
        )
 SELECT l.league,
    l.display_name,
    COALESCE(ev.matches, (0)::bigint) AS matches,
    COALESCE(ts.qualifying, (0)::bigint) AS clubs_at_threshold,
    COALESCE(ts.total, (0)::bigint) AS clubs,
    COALESCE(ins.n, (0)::bigint) AS insights,
    ( SELECT detector_requirements.min_matches
           FROM detector_requirements
          WHERE (detector_requirements.detector = 'team_profile'::text)) AS min_matches_required,
        CASE
            WHEN (COALESCE(ts.qualifying, (0)::bigint) > 0) THEN 'available'::text
            WHEN (COALESCE(ev.matches, (0)::bigint) = 0) THEN 'no data yet'::text
            ELSE 'below sample threshold'::text
        END AS insight_status
   FROM (((leagues l
     LEFT JOIN ev ON ((ev.league = l.league)))
     LEFT JOIN ts ON ((ts.league = l.league)))
     LEFT JOIN ins ON ((ins.league = l.league)))
  WHERE l.is_active;
CREATE UNIQUE INDEX mv_league_availability_pk ON public.mv_league_availability USING btree (league);
alter materialized view public.mv_league_availability owner to postgres;
revoke all on public.mv_league_availability from public, anon, authenticated, service_role;
grant SELECT on public.mv_league_availability to anon;
grant SELECT on public.mv_league_availability to authenticated;
grant DELETE on public.mv_league_availability to service_role;
grant INSERT on public.mv_league_availability to service_role;
grant MAINTAIN on public.mv_league_availability to service_role;
grant REFERENCES on public.mv_league_availability to service_role;
grant SELECT on public.mv_league_availability to service_role;
grant TRIGGER on public.mv_league_availability to service_role;
grant TRUNCATE on public.mv_league_availability to service_role;
grant UPDATE on public.mv_league_availability to service_role;

create materialized view public.mv_metric_examples as
WITH q AS (
         SELECT p.metric,
            p.pool,
            p.player_id,
            p.value,
            p.pct,
            p.league,
            s.player_name,
            s.team,
            s.nineties
           FROM (mv_player_percentiles p
             JOIN mv_player_season s USING (player_id))
          WHERE (s.nineties >= (8)::numeric)
        ), stat AS (
         SELECT q.metric,
            q.league,
            count(*) AS n,
            round(min(q.value), 3) AS min_v,
            round((percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((q.value)::double precision)))::numeric, 3) AS med_v,
            round(max(q.value), 3) AS max_v
           FROM q
          GROUP BY q.metric, q.league
        ), hi AS (
         SELECT DISTINCT ON (q.metric, q.league) q.metric,
            q.league,
            q.player_id,
            q.player_name,
            q.team,
            q.pool,
            q.value,
            q.nineties
           FROM q
          ORDER BY q.metric, q.league, q.value DESC
        ), lo AS (
         SELECT DISTINCT ON (q.metric, q.league) q.metric,
            q.league,
            q.player_id,
            q.player_name,
            q.team,
            q.pool,
            q.value,
            q.nineties
           FROM q
          ORDER BY q.metric, q.league, q.value
        )
 SELECT st.metric,
    st.n,
    st.min_v,
    st.med_v,
    st.max_v,
    hi.player_name AS hi_name,
    hi.team AS hi_team,
    hi.pool AS hi_pool,
    round(hi.value, 3) AS hi_value,
    hi.player_id AS hi_id,
    lo.player_name AS lo_name,
    lo.team AS lo_team,
    lo.pool AS lo_pool,
    round(lo.value, 3) AS lo_value,
    lo.player_id AS lo_id,
    st.league
   FROM ((stat st
     LEFT JOIN hi ON (((hi.metric = st.metric) AND (hi.league = st.league))))
     LEFT JOIN lo ON (((lo.metric = st.metric) AND (lo.league = st.league))));
CREATE INDEX mv_metric_examples_metric_idx ON public.mv_metric_examples USING btree (metric);
alter materialized view public.mv_metric_examples owner to postgres;
revoke all on public.mv_metric_examples from public, anon, authenticated, service_role;
grant SELECT on public.mv_metric_examples to anon;
grant SELECT on public.mv_metric_examples to authenticated;
grant DELETE on public.mv_metric_examples to service_role;
grant INSERT on public.mv_metric_examples to service_role;
grant MAINTAIN on public.mv_metric_examples to service_role;
grant REFERENCES on public.mv_metric_examples to service_role;
grant SELECT on public.mv_metric_examples to service_role;
grant TRIGGER on public.mv_metric_examples to service_role;
grant TRUNCATE on public.mv_metric_examples to service_role;
grant UPDATE on public.mv_metric_examples to service_role;

create materialized view public.mv_player_pillars as
SELECT p.player_id,
    p.pool,
    d.pillar,
    min(d.ord) AS ord,
    round((sum((p.pct * d.weight)) / NULLIF(sum(d.weight), (0)::numeric)), 1) AS score,
    count(*) AS markers_used,
    p.league
   FROM (mv_player_percentiles p
     JOIN pillar_defs d ON ((d.metric = p.metric)))
  WHERE (p.pool <> 'GK'::text)
  GROUP BY p.player_id, p.pool, d.pillar, p.league;
CREATE INDEX mv_player_pillars_p ON public.mv_player_pillars USING btree (player_id);
CREATE UNIQUE INDEX mv_player_pillars_uq ON public.mv_player_pillars USING btree (player_id, pillar);
alter materialized view public.mv_player_pillars owner to postgres;
revoke all on public.mv_player_pillars from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_pillars to anon;
grant SELECT on public.mv_player_pillars to authenticated;
grant DELETE on public.mv_player_pillars to service_role;
grant INSERT on public.mv_player_pillars to service_role;
grant MAINTAIN on public.mv_player_pillars to service_role;
grant REFERENCES on public.mv_player_pillars to service_role;
grant SELECT on public.mv_player_pillars to service_role;
grant TRIGGER on public.mv_player_pillars to service_role;
grant TRUNCATE on public.mv_player_pillars to service_role;
grant UPDATE on public.mv_player_pillars to service_role;

create materialized view public.mv_squad_role as
WITH mlen AS (
         SELECT events.game_id,
            (max(events.expanded_minute) + 1) AS end_min
           FROM events
          GROUP BY events.game_id
        ), tg AS (
         SELECT DISTINCT e.game_id,
            e.team,
            e.league,
            m.date,
            ml.end_min
           FROM ((events e
             JOIN matches m ON ((m.game_id = e.game_id)))
             JOIN mlen ml ON ((ml.game_id = e.game_id)))
          WHERE ((e.team IS NOT NULL) AND (m.date IS NOT NULL))
        ), team_last AS (
         SELECT tg.team,
            max(tg.date) AS last_team_date
           FROM tg
          GROUP BY tg.team
        ), pt AS (
         SELECT pm.player_id,
            pm.team,
            min(t.league) AS league,
            min(t.date) AS first_date,
            max(t.date) AS last_date,
            sum(pm.minutes) AS minutes_played,
            count(*) AS appearances,
            count(*) FILTER (WHERE pm.is_starter) AS starts
           FROM (mv_player_stints pm
             JOIN tg t ON (((t.game_id = pm.game_id) AND (t.team = pm.team))))
          GROUP BY pm.player_id, pm.team
        ), moved AS (
         SELECT a.player_id,
            a.team,
            max(b.last_date) AS later_elsewhere
           FROM (pt a
             JOIN pt b ON (((b.player_id = a.player_id) AND (b.team <> a.team) AND (b.last_date > a.last_date))))
          GROUP BY a.player_id, a.team
        ), bounds AS (
         SELECT p.player_id,
            p.team,
            p.league,
            p.first_date,
            p.last_date,
            p.minutes_played,
            p.appearances,
            p.starts,
                CASE
                    WHEN (mv.later_elsewhere IS NOT NULL) THEN p.last_date
                    ELSE tl.last_team_date
                END AS window_end
           FROM ((pt p
             LEFT JOIN moved mv ON (((mv.player_id = p.player_id) AND (mv.team = p.team))))
             JOIN team_last tl ON ((tl.team = p.team)))
        ), avail AS (
         SELECT b.player_id,
            b.team,
            b.league,
            b.first_date,
            b.last_date,
            b.window_end,
            b.minutes_played,
            b.appearances,
            b.starts,
            count(t.game_id) AS games_available,
            COALESCE(sum(t.end_min), (0)::bigint) AS minutes_available
           FROM (bounds b
             LEFT JOIN tg t ON (((t.team = b.team) AND ((t.date >= b.first_date) AND (t.date <= b.window_end)))))
          GROUP BY b.player_id, b.team, b.league, b.first_date, b.last_date, b.window_end, b.minutes_played, b.appearances, b.starts
        ), scored AS (
         SELECT a.player_id,
            a.team,
            a.league,
            a.first_date,
            a.last_date,
            a.window_end,
            a.minutes_played,
            a.appearances,
            a.starts,
            a.games_available,
            a.minutes_available,
            lv.leverage_pct,
            round(((100.0 * (a.minutes_played)::numeric) / (NULLIF(a.minutes_available, 0))::numeric), 1) AS selection_pct,
            round(((100.0 * (a.starts)::numeric) / (NULLIF(a.games_available, 0))::numeric), 1) AS start_pct
           FROM (avail a
             LEFT JOIN mv_player_leverage lv ON (((lv.player_id = a.player_id) AND (lv.team = a.team))))
        ), ranked AS (
         SELECT s.player_id,
            s.team,
            s.league,
            s.first_date,
            s.last_date,
            s.window_end,
            s.minutes_played,
            s.appearances,
            s.starts,
            s.games_available,
            s.minutes_available,
            s.leverage_pct,
            s.selection_pct,
            s.start_pct,
            rank() OVER (PARTITION BY s.team ORDER BY s.selection_pct DESC NULLS LAST) AS squad_rank,
            round(((s.leverage_pct - avg(s.leverage_pct) OVER (PARTITION BY s.team)) / NULLIF(stddev_samp(s.leverage_pct) OVER (PARTITION BY s.team), (0)::numeric)), 2) AS leverage_z_in_squad
           FROM scored s
        )
 SELECT r.player_id,
    r.team,
    r.league,
    r.first_date,
    r.last_date,
    r.window_end,
    r.minutes_played,
    r.appearances,
    r.starts,
    r.games_available,
    r.minutes_available,
    r.leverage_pct,
    r.selection_pct,
    r.start_pct,
    r.squad_rank,
    r.leverage_z_in_squad,
    pcr.player,
    pcr.pos,
        CASE
            WHEN (r.selection_pct >= (70)::numeric) THEN 'Key player'::text
            WHEN (r.selection_pct >= (45)::numeric) THEN 'Starter'::text
            WHEN (r.selection_pct >= (20)::numeric) THEN 'Rotation'::text
            ELSE 'Fringe'::text
        END AS squad_role
   FROM (ranked r
     JOIN player_chain_roles pcr ON ((pcr.player_id = r.player_id)))
  WHERE (r.games_available >= 6);
CREATE INDEX mv_squad_role_player ON public.mv_squad_role USING btree (player_id);
alter materialized view public.mv_squad_role owner to postgres;
revoke all on public.mv_squad_role from public, anon, authenticated, service_role;
grant SELECT on public.mv_squad_role to anon;
grant SELECT on public.mv_squad_role to authenticated;
grant DELETE on public.mv_squad_role to service_role;
grant INSERT on public.mv_squad_role to service_role;
grant MAINTAIN on public.mv_squad_role to service_role;
grant REFERENCES on public.mv_squad_role to service_role;
grant SELECT on public.mv_squad_role to service_role;
grant TRIGGER on public.mv_squad_role to service_role;
grant TRUNCATE on public.mv_squad_role to service_role;
grant UPDATE on public.mv_squad_role to service_role;

create materialized view public.mv_team_directness_state as
WITH base AS (
         SELECT d.team,
            COALESCE(tl.league, 'USA-MLS'::text) AS league,
            d.state,
            round(avg(d.directness), 4) AS directness,
            count(*) AS n
           FROM (v_seq_directness d
             LEFT JOIN mv_team_league tl ON ((tl.team = d.team)))
          GROUP BY d.team, COALESCE(tl.league, 'USA-MLS'::text), d.state
        ), piv AS (
         SELECT base.team,
            base.league,
            max(base.directness) FILTER (WHERE (base.state = 'winning'::text)) AS dir_winning,
            max(base.directness) FILTER (WHERE (base.state = 'drawing'::text)) AS dir_drawing,
            max(base.directness) FILTER (WHERE (base.state = 'losing'::text)) AS dir_losing,
            sum(base.n) FILTER (WHERE (base.state = 'winning'::text)) AS n_winning,
            sum(base.n) FILTER (WHERE (base.state = 'drawing'::text)) AS n_drawing,
            sum(base.n) FILTER (WHERE (base.state = 'losing'::text)) AS n_losing,
            round(avg(base.directness), 4) AS dir_overall
           FROM base
          GROUP BY base.team, base.league
        )
 SELECT team,
    league,
    dir_winning,
    dir_drawing,
    dir_losing,
    n_winning,
    n_drawing,
    n_losing,
    dir_overall,
    round((dir_losing - dir_winning), 4) AS swing_l_minus_w,
    rank() OVER (PARTITION BY league ORDER BY (dir_losing - dir_winning) DESC) AS swing_rank
   FROM piv;
CREATE UNIQUE INDEX mv_team_directness_state_pk ON public.mv_team_directness_state USING btree (team);
alter materialized view public.mv_team_directness_state owner to postgres;
revoke all on public.mv_team_directness_state from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_directness_state to anon;
grant SELECT on public.mv_team_directness_state to authenticated;
grant DELETE on public.mv_team_directness_state to service_role;
grant INSERT on public.mv_team_directness_state to service_role;
grant MAINTAIN on public.mv_team_directness_state to service_role;
grant REFERENCES on public.mv_team_directness_state to service_role;
grant SELECT on public.mv_team_directness_state to service_role;
grant TRIGGER on public.mv_team_directness_state to service_role;
grant TRUNCATE on public.mv_team_directness_state to service_role;
grant UPDATE on public.mv_team_directness_state to service_role;

create materialized view public.mv_team_percentiles as
WITH long AS (
         SELECT t.team,
            COALESCE(tl.league, 'USA-MLS'::text) AS league,
            v.metric,
            v.value
           FROM ((mv_team_all t
             LEFT JOIN mv_team_league tl ON ((tl.team = t.team)))
             CROSS JOIN LATERAL ( VALUES ('possession_pct'::text,t.possession_pct), ('field_tilt'::text,t.field_tilt), ('avg_touch_x'::text,t.avg_touch_x), ('directness'::text,t.directness), ('long_ball_pct'::text,t.long_ball_pct), ('build_from_back_pct'::text,t.build_from_back_pct), ('ppda'::text,t.ppda), ('def_height'::text,t.def_height), ('prog_passes_pg'::text,t.prog_passes_pg), ('box_entries_pg'::text,t.box_entries_pg), ('crosses_pg'::text,t.crosses_pg), ('shots_pg'::text,t.shots_pg), ('goals_pg'::text,t.goals_pg), ('open_play_shot_pct'::text,t.open_play_shot_pct), ('shots_against_pg'::text,t.shots_against_pg), ('goals_against_pg'::text,t.goals_against_pg), ('passes_per_seq'::text,t.passes_per_seq), ('secs_per_seq'::text,t.secs_per_seq), ('long_sequence_pct'::text,t.long_sequence_pct), ('pct_ending_in_shot'::text,t.pct_ending_in_shot), ('ground_gained'::text,t.ground_gained), ('sequences_pg'::text,t.sequences_pg), ('gk_long_pct'::text,t.gk_long_pct), ('d3_pass_share'::text,t.d3_pass_share), ('d3_accuracy'::text,t.d3_accuracy), ('d3_long_pct'::text,t.d3_long_pct), ('deep_circulation_pg'::text,t.deep_circulation_pg), ('cb_prog_pg'::text,t.cb_prog_pg), ('escape_pct'::text,t.escape_pct), ('deep_to_final_pct'::text,t.deep_to_final_pct), ('d3_touch_share'::text,t.d3_touch_share), ('att_directness'::text,t.att_directness), ('mid_release'::text,t.mid_release), ('ft_release'::text,t.ft_release), ('passes_per_shot'::text,t.passes_per_shot), ('ft_entries_pg'::text,t.ft_entries_pg), ('box_per_entry'::text,t.box_per_entry), ('final_to_shot_pct'::text,t.final_to_shot_pct), ('pct_left'::text,t.pct_left), ('pct_centre'::text,t.pct_centre), ('pct_right'::text,t.pct_right)) v(metric, value))
        ), r AS (
         SELECT l.team,
            l.league,
            l.metric,
            l.value,
            d.higher_is_better,
            percent_rank() OVER (PARTITION BY l.league, l.metric ORDER BY l.value) AS pr
           FROM (long l
             JOIN team_metric_defs d ON ((d.key = l.metric)))
          WHERE (l.value IS NOT NULL)
        )
 SELECT team,
    metric,
    value,
    round((((100)::double precision *
        CASE
            WHEN higher_is_better THEN pr
            ELSE ((1)::double precision - pr)
        END))::numeric, 0) AS pct,
    league
   FROM r;
CREATE INDEX mv_team_percentiles_tm ON public.mv_team_percentiles USING btree (team, metric);
alter materialized view public.mv_team_percentiles owner to postgres;
revoke all on public.mv_team_percentiles from public, anon, authenticated, service_role;
grant SELECT on public.mv_team_percentiles to anon;
grant SELECT on public.mv_team_percentiles to authenticated;
grant DELETE on public.mv_team_percentiles to service_role;
grant INSERT on public.mv_team_percentiles to service_role;
grant MAINTAIN on public.mv_team_percentiles to service_role;
grant REFERENCES on public.mv_team_percentiles to service_role;
grant SELECT on public.mv_team_percentiles to service_role;
grant TRIGGER on public.mv_team_percentiles to service_role;
grant TRUNCATE on public.mv_team_percentiles to service_role;
grant UPDATE on public.mv_team_percentiles to service_role;

create view public.v_team_directory as
SELECT t.team,
    COALESCE(tl.league, 'USA-MLS'::text) AS league,
    COALESCE(l.display_name, 'Major League Soccer'::text) AS league_name,
    l.country,
    count(*) OVER (PARTITION BY COALESCE(tl.league, 'USA-MLS'::text)) AS teams_in_league,
    ( SELECT count(*) AS count
           FROM matches m
          WHERE ((m.league = COALESCE(tl.league, 'USA-MLS'::text)) AND (m.home_score IS NOT NULL) AND ((m.home_team = t.team) OR (m.away_team = t.team)))) AS matches_played
   FROM ((mv_team_all t
     LEFT JOIN mv_team_league tl ON ((tl.team = t.team)))
     LEFT JOIN leagues l ON ((l.league = tl.league)));
alter view public.v_team_directory owner to postgres;
revoke all on public.v_team_directory from public, anon, authenticated, service_role;
grant SELECT on public.v_team_directory to anon;
grant SELECT on public.v_team_directory to authenticated;
grant DELETE on public.v_team_directory to service_role;
grant INSERT on public.v_team_directory to service_role;
grant MAINTAIN on public.v_team_directory to service_role;
grant REFERENCES on public.v_team_directory to service_role;
grant SELECT on public.v_team_directory to service_role;
grant TRIGGER on public.v_team_directory to service_role;
grant TRUNCATE on public.v_team_directory to service_role;
grant UPDATE on public.v_team_directory to service_role;

create materialized view public.mv_player_dna as
WITH w AS (
         SELECT p.player_id,
            p.pool,
            p.pillar,
            p.score,
            p.league,
            COALESCE(rw.weight, (0)::numeric) AS weight
           FROM (mv_player_pillars p
             LEFT JOIN role_pillar_weights rw ON (((rw.pool = p.pool) AND (rw.pillar = p.pillar))))
        ), ranked AS (
         SELECT w.player_id,
            w.pool,
            w.pillar,
            w.score,
            w.league,
            w.weight,
            row_number() OVER (PARTITION BY w.player_id ORDER BY w.score DESC) AS rk_all,
            row_number() OVER (PARTITION BY w.player_id ORDER BY (w.score * w.weight) DESC) AS rk_rel
           FROM w
        ), raw AS (
         SELECT ranked.player_id,
            ranked.pool,
            min(ranked.league) AS league,
            round(exp((sum((ranked.weight * ln(GREATEST(ranked.score, (1)::numeric)))) FILTER (WHERE (ranked.weight > (0)::numeric)) / NULLIF(sum(ranked.weight) FILTER (WHERE (ranked.weight > (0)::numeric)), (0)::numeric))), 1) AS completeness_raw,
            round(avg(ranked.score) FILTER (WHERE ((ranked.weight > (0)::numeric) AND (ranked.rk_rel <= 2))), 1) AS impact_raw,
            round(avg(ranked.score) FILTER (WHERE (ranked.weight > (0)::numeric)), 1) AS mean_relevant,
            round(stddev_pop(ranked.score) FILTER (WHERE (ranked.weight > (0)::numeric)), 1) AS spread,
            max(
                CASE
                    WHEN (ranked.rk_all = 1) THEN ranked.pillar
                    ELSE NULL::text
                END) AS top_pillar,
            max(
                CASE
                    WHEN (ranked.rk_all = 2) THEN ranked.pillar
                    ELSE NULL::text
                END) AS second_pillar
           FROM ranked
          GROUP BY ranked.player_id, ranked.pool
        ), weak AS (
         SELECT DISTINCT ON (ranked.player_id) ranked.player_id,
            ranked.pillar AS weakest_pillar,
            ranked.score AS weakest_score
           FROM ranked
          WHERE (ranked.weight > (0)::numeric)
          ORDER BY ranked.player_id, ranked.score
        )
 SELECT r.player_id,
    r.pool,
    r.mean_relevant,
    r.spread,
    r.top_pillar,
    r.second_pillar,
    w2.weakest_pillar,
    w2.weakest_score,
    r.completeness_raw,
    r.impact_raw,
    round(((100)::double precision * percent_rank() OVER (PARTITION BY r.league, r.pool ORDER BY r.completeness_raw))) AS completeness,
    round(((100)::double precision * percent_rank() OVER (PARTITION BY r.league, r.pool ORDER BY r.impact_raw))) AS impact,
    r.league
   FROM (raw r
     JOIN weak w2 USING (player_id));
CREATE UNIQUE INDEX mv_player_dna_pk ON public.mv_player_dna USING btree (player_id);
alter materialized view public.mv_player_dna owner to postgres;
revoke all on public.mv_player_dna from public, anon, authenticated, service_role;
grant SELECT on public.mv_player_dna to anon;
grant SELECT on public.mv_player_dna to authenticated;
grant DELETE on public.mv_player_dna to service_role;
grant INSERT on public.mv_player_dna to service_role;
grant MAINTAIN on public.mv_player_dna to service_role;
grant REFERENCES on public.mv_player_dna to service_role;
grant SELECT on public.mv_player_dna to service_role;
grant TRIGGER on public.mv_player_dna to service_role;
grant TRUNCATE on public.mv_player_dna to service_role;
grant UPDATE on public.mv_player_dna to service_role;

create view public.v_league_availability as
SELECT league,
    display_name,
    matches,
    clubs_at_threshold,
    clubs,
    insights,
    min_matches_required,
    insight_status
   FROM mv_league_availability;
alter view public.v_league_availability owner to postgres;
revoke all on public.v_league_availability from public, anon, authenticated, service_role;
grant SELECT on public.v_league_availability to anon;
grant SELECT on public.v_league_availability to authenticated;
grant DELETE on public.v_league_availability to service_role;
grant INSERT on public.v_league_availability to service_role;
grant MAINTAIN on public.v_league_availability to service_role;
grant REFERENCES on public.v_league_availability to service_role;
grant SELECT on public.v_league_availability to service_role;
grant TRIGGER on public.v_league_availability to service_role;
grant TRUNCATE on public.v_league_availability to service_role;
grant UPDATE on public.v_league_availability to service_role;

create view public.v_squad_role as
WITH lg AS (
         SELECT mv_squad_role.league,
            percentile_cont((0.25)::double precision) WITHIN GROUP (ORDER BY ((mv_squad_role.leverage_pct)::double precision)) AS p25,
            percentile_cont((0.50)::double precision) WITHIN GROUP (ORDER BY ((mv_squad_role.leverage_pct)::double precision)) AS p50
           FROM mv_squad_role
          WHERE (mv_squad_role.leverage_pct IS NOT NULL)
          GROUP BY mv_squad_role.league
        )
 SELECT r.player_id,
    r.player,
    r.team,
    r.pos,
    r.squad_role,
    r.squad_rank,
    r.selection_pct,
    r.start_pct,
    r.leverage_pct,
    r.leverage_z_in_squad,
    r.minutes_played,
    r.minutes_available,
    r.appearances,
    r.starts,
    r.games_available,
    (round(((100.0)::double precision * percent_rank() OVER (PARTITION BY r.league ORDER BY r.leverage_pct))))::integer AS leverage_pct_rank,
    ((r.selection_pct >= (40)::numeric) AND ((r.leverage_pct)::double precision < lg.p25)) AS minutes_inflated,
    r.league
   FROM (mv_squad_role r
     JOIN lg ON ((lg.league = r.league)));
alter view public.v_squad_role owner to postgres;
revoke all on public.v_squad_role from public, anon, authenticated, service_role;
grant SELECT on public.v_squad_role to anon;
grant SELECT on public.v_squad_role to authenticated;
grant DELETE on public.v_squad_role to service_role;
grant INSERT on public.v_squad_role to service_role;
grant MAINTAIN on public.v_squad_role to service_role;
grant REFERENCES on public.v_squad_role to service_role;
grant SELECT on public.v_squad_role to service_role;
grant TRIGGER on public.v_squad_role to service_role;
grant TRUNCATE on public.v_squad_role to service_role;
grant UPDATE on public.v_squad_role to service_role;


delete from league_mart_entry_objects where object_name='mv_game_goals';
insert into league_mart_entry_objects
select (jsonb_populate_record(null::league_mart_entry_objects,'{"note": "match goals, shootout rule", "object_name": "mv_game_goals"}'::jsonb)).*;
do $restore_severity$
declare item record; changed int; baseline jsonb:='{"team_league_resolves": "warn", "league_mart_reads_scoped_sources": "warn", "no_non_league_fixture_in_metrics": "warn", "no_non_league_row_in_league_outputs": "warn"}'::jsonb;
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
declare expected jsonb:='{"mv_team_all": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_all_team_idx", "definition": "CREATE UNIQUE INDEX mv_team_all_team_idx ON public.mv_team_all USING btree (team)"}], "reloptions": []}, "mv_seq_state": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_seq_state_pk", "definition": "CREATE UNIQUE INDEX mv_seq_state_pk ON public.mv_seq_state USING btree (seq_uid)"}, {"name": "mv_seq_state_team", "definition": "CREATE INDEX mv_seq_state_team ON public.mv_seq_state USING btree (team, state)"}], "reloptions": []}, "v_squad_role": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_game_goals": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_game_goals_idx", "definition": "CREATE INDEX mv_game_goals_idx ON public.mv_game_goals USING btree (game_id, expanded_minute)"}], "reloptions": []}, "mv_player_dna": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_player_dna_pk", "definition": "CREATE UNIQUE INDEX mv_player_dna_pk ON public.mv_player_dna USING btree (player_id)"}], "reloptions": []}, "mv_squad_role": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_squad_role_player", "definition": "CREATE INDEX mv_squad_role_player ON public.mv_squad_role USING btree (player_id)"}], "reloptions": []}, "mv_team_lanes": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_lanes_team_idx", "definition": "CREATE INDEX mv_team_lanes_team_idx ON public.mv_team_lanes USING btree (team)"}], "reloptions": []}, "mv_team_match": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_match_game_id_team_idx", "definition": "CREATE UNIQUE INDEX mv_team_match_game_id_team_idx ON public.mv_team_match USING btree (game_id, team)"}], "reloptions": []}, "mv_team_zones": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_zones_team_idx", "definition": "CREATE INDEX mv_team_zones_team_idx ON public.mv_team_zones USING btree (team)"}], "reloptions": []}, "v_team_sample": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": "Team evidence base, league competitions only via v_league_sequences. Source of truth for the six-match minimum.", "indexes": [], "reloptions": []}, "mv_team_league": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_league_pk", "definition": "CREATE UNIQUE INDEX mv_team_league_pk ON public.mv_team_league USING btree (team)"}], "reloptions": []}, "mv_team_season": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_season_team_idx", "definition": "CREATE UNIQUE INDEX mv_team_season_team_idx ON public.mv_team_season USING btree (team)"}], "reloptions": []}, "v_season_stats": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_team_buildup": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_buildup_team_idx", "definition": "CREATE UNIQUE INDEX mv_team_buildup_team_idx ON public.mv_team_buildup USING btree (team)"}], "reloptions": []}, "v_league_summary": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "v_seq_directness": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "v_team_directory": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "v_team_signature": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_league_summary": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_league_summary_pk", "definition": "CREATE UNIQUE INDEX mv_league_summary_pk ON public.mv_league_summary USING btree (league)"}], "reloptions": []}, "mv_player_pillars": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_player_pillars_p", "definition": "CREATE INDEX mv_player_pillars_p ON public.mv_player_pillars USING btree (player_id)"}, {"name": "mv_player_pillars_uq", "definition": "CREATE UNIQUE INDEX mv_player_pillars_uq ON public.mv_player_pillars USING btree (player_id, pillar)"}], "reloptions": []}, "mv_state_segments": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_state_segments_gt", "definition": "CREATE INDEX mv_state_segments_gt ON public.mv_state_segments USING btree (game_id, team)"}], "reloptions": []}, "mv_team_breakdown": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_breakdown_team", "definition": "CREATE INDEX mv_team_breakdown_team ON public.mv_team_breakdown USING btree (team)"}], "reloptions": []}, "mv_team_sequences": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_sequences_team_idx", "definition": "CREATE INDEX mv_team_sequences_team_idx ON public.mv_team_sequences USING btree (team)"}], "reloptions": []}, "mv_metric_examples": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_metric_examples_metric_idx", "definition": "CREATE INDEX mv_metric_examples_metric_idx ON public.mv_metric_examples USING btree (metric)"}], "reloptions": []}, "mv_player_leverage": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_player_leverage_p", "definition": "CREATE INDEX mv_player_leverage_p ON public.mv_player_leverage USING btree (player_id)"}], "reloptions": []}, "mv_team_buildphase": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_buildphase_team_idx", "definition": "CREATE UNIQUE INDEX mv_team_buildphase_team_idx ON public.mv_team_buildphase USING btree (team)"}], "reloptions": []}, "mv_team_stat_ranks": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_stat_ranks_tm", "definition": "CREATE INDEX mv_team_stat_ranks_tm ON public.mv_team_stat_ranks USING btree (team, metric)"}], "reloptions": []}, "mv_player_team_poss": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_player_team_poss_player_id_idx", "definition": "CREATE UNIQUE INDEX mv_player_team_poss_player_id_idx ON public.mv_player_team_poss USING btree (player_id)"}], "reloptions": []}, "mv_team_attackphase": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_attackphase_team_idx", "definition": "CREATE UNIQUE INDEX mv_team_attackphase_team_idx ON public.mv_team_attackphase USING btree (team)"}], "reloptions": []}, "mv_team_carry_zones": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_carry_zones_team_idx", "definition": "CREATE INDEX mv_team_carry_zones_team_idx ON public.mv_team_carry_zones USING btree (team)"}], "reloptions": []}, "mv_team_percentiles": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_percentiles_tm", "definition": "CREATE INDEX mv_team_percentiles_tm ON public.mv_team_percentiles USING btree (team, metric)"}], "reloptions": []}, "mv_player_percentiles": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_player_percentiles_metric", "definition": "CREATE INDEX mv_player_percentiles_metric ON public.mv_player_percentiles USING btree (metric)"}, {"name": "mv_player_percentiles_pm", "definition": "CREATE INDEX mv_player_percentiles_pm ON public.mv_player_percentiles USING btree (player_id, metric)"}], "reloptions": []}, "v_league_availability": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "v", "owner": "postgres", "comment": null, "indexes": [], "reloptions": []}, "mv_league_availability": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_league_availability_pk", "definition": "CREATE UNIQUE INDEX mv_league_availability_pk ON public.mv_league_availability USING btree (league)"}], "reloptions": []}, "mv_player_state_output": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_player_state_output_pk", "definition": "CREATE UNIQUE INDEX mv_player_state_output_pk ON public.mv_player_state_output USING btree (player_id)"}], "reloptions": []}, "mv_team_directness_state": {"acl": [{"grantee": "anon", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "authenticated", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "postgres", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "DELETE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "INSERT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "MAINTAIN"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "REFERENCES"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "SELECT"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRIGGER"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "TRUNCATE"}, {"grantee": "service_role", "grantor": "postgres", "grantable": false, "privilege": "UPDATE"}], "kind": "m", "owner": "postgres", "comment": null, "indexes": [{"name": "mv_team_directness_state_pk", "definition": "CREATE UNIQUE INDEX mv_team_directness_state_pk ON public.mv_team_directness_state USING btree (team)"}], "reloptions": []}}'::jsonb; actual jsonb; problem text;
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
declare baseline_results jsonb:=E'[{"name": "events_have_matches", "note": null, "severity": "error", "violations": 0, "description": "Every game with events has a matching row in matches."}, {"name": "goals_reconcile", "note": null, "severity": "error", "violations": 1, "description": "Goals parsed from the event feed must equal the published scoreline for every match. This is the strongest single check in the system: it validates event parsing, own-goal attribution and team-name reconciliation simultaneously, against a number we did not generate."}, {"name": "insight_denominator_declared", "note": null, "severity": "error", "violations": 0, "description": "Every detector currently producing insights has a published denominator requirement, so no detector runs without a stated sample basis."}, {"name": "insight_meets_sample", "note": null, "severity": "error", "violations": 0, "description": "No team-scoped insight exists for a club below the published minimum match count. Thresholds live in detector_requirements."}, {"name": "insight_no_all_zero_tie", "note": null, "severity": "error", "violations": 0, "description": "No rank-based detector fires when every team in that league scored zero on the ranked metric. A rank of first among identical zeros is not a finding."}, {"name": "insight_no_zero_claim", "note": null, "severity": "error", "violations": 0, "description": "No insight asserts a behaviour while its own supporting metric is zero. This is the defect that produced six clubs described as breaking at speed from deep on a 0.00% counter-attack rate."}, {"name": "league_mart_reads_scoped_sources", "note": null, "severity": "warn", "violations": 16, "description": "Audited league-mart entry objects must read the canonical scoped sources (v_league_events, v_league_matches, v_league_sequences, v_league_lineups) rather than the raw events, matches, sequences or lineups tables. Structural rather than value based: it catches a new object that pools competitions before any wrong number is published."}, {"name": "league_registered", "note": null, "severity": "error", "violations": 0, "description": "Every league present in events is registered in the leagues table."}, {"name": "leagues_without_whitelist", "note": null, "severity": "warn", "violations": 1, "description": "Active leagues with no team whitelist yet, so the contamination guard fails open."}, {"name": "no_foreign_teams", "note": null, "severity": "error", "violations": 0, "description": "No team appears in a league whose whitelist does not contain it. Only checked once a league''s whitelist is complete, since a league still bootstrapping will legitimately meet new clubs each week."}, {"name": "no_non_league_fixture_in_metrics", "note": null, "severity": "warn", "violations": 42, "description": "No domestic_cup or continental fixture may contribute to team metric grains. Counts contributing matches in mv_team_match whose competition is not a league."}, {"name": "no_non_league_row_in_league_outputs", "note": null, "severity": "warn", "violations": 1122, "description": "No league-scoped output object may carry a row labelled with a domestic_cup or continental competition."}, {"name": "no_null_league", "note": null, "severity": "error", "violations": 0, "description": "No ingest row is missing a league."}, {"name": "no_null_xt", "note": null, "severity": "error", "violations": 0, "description": "No sequence has a null threat value."}, {"name": "pcr_league_matches_player", "note": null, "severity": "error", "violations": 0, "description": "Every player chain-role row carries the league the player actually played in."}, {"name": "percentiles_in_range", "note": null, "severity": "error", "violations": 0, "description": "Every percentile falls between 0 and 100."}, {"name": "played_without_events", "note": null, "severity": "warn", "violations": 3, "description": "Played matches that have no event data (WhoScored sometimes publishes none)."}, {"name": "possession_sums", "note": null, "severity": "error", "violations": 0, "description": "Each match must have both sides'' possession shares summing to 100. A drift here means the touch attribution is wrong."}, {"name": "search_matches_roles", "note": null, "severity": "error", "violations": 0, "description": "The search index contains every profiled player and no others."}, {"name": "seq_covers_events", "note": null, "severity": "error", "violations": 0, "description": "The sequence layer covers exactly the games that have events."}, {"name": "seq_league_matches_events", "note": null, "severity": "error", "violations": 0, "description": "Every sequence carries the same league as the events it was built from."}, {"name": "shots_in_xg_model", "note": null, "severity": "warn", "violations": 36, "description": "Shots present in the event feed but missing from the shot model, usually because they carry no coordinates."}, {"name": "team_league_resolves", "note": null, "severity": "warn", "violations": 0, "description": "Every club appearing in a registered league competition must resolve in mv_team_league, and no club may resolve to a league it never played in. Guards the silent MLS fallback class of defect."}, {"name": "team_names_one_to_one", "note": null, "severity": "error", "violations": 0, "description": "Each club maps to exactly one schedule name, and no two clubs share one. A duplicate match_name means an away side was paired with its opponent, which shows up as \\"Elche 1-1 Elche\\" in fixture lists."}, {"name": "team_names_resolve", "note": null, "severity": "error", "violations": 0, "description": "Every schedule name in team_names actually appears in the fixture list for that league."}, {"name": "unused_subs_carry_minutes", "note": null, "severity": "warn", "violations": 603, "description": "Players with no events are credited minutes in mv_player_season. Every lineup row is treated as 90 minutes regardless of whether the player was used, so unused substitutes accrue appearances and minutes they did not play. Any metric derived from mv_player_season.minutes for these players is wrong. Tracked as a known defect pending a fix to the minutes derivation."}, {"name": "xg_bins_sparse", "note": null, "severity": "warn", "violations": 18, "description": "Shot-model lookup bins holding fewer than 20 shots. Rates in these bins are noise rather than signal, so any xG assigned from them is weakly supported. Reported as a count, not a pass or fail, because no defensible sparse-bin ceiling has been established. Currently 18 of 44 bins, covering under 1 percent of shots."}, {"name": "xg_calibration", "note": null, "severity": "error", "violations": 0, "description": "Across the season, total non-penalty xG should land within 10 percent of goals actually scored. Wider than that means the shot model has drifted away from reality."}]'::jsonb; actual_results jsonb;
 baseline_registry jsonb:='{"note": "match goals, shootout rule", "object_name": "mv_game_goals"}'::jsonb; actual_registry jsonb;
 baseline_severities jsonb:='{"team_league_resolves": "warn", "league_mart_reads_scoped_sources": "warn", "no_non_league_fixture_in_metrics": "warn", "no_non_league_row_in_league_outputs": "warn"}'::jsonb; actual_severities jsonb;
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
