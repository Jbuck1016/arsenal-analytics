
create or replace function public.rebuild_step(p_step text)
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare wl_ct int; bad_teams text; seq_games int; evt_games int; null_xt int;
        n_seq int; n_pcr int; n_srch int; n_st int; n_ce int; n_tj int; n_sq int; n_pct int;
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
    when 'state' then
      refresh materialized view public.mv_game_goals;
      refresh materialized view public.mv_seq_state;
      refresh materialized view public.mv_state_segments;
      select count(*) into n_st from public.mv_seq_state;
      return format('game state built (%s possessions tagged)', n_st);
    when 'chains' then
      refresh materialized view public.mv_seq_events;
      refresh materialized view public.mv_player_chain_value;
      select count(*) into n_ce from public.mv_player_chain_value;
      return format('chain value built (%s players)', n_ce);
    when 'traj' then
      refresh materialized view public.mv_pass_traj;
      refresh materialized view public.mv_player_pass_traj;
      select count(*) into n_tj from public.mv_player_pass_traj;
      return format('pass trajectory built (%s players)', n_tj);
    when 'profiles' then
      refresh materialized view public.mv_player_foot;
      refresh materialized view public.mv_player_archetype;
      refresh materialized view public.mv_player_progression;
      return 'foot / archetype / progression refreshed';
    when 'usage' then
      refresh materialized view public.mv_player_minutes;
      refresh materialized view public.mv_player_leverage;
      refresh materialized view public.mv_squad_role;
      select count(*) into n_sq from public.mv_squad_role;
      return format('squad usage built (%s player-club rows)', n_sq);
    when 'teamstyle' then
      refresh materialized view public.mv_team_directness_state;
      refresh materialized view public.mv_press_vs_buildup;
      refresh materialized view public.mv_team_breakdown;
      return 'directness / press / breakdown refreshed';
    when 'search' then
      refresh materialized view public.player_search;
      select count(*) into n_srch from public.player_search;
      return format('search index refreshed (%s players)', n_srch);
    when 'percentiles' then
      refresh materialized view public.mv_player_pct;
      select count(*) into n_pct from public.mv_player_pct;
      return format('percentile layer refreshed (%s rows)', n_pct);
    when 'insights'  then return public.build_insights();
    when 'verify' then
      select count(*) into null_xt from public.sequences where xt_sum is null;
      if null_xt > 0 then raise exception 'verify failed -- % sequences with null xt_sum', null_xt; end if;
      select count(distinct game_id) into seq_games from public.sequences;
      select count(distinct game_id) into evt_games from public.events;
      if seq_games <> evt_games then raise exception 'verify failed -- game-count sequences % vs events %', seq_games, evt_games; end if;
      select count(*) into n_seq from public.sequences;
      select count(*) into n_pcr from public.player_chain_roles;
      select count(*) into n_srch from public.player_search;
      return format('verified -- %s sequences over %s games, %s outfield players, %s in search index',
                    n_seq, seq_games, n_pcr, n_srch);
    else raise exception 'unknown rebuild step: %', p_step;
  end case;
end $fn$;
revoke execute on function public.rebuild_step(text) from public, anon, authenticated;
grant execute on function public.rebuild_step(text) to service_role;
