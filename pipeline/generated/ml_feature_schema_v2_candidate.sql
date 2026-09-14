begin;

-- Generated candidate only. Apply through the reviewed Supabase database
-- channel, verify on a bounded season, then capture clean migration history.

alter table public.ml_team_match_observations
  add column if not exists final_third_touches integer,
  add column if not exists final_third_touches_against integer,
  add column if not exists final_third_touch_difference integer,
  add column if not exists penalty_area_touches integer,
  add column if not exists penalty_area_touches_against integer,
  add column if not exists penalty_area_touch_difference integer,
  add column if not exists successful_takeons integer,
  add column if not exists successful_takeons_against integer,
  add column if not exists xt_created numeric(14,6),
  add column if not exists xt_conceded numeric(14,6),
  add column if not exists xt_difference numeric(14,6),
  add column if not exists open_play_xt_created numeric(14,6),
  add column if not exists open_play_xt_conceded numeric(14,6),
  add column if not exists open_play_xt_difference numeric(14,6),
  add column if not exists sequence_count integer,
  add column if not exists sequence_count_against integer,
  add column if not exists shot_ending_sequences integer,
  add column if not exists shot_ending_sequences_against integer,
  add column if not exists box_entry_sequences integer,
  add column if not exists box_entry_sequences_against integer,
  add column if not exists progressive_sequences integer,
  add column if not exists progressive_sequences_against integer,
  add column if not exists npxg_for numeric(12,6),
  add column if not exists npxg_against numeric(12,6),
  add column if not exists npxg_difference numeric(12,6),
  add column if not exists set_piece_xg_for numeric(12,6),
  add column if not exists set_piece_xg_against numeric(12,6),
  add column if not exists xg_shot_count integer,
  add column if not exists non_penalty_shot_count integer;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.ml_team_match_observations'::regclass
      and conname='ml_team_match_observations_v2_counts_check'
  ) then
    alter table public.ml_team_match_observations
      add constraint ml_team_match_observations_v2_counts_check check (
        observation_schema_version < 2 or (
          final_third_touches >= 0 and final_third_touches_against >= 0
          and penalty_area_touches >= 0 and penalty_area_touches_against >= 0
          and successful_takeons >= 0 and successful_takeons_against >= 0
          and sequence_count >= 0 and sequence_count_against >= 0
          and shot_ending_sequences >= 0 and shot_ending_sequences_against >= 0
          and box_entry_sequences >= 0 and box_entry_sequences_against >= 0
          and progressive_sequences >= 0 and progressive_sequences_against >= 0
          and xg_shot_count >= 0 and non_penalty_shot_count >= 0
        )
      );
  end if;
end $$;

comment on column public.ml_team_match_observations.xt_created is
  'Sum of sequence xT for the team in the match. Nullable when sequence coverage is incomplete; never coalesced to zero.';
comment on column public.ml_team_match_observations.npxg_for is
  'Non-penalty xG only when every eligible non-penalty shot reconciles to the versioned xG source; otherwise null.';

