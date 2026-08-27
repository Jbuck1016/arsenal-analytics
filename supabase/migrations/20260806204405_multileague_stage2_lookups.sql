
-- Lookups so a percentile view needs only a join + `partition by league`, rather than
-- the league column being threaded through the entire metric chain.
drop materialized view if exists public.mv_team_league cascade;
create materialized view public.mv_team_league as
select team, min(league) as league, count(*) as events
from public.events where team is not null group by team;
create unique index mv_team_league_pk on public.mv_team_league (team);
grant select on public.mv_team_league to anon, authenticated;

-- A player belongs to the league he has played most of his minutes in. Handles a
-- mid-season move between leagues, where WhoScored keeps the same player_id.
drop materialized view if exists public.mv_player_league cascade;
create materialized view public.mv_player_league as
select player_id, league, ev from (
  select player_id, league, count(*) ev,
    row_number() over (partition by player_id order by count(*) desc) rk
  from public.events where player_id is not null group by player_id, league
) z where rk = 1;
create unique index mv_player_league_pk on public.mv_player_league (player_id);
grant select on public.mv_player_league to anon, authenticated;
