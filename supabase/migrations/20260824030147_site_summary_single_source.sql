
-- One source for every count displayed anywhere. Pages previously hardcoded figures that
-- went stale within a week, and three different player populations were shown as if they
-- were the same number.
drop materialized view if exists public.mv_site_summary cascade;
create materialized view public.mv_site_summary as
select
  -- as of = the latest played match actually INCLUDED in the analysis, not page-load date
  (select max(m.date) from public.matches m
     where m.home_score is not null
       and exists (select 1 from public.events e where e.game_id = m.game_id)) as as_of_match_date,
  (select count(distinct game_id) from public.events)                as matches_analysed,
  (select count(*) from public.events)                               as events,
  (select count(*) from public.sequences)                            as sequences,
  (select count(*) from public.leagues where is_active)              as leagues_active,
  (select count(distinct league) from public.events)                 as leagues_with_data,
  (select count(distinct team) from public.events)                   as clubs,
  -- three distinct player populations, never to be shown as one number again
  (select count(distinct player_id) from public.events where player_id is not null)
                                                                     as players_event_participants,
  (select count(*) from public.mv_player_season)                     as players_season_record,
  (select count(*) from public.player_search)                        as players_profiled_outfield,
  (select count(*) from public.insights)                             as insights,
  (select count(distinct team) from public.insights)                 as clubs_with_insights,
  (select count(*) from public.metric_defs)                          as metrics_player,
  (select count(*) from public.team_metric_defs)                     as metrics_team,
  (select count(*) from public.mv_shot_xg where is_pen = false)       as shots_non_pen,
  (select round(sum(xg),1) from public.mv_shot_xg where is_pen = false) as xg_predicted,
  (select count(*) from public.mv_shot_xg where is_pen = false and is_goal) as goals_actual,
  (select count(*) from public.invariants where enabled and severity='error') as checks_error,
  now() as refreshed_at;
grant select on public.mv_site_summary to anon, authenticated;

-- per-league availability, so a page can say WHY a league shows nothing
drop view if exists public.v_league_availability cascade;
create view public.v_league_availability as
select l.league, l.display_name,
  coalesce(ev.matches,0) as matches,
  coalesce(ts.qualifying,0) as clubs_at_threshold,
  coalesce(ts.total,0) as clubs,
  coalesce(ins.n,0) as insights,
  (select min_matches from public.detector_requirements where detector='team_profile') as min_matches_required,
  case when coalesce(ts.qualifying,0) > 0 then 'available'
       when coalesce(ev.matches,0) = 0 then 'no data yet'
       else 'below sample threshold' end as insight_status
from public.leagues l
left join (select league, count(distinct game_id) matches from public.events group by league) ev
  on ev.league = l.league
left join (select league, count(*) filter (where meets_min_matches) qualifying, count(*) total
           from public.v_team_sample group by league) ts on ts.league = l.league
left join (select tl.league, count(*) n from public.insights i
           join public.mv_team_league tl on tl.team = i.team group by tl.league) ins
  on ins.league = l.league
where l.is_active;
grant select on public.v_league_availability to anon, authenticated;
