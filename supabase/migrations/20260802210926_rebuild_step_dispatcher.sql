
-- per-step rebuild dispatcher: short calls, timeout-proof over the REST path
create or replace function public.rebuild_step(p_step text)
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare wl_ct int; bad_teams text; seq_games int; evt_games int; null_xt int; n_seq int; n_pcr int;
begin
  case p_step
    when 'preflight' then
      select count(*) into wl_ct from public.team_names;
      if wl_ct > 0 then
        select string_agg(distinct team, ', ') into bad_teams from public.events
          where team is not null and team not in (select event_name from public.team_names);
        if bad_teams is not null then
          raise exception 'rebuild aborted -- events contain team(s) not in team_names whitelist: %', bad_teams;
        end if;
      end if;
      return 'preflight ok';
    when 'metrics'   then perform public.refresh_analytics();       return 'metrics refreshed';
    when 'sequences' then perform public.build_sequences();          return 'sequences built';
    when 'players'   then perform public.build_player_chain_roles(); return 'players built';
    when 'seqfz'     then refresh materialized view public.seq_fz;   return 'seq_fz refreshed';
    when 'verify' then
      select count(*) into null_xt from public.sequences where xt_sum is null;
      if null_xt > 0 then raise exception 'verify failed -- % sequences with null xt_sum', null_xt; end if;
      select count(distinct game_id) into seq_games from public.sequences;
      select count(distinct game_id) into evt_games from public.events;
      if seq_games <> evt_games then raise exception 'verify failed -- game-count sequences % vs events %', seq_games, evt_games; end if;
      select count(*) into n_seq from public.sequences;
      select count(*) into n_pcr from public.player_chain_roles;
      return format('verified -- %s sequences over %s games, %s outfield players', n_seq, seq_games, n_pcr);
    else raise exception 'unknown rebuild step: %', p_step;
  end case;
end $fn$;
revoke execute on function public.rebuild_step(text) from public, anon, authenticated;
grant execute on function public.rebuild_step(text) to service_role;

-- manual one-shot for direct psql use (no gateway); scraper uses per-step calls instead
create or replace function public.rebuild_all()
returns text language plpgsql security definer set search_path = public set statement_timeout = 0
as $fn$
begin
  perform public.rebuild_step('preflight');
  perform public.rebuild_step('metrics');
  perform public.rebuild_step('sequences');
  perform public.rebuild_step('players');
  perform public.rebuild_step('seqfz');
  return public.rebuild_step('verify');
end $fn$;
revoke execute on function public.rebuild_all() from public, anon, authenticated;
grant execute on function public.rebuild_all() to service_role;
