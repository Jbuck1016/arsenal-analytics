-- Two invariants written for a world where every event lived in events and the
-- stored live-scope flag was the only live-scope flag. Both would have failed
-- the rebuild gate on a correct database.
--
-- seq_league_matches_events flagged 453 sequence games. Broken down against
-- the live database before changing anything: 0 without a fixture row, 0 with a
-- league mismatch, 0 in neither events table, 0 in live scope. All 453 were
-- historical games whose events the archive split had moved to events_archive.
-- The check looked only in events. It now requires a game to be absent from
-- both, the rule sequences_without_events already used.
--
-- sequences_built_for_live_season flagged 5 fixtures. Three were the fixtures
-- in the re-scrape queue (1952894, Como v Parma, Torino v Roma). Those keep
-- matches.is_live_scope true on purpose and are excluded from every metric by
-- v_match_season_scope, but the check read the stored flag, so it would have
-- held the gate shut until each was re-scraped. It now reads the scoped flag,
-- the same one every live view uses. The other two, Leeds v Newcastle and
-- Villarreal v Real Betis on 14 September, were genuine: events landed, no
-- sequences yet, which the rebuild's sequences step builds.

update public.invariants set
  check_sql = $q$select count(*) from (select distinct game_id, league from public.sequences) sg
   left join public.matches m on m.game_id = sg.game_id
  where m.game_id is null
     or sg.league is distinct from m.league
     or (not exists (select 1 from public.events e where e.game_id = sg.game_id)
         and not exists (select 1 from public.events_archive a where a.game_id = sg.game_id))$q$,
  description = 'Every sequence must belong to a real fixture, carry that fixture league, and have events behind it in either events or events_archive. Since the archive split, historical events live in events_archive; checking only events flagged all 453 historical sequence games as orphaned, every one of them archive-only, which would have failed the rebuild gate on a correct database. Anti-join throughout: an inner join would skip sequences whose fixture has no events at all, which is how orphans survive a fixture being pulled. This is the check that caught 1,573 La Liga sequences written as MLS and 2,834 Premier League rows on 8 September.'
where name = 'seq_league_matches_events';

update public.invariants set
  check_sql = $q$select count(*) from public.v_match_season_scope s
   join public.leagues l on l.league = s.league and l.competition_type = 'league'
  where s.is_live_scope and s.home_score is not null
    and exists (select 1 from public.events e where e.game_id = s.game_id)
    and not exists (select 1 from public.sequences q where q.game_id = s.game_id)$q$,
  description = 'Every played fixture in live scope with events must have sequences built. Reads the scoped is_live_scope from v_match_season_scope, the same flag every live view uses, rather than the stored matches.is_live_scope. The stored flag deliberately stays true for fixtures in the re-scrape queue, which are excluded from every metric; reading it flagged the three queued fixtures and would have held the rebuild gate shut until they were re-scraped.'
where name = 'sequences_built_for_live_season';
