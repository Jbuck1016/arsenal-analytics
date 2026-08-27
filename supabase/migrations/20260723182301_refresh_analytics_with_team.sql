create or replace function refresh_analytics()
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  refresh materialized view mv_match_length;
  refresh materialized view mv_player_minutes;
  refresh materialized view mv_player_season;
  refresh materialized view mv_player_territory;
  refresh materialized view mv_player_defload;
  refresh materialized view mv_player_pool;
  refresh materialized view mv_player_role;
  refresh materialized view mv_player_metrics_raw;
  refresh materialized view mv_player_metrics;
  refresh materialized view mv_player_percentiles;
  refresh materialized view mv_team_match;
  refresh materialized view mv_team_season;
  return 'refreshed at ' || now()::text;
end;
$$;

grant execute on function refresh_analytics() to anon, authenticated;
