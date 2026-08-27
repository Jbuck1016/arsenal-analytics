
-- refresh_analytics() rebuilds 42 materialized views in one call, which now brushes
-- against the REST gateway timeout at 284 games in a single league. With five European
-- leagues ingesting it would exceed it outright and the scraper would report a failed
-- rebuild while leaving freshly scraped data unprocessed.
--
-- Split into four batches on the existing dependency order. Nothing is reordered.
create or replace function public.refresh_analytics_batch(p_batch int)
returns text language plpgsql security definer set search_path = public
set statement_timeout = '240s' as $fn$
begin
  case p_batch
    when 1 then  -- foundations: match length, minutes, pools, roles, raw metrics
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
      return 'metrics 1/4: foundations';

    when 2 then  -- chains, shot model, threat, and the per-player derived layers
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
      return 'metrics 2/4: chains, xG, xT';

    when 3 then  -- team layer
      refresh materialized view mv_team_match;
      refresh materialized view mv_team_season;
      refresh materialized view mv_team_zones;
      refresh materialized view mv_team_carry_zones;
      refresh materialized view mv_team_sequences;
      refresh materialized view mv_team_buildup;
      refresh materialized view mv_team_buildphase;
      refresh materialized view mv_team_attackphase;
      refresh materialized view mv_team_lanes;
      refresh materialized view mv_team_all;
      refresh materialized view mv_team_percentiles;
      refresh materialized view mv_team_stat_ranks;
      refresh materialized view mv_player_team_poss;
      refresh materialized view mv_gk_match;
      refresh materialized view mv_player_gk;
      return 'metrics 3/4: team layer';

    when 4 then  -- player metrics, percentiles, pillars, DNA, examples
      refresh materialized view mv_player_metrics;
      refresh materialized view mv_player_percentiles;
      refresh materialized view mv_player_pillars;
      refresh materialized view mv_player_dna;
      refresh materialized view mv_metric_examples;
      return 'metrics 4/4: percentiles and DNA';

    else raise exception 'unknown metrics batch: %', p_batch;
  end case;
end $fn$;
revoke execute on function public.refresh_analytics_batch(int) from public, anon, authenticated;
grant execute on function public.refresh_analytics_batch(int) to service_role;

-- keep the single-call version for direct psql use, where no gateway timeout applies
create or replace function public.refresh_analytics()
returns text language plpgsql security definer set search_path = public
set statement_timeout = 0 as $fn$
begin
  perform public.refresh_analytics_batch(1);
  perform public.refresh_analytics_batch(2);
  perform public.refresh_analytics_batch(3);
  perform public.refresh_analytics_batch(4);
  return 'refreshed at ' || now()::text;
end $fn$;
