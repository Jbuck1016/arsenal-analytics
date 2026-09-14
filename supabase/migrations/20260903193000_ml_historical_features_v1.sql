begin;

create table if not exists public.ml_match_team_map (
  game_id text not null references public.matches(game_id),
  team_id text not null,
  team text not null,
  opponent text not null,
  source_team text not null,
  is_home boolean not null,
  season text not null,
  league text not null,
  source_provider text not null default 'WhoScored',
  mapped_at timestamptz not null default now(),
  primary key (game_id, team_id),
  unique (game_id, team),
  unique (game_id, is_home),
  check (team <> opponent)
);

create index if not exists ml_match_team_map_scope_idx
  on public.ml_match_team_map (season, league, game_id);

comment on table public.ml_match_team_map is
  'Service-only deterministic mapping from provider team IDs to canonical fixture-side team names. Built from raw home/away match metadata; never inferred by fuzzy name matching.';

create table if not exists public.ml_team_match_observations (
  game_id text not null references public.matches(game_id),
  team text not null,
  opponent text not null,
  season text not null,
  league text not null,
  match_date date not null,
  is_home boolean not null,
  observation_schema_version integer not null default 1
    check (observation_schema_version > 0),
  passes integer not null check (passes >= 0),
  passes_completed integer not null check (passes_completed >= 0 and passes_completed <= passes),
  shots integer not null check (shots >= 0),
  open_play_shots integer not null check (open_play_shots >= 0 and open_play_shots <= shots),
  goals_for integer not null check (goals_for >= 0),
  goals_against integer not null check (goals_against >= 0),
  shots_against integer not null check (shots_against >= 0),
  possession_proxy_pct numeric(6,3),
  field_tilt_pct numeric(6,3),
  ppda numeric(9,3),
  defensive_height numeric(6,3),
  average_touch_x numeric(6,3),
  long_ball_pct numeric(6,3),
  build_from_back_pct numeric(6,3),
  directness numeric(9,3),
  progressive_passes integer not null check (progressive_passes >= 0),
  box_entries_pass integer not null check (box_entries_pass >= 0),
  crosses integer not null check (crosses >= 0),
  defensive_actions integer not null check (defensive_actions >= 0),
  open_play_shot_pct numeric(6,3),
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  computed_at timestamptz not null default now(),
  primary key (game_id, team, observation_schema_version),
  unique (game_id, is_home, observation_schema_version),
  check (team <> opponent),
  check (possession_proxy_pct is null or possession_proxy_pct between 0 and 100),
  check (field_tilt_pct is null or field_tilt_pct between 0 and 100),
  check (long_ball_pct is null or long_ball_pct between 0 and 100),
  check (build_from_back_pct is null or build_from_back_pct between 0 and 100),
  check (open_play_shot_pct is null or open_play_shot_pct between 0 and 100)
);

create index if not exists ml_team_match_observations_history_idx
  on public.ml_team_match_observations
    (league, team, match_date desc, game_id, observation_schema_version);

comment on table public.ml_team_match_observations is
  'Service-only typed post-match observations. They may become model inputs only through strictly prior point-in-time rolling windows.';

alter table public.ml_team_match_features
  add column if not exists target_match_date date;

alter table public.ml_team_match_features
  alter column history_cutoff_date drop not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.ml_team_match_features'::regclass
      and conname='ml_team_match_features_cutoff_check'
  ) then
    alter table public.ml_team_match_features
      add constraint ml_team_match_features_cutoff_check
      check (
        target_match_date is not null
        and (
          (source_match_count = 0 and history_cutoff_date is null)
          or
          (source_match_count > 0 and history_cutoff_date < target_match_date)
        )
      );
  end if;
end $$;

create index if not exists ml_team_match_features_target_idx
  on public.ml_team_match_features
    (feature_schema_version, target_match_date, game_id, team);

drop function if exists public.ml_backfill_team_match_observations(text,integer);
drop function if exists public.ml_backfill_team_match_observations(text,integer,text);
drop function if exists public.ml_backfill_team_match_observations(text,integer,text,text[]);