create or replace function public.ml_backfill_team_match_observations_v2(
  p_season text,
  p_league text,
  p_game_ids text[]
)
returns bigint
language sql
security invoker
set search_path = ''
as $function$
with base as (
  select o.*
  from public.ml_team_match_observations o
  where o.observation_schema_version=1
    and o.season=p_season and o.league=p_league
    and o.game_id=any(p_game_ids)
), event_stats as (
  select mp.game_id,mp.team,
         count(*) filter(
           where e.is_touch and e.x is not null and e.x>=66.7
         )::integer as final_third_touches,
         count(*) filter(
           where e.is_touch and e.x is not null and e.y is not null
             and e.x>=83 and e.y between 21 and 79
         )::integer as penalty_area_touches,
         count(*) filter(
           where e.type='TakeOn' and e.outcome_type='Successful'
         )::integer as successful_takeons,
         count(*) filter(
           where e.is_shot
             and not coalesce(e.qualifiers @> '[{"type":{"displayName":"Penalty"}}]'::jsonb,false)
             and not coalesce(e.qualifiers @> '[{"type":{"displayName":"OwnGoal"}}]'::jsonb,false)
         )::integer as non_penalty_shot_count
  from public.events e
  join public.ml_match_team_map mp
    on mp.game_id=e.game_id and mp.team_id=e.team_id
  where mp.season=p_season and mp.league=p_league
    and mp.game_id=any(p_game_ids)
  group by mp.game_id,mp.team
), sequence_stats as (
  select mp.game_id,mp.team,
         count(*)::integer as sequence_count,
         count(*) filter(where s.ended_shot)::integer as shot_ending_sequences,
         count(*) filter(where s.ended_in_box)::integer as box_entry_sequences,
         count(*) filter(where coalesce(s.n_prog,0)>0)::integer as progressive_sequences,
         round(sum(s.xt_sum),6) as xt_created,
         round(sum(s.xt_sum) filter(where s.is_open_play),6) as open_play_xt_created
  from public.sequences s
  join public.ml_match_team_map mp
    on mp.game_id=s.game_id and mp.team_id=s.team_id
  where mp.season=p_season and mp.league=p_league
    and mp.game_id=any(p_game_ids)
  group by mp.game_id,mp.team
), xg_stats as (
  select mp.game_id,mp.team,
         count(*)::integer as xg_shot_count,
         round(sum(x.xg) filter(where not x.is_pen),6) as npxg_for,
         round(sum(x.xg) filter(where not x.is_pen and not x.is_open_play),6) as set_piece_xg_for
  from public.mv_shot_xg x
  join public.ml_match_team_map mp
    on mp.game_id=x.game_id and mp.source_team=x.team
  where mp.season=p_season and mp.league=p_league
    and mp.game_id=any(p_game_ids)
    and not x.is_pen
  group by mp.game_id,mp.team
), own as (
  select b.*,
         e.final_third_touches,e.penalty_area_touches,e.successful_takeons,
         e.non_penalty_shot_count,
         coalesce(s.sequence_count,0) as sequence_count,
         coalesce(s.shot_ending_sequences,0) as shot_ending_sequences,
         coalesce(s.box_entry_sequences,0) as box_entry_sequences,
         coalesce(s.progressive_sequences,0) as progressive_sequences,
         case when s.sequence_count>0 then s.xt_created end as xt_created,
         case when s.sequence_count>0 then s.open_play_xt_created end as open_play_xt_created,
         coalesce(x.xg_shot_count,0) as xg_shot_count,
         case when coalesce(x.xg_shot_count,0)=e.non_penalty_shot_count
              then coalesce(x.npxg_for,0) end as npxg_for,
         case when coalesce(x.xg_shot_count,0)=e.non_penalty_shot_count
              then coalesce(x.set_piece_xg_for,0) end as set_piece_xg_for
  from base b
  join event_stats e on e.game_id=b.game_id and e.team=b.team
  left join sequence_stats s on s.game_id=b.game_id and s.team=b.team
  left join xg_stats x on x.game_id=b.game_id and x.team=b.team
), paired as (
  select a.*,b.final_third_touches as final_third_touches_against,
         b.penalty_area_touches as penalty_area_touches_against,
         b.successful_takeons as successful_takeons_against,
         b.sequence_count as sequence_count_against,
         b.shot_ending_sequences as shot_ending_sequences_against,
         b.box_entry_sequences as box_entry_sequences_against,
         b.progressive_sequences as progressive_sequences_against,
         b.xt_created as xt_conceded,
         b.open_play_xt_created as open_play_xt_conceded,
         b.npxg_for as npxg_against,
         b.set_piece_xg_for as set_piece_xg_against
  from own a
  join own b on b.game_id=a.game_id and b.team=a.opponent
), shaped as (
  select game_id,team,opponent,season,league,match_date,is_home,
         2 as observation_schema_version,
         passes,passes_completed,shots,open_play_shots,goals_for,goals_against,
         shots_against,possession_proxy_pct,field_tilt_pct,ppda,defensive_height,
         average_touch_x,long_ball_pct,build_from_back_pct,directness,
         progressive_passes,box_entries_pass,crosses,defensive_actions,
         open_play_shot_pct,
         final_third_touches,final_third_touches_against,
         final_third_touches-final_third_touches_against as final_third_touch_difference,
         penalty_area_touches,penalty_area_touches_against,
         penalty_area_touches-penalty_area_touches_against as penalty_area_touch_difference,
         successful_takeons,successful_takeons_against,
         xt_created,xt_conceded,xt_created-xt_conceded as xt_difference,
         open_play_xt_created,open_play_xt_conceded,
         open_play_xt_created-open_play_xt_conceded as open_play_xt_difference,
         sequence_count,sequence_count_against,
         shot_ending_sequences,shot_ending_sequences_against,
         box_entry_sequences,box_entry_sequences_against,
         progressive_sequences,progressive_sequences_against,
         npxg_for,npxg_against,npxg_for-npxg_against as npxg_difference,
         set_piece_xg_for,set_piece_xg_against,xg_shot_count,non_penalty_shot_count
  from paired
), hashed as (
  select s.*,
         encode(extensions.digest(convert_to(to_jsonb(s)::text,'UTF8'),'sha256'),'hex')
           as content_sha256
  from shaped s
), deleted as (
  delete from public.ml_team_match_observations o
  where o.observation_schema_version=2
    and o.season=p_season and o.league=p_league
    and o.game_id=any(p_game_ids)
  returning 1
), upserted as (
  insert into public.ml_team_match_observations (
    game_id,team,opponent,season,league,match_date,is_home,observation_schema_version,
    passes,passes_completed,shots,open_play_shots,goals_for,goals_against,shots_against,
    possession_proxy_pct,field_tilt_pct,ppda,defensive_height,average_touch_x,
    long_ball_pct,build_from_back_pct,directness,progressive_passes,box_entries_pass,
    crosses,defensive_actions,open_play_shot_pct,
    final_third_touches,final_third_touches_against,final_third_touch_difference,
    penalty_area_touches,penalty_area_touches_against,penalty_area_touch_difference,
    successful_takeons,successful_takeons_against,
    xt_created,xt_conceded,xt_difference,open_play_xt_created,
    open_play_xt_conceded,open_play_xt_difference,
    sequence_count,sequence_count_against,shot_ending_sequences,
    shot_ending_sequences_against,box_entry_sequences,box_entry_sequences_against,
    progressive_sequences,progressive_sequences_against,
    npxg_for,npxg_against,npxg_difference,set_piece_xg_for,set_piece_xg_against,
    xg_shot_count,non_penalty_shot_count,content_sha256
  )
  select game_id,team,opponent,season,league,match_date,is_home,observation_schema_version,
         passes,passes_completed,shots,open_play_shots,goals_for,goals_against,shots_against,
         possession_proxy_pct,field_tilt_pct,ppda,defensive_height,average_touch_x,
         long_ball_pct,build_from_back_pct,directness,progressive_passes,box_entries_pass,
         crosses,defensive_actions,open_play_shot_pct,
         final_third_touches,final_third_touches_against,final_third_touch_difference,
         penalty_area_touches,penalty_area_touches_against,penalty_area_touch_difference,
         successful_takeons,successful_takeons_against,
         xt_created,xt_conceded,xt_difference,open_play_xt_created,
         open_play_xt_conceded,open_play_xt_difference,
         sequence_count,sequence_count_against,shot_ending_sequences,
         shot_ending_sequences_against,box_entry_sequences,box_entry_sequences_against,
         progressive_sequences,progressive_sequences_against,
         npxg_for,npxg_against,npxg_difference,set_piece_xg_for,set_piece_xg_against,
         xg_shot_count,non_penalty_shot_count,content_sha256
  from hashed
  returning 1
)
select count(*)::bigint from upserted;
$function$;

