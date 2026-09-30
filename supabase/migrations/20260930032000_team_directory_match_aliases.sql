begin;

-- mv_team_all is keyed by event-side short names, while league fixtures use
-- match-side canonical names. Counting fixtures against t.team directly made
-- 28 active clubs look like they had played zero games.
create or replace view public.v_team_directory as
select
  t.team,
  tl.league,
  coalesce(l.display_name, 'Major League Soccer'::text) as league_name,
  l.country,
  count(*) over (partition by tl.league) as teams_in_league,
  (
    select count(*)
    from public.v_league_matches m
    where m.league = tl.league
      and m.home_score is not null
      and m.away_score is not null
      and (
        m.home_team = coalesce(names.match_name, t.team)
        or m.away_team = coalesce(names.match_name, t.team)
      )
  ) as matches_played
from public.mv_team_all t
join public.mv_team_league tl on tl.team = t.team
left join public.team_names names
  on names.league = tl.league and names.event_name = t.team
left join public.leagues l on l.league = tl.league;

commit;
