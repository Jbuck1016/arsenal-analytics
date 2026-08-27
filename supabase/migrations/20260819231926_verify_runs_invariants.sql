
-- verify now runs the whole invariant battery instead of a handful of hardcoded checks.
-- Any error-severity violation aborts the rebuild loudly and names the check that failed.
create or replace function public.verify_rebuild()
returns text language plpgsql security definer set search_path = public as $fn$
declare bad text; warns text; n_seq int; seq_games int; n_pcr int; n_srch int;
begin
  select string_agg(format('%s (%s violations)', name, violations), '; ' order by name)
    into bad
  from public.run_invariants()
  where severity = 'error' and violations <> 0;

  if bad is not null then
    raise exception 'rebuild verification FAILED -- %', bad;
  end if;

  select string_agg(format('%s: %s', name, violations), '; ' order by name)
    into warns
  from public.run_invariants()
  where severity = 'warn' and violations > 0;

  select count(*), count(distinct game_id) into n_seq, seq_games from public.sequences;
  select count(*) into n_pcr from public.player_chain_roles;
  select count(*) into n_srch from public.player_search;

  return format('verified -- %s sequences over %s games, %s outfield players, %s in search index, %s league(s)%s',
    n_seq, seq_games, n_pcr, n_srch,
    (select count(*) from public.leagues where is_active),
    case when warns is null then '' else ' | notes: ' || warns end);
end $fn$;
revoke execute on function public.verify_rebuild() from public, anon;
grant execute on function public.verify_rebuild() to service_role, authenticated;
