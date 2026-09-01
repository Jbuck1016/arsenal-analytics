begin;

create or replace function public.historical_loaded_game_ids(
  p_league text,
  p_season text
) returns table(game_id text)
language sql
stable
security invoker
set search_path = public, pg_temp
as $fn$
  select m.game_id::text
  from public.matches m
  where m.league = p_league
    and m.season = p_season
    and exists (
      select 1
      from public.events e
      where e.game_id = m.game_id
    )
$fn$;

revoke all on function public.historical_loaded_game_ids(text,text)
  from public, anon, authenticated;
grant execute on function public.historical_loaded_game_ids(text,text)
  to service_role;

comment on function public.historical_loaded_game_ids(text,text) is
  'Service-only resume set for raw historical ingestion. Deliberately bypasses the current-season v_loaded_games boundary without exposing archived events.';

do $assert$
begin
  if has_function_privilege(
       'anon',
       'public.historical_loaded_game_ids(text,text)',
       'execute'
     ) or has_function_privilege(
       'authenticated',
       'public.historical_loaded_game_ids(text,text)',
       'execute'
     ) then
    raise exception 'browser role can execute historical_loaded_game_ids';
  end if;
  if not has_function_privilege(
       'service_role',
       'public.historical_loaded_game_ids(text,text)',
       'execute'
     ) then
    raise exception 'service_role cannot execute historical_loaded_game_ids';
  end if;
end
$assert$;

commit;
