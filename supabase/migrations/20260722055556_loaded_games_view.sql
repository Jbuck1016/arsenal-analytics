-- Cheap lookup of which games already have events, for idempotent/resumable backfill.
create or replace view v_loaded_games as
select distinct game_id from public.events;

grant select on v_loaded_games to anon, authenticated;
