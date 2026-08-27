
-- The La Liga whitelist was built by joining each event team to the match's HOME team,
-- so every away side was mapped to its opponent's name. Rebuild by pairing each event
-- team against the home/away pair for that fixture, choosing whichever it resembles more.
create or replace function public.rebuild_team_names(p_league text)
returns text language plpgsql security definer set search_path = public as $fn$
declare n int;
begin
  delete from public.team_names where league = p_league;

  insert into public.team_names (event_name, match_name, display_name, league)
  with g as (
    select e.game_id, m.home_team, m.away_team, array_agg(distinct e.team) as ets
    from public.events e
    join public.matches m on m.game_id = e.game_id
    where e.league = p_league and e.team is not null
    group by e.game_id, m.home_team, m.away_team
  ),
  paired as (
    select t as event_name,
      case when similarity(unaccent(lower(t)), unaccent(lower(g.home_team)))
              >= similarity(unaccent(lower(t)), unaccent(lower(g.away_team)))
           then g.home_team else g.away_team end as match_name
    from g, unnest(g.ets) t
  ),
  -- a club can appear in several fixtures, so take the name it matched most often
  ranked as (
    select event_name, match_name, count(*) n,
      row_number() over (partition by event_name order by count(*) desc, match_name) rk
    from paired group by event_name, match_name
  )
  select event_name, match_name, match_name, p_league
  from ranked where rk = 1;

  get diagnostics n = row_count;
  return format('%s: %s clubs mapped', p_league, n);
end $fn$;
revoke execute on function public.rebuild_team_names(text) from public, anon, authenticated;
grant execute on function public.rebuild_team_names(text) to service_role;

select public.rebuild_team_names('ESP-La Liga');
