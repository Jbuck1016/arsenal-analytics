
-- 1) bake GK-exclusion into build_player_chain_roles at source (final line filters pos <> 'GK')
CREATE OR REPLACE FUNCTION public.build_player_chain_roles()
 RETURNS void LANGUAGE plpgsql AS $function$
begin
  truncate table public.player_chain_roles;
  insert into public.player_chain_roles
    (player_id, player, team, pos, inv, player_xt, hold_secs,
     initiator, bridge, progressor, carrier, vertical, support_angle, individual, creator, box_threat, finisher)
  with base as (
    select game_id, period, expanded_minute, second, event_id, team, player, player_id, type, outcome_type,
      x, y, end_x, end_y, is_shot,
      case when type='Pass' and outcome_type='Successful' and end_x is not null
        then coalesce(public.xt_val(end_x,end_y),0)-coalesce(public.xt_val(x,y),0) else 0 end as xt_delta,
      case when jsonb_typeof(qualifiers)='array' then exists(select 1 from jsonb_array_elements(qualifiers) q
        where q->'type'->>'displayName' in ('ThrowIn','CornerTaken','FreekickTaken','GoalKick','KickOff','Penalty')) else false end as is_setpiece,
      case when type in ('Pass','TakeOn','BallTouch','MissedShots','SavedShot','ShotOnPost','Goal','KeeperPickup','Claim') then team end as ctrl_team,
      case when type in ('Foul','Card','OffsideGiven','OffsidePass','CornerAwarded','End') or is_goal then 1 else 0 end as stop_flag
    from public.events
  ),
  cum as (select *, sum(stop_flag) over (partition by game_id order by period,expanded_minute,second,event_id rows between unbounded preceding and current row) stop_cum from base),
  ctrl as (select *, lag(ctrl_team) over w prev_ctrl_team, lag(stop_cum) over w prev_stop_cum, lag(period) over w prev_period
    from cum where ctrl_team is not null window w as (partition by game_id order by period,expanded_minute,second,event_id)),
  bounded as (select *, case when prev_ctrl_team is null or period<>prev_period or ctrl_team<>prev_ctrl_team or is_setpiece or stop_cum>coalesce(prev_stop_cum,-1) then 1 else 0 end is_break from ctrl),
  seqd as (select *, sum(is_break) over (partition by game_id order by period,expanded_minute,second,event_id) seq_no from bounded),
  ordd as (select *,
    row_number() over w2 ord_a,
    count(*) over (partition by game_id,seq_no) seq_len,
    bool_or(is_break=1 and is_setpiece) over (partition by game_id,seq_no) seq_sp,
    lag(expanded_minute*60+second) over w2 prev_t,
    lag(x) over w2 prev_x, lag(y) over w2 prev_y, lag(end_x) over w2 prev_ex, lag(end_y) over w2 prev_ey,
    lead(case when is_shot then 1 else 0 end) over w2 next_shot
    from seqd window w2 as (partition by game_id,seq_no order by period,expanded_minute,second,event_id)),
  invv as (
    select player_id, player, team, xt_delta,
      (ord_a=1) f_init,
      (ord_a>1 and ord_a<seq_len and type='Pass' and outcome_type='Successful'
        and ((x<33.3 and end_x>=33.3) or (x<66.7 and end_x>=66.7))) f_bridge,
      (type='Pass' and outcome_type='Successful' and end_x-x>=10) f_prog,
      (type='Pass' and prev_ex is not null and (x-prev_ex)>=6) f_carry,
      (type='Pass' and outcome_type='Successful' and end_x-x>=8 and abs(end_y-y)<=8) f_vert,
      (( type='Pass' and outcome_type='Successful' and end_x-x>0 and degrees(atan2(abs(end_y-y),end_x-x)) between 35 and 55)
        or (prev_ex is not null and prev_ex-prev_x>0 and degrees(atan2(abs(prev_ey-prev_y),prev_ex-prev_x)) between 35 and 55)) f_support,
      (type='TakeOn') f_indiv,
      (type='Pass' and outcome_type='Successful' and next_shot=1) f_creator,
      (x>=83 and y between 21.1 and 78.9) f_box,
      is_shot f_finish,
      case when ord_a>1 then (expanded_minute*60+second)-prev_t end hold
    from ordd where seq_sp=false
  ),
  agg as (
    select player_id, max(player) player, max(team) team, count(*) inv,
      round(sum(xt_delta)::numeric,2) player_xt, round(avg(hold)::numeric,2) hold_secs,
      round(100*avg(f_init::int),1) initiator, round(100*avg(f_bridge::int),1) bridge,
      round(100*avg(f_prog::int),1) progressor, round(100*avg(f_carry::int),1) carrier,
      round(100*avg(f_vert::int),1) vertical, round(100*avg(f_support::int),1) support_angle,
      round(100*avg(f_indiv::int),1) individual, round(100*avg(f_creator::int),1) creator,
      round(100*avg(f_box::int),1) box_threat, round(100*avg(f_finish::int),1) finisher
    from invv group by player_id having count(*)>=120
  )
  select a.player_id, a.player, a.team, coalesce(r.modal_position,'?') pos, a.inv, a.player_xt, a.hold_secs,
    a.initiator, a.bridge, a.progressor, a.carrier, a.vertical, a.support_angle, a.individual, a.creator, a.box_threat, a.finisher
  from agg a left join public.mv_player_role r on r.player_id=a.player_id
  where coalesce(r.modal_position,'?') <> 'GK';
end $function$;

-- 2) one-call matchweek rebuild: contamination gate -> ordered rebuild -> output asserts
CREATE OR REPLACE FUNCTION public.rebuild_all()
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
declare
  wl_ct int; bad_teams text;
  seq_games int; evt_games int; null_xt int; n_seq int; n_pcr int;
begin
  -- gate: refuse to rebuild on contaminated events (fail-open if whitelist empty, e.g. fresh PL db)
  select count(*) into wl_ct from public.team_names;
  if wl_ct > 0 then
    select string_agg(distinct team, ', ') into bad_teams
      from public.events
      where team is not null and team not in (select event_name from public.team_names);
    if bad_teams is not null then
      raise exception 'rebuild aborted — events contain team(s) not in team_names whitelist: %', bad_teams;
    end if;
  end if;

  perform public.refresh_analytics();       -- metric MVs first (mv_player_role for chain-roles)
  perform public.build_sequences();          -- sequence layer
  perform public.build_player_chain_roles(); -- player layer (GK excluded at source)
  refresh materialized view public.seq_fz;   -- similarity vectors off fresh sequences

  -- output invariants: fail loudly rather than leave the site on broken data
  select count(*) into null_xt from public.sequences where xt_sum is null;
  if null_xt > 0 then raise exception 'rebuild produced % sequences with null xt_sum', null_xt; end if;

  select count(distinct game_id) into seq_games from public.sequences;
  select count(distinct game_id) into evt_games from public.events;
  if seq_games <> evt_games then
    raise exception 'game-count mismatch — sequences % vs events %', seq_games, evt_games;
  end if;

  select count(*) into n_seq from public.sequences;
  select count(*) into n_pcr from public.player_chain_roles;
  return format('ok @ %s — %s sequences over %s games, %s outfield players',
    now()::timestamptz(0), n_seq, seq_games, n_pcr);
end $fn$;

revoke execute on function public.rebuild_all() from public, anon, authenticated;
grant execute on function public.rebuild_all() to service_role;
