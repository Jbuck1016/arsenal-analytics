-- Permit an operator to claim an explicitly approved fixture set without
-- draining unrelated queue entries. Attempts still increment before work starts,
-- preserving the same crash and exhaustion semantics as claim_rescrape_batch.
create or replace function public.claim_rescrape_games(p_game_ids text[])
returns table(game_id text, league text, attempts int)
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
begin
  if p_game_ids is null or cardinality(p_game_ids) = 0 then
    return;
  end if;

  return query
  update public.rescrape_queue q
     set status = 'in_progress',
         attempts = q.attempts + 1,
         last_attempt_at = now()
   where q.game_id in (
     select g.game_id
       from public.rescrape_queue g
       join (select distinct unnest(p_game_ids) as game_id) requested
         on requested.game_id = g.game_id
      where g.status in ('queued', 'in_progress')
        and g.attempts < 3
      for update of g skip locked
   )
  returning q.game_id, q.league, q.attempts;
end
$fn$;

revoke execute on function public.claim_rescrape_games(text[])
  from public, anon, authenticated;
grant execute on function public.claim_rescrape_games(text[])
  to service_role;