create or replace function public.ml_backfill_team_match_observations(
  p_season text,
  p_league text,
  p_game_ids text[],
  p_observation_schema_version integer default 1
)
returns bigint
language sql
security invoker
set search_path = ''
as $function$
with ev as (
  select e.game_id, mp.team, mp.opponent, mp.is_home, mp.season, mp.league,
         m.date as match_date, m.home_score, m.away_score,
         e.type, e.x, e.y, e.end_x, e.end_y,
         coalesce(e.is_shot,false) as is_shot,
         coalesce(e.is_open_play,false) as is_open_play,
         e.outcome_type = 'Successful' as ok,
         (
           e.type='Pass' and e.x is not null and e.end_x is not null
           and (
             (e.x < 50 and e.end_x < 50 and e.end_x-e.x >= 30)
             or (e.x < 50 and e.end_x >= 50 and e.end_x-e.x >= 15)
             or (e.x >= 50 and e.end_x >= 50 and e.end_x-e.x >= 10)
           )
         ) as progressive,
         e.qualifiers @> '[{"type":{"displayName":"Cross"}}]'::jsonb as is_cross,
         e.qualifiers @> '[{"type":{"displayName":"Longball"}}]'::jsonb as is_long_ball,
         (
           e.type <> all(array[
             'SubstitutionOn','SubstitutionOff','Card','FormationChange',
             'FormationSet','Start','End','CornerAwarded','OffsideGiven','OffsideProvoked'
           ]) and e.x is not null
         ) as is_touch_proxy
  from public.events e
  join public.ml_match_team_map mp
    on mp.game_id=e.game_id and mp.team_id=e.team_id
  join public.matches m on m.game_id=e.game_id
  join public.archive_match_manifest am
    on am.game_id=e.game_id and am.verified_at is not null
  where mp.season=p_season
    and mp.league=p_league
    and e.game_id=any(p_game_ids)
), team_agg as (
  select game_id,team,opponent,is_home,season,league,match_date,
         case when is_home then max(home_score) else max(away_score) end::integer as goals_for,
         case when is_home then max(away_score) else max(home_score) end::integer as goals_against,
         count(*) filter(where type='Pass')::integer as passes,
         count(*) filter(where type='Pass' and ok)::integer as passes_completed,
         count(*) filter(where is_shot)::integer as shots,
         count(*) filter(where is_shot and is_open_play)::integer as open_play_shots,
         count(*) filter(where type='Pass' and is_open_play and is_long_ball)::integer as long_balls,
         count(*) filter(where type='Pass' and progressive and ok)::integer as progressive_passes,
         coalesce(sum(greatest(0,end_x-x)*1.05) filter(where type='Pass' and ok),0) as territory,
         count(*) filter(where is_touch_proxy and x>=66.7)::integer as final_third_touches,
         count(*) filter(where is_touch_proxy)::integer as touches,
         count(*) filter(where type='Pass' and x<33.3)::integer as passes_from_def_third,
         count(*) filter(
           where type='Pass' and is_open_play and ok
             and end_x>=83 and end_y between 21 and 79
         )::integer as box_entries_pass,
         count(*) filter(where type='Pass' and is_open_play and is_cross)::integer as crosses,
         count(*) filter(
           where type=any(array['Tackle','Interception','BallRecovery','BlockedPass','Challenge'])
         )::integer as defensive_actions,
         count(*) filter(
           where type=any(array['Tackle','Interception','BallRecovery','BlockedPass','Challenge']) and x>40
         )::integer as high_defensive_actions,
         count(*) filter(where type='Pass' and x<60)::integer as passes_own60,
         avg(x) filter(
           where type=any(array['Tackle','Interception','BallRecovery','BlockedPass','Challenge'])
         ) as defensive_height,
         avg(x) filter(where is_touch_proxy) as average_touch_x
  from ev
  group by game_id,team,opponent,is_home,season,league,match_date
), paired as (
  select a.*, b.passes as opponent_passes,
         b.passes_own60 as opponent_passes_own60,
         b.final_third_touches as opponent_final_third_touches,
         b.touches as opponent_touches,
         b.shots as opponent_shots
  from team_agg a
  join team_agg b on b.game_id=a.game_id and b.team=a.opponent
), shaped as (
  select game_id,team,opponent,season,league,match_date,is_home,
         p_observation_schema_version as observation_schema_version,
         passes,passes_completed,shots,open_play_shots,goals_for,goals_against,
         opponent_shots as shots_against,
         round(100.0*passes/nullif(passes+opponent_passes,0),3) as possession_proxy_pct,
         round(100.0*final_third_touches/nullif(final_third_touches+opponent_final_third_touches,0),3) as field_tilt_pct,
         round(opponent_passes_own60::numeric/nullif(high_defensive_actions,0),3) as ppda,
         round(defensive_height::numeric,3) as defensive_height,
         round(average_touch_x::numeric,3) as average_touch_x,
         round(100.0*long_balls/nullif(passes,0),3) as long_ball_pct,
         round(100.0*passes_from_def_third/nullif(passes,0),3) as build_from_back_pct,
         round(territory::numeric/nullif(passes_completed,0),3) as directness,
         progressive_passes,box_entries_pass,crosses,defensive_actions,
         round(100.0*open_play_shots/nullif(shots,0),3) as open_play_shot_pct
  from paired
), hashed as (
  select s.*,
         encode(extensions.digest(convert_to(
           jsonb_build_object(
             'game_id',game_id,'team',team,'opponent',opponent,'season',season,
             'league',league,'match_date',match_date,'is_home',is_home,
             'observation_schema_version',observation_schema_version,
             'passes',passes,'passes_completed',passes_completed,'shots',shots,
             'open_play_shots',open_play_shots,'goals_for',goals_for,
             'goals_against',goals_against,'shots_against',shots_against,
             'possession_proxy_pct',possession_proxy_pct,'field_tilt_pct',field_tilt_pct,
             'ppda',ppda,'defensive_height',defensive_height,'average_touch_x',average_touch_x,
             'long_ball_pct',long_ball_pct,'build_from_back_pct',build_from_back_pct,
             'directness',directness,'progressive_passes',progressive_passes,
             'box_entries_pass',box_entries_pass,'crosses',crosses,
             'defensive_actions',defensive_actions,'open_play_shot_pct',open_play_shot_pct
           )::text,'UTF8'),'sha256'),'hex') as content_sha256
  from shaped s
), upserted as (
  insert into public.ml_team_match_observations (
    game_id,team,opponent,season,league,match_date,is_home,observation_schema_version,
    passes,passes_completed,shots,open_play_shots,goals_for,goals_against,shots_against,
    possession_proxy_pct,field_tilt_pct,ppda,defensive_height,average_touch_x,
    long_ball_pct,build_from_back_pct,directness,progressive_passes,box_entries_pass,
    crosses,defensive_actions,open_play_shot_pct,content_sha256
  )
  select game_id,team,opponent,season,league,match_date,is_home,observation_schema_version,
         passes,passes_completed,shots,open_play_shots,goals_for,goals_against,shots_against,
         possession_proxy_pct,field_tilt_pct,ppda,defensive_height,average_touch_x,
         long_ball_pct,build_from_back_pct,directness,progressive_passes,box_entries_pass,
         crosses,defensive_actions,open_play_shot_pct,content_sha256
  from hashed
  on conflict (game_id,team,observation_schema_version) do update set
    opponent=excluded.opponent,season=excluded.season,league=excluded.league,
    match_date=excluded.match_date,is_home=excluded.is_home,passes=excluded.passes,
    passes_completed=excluded.passes_completed,shots=excluded.shots,
    open_play_shots=excluded.open_play_shots,goals_for=excluded.goals_for,
    goals_against=excluded.goals_against,shots_against=excluded.shots_against,
    possession_proxy_pct=excluded.possession_proxy_pct,field_tilt_pct=excluded.field_tilt_pct,
    ppda=excluded.ppda,defensive_height=excluded.defensive_height,
    average_touch_x=excluded.average_touch_x,long_ball_pct=excluded.long_ball_pct,
    build_from_back_pct=excluded.build_from_back_pct,directness=excluded.directness,
    progressive_passes=excluded.progressive_passes,box_entries_pass=excluded.box_entries_pass,
    crosses=excluded.crosses,defensive_actions=excluded.defensive_actions,
    open_play_shot_pct=excluded.open_play_shot_pct,content_sha256=excluded.content_sha256,
    computed_at=now()
  returning 1
)
select count(*)::bigint from upserted;
$function$;

