
-- mv_team_all has no league column and sits under the deepest dependency chain in the
-- database, so rather than drop and recreate it, expose the league alongside it.
-- The frontend joins on team to filter its club list and to label things correctly.
create or replace view public.v_team_directory as
select
  t.team,
  coalesce(tl.league, 'USA-MLS') as league,
  coalesce(l.display_name, 'Major League Soccer') as league_name,
  l.country,
  count(*) over (partition by coalesce(tl.league, 'USA-MLS')) as teams_in_league,
  (select count(*) from public.matches m
    where m.league = coalesce(tl.league,'USA-MLS')
      and m.home_score is not null
      and (m.home_team = t.team or m.away_team = t.team)) as matches_played
from public.mv_team_all t
left join public.mv_team_league tl on tl.team = t.team
left join public.leagues l on l.league = tl.league;
grant select on public.v_team_directory to anon, authenticated;

-- Per-league headline counts, so the landing page can say "MLS 2026" or "La Liga 2026"
-- honestly instead of labelling everything MLS.
create or replace view public.v_league_summary as
select
  l.league,
  l.display_name,
  l.country,
  l.season,
  (select count(distinct e.game_id) from public.events e where e.league = l.league) as matches,
  (select count(distinct t.team) from public.mv_team_league t where t.league = l.league) as teams,
  (select count(*) from public.player_search p where p.league = l.league) as players_profiled,
  (select count(*) from public.sequences s where s.league = l.league) as sequences,
  (select count(*) from public.insights i
     where i.team in (select team from public.mv_team_league where league = l.league)) as insights
from public.leagues l
where l.is_active;
grant select on public.v_league_summary to anon, authenticated;
