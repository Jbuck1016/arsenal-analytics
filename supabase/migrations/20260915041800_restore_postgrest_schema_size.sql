-- Restore the pre-feature PostgREST schema surface after its cache rebuild
-- exceeded the project's current authenticator timeout. The table is empty;
-- no transfer-history data is discarded.

drop table if exists public.player_transfer_events;

notify pgrst, 'reload schema';
