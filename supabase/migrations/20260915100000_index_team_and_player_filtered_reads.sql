-- The Maps page returned "Error: v_team_carries 500". A team-filtered read took
-- 5.83 s for 938 rows, past PostgREST's timeout, and 12.8 s when re-measured on
-- 15 September.
--
-- v_team_carries is a plain filter over mv_receipt_events, and the plan showed
-- the team predicate already reaching the scan:
--   Parallel Seq Scan on mv_receipt_events
--     Filter: (is_carry AND (team = 'Arsenal'))  Rows Removed by Filter: 276115
--     Buffers: shared read=9178
-- Pushdown was fine. There was no index for it to use, so every request read
-- all 72 MB of the matview from disk.
--
-- Every object the site filters by team or player was checked, against the
-- exact reads in dashboard/*.html (sbAll(name, {team: ...}) and
-- sbAll(name, {player_id: ...})):
--
--   v_team_actions (team)            events, idx_events_team_type      325 ms
--   v_player_actions (player_id)     events, idx_events_player_id      114 ms
--   v_player_carries (player_id)     mv_receipt_events player_id idx
--   v_player_receipts (player_id)    mv_receipt_events player_id idx
--   mv_team_stat_ranks (team)        indexed
--   mv_player_percentiles            indexed on player_id and on metric
--   mv_player_pillars, mv_player_dna indexed on player_id
--   team_sequence_agg (team)         sequences_team_op_idx            1.08 s
--   player_chain_pct (player_id)     window over 859 players, 236 ms
--   v_team_carries (team)            NO INDEX                          12.8 s
--   mv_team_match (team)             NO INDEX, 1,122 rows
--   mv_player_season (team)          NO INDEX, 2,822 rows
--   team_sequence_style (team)       window over every team, 28.96 s;
--                                    fixed by materialization, separately
--
-- The two small matviews are cheap to scan when warm, but on a throttled disk
-- an unindexed read is a cold sequential read per request. REFRESH
-- CONCURRENTLY preserves indexes, so all three survive every rebuild.
--
-- Verified after building: the same Arsenal read of v_team_carries now uses
-- idx_mv_receipt_events_team_carry and takes 374 ms, from 12.8 s.

-- Partial on is_carry because v_team_carries only ever returns carries.
create index if not exists idx_mv_receipt_events_team_carry
  on public.mv_receipt_events (team) where is_carry;

create index if not exists idx_mv_team_match_team   on public.mv_team_match (team);
create index if not exists idx_mv_player_season_team on public.mv_player_season (team);
