create or replace function public.ml_backfill_team_match_features_v2_batch(
  p_season text,p_game_ids text[]
)
returns bigint language sql security invoker set search_path=''
as $function$
with rolled as (
  select o.game_id,o.team,o.opponent,o.season,o.league,o.match_date,o.is_home,
    th.source_match_count,th.history_cutoff_date,th.matches_last_14_days,
    th.matches_last_21_days,th.metrics,
    oh.source_match_count as opponent_source_match_count,
    oh.history_cutoff_date as opponent_history_cutoff_date,
    oh.matches_last_14_days as opponent_matches_last_14_days,
    oh.matches_last_21_days as opponent_matches_last_21_days,
    oh.metrics as opponent_metrics
  from public.ml_team_match_observations o
  cross join lateral public.ml_v2_rolling_metrics(o.league,o.team,o.match_date) th
  cross join lateral public.ml_v2_rolling_metrics(o.league,o.opponent,o.match_date) oh
  where o.season=p_season and o.observation_schema_version=2
    and o.game_id=any(p_game_ids)
), payloads as (
  select r.*,jsonb_build_object(
    'schema_version',2,
    'context',jsonb_build_object(
      'league',league,'season',season,'is_home',is_home,
      'team_prior_matches',source_match_count,
      'opponent_prior_matches',opponent_source_match_count,
      'team_rest_days',case when history_cutoff_date is null then null else match_date-history_cutoff_date end,
      'opponent_rest_days',case when opponent_history_cutoff_date is null then null else match_date-opponent_history_cutoff_date end,
      'team_matches_last_14_days',matches_last_14_days,
      'opponent_matches_last_14_days',opponent_matches_last_14_days,
      'team_matches_last_21_days',matches_last_21_days,
      'opponent_matches_last_21_days',opponent_matches_last_21_days),
    'team',metrics,'opponent',opponent_metrics) as feature_payload
  from rolled r
), hashed as (
  select p.*,greatest(history_cutoff_date,opponent_history_cutoff_date) as combined_cutoff,
    encode(extensions.digest(convert_to(feature_payload::text,'UTF8'),'sha256'),'hex') as payload_sha256
  from payloads p
), upserted as (
  insert into public.ml_team_match_features(
    game_id,team,feature_schema_version,as_of,history_cutoff_date,target_match_date,
    source_match_count,features,content_sha256)
  select h.game_id,h.team,2,coalesce(m.kickoff_at,h.match_date::timestamp at time zone 'UTC'),
    h.combined_cutoff,h.match_date,h.source_match_count+h.opponent_source_match_count,
    h.feature_payload,h.payload_sha256
  from hashed h join public.matches m on m.game_id=h.game_id
  on conflict(game_id,team,feature_schema_version) do update set
    as_of=excluded.as_of,history_cutoff_date=excluded.history_cutoff_date,
    target_match_date=excluded.target_match_date,source_match_count=excluded.source_match_count,
    features=excluded.features,content_sha256=excluded.content_sha256,computed_at=now()
  returning 1
)
select count(*)::bigint from upserted;
$function$;

revoke all on function public.ml_backfill_team_match_features_v2_batch(text,text[])
  from public,anon,authenticated;
grant execute on function public.ml_backfill_team_match_features_v2_batch(text,text[])
  to service_role;
