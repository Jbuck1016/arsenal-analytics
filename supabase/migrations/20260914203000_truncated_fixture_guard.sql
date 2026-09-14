-- Keep truncated event feeds out of the metrics layer.
--
-- Found while diagnosing a gate failure. Game 1952894 (FC Cincinnati 2-1 New
-- York City FC, 19 August, MLS) carried 31 event rows with max expanded_minute
-- of 1: a scrape that stopped after a minute. The fixture feed had the correct
-- 2-1, so goals_reconcile failed, and that was the visible symptom.
--
-- The quiet damage was in the metrics layer. mv_player_minutes computes
--   round(raw_minutes * 90.0 / nullif(length_min, 0), 2)
-- and mv_match_length reported length_min = 1 for that game. Every one of the 22
-- players in it was credited exactly 90.00 minutes, a full nineties of exposure,
-- against a numerator that stopped when the scrape did.
--
-- Worth being precise about the direction, because it is the opposite of what it
-- looks like. raw_minutes is itself bounded by length_min, since it is
-- coalesce(off_min, length_min) minus the entry minute, so raw/length can never
-- exceed 1 and the scaled figure can never exceed 90. Nobody's minutes inflate.
-- What happens is that exposure is credited in full while output is truncated, so
-- every per-90 for those players is DILUTED, and the percentile pools they sit in
-- are depressed with them. Understated, not overstated, and silent either way.
--
-- The 31 stub rows were moved to events_quarantine and deleted from events, which
-- dropped the game from mv_match_length and mv_player_minutes entirely and took
-- goals_reconcile from 1 violation to 0. Re-scraping the fixture restores it.
--
-- Floor choice. The three truncated fixtures measured 1, 49 and 50 minutes. The
-- shortest complete fixture measured 93. Any floor between 51 and 92 separates
-- them identically, so 60 is safe rather than finely tuned.
--
-- The date restriction is load bearing. The two 49 and 50 minute fixtures were
-- Serie A matches being played and scraped on the day this ran. Without
-- m.date < current_date this check would fire every time a match is scraped live
-- and would block publication for the duration of every matchday.

insert into public.invariants (name, description, check_sql, severity, enabled) values
('truncated_fixture_in_metrics',
 'A settled fixture whose event feed covers under 60 minutes must not feed the metrics layer. mv_player_minutes scales each spell by 90.0/length_min, so a truncated feed credits players a full 90 of exposure against a numerator that stops when the scrape stopped, silently diluting every per-90 and the percentile pools those players sit in. The 60 floor is empirical: the three truncated fixtures found on 14 September measured 1, 49 and 50 minutes and the shortest complete fixture measured 93, so any floor between 51 and 92 separates them identically. Restricted to fixtures before today, because a match scraped while it is being played legitimately reads short.',
 $q$select count(*) from public.mv_match_length ml
     join public.v_league_matches m on m.game_id = ml.game_id
    where ml.length_min < 60
      and m.date < current_date
      and exists (select 1 from public.mv_player_minutes pm where pm.game_id = ml.game_id)$q$,
 'error', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;

-- Quarantine table for event rows pulled out of the live feed, so a deletion of
-- this kind stays reversible without a re-scrape.
create table if not exists public.events_quarantine (like public.events including defaults);
