begin;

-- The mart resolves only current-season league events. Comparing it to the
-- raw multi-season archive makes a correct refresh look broken when an
-- archived-only club drops out of the current season.
update public.invariants
set description = 'Every current-season club resolves to a league it actually played in during the registered season.',
    check_sql = $sql$
      select
        (select count(*)
         from (select distinct e.team from public.v_league_events e where e.team is not null) t
         where not exists (
           select 1 from public.mv_team_league tl where tl.team = t.team
         ))
        +
        (select count(*)
         from public.mv_team_league tl
         where not exists (
           select 1 from public.v_league_events e
           where e.team = tl.team and e.league = tl.league
         ))
    $sql$
where name = 'team_league_resolves';

do $assert$
begin
  if not exists(select 1 from public.invariants where name='team_league_resolves'
                and check_sql like '%v_league_events%') then
    raise exception 'team_league_resolves invariant missing or not current-season scoped';
  end if;
  if (select count(*) from public.v_league_events where team is not null) = 0 then
    raise exception 'current-season event scope is empty';
  end if;
end
$assert$;

commit;
