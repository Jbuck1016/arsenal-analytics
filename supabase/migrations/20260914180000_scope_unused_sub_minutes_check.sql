-- Scope the unused-substitute minutes check to the match.
--
-- The original check, seeded in 20260824174855_correct_player_populations.sql,
-- asked whether a player had events ANYWHERE in the events table:
--
--     not exists (select 1 from public.events e where e.player_id = s.player_id)
--
-- That is true for almost every player in the table, so the check read 0 for its
-- whole life and could never fire, including while the defect it was written to
-- guard was live across 1,846 rows and 966 players. Correlating on game_id as
-- well as player_id is what makes it a real check.
--
-- It also now reads mv_player_minutes rather than mv_player_season, so a
-- violation names the match it came from instead of only the player.
--
-- The underlying defect is fixed: mv_player_minutes derives participation from
-- the listed position rather than lineups.is_starter, which is true on 110,903
-- of 114,595 Sub rows and so admitted unused substitutes and credited them a
-- full match. Substitute rows carrying minutes are now 0. Residual violations
-- are named starters whose match has no event data at all, which is an
-- ingestion gap rather than a minutes-derivation fault, so this stays warn.

insert into public.invariants (name, description, check_sql, severity) values
('unused_subs_carry_minutes',
 'Minutes credited for a match in which the player has no events at all. Scoped to the match: the previous version asked whether the player had events anywhere in the table, which is true for almost everyone, so it could never fire. mv_player_minutes now derives participation from the listed position rather than lineups.is_starter, so unused substitutes no longer accrue minutes. Any residual rows are named starters whose match has no event data, which is an ingestion gap rather than a minutes-derivation fault.',
 $q$select count(*) from public.mv_player_minutes pm
   where pm.minutes > 0
     and not exists (select 1 from public.events e
                     where e.game_id = pm.game_id and e.player_id = pm.player_id)$q$,
 'warn')
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity;
