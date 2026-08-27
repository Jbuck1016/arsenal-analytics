create or replace function refresh_analytics()
returns text language plpgsql security definer set search_path = public as $$
begin
  refresh materialized view mv_match_length;
  refresh materialized view mv_player_minutes;
  refresh materialized view mv_player_season;
  refresh materialized view mv_player_territory;
  refresh materialized view mv_player_defload;
  refresh materialized view mv_player_pool;
  refresh materialized view mv_player_role;
  refresh materialized view mv_player_metrics_raw;
  refresh materialized view mv_receipt_events;
  refresh materialized view mv_player_carry;
  refresh materialized view mv_player_chains;
  refresh materialized view mv_shot_features;
  refresh materialized view mv_xg_bins;
  refresh materialized view mv_shot_xg;
  refresh materialized view mv_event_phase;
  refresh materialized view mv_player_xa;
  refresh materialized view mv_player_xt;
  refresh materialized view mv_player_zones;
  refresh materialized view mv_player_sca;
  refresh materialized view mv_player_counterpress;
  refresh materialized view mv_player_holdup;
  refresh materialized view mv_player_setpiece;
  refresh materialized view mv_team_match;
  refresh materialized view mv_team_season;
  refresh materialized view mv_player_team_poss;
  refresh materialized view mv_gk_match;
  refresh materialized view mv_player_gk;
  refresh materialized view mv_player_metrics;
  refresh materialized view mv_player_percentiles;
  return 'refreshed at ' || now()::text;
end;$$;
grant execute on function refresh_analytics() to anon, authenticated;
