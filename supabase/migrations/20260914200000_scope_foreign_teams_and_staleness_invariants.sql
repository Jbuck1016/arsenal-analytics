-- Close the whitelist guard, and make analytics staleness visible.
--
-- Context: the site served 1 September data for thirteen days. Nothing errored.
-- Match Analysis was right because it reads a live view; every matview-backed
-- page was a snapshot. No invariant could see it, because no invariant compared
-- a matview against its live equivalent.

-- 1. no_foreign_teams (section 11a)
--
-- The old check had two defects. It read raw events with no scope filter, so
-- clubs from archived seasons registered as violations: all six failures on the
-- 14 September run were Bundesliga archive sides (Bochum, Darmstadt, FC
-- Heidenheim, Holstein Kiel, St. Pauli, Wolfsburg), none of which appear in a
-- live fixture or a live event. And it skipped any league whose team_names count
-- was below leagues.expected_teams, which switched the guard off in four of six
-- leagues (Premier League 13/20, Serie A 8/20, Ligue 1 13/18, La Liga 18/20),
-- precisely when the mapping was least trustworthy.
--
-- The replacement scopes to live events and drops the threshold skip. A team
-- fails only if it is in neither team_names for that league nor the home or away
-- side of a live-scope fixture in it. matches.home_team and away_team are an
-- independent record of who plays in the competition, so the guard is closed in
-- all six leagues now rather than after team_names is completed.
--
-- Verified on live: 126 live teams, 26 of them absent from team_names, all 26
-- covered by the fixture arm, 0 violations.

update public.invariants set
 check_sql = $q$with live_team as (
  select distinct e.league, e.team from public.v_league_events e where e.team is not null
)
select count(*) from live_team lt
 where not exists (select 1 from public.team_names t
                    where t.league = lt.league and t.event_name = lt.team)
   and not exists (select 1 from public.matches m
                    where m.is_live_scope and m.league = lt.league
                      and (m.home_team = lt.team or m.away_team = lt.team))$q$,
 description = 'A team appearing in live-scope events must be recognised by the competition: either mapped in team_names for that league, or named as the home or away side of a live-scope fixture in it. Scoped to live events, so archive clubs from previous seasons no longer register. The previous version read raw events unscoped and skipped any league whose team_names count was below leagues.expected_teams, which switched the guard off in four of six leagues precisely when the mapping was least complete. matches.home_team and away_team are an independent record of who plays in the competition, so the fixture arm closes the guard without team_names being complete.'
where name = 'no_foreign_teams';

-- 2. Staleness (section 4)
--
-- Full outer on purpose. The obvious formulation,
--   join mv_team_all on team where matches <> matches
-- is an inner join, so a team with no matview row at all scores zero violations.
-- That is not hypothetical: on 14 September all 18 Bundesliga teams and 2 Ligue 1
-- teams were absent from mv_team_all entirely, and the inner join reported 106
-- while the true figure was 126. A whole league can disappear from the site and
-- an inner-join check will call it clean.

insert into public.invariants (name, description, check_sql, severity, enabled) values
('team_matview_matches_live',
 'Every team in the live sample must appear in mv_team_all with the same match count, and mv_team_all must carry no team the live sample does not. Full outer on purpose: an inner join scores a team missing from the matview entirely as zero violations, which is how a whole league can vanish from the site without the check noticing. This is the check that would have caught the analytics layer serving a 1 September snapshot for thirteen days.',
 $q$select count(*) from (
   select 1 from public.v_team_sample ts
   full outer join public.mv_team_all ta on ta.team = ts.team
   where ts.team is null or ta.team is null or ta.matches <> ts.matches) z$q$,
 'error', true),
('analytics_rebuild_recent',
 'Hours since the newest analytics_rebuild_runs row with status complete, flagging over 48. Warn rather than error on purpose: a stale rebuild must be audible without blocking the publish of a fix that would clear it.',
 $q$select case
        when (select max(finished_at) from public.analytics_rebuild_runs where status='complete') is null then 1
        else ((extract(epoch from now() - (select max(finished_at)
              from public.analytics_rebuild_runs where status='complete'))/3600) > 48)::int
      end$q$,
 'warn', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;
