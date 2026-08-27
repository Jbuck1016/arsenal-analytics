
-- Raw column names leak into insight prose ("end around box pct"). This maps them to
-- football language. Kept as a function so any detector can use it.
create or replace function public.pretty_metric(p text)
returns text language sql immutable as $$
  select coalesce((select l from (values
    ('seqs_per_match','possession volume'),
    ('passes_seq','long passing sequences'),
    ('seconds_seq','slow, patient possessions'),
    ('players_seq','number of players per move'),
    ('xt_seq','threat per possession'),
    ('low_build_pct','building from deep'),
    ('high_build_pct','winning the ball high'),
    ('structured_pct','patient structured build-up'),
    ('very_short_pct','short passing'),
    ('long_pct','going long'),
    ('switches_pct','switching play'),
    ('wide_tri_pct','wide combination play'),
    ('hold_up_pct','holding the ball up'),
    ('ends_opp_half_pct','finishing moves in the opposition half'),
    ('ends_def_third_pct','possessions dying in their own third'),
    ('end_att_third_pct','reaching the final third'),
    ('end_in_box_pct','getting into the box'),
    ('end_around_box_pct','working the ball to the edge of the box'),
    ('finds_central_pct','progressing centrally'),
    ('finds_wide_pct','progressing wide'),
    ('ends_in_shot_pct','turning possessions into shots'),
    ('central_prog_share','central progression'),
    ('wide_pass_pct','wide passing')
  ) t(k,l) where t.k = p), replace(p,'_',' '));
$$;
grant execute on function public.pretty_metric(text) to anon, authenticated;

-- Post-build pass: rewrite raw metric names in insight text into football language.
-- Also the natural home for a richer prose layer later.
create or replace function public.polish_insights()
returns text language plpgsql security definer set search_path = public as $fn$
declare r record; n int := 0;
begin
  for r in select distinct metrics->>'top_metric' m from public.insights
           where detector='team_profile' and metrics ? 'top_metric' loop
    if r.m is null then continue; end if;
    update public.insights
      set headline = replace(headline, replace(r.m,'_',' '), public.pretty_metric(r.m)),
          detail   = replace(detail,   replace(r.m,'_',' '), public.pretty_metric(r.m))
      where detector='team_profile' and metrics->>'top_metric' = r.m;
    n := n + 1;
  end loop;
  return format('polished %s metric labels', n);
end $fn$;
revoke execute on function public.polish_insights() from public, anon, authenticated;
grant execute on function public.polish_insights() to service_role;

-- rebuild_step now builds then polishes
create or replace function public.rebuild_step(p_step text)
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare wl_ct int; bad_teams text; seq_games int; evt_games int; null_xt int;
        n_seq int; n_pcr int; n_srch int; n_st int; n_ce int; n_tj int; n_sq int; n_pct int; msg text;
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
      return msg;
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