create or replace function public.ml_v2_rolling_metrics(
  p_league text,
  p_team text,
  p_target_date date
)
returns table(
  source_match_count integer,
  history_cutoff_date date,
  matches_last_14_days integer,
  matches_last_21_days integer,
  metrics jsonb
)
language sql
security invoker
set search_path = ''
as $function$
with history as (
  select h.*,
         case when h.goals_for>h.goals_against then 3
              when h.goals_for=h.goals_against then 1 else 0 end::numeric as points,
         100.0*h.passes_completed/nullif(h.passes,0) as pass_completion_pct,
         row_number() over(order by h.match_date desc,h.game_id desc) as recency
  from public.ml_team_match_observations h
  where h.observation_schema_version=2
    and h.league=p_league and h.team=p_team and h.match_date<p_target_date
), long_metrics as (
  select h.recency,v.metric,v.value
  from history h
  cross join lateral (values
    ('points_per_match',h.points),('goals_for',h.goals_for::numeric),
    ('goals_against',h.goals_against::numeric),('shots',h.shots::numeric),
    ('shots_against',h.shots_against::numeric),('pass_completion_pct',h.pass_completion_pct),
    ('possession_proxy_pct',h.possession_proxy_pct),('field_tilt_pct',h.field_tilt_pct),
    ('ppda',h.ppda),('progressive_passes',h.progressive_passes::numeric),
    ('box_entries_pass',h.box_entries_pass::numeric),
    ('defensive_actions',h.defensive_actions::numeric),('directness',h.directness),
    ('defensive_height',h.defensive_height),('open_play_shot_pct',h.open_play_shot_pct),
    ('final_third_touches',h.final_third_touches::numeric),
    ('final_third_touches_against',h.final_third_touches_against::numeric),
    ('final_third_touch_difference',h.final_third_touch_difference::numeric),
    ('penalty_area_touches',h.penalty_area_touches::numeric),
    ('penalty_area_touches_against',h.penalty_area_touches_against::numeric),
    ('penalty_area_touch_difference',h.penalty_area_touch_difference::numeric),
    ('successful_takeons',h.successful_takeons::numeric),
    ('successful_takeons_against',h.successful_takeons_against::numeric),
    ('xt_created',h.xt_created),('xt_conceded',h.xt_conceded),
    ('xt_difference',h.xt_difference),('open_play_xt_created',h.open_play_xt_created),
    ('open_play_xt_conceded',h.open_play_xt_conceded),
    ('open_play_xt_difference',h.open_play_xt_difference),
    ('sequence_count',h.sequence_count::numeric),
    ('sequence_count_against',h.sequence_count_against::numeric),
    ('shot_ending_sequences',h.shot_ending_sequences::numeric),
    ('shot_ending_sequences_against',h.shot_ending_sequences_against::numeric),
    ('box_entry_sequences',h.box_entry_sequences::numeric),
    ('box_entry_sequences_against',h.box_entry_sequences_against::numeric),
    ('progressive_sequences',h.progressive_sequences::numeric),
    ('progressive_sequences_against',h.progressive_sequences_against::numeric),
    ('npxg_for',h.npxg_for),('npxg_against',h.npxg_against),
    ('npxg_difference',h.npxg_difference),('set_piece_xg_for',h.set_piece_xg_for),
    ('set_piece_xg_against',h.set_piece_xg_against)
  ) v(metric,value)
), windowed as (
  select metric,w.window_size,
         round(avg(value) filter(where recency<=w.window_size),4) as value
  from long_metrics
  cross join (values (3),(5),(10)) w(window_size)
  group by metric,w.window_size
)
select (select count(*)::integer from history),
       (select max(match_date) from history),
       (select count(*)::integer from history where match_date>=p_target_date-14),
       (select count(*)::integer from history where match_date>=p_target_date-21),
       coalesce(
         (select jsonb_object_agg(metric||'_'||window_size,value order by metric,window_size)
          from windowed),
         '{}'::jsonb
       ) || jsonb_build_object(
         'points_per_match_all',(select round(avg(points),4) from history)
       );
