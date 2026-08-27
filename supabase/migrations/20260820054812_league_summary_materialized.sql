
-- v_league_summary ran five correlated subqueries per league, including a
-- count(distinct game_id) over 438k events. Fine under the service role's long
-- statement timeout, but the anon role has a short one, so the page got a 500.
-- Precomputed instead: these counts only change on rebuild anyway.
drop view if exists public.v_league_summary cascade;

create materialized view public.mv_league_summary as
with ev as (
  select league, count(distinct game_id) matches, count(distinct team) teams
  from public.events group by league
),
seq as (select league, count(*) sequences from public.sequences group by league),
pl  as (select league, count(*) players_profiled from public.player_search group by league),
ins as (
  select tl.league, count(*) insights
  from public.insights i join public.mv_team_league tl on tl.team = i.team
  group by tl.league
)
select l.league, l.display_name, l.country, l.season,
  coalesce(ev.matches,0)          as matches,
  coalesce(ev.teams,0)            as teams,
  coalesce(pl.players_profiled,0) as players_profiled,
  coalesce(seq.sequences,0)       as sequences,
  coalesce(ins.insights,0)        as insights
from public.leagues l
left join ev  on ev.league  = l.league
left join seq on seq.league = l.league
left join pl  on pl.league  = l.league
left join ins on ins.league = l.league
where l.is_active;
create unique index mv_league_summary_pk on public.mv_league_summary (league);
grant select on public.mv_league_summary to anon, authenticated;

-- keep the old name working so nothing that already reads it breaks
create or replace view public.v_league_summary as
  select * from public.mv_league_summary;
grant select on public.v_league_summary to anon, authenticated;
