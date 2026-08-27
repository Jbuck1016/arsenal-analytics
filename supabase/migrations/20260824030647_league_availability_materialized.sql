
-- 2.95s and a full scan of 520k events. The anon role has a short statement timeout, so a
-- view like this fails in the browser while looking healthy under the service role. Same
-- trap as v_league_summary. Precompute it; the numbers only change on rebuild.
drop view if exists public.v_league_availability cascade;

create materialized view public.mv_league_availability as
with ev as (select league, count(distinct game_id) matches from public.events group by league),
     ts as (select league, count(*) filter (where meets_min_matches) qualifying, count(*) total
            from public.v_team_sample group by league),
     ins as (select tl.league, count(*) n from public.insights i
             join public.mv_team_league tl on tl.team = i.team group by tl.league)
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
left join ev  on ev.league  = l.league
left join ts  on ts.league  = l.league
left join ins on ins.league = l.league
where l.is_active;
create unique index mv_league_availability_pk on public.mv_league_availability (league);
grant select on public.mv_league_availability to anon, authenticated;

-- keep the view name working for anything already pointed at it
create or replace view public.v_league_availability as
  select * from public.mv_league_availability;
grant select on public.v_league_availability to anon, authenticated;