$function$;

create or replace function public.ml_backfill_team_match_features_v2(p_season text)
returns bigint
language sql
security invoker
set search_path = ''
as $function$
with rolled as (
  select o.game_id,o.team,o.opponent,o.season,o.league,o.match_date,o.is_home,
         th.source_match_count,th.history_cutoff_date,
         th.matches_last_14_days,th.matches_last_21_days,th.metrics,
         oh.source_match_count as opponent_source_match_count,
         oh.history_cutoff_date as opponent_history_cutoff_date,
         oh.matches_last_14_days as opponent_matches_last_14_days,
         oh.matches_last_21_days as opponent_matches_last_21_days,
         oh.metrics as opponent_metrics
  from public.ml_team_match_observations o
  cross join lateral public.ml_v2_rolling_metrics(o.league,o.team,o.match_date) th
  cross join lateral public.ml_v2_rolling_metrics(o.league,o.opponent,o.match_date) oh
  where o.season=p_season and o.observation_schema_version=2
), payloads as (
  select r.*,
         jsonb_build_object(
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
             'opponent_matches_last_21_days',opponent_matches_last_21_days
           ),
           'team',metrics,'opponent',opponent_metrics
         ) as feature_payload
  from rolled r
), hashed as (
  select p.*,greatest(history_cutoff_date,opponent_history_cutoff_date) as combined_cutoff,
         encode(extensions.digest(convert_to(feature_payload::text,'UTF8'),'sha256'),'hex')
           as payload_sha256
  from payloads p
), upserted as (
  insert into public.ml_team_match_features (
    game_id,team,feature_schema_version,as_of,history_cutoff_date,target_match_date,
    source_match_count,features,content_sha256
  )
  select h.game_id,h.team,2,
         coalesce(m.kickoff_at,h.match_date::timestamp at time zone 'UTC'),
         h.combined_cutoff,h.match_date,
         h.source_match_count+h.opponent_source_match_count,
         h.feature_payload,h.payload_sha256
  from hashed h
  join public.matches m on m.game_id=h.game_id
  on conflict (game_id,team,feature_schema_version) do update set
    as_of=excluded.as_of,history_cutoff_date=excluded.history_cutoff_date,
    target_match_date=excluded.target_match_date,source_match_count=excluded.source_match_count,
    features=excluded.features,content_sha256=excluded.content_sha256,computed_at=now()
  returning 1
)
select count(*)::bigint from upserted;
$function$;

revoke all on function public.ml_backfill_team_match_observations_v2(text,text,text[])
  from public,anon,authenticated;
revoke all on function public.ml_v2_rolling_metrics(text,text,date)
  from public,anon,authenticated;
revoke all on function public.ml_backfill_team_match_features_v2(text)
  from public,anon,authenticated;
grant execute on function public.ml_backfill_team_match_observations_v2(text,text,text[])
  to service_role;
grant execute on function public.ml_v2_rolling_metrics(text,text,date)
  to service_role;
grant execute on function public.ml_backfill_team_match_features_v2(text)
  to service_role;

commit;