create or replace function public.ml_backfill_team_match_features(
  p_season text,
  p_feature_schema_version integer default 1,
  p_observation_schema_version integer default 1
)
returns bigint
language sql
security invoker
set search_path = ''
as $function$
with rolled as (
  select o.game_id,o.team,o.opponent,o.season,o.league,o.match_date,o.is_home,
         h.source_match_count,h.history_cutoff_date,h.metrics
  from public.ml_team_match_observations o
  cross join lateral (
    select count(*)::integer as source_match_count,
           max(r.match_date) as history_cutoff_date,
           jsonb_build_object(
             'points_per_match_all',round(avg(r.points)::numeric,4),
             'points_per_match_3',round(avg(r.points) filter(where r.recency<=3)::numeric,4),
             'points_per_match_5',round(avg(r.points) filter(where r.recency<=5)::numeric,4),
             'points_per_match_10',round(avg(r.points) filter(where r.recency<=10)::numeric,4),
             'goals_for_3',round(avg(r.goals_for) filter(where r.recency<=3)::numeric,4),
             'goals_for_5',round(avg(r.goals_for) filter(where r.recency<=5)::numeric,4),
             'goals_for_10',round(avg(r.goals_for) filter(where r.recency<=10)::numeric,4),
             'goals_against_3',round(avg(r.goals_against) filter(where r.recency<=3)::numeric,4),
             'goals_against_5',round(avg(r.goals_against) filter(where r.recency<=5)::numeric,4),
             'goals_against_10',round(avg(r.goals_against) filter(where r.recency<=10)::numeric,4),
             'shots_3',round(avg(r.shots) filter(where r.recency<=3)::numeric,4),
             'shots_5',round(avg(r.shots) filter(where r.recency<=5)::numeric,4),
             'shots_10',round(avg(r.shots) filter(where r.recency<=10)::numeric,4),
             'shots_against_3',round(avg(r.shots_against) filter(where r.recency<=3)::numeric,4),
             'shots_against_5',round(avg(r.shots_against) filter(where r.recency<=5)::numeric,4),
             'shots_against_10',round(avg(r.shots_against) filter(where r.recency<=10)::numeric,4),
             'pass_completion_pct_3',round(avg(100.0*r.passes_completed/nullif(r.passes,0)) filter(where r.recency<=3)::numeric,4),
             'pass_completion_pct_5',round(avg(100.0*r.passes_completed/nullif(r.passes,0)) filter(where r.recency<=5)::numeric,4),
             'pass_completion_pct_10',round(avg(100.0*r.passes_completed/nullif(r.passes,0)) filter(where r.recency<=10)::numeric,4),
             'possession_proxy_pct_3',round(avg(r.possession_proxy_pct) filter(where r.recency<=3),4),
             'possession_proxy_pct_5',round(avg(r.possession_proxy_pct) filter(where r.recency<=5),4),
             'possession_proxy_pct_10',round(avg(r.possession_proxy_pct) filter(where r.recency<=10),4),
             'field_tilt_pct_3',round(avg(r.field_tilt_pct) filter(where r.recency<=3),4),
             'field_tilt_pct_5',round(avg(r.field_tilt_pct) filter(where r.recency<=5),4),
             'field_tilt_pct_10',round(avg(r.field_tilt_pct) filter(where r.recency<=10),4),
             'ppda_3',round(avg(r.ppda) filter(where r.recency<=3),4),
             'ppda_5',round(avg(r.ppda) filter(where r.recency<=5),4),
             'ppda_10',round(avg(r.ppda) filter(where r.recency<=10),4),
             'progressive_passes_3',round(avg(r.progressive_passes) filter(where r.recency<=3)::numeric,4),
             'progressive_passes_5',round(avg(r.progressive_passes) filter(where r.recency<=5)::numeric,4),
             'progressive_passes_10',round(avg(r.progressive_passes) filter(where r.recency<=10)::numeric,4),
             'box_entries_pass_3',round(avg(r.box_entries_pass) filter(where r.recency<=3)::numeric,4),
             'box_entries_pass_5',round(avg(r.box_entries_pass) filter(where r.recency<=5)::numeric,4),
             'box_entries_pass_10',round(avg(r.box_entries_pass) filter(where r.recency<=10)::numeric,4),
             'defensive_actions_3',round(avg(r.defensive_actions) filter(where r.recency<=3)::numeric,4),
             'defensive_actions_5',round(avg(r.defensive_actions) filter(where r.recency<=5)::numeric,4),
             'defensive_actions_10',round(avg(r.defensive_actions) filter(where r.recency<=10)::numeric,4),
             'directness_3',round(avg(r.directness) filter(where r.recency<=3),4),
             'directness_5',round(avg(r.directness) filter(where r.recency<=5),4),
             'directness_10',round(avg(r.directness) filter(where r.recency<=10),4),
             'defensive_height_3',round(avg(r.defensive_height) filter(where r.recency<=3),4),
             'defensive_height_5',round(avg(r.defensive_height) filter(where r.recency<=5),4),
             'defensive_height_10',round(avg(r.defensive_height) filter(where r.recency<=10),4)
           ) as metrics
    from (
      select h.*,
             case when h.goals_for>h.goals_against then 3
                  when h.goals_for=h.goals_against then 1 else 0 end as points,
             row_number() over(order by h.match_date desc,h.game_id desc) as recency
      from public.ml_team_match_observations h
      where h.observation_schema_version=p_observation_schema_version
        and h.league=o.league and h.team=o.team and h.match_date<o.match_date
    ) r
  ) h
  where o.season=p_season
    and o.observation_schema_version=p_observation_schema_version
), paired as (
  select a.*, b.source_match_count as opponent_source_match_count,
         b.history_cutoff_date as opponent_history_cutoff_date,
         b.metrics as opponent_metrics
  from rolled a
  join rolled b on b.game_id=a.game_id and b.team=a.opponent
), payloads as (
  select p.*,
         jsonb_build_object(
           'schema_version',p_feature_schema_version,
           'context',jsonb_build_object(
             'league',league,'season',season,'is_home',is_home,
             'team_prior_matches',source_match_count,
             'opponent_prior_matches',opponent_source_match_count,
             'team_rest_days',case when history_cutoff_date is null then null else match_date-history_cutoff_date end,
             'opponent_rest_days',case when opponent_history_cutoff_date is null then null else match_date-opponent_history_cutoff_date end
           ),
           'team',metrics,'opponent',opponent_metrics
         ) as feature_payload
  from paired p
), hashed as (
  select p.*, greatest(history_cutoff_date,opponent_history_cutoff_date) as combined_cutoff,
         encode(extensions.digest(convert_to(feature_payload::text,'UTF8'),'sha256'),'hex') as payload_sha256
  from payloads p
), upserted as (
  insert into public.ml_team_match_features (
    game_id,team,feature_schema_version,as_of,history_cutoff_date,target_match_date,
    source_match_count,features,content_sha256
  )
  select h.game_id,h.team,p_feature_schema_version,
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

alter table public.ml_match_team_map enable row level security;
alter table public.ml_team_match_observations enable row level security;

revoke all on table public.ml_match_team_map from public, anon, authenticated;
revoke all on table public.ml_team_match_observations from public, anon, authenticated;
grant select,insert,update,delete on table public.ml_match_team_map to service_role;
grant select,insert,update,delete on table public.ml_team_match_observations to service_role;

revoke all on function public.ml_backfill_team_match_observations(text,text,text[],integer)
  from public, anon, authenticated;
grant execute on function public.ml_backfill_team_match_observations(text,text,text[],integer)
  to service_role;
revoke all on function public.ml_backfill_team_match_features(text,integer,integer)
  from public, anon, authenticated;
grant execute on function public.ml_backfill_team_match_features(text,integer,integer)
  to service_role;

commit;
