begin;

-- REFRESH ... CONCURRENTLY requires a plain, unconditional unique index.
-- Each key was checked against production immediately before this migration;
-- CREATE UNIQUE remains the transaction-level assertion against drift.
create unique index if not exists mv_game_goals_refresh_uq on public.mv_game_goals(game_id,expanded_minute,second,scoring_team,is_og) nulls not distinct;
create unique index if not exists mv_gk_match_refresh_uq on public.mv_gk_match(game_id,team,player_id) nulls not distinct;
create unique index if not exists mv_metric_examples_refresh_uq on public.mv_metric_examples(metric,league) nulls not distinct;
create unique index if not exists mv_pass_traj_refresh_uq on public.mv_pass_traj(id) nulls not distinct;
create unique index if not exists mv_player_leverage_refresh_uq on public.mv_player_leverage(player_id,team) nulls not distinct;
create unique index if not exists mv_player_minutes_refresh_uq on public.mv_player_minutes(game_id,player_id,team) nulls not distinct;
create unique index if not exists mv_player_pct_refresh_uq on public.mv_player_pct(player_id,metric,league) nulls not distinct;
create unique index if not exists mv_player_percentiles_refresh_uq on public.mv_player_percentiles(player_id,metric,league) nulls not distinct;
create unique index if not exists mv_player_stints_refresh_uq on public.mv_player_stints(game_id,player_id,team) nulls not distinct;
create unique index if not exists mv_press_vs_buildup_refresh_uq on public.mv_press_vs_buildup(defending_team,league,buildup_type) nulls not distinct;
create unique index if not exists mv_receipt_events_refresh_uq on public.mv_receipt_events(game_id,ws_id) nulls not distinct;
create unique index if not exists mv_seq_events_refresh_uq on public.mv_seq_events(seq_uid,ord_a) nulls not distinct;
create unique index if not exists mv_site_summary_refresh_uq on public.mv_site_summary(as_of_match_date) nulls not distinct;
create unique index if not exists mv_squad_role_refresh_uq on public.mv_squad_role(player_id,team,league) nulls not distinct;
create unique index if not exists mv_state_segments_refresh_uq on public.mv_state_segments(game_id,team,seg_start,seg_end) nulls not distinct;
create unique index if not exists mv_team_breakdown_refresh_uq on public.mv_team_breakdown(team,league,route) nulls not distinct;
create unique index if not exists mv_team_carry_zones_refresh_uq on public.mv_team_carry_zones(team,zx,zy) nulls not distinct;
create unique index if not exists mv_team_lanes_refresh_uq on public.mv_team_lanes(team,lane) nulls not distinct;
create unique index if not exists mv_team_percentiles_refresh_uq on public.mv_team_percentiles(team,metric,league) nulls not distinct;
create unique index if not exists mv_team_sequences_refresh_uq on public.mv_team_sequences(game_id,seq_id,team) nulls not distinct;
create unique index if not exists mv_team_stat_ranks_refresh_uq on public.mv_team_stat_ranks(team,metric,league) nulls not distinct;
create unique index if not exists mv_team_zones_refresh_uq on public.mv_team_zones(team,zx,zy) nulls not distinct;

do $rewrite$
declare r record; definition text; changed integer:=0;
begin
  for r in
    select p.oid,p.oid::regprocedure::text identity
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('refresh_analytics_batch','rebuild_step','refresh_site_summaries')
  loop
    definition:=pg_get_functiondef(r.oid);
    if definition not ilike '%refresh materialized view%' then
      raise exception '% has no materialized-view refreshes',r.identity;
    end if;
    definition:=regexp_replace(
      definition,
      'refresh materialized view (?!concurrently )',
      'refresh materialized view concurrently ',
      'gi'
    );
    execute definition;
    changed:=changed+1;
  end loop;
  if changed<>3 then raise exception 'expected 3 refresh functions, rewrote %',changed; end if;
end
$rewrite$;

do $schedule$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job where jobname='analytics-rebuild-worker';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule(
    'analytics-rebuild-worker','* * * * *',
    'set statement_timeout = 0; select public.process_analytics_rebuild_queue();'
  );
end
$schedule$;

do $assert$
declare ready integer; total integer; nonconcurrent integer;
begin
  select count(*),count(*) filter(where has_unique) into total,ready
  from (
    select c.oid,exists(
      select 1 from pg_index i where i.indrelid=c.oid and i.indisunique
        and i.indisvalid and i.indpred is null and i.indexprs is null
    ) has_unique
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='m'
  ) q;
  if ready<>total then raise exception 'only % of % matviews are concurrent-ready',ready,total; end if;

  select count(*) into nonconcurrent
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in ('refresh_analytics_batch','rebuild_step','refresh_site_summaries')
    and regexp_replace(lower(pg_get_functiondef(p.oid)),
      'refresh materialized view concurrently','', 'g') like '%refresh materialized view%';
  if nonconcurrent<>0 then raise exception '% rebuild functions retain blocking refreshes',nonconcurrent; end if;
end
$assert$;

commit;
