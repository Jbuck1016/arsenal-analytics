
create or replace function public.refresh_site_summaries()
returns text language plpgsql security definer set search_path = public as $fn$
begin
  refresh materialized view public.mv_league_summary;
  refresh materialized view public.mv_league_availability;
  refresh materialized view public.mv_site_summary;
  return 'site summaries refreshed';
end $fn$;
revoke execute on function public.refresh_site_summaries() from public, anon, authenticated;
grant execute on function public.refresh_site_summaries() to service_role;

create or replace function public.rebuild_step(p_step text, p_league text default null)
returns text language plpgsql security definer set search_path = public set statement_timeout = '240s'
as $fn$
declare n_srch int; n_st int; n_ce int; n_tj int; n_sq int; n_pct int; msg text;
begin
  case p_step
    when 'preflight' then return public.preflight_league(p_league);
    when 'metrics1'  then return public.refresh_analytics_batch(1);
    when 'metrics2'  then return public.refresh_analytics_batch(2);
    when 'metrics3'  then return public.refresh_analytics_batch(3);
    when 'metrics4'  then return public.refresh_analytics_batch(4);
    when 'metrics'   then perform public.refresh_analytics();       return 'metrics refreshed';
    when 'sequences' then
      perform public.build_sequences();
      msg := public.stamp_sequence_leagues();
      return 'sequences built; ' || msg;
    when 'players' then
      perform public.build_player_chain_roles();
      perform public.stamp_sequence_leagues();
      return 'players built';
    when 'seqfz'     then refresh materialized view public.seq_fz;   return 'seq_fz refreshed';
    when 'lookups' then
      refresh materialized view public.mv_team_league;
      refresh materialized view public.mv_player_league;
      perform public.stamp_sequence_leagues();
      return 'league lookups refreshed';
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
      refresh materialized view public.mv_player_stints;
      refresh materialized view public.mv_player_leverage;
      refresh materialized view public.mv_squad_role;
      refresh materialized view public.mv_player_state_output;
      select count(*) into n_sq from public.mv_squad_role;
      return format('squad usage + state-adjusted output built (%s rows)', n_sq);
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
    when 'insights' then
      msg := public.build_insights();
      perform public.polish_insights();
      perform public.refresh_site_summaries();
      return msg;
    when 'verify' then return public.verify_rebuild();
    else raise exception 'unknown rebuild step: %', p_step;
  end case;
end $fn$;
revoke execute on function public.rebuild_step(text,text) from public, anon, authenticated;
grant execute on function public.rebuild_step(text,text) to service_role;
