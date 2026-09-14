create or replace function public.ml_v2_side_metrics(
  p_season text,p_league text,p_game_ids text[]
)
returns table(
  game_id text,team text,final_third_touches integer,penalty_area_touches integer,
  successful_takeons integer,non_penalty_shot_count integer,sequence_count integer,
  shot_ending_sequences integer,box_entry_sequences integer,progressive_sequences integer,
  xt_created numeric,open_play_xt_created numeric,xg_shot_count integer,
  npxg_for numeric,set_piece_xg_for numeric
)
language sql security invoker set search_path=''
as $function$
with sides as (
  select distinct m.game_id,m.team
  from public.ml_match_team_map m
  where m.season=p_season and m.league=p_league and m.game_id=any(p_game_ids)
), ev as (
  select m.game_id,m.team,
    count(*) filter(where e.is_touch and e.x>=66.7)::integer as ft,
    count(*) filter(where e.is_touch and e.x>=83 and e.y between 21 and 79)::integer as box,
    count(*) filter(where e.type='TakeOn' and e.outcome_type='Successful')::integer as takeons,
    count(*) filter(where e.is_shot
      and not coalesce(e.qualifiers @> '[{"type":{"displayName":"Penalty"}}]'::jsonb,false)
      and not coalesce(e.qualifiers @> '[{"type":{"displayName":"OwnGoal"}}]'::jsonb,false))::integer as np_shots
  from public.events e join public.ml_match_team_map m
    on m.game_id=e.game_id and m.team_id=e.team_id
  where m.season=p_season and m.league=p_league and m.game_id=any(p_game_ids)
  group by m.game_id,m.team
), seq as (
  select m.game_id,m.team,count(*)::integer as n,
    count(*) filter(where s.ended_shot)::integer as shots,
    count(*) filter(where s.ended_in_box)::integer as boxes,
    count(*) filter(where coalesce(s.n_prog,0)>0)::integer as prog,
    round(sum(s.xt_sum),6) as xt,
    round(sum(s.xt_sum) filter(where s.is_open_play),6) as op_xt
  from public.sequences s join public.ml_match_team_map m
    on m.game_id=s.game_id and m.team_id=s.team_id
  where m.season=p_season and m.league=p_league and m.game_id=any(p_game_ids)
  group by m.game_id,m.team
), xg as (
  select m.game_id,m.team,count(*)::integer as n,
    round(sum(x.xg),6) as npxg,
    round(sum(x.xg) filter(where not x.is_open_play),6) as spxg
  from public.mv_shot_xg x join public.ml_match_team_map m
    on m.game_id=x.game_id and m.source_team=x.team
  where m.season=p_season and m.league=p_league and m.game_id=any(p_game_ids) and not x.is_pen
  group by m.game_id,m.team
)
select d.game_id,d.team,coalesce(e.ft,0),coalesce(e.box,0),coalesce(e.takeons,0),
  coalesce(e.np_shots,0),s.n,
  case when s.n>0 then s.shots end,case when s.n>0 then s.boxes end,
  case when s.n>0 then s.prog end,case when s.n>0 then s.xt end,
  case when s.n>0 then s.op_xt end,
  coalesce(x.n,0),case when coalesce(x.n,0)=coalesce(e.np_shots,0) then coalesce(x.npxg,0) end,
  case when coalesce(x.n,0)=coalesce(e.np_shots,0) then coalesce(x.spxg,0) end
from sides d left join ev e using(game_id,team) left join seq s using(game_id,team)
left join xg x using(game_id,team);
$function$;

revoke all on function public.ml_v2_side_metrics(text,text,text[]) from public,anon,authenticated;
grant execute on function public.ml_v2_side_metrics(text,text,text[]) to service_role;

-- SPLIT HERE: deploy the builder only after the secured helper exists.

create or replace function public.ml_backfill_team_match_observations_v2(
  p_season text,p_league text,p_game_ids text[]
)
returns bigint language sql security invoker set search_path=''
as $function$
with metric as materialized (
  select * from public.ml_v2_side_metrics(p_season,p_league,p_game_ids)
), patched as (
  select jsonb_populate_record(b,jsonb_build_object(
    'observation_schema_version',2,
    'final_third_touches',a.final_third_touches,
    'final_third_touches_against',z.final_third_touches,
    'final_third_touch_difference',a.final_third_touches-z.final_third_touches,
    'penalty_area_touches',a.penalty_area_touches,
    'penalty_area_touches_against',z.penalty_area_touches,
    'penalty_area_touch_difference',a.penalty_area_touches-z.penalty_area_touches,
    'successful_takeons',a.successful_takeons,'successful_takeons_against',z.successful_takeons,
    'xt_created',a.xt_created,'xt_conceded',z.xt_created,'xt_difference',a.xt_created-z.xt_created,
    'open_play_xt_created',a.open_play_xt_created,'open_play_xt_conceded',z.open_play_xt_created,
    'open_play_xt_difference',a.open_play_xt_created-z.open_play_xt_created,
    'sequence_count',a.sequence_count,'sequence_count_against',z.sequence_count,
    'shot_ending_sequences',a.shot_ending_sequences,
    'shot_ending_sequences_against',z.shot_ending_sequences,
    'box_entry_sequences',a.box_entry_sequences,'box_entry_sequences_against',z.box_entry_sequences,
    'progressive_sequences',a.progressive_sequences,
    'progressive_sequences_against',z.progressive_sequences,
    'npxg_for',a.npxg_for,'npxg_against',z.npxg_for,'npxg_difference',a.npxg_for-z.npxg_for,
    'set_piece_xg_for',a.set_piece_xg_for,'set_piece_xg_against',z.set_piece_xg_for,
    'xg_shot_count',a.xg_shot_count,'non_penalty_shot_count',a.non_penalty_shot_count
  )) as r
  from public.ml_team_match_observations b
  join metric a on a.game_id=b.game_id and a.team=b.team
  join metric z on z.game_id=b.game_id and z.team=b.opponent
  where b.observation_schema_version=1 and b.season=p_season and b.league=p_league
    and b.game_id=any(p_game_ids)
), finalized as (
  select jsonb_populate_record(r,jsonb_build_object(
    'content_sha256',encode(extensions.digest(convert_to((to_jsonb(r)-'content_sha256'-'computed_at')::text,'UTF8'),'sha256'),'hex'),
    'computed_at',now()
  )) as r from patched
), deleted as (
  delete from public.ml_team_match_observations o
  where o.observation_schema_version=2 and o.season=p_season and o.league=p_league
    and o.game_id=any(p_game_ids) returning 1
), inserted as (
  insert into public.ml_team_match_observations
  select (r).* from finalized cross join (select count(*) from deleted) deletion_barrier
  returning 1
)
select count(*)::bigint from inserted;
$function$;

revoke all on function public.ml_backfill_team_match_observations_v2(text,text,text[])
  from public,anon,authenticated;
grant execute on function public.ml_backfill_team_match_observations_v2(text,text,text[])
  to service_role;
