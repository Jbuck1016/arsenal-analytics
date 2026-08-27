
alter table public.sequences
  add column if not exists mean_pass_len numeric,
  add column if not exists low_build boolean,
  add column if not exists high_build boolean,
  add column if not exists structured boolean,
  add column if not exists has_switch boolean,
  add column if not exists wide_triangles boolean,
  add column if not exists hold_up boolean,
  add column if not exists very_short boolean,
  add column if not exists long_ball boolean,
  add column if not exists ends_opp_half boolean,
  add column if not exists end_around_box boolean,
  add column if not exists finds_central boolean,
  add column if not exists finds_wide boolean,
  add column if not exists n_wide_pass integer,
  add column if not exists n_prog integer,
  add column if not exists n_prog_central integer,
  add column if not exists n_prog_wide integer;

create or replace function public.build_sequences()
returns void language plpgsql as $$
begin
  truncate table public.sequences;

  insert into public.sequences (
    seq_uid, game_id, seq_no, team_id, team, period, start_min, start_sec, dur_s,
    n_events, n_pass, n_players, start_x, start_y, end_x, end_y, start_third, end_third,
    ended_in_box, ended_shot, ended_goal, started_setpiece, is_open_play, xt_sum,
    mean_pass_len, low_build, high_build, structured, has_switch, wide_triangles, hold_up,
    very_short, long_ball, ends_opp_half, end_around_box, finds_central, finds_wide,
    n_wide_pass, n_prog, n_prog_central, n_prog_wide
  )
  with base as (
    select
      game_id, period, expanded_minute, second, event_id,
      team_id, team, player, type, outcome_type, x, y, end_x, end_y, is_shot, is_goal,
      case when type='Pass' and outcome_type='Successful' and end_x is not null
           then coalesce(public.xt_val(end_x,end_y),0)-coalesce(public.xt_val(x,y),0) else 0 end as xt_delta,
      case when type='Pass' and outcome_type='Successful' and end_x is not null
           then sqrt(power(end_x-x,2)+power(end_y-y,2)) end as pass_len,
      (type='Pass' and outcome_type='Successful' and end_x is not null and (end_x-x)>=10) as is_prog,
      (type='Pass' and outcome_type='Successful' and end_x is not null and (end_x-x)>=10
        and ((y+end_y)/2.0) between 21.1 and 78.9) as prog_central,
      (type='Pass' and outcome_type='Successful' and end_x is not null and (end_x-x)>=10
        and ((y+end_y)/2.0) not between 21.1 and 78.9) as prog_wide,
      (type='Pass' and outcome_type='Successful' and (y<21.1 or y>78.9)) as is_wide_pass,
      (type='Pass' and outcome_type='Successful' and (y<21.1 or y>78.9) and x>=50) as is_wide_att,
      (type='Pass' and outcome_type='Successful' and end_x is not null
        and abs(end_y-y)>40 and (y-50)*(end_y-50)<0) as is_switch,
      (type='Pass' and outcome_type='Successful' and x>=66.7 and end_x < x-5) as is_holdup,
      case when jsonb_typeof(qualifiers)='array' then exists (
        select 1 from jsonb_array_elements(qualifiers) q
        where q->'type'->>'displayName' in
          ('ThrowIn','CornerTaken','FreekickTaken','GoalKick','KickOff','Penalty')
      ) else false end as is_setpiece,
      case when type in ('Pass','TakeOn','BallTouch','MissedShots','SavedShot',
                         'ShotOnPost','Goal','KeeperPickup','Claim') then team end as ctrl_team,
      case when type in ('Foul','Card','OffsideGiven','OffsidePass','CornerAwarded','End')
                or is_goal then 1 else 0 end as stop_flag
    from public.events
  ),
  cum as (
    select *, sum(stop_flag) over (partition by game_id
        order by period,expanded_minute,second,event_id
        rows between unbounded preceding and current row) as stop_cum
    from base
  ),
  ctrl as (
    select *, lag(ctrl_team) over w as prev_ctrl_team, lag(stop_cum) over w as prev_stop_cum,
           lag(period) over w as prev_period
    from cum where ctrl_team is not null
    window w as (partition by game_id order by period,expanded_minute,second,event_id)
  ),
  bounded as (
    select *, case when prev_ctrl_team is null or period<>prev_period or ctrl_team<>prev_ctrl_team
                or is_setpiece or stop_cum > coalesce(prev_stop_cum,-1) then 1 else 0 end as is_break
    from ctrl
  ),
  seqd as (
    select *, sum(is_break) over (partition by game_id
        order by period,expanded_minute,second,event_id) as seq_no
    from bounded
  ),
  ordd as (
    select *,
      row_number() over (partition by game_id,seq_no order by period,expanded_minute,second,event_id) as ord_a,
      row_number() over (partition by game_id,seq_no order by period desc,expanded_minute desc,second desc,event_id desc) as ord_d,
      first_value(case when coalesce(end_x,x)>=66.7 then coalesce(end_y,y) end) over (
        partition by game_id,seq_no
        order by (case when coalesce(end_x,x)>=66.7 then 0 else 1 end),
                 period,expanded_minute,second,event_id
        rows between unbounded preceding and unbounded following) as first_att_y
    from seqd
  ),
  agg as (
    select
      game_id||'-'||seq_no as seq_uid, game_id, seq_no,
      max(team_id) filter (where ord_a=1) as team_id,
      max(team)    filter (where ord_a=1) as team,
      max(period)  filter (where ord_a=1) as period,
      max(expanded_minute) filter (where ord_a=1) as start_min,
      max(second)  filter (where ord_a=1) as start_sec,
      max(expanded_minute*60+second)-min(expanded_minute*60+second) as dur_s,
      count(*) as n_events,
      count(*) filter (where type='Pass') as n_pass,
      count(distinct player) as n_players,
      max(x) filter (where ord_a=1) as start_x,
      max(y) filter (where ord_a=1) as start_y,
      max(coalesce(end_x,x)) filter (where ord_d=1) as end_x,
      max(coalesce(end_y,y)) filter (where ord_d=1) as end_y,
      bool_or(is_shot) as ended_shot,
      bool_or(is_goal) as ended_goal,
      bool_or(is_break=1 and is_setpiece) as started_setpiece,
      round(sum(xt_delta)::numeric,4) as xt_sum,
      round(avg(pass_len)::numeric,1) as mean_pass_len,
      max(pass_len) as max_pass_len,
      bool_or(is_switch) as has_switch,
      bool_or(is_holdup) as hold_up,
      count(*) filter (where is_wide_att) as wide_att_ct,
      count(distinct player) filter (where is_wide_att) as wide_att_players,
      count(*) filter (where is_wide_pass) as n_wide_pass,
      count(*) filter (where is_prog) as n_prog,
      count(*) filter (where prog_central) as n_prog_central,
      count(*) filter (where prog_wide) as n_prog_wide,
      max(first_att_y) as first_att_y
    from ordd group by game_id, seq_no
  )
  select
    seq_uid, game_id, seq_no, team_id, team, period, start_min, start_sec, dur_s,
    n_events, n_pass, n_players, start_x, start_y, end_x, end_y,
    case when start_x<33.3 then 'def' when start_x<66.7 then 'mid' else 'att' end,
    case when end_x<33.3 then 'def' when end_x<66.7 then 'mid' else 'att' end,
    (end_x>=83 and end_y between 21.1 and 78.9) as ended_in_box,
    ended_shot, ended_goal, started_setpiece, not started_setpiece as is_open_play, xt_sum,
    mean_pass_len,
    (start_x<33.3) as low_build,
    (start_x>=50) as high_build,
    (start_x<50 and n_pass>=5 and dur_s>=12) as structured,
    has_switch,
    (wide_att_ct>=3 and wide_att_players>=3) as wide_triangles,
    hold_up,
    (mean_pass_len is not null and mean_pass_len<15) as very_short,
    (coalesce(mean_pass_len>26,false) or coalesce(max_pass_len>=40,false)) as long_ball,
    (end_x>=50) as ends_opp_half,
    (end_x>=70 and not (end_x>=83 and end_y between 21.1 and 78.9)) as end_around_box,
    (first_att_y is not null and first_att_y between 21.1 and 78.9) as finds_central,
    (first_att_y is not null and first_att_y not between 21.1 and 78.9) as finds_wide,
    n_wide_pass, n_prog, n_prog_central, n_prog_wide
  from agg;
end;
$$;

select public.build_sequences();
