-- Keep the new history API small: browser reads use the RLS-protected base
-- tables and the already-existing latest-value view. Two convenience views
-- are unnecessary additions to an already large PostgREST schema cache.

drop view if exists public.v_player_transfer_history;
drop view if exists public.v_player_market_value_history;

notify pgrst, 'reload schema';
