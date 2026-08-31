-- Keep competitions out of the active browser registry until ingestion and
-- team-name coverage exist. This is deliberately narrow: if Bundesliga data
-- has arrived, the migration aborts instead of hiding it.
do $$
begin
  if exists (
    select 1 from public.matches m
    join public.leagues l on l.league = m.league and l.season = m.season
    where l.league = 'GER-Bundesliga'
  ) or exists (
    select 1 from public.v_league_events e
    where e.league = 'GER-Bundesliga'
  ) or exists (
    select 1 from public.team_names t
    where t.league = 'GER-Bundesliga'
  ) then
    raise exception 'Bundesliga now has ingested data or a whitelist; activate it through the ingestion rollout instead';
  end if;

  update public.leagues
  set is_active = false
  where league = 'GER-Bundesliga'
    and season = '2627';

  if not found then
    raise exception 'Expected GER-Bundesliga 2627 registry row was not found';
  end if;
end
$$;

select public.refresh_site_summaries();

do $$
begin
  if exists (
    select 1 from public.leagues
    where league = 'GER-Bundesliga' and season = '2627' and is_active
  ) then
    raise exception 'Bundesliga remained active';
  end if;
  if exists (
    select 1 from public.run_invariants()
    where name = 'leagues_without_whitelist' and violations <> 0
  ) then
    raise exception 'Whitelist invariant did not remain clean';
  end if;
end
$$;
