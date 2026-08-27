
-- build_sequences() and build_player_chain_roles() predate the league column and do not
-- populate it, so every row fell back to the 'USA-MLS' default. Left alone, La Liga
-- possessions would be standardised against MLS norms in seq_fz and the press profile.
-- Rather than rewrite two large functions, the league is stamped on immediately after
-- each build, derived from the events the rows were built from.
create or replace function public.stamp_sequence_leagues()
returns text language plpgsql security definer set search_path = public as $fn$
declare n_seq int; n_pcr int;
begin
  with gl as (select distinct game_id, league from public.events)
  update public.sequences s set league = gl.league
  from gl where gl.game_id = s.game_id and s.league is distinct from gl.league;
  get diagnostics n_seq = row_count;

  update public.player_chain_roles p set league = pl.league
  from public.mv_player_league pl
  where pl.player_id = p.player_id and p.league is distinct from pl.league;
  get diagnostics n_pcr = row_count;

  return format('league stamped on %s sequences, %s player rows', n_seq, n_pcr);
end $fn$;
revoke execute on function public.stamp_sequence_leagues() from public, anon, authenticated;
grant execute on function public.stamp_sequence_leagues() to service_role;
