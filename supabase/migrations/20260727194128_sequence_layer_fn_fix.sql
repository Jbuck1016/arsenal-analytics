
create or replace function public.build_sequences()
returns void
language plpgsql
as $$
begin
  truncate table public.sequences;

  insert into public.sequences
  with base as (
    select
      game_id, period, expanded_minute, second, event_id,
      team_id, team, player, type, x, y, end_x, end_y, is_shot, is_goal,
      case when jsonb_typeof(qualifiers)='array' then exists (
        select 1 from jsonb_array_elements(qualifiers) q
        where q->'type'->>'displayName' in
          ('ThrowIn','CornerTaken','FreekickTaken','GoalKick','KickOff','Penalty')
      ) else false end as is_setpiece,
      case when type in ('Pass','TakeOn','BallTouch','MissedShots','SavedShot',
                         'ShotOnPost','Goal','KeeperPickup','Claim')
           then team end as ctrl_team,
      case when type in ('Foul','Card','OffsideGiven','OffsidePass','CornerAwarded','End')
                or is_goal then 1 else 0 end as stop_flag
    from public.events
  ),
  cum as (
    select *,
      sum(stop_flag) over (partition by game_id
        order by period, expanded_minute, second, event_id
        rows between unbounded preceding and current row) as stop_cum
    from base
  ),
  ctrl as (
    select *,
      lag(ctrl_team) over w as prev_ctrl_team,
      lag(stop_cum)  over w as prev_stop_cum,
      lag(period)    over w as prev_period
    from cum
    where ctrl_team is not null
    window w as (partition by game_id order by period, expanded_minute, second, event_id)
  ),
  bounded as (
    select *,
      case when prev_ctrl_team is null
                or period <> prev_period
                or ctrl_team <> prev_ctrl_team
                or is_setpiece
                or stop_cum > coalesce(prev_stop_cum, -1)
           then 1 else 0 end as is_break
    from ctrl
  ),
  seqd as (
    select *,
      sum(is_break) over (partition by game_id
        order by period, expanded_minute, second, event_id) as seq_no
    from bounded
  ),
  ordd as (
    select *,
      row_number() over (partition by game_id, seq_no
        order by period, expanded_minute, second, event_id) as ord_a,
      row_number() over (partition by game_id, seq_no
        order by period desc, expanded_minute desc, second desc, event_id desc) as ord_d
    from seqd
  )
  select
    game_id || '-' || seq_no                                    as seq_uid,
    game_id,
    seq_no,
    max(team_id) filter (where ord_a=1)                          as team_id,
    max(team)    filter (where ord_a=1)                          as team,
    max(period)  filter (where ord_a=1)                          as period,
    max(expanded_minute) filter (where ord_a=1)                  as start_min,
    max(second)  filter (where ord_a=1)                          as start_sec,
    max(expanded_minute*60+second) - min(expanded_minute*60+second) as dur_s,
    count(*)                                                     as n_events,
    count(*) filter (where type='Pass')                          as n_pass,
    count(distinct player)                                       as n_players,
    max(x) filter (where ord_a=1)                                as start_x,
    max(y) filter (where ord_a=1)                                as start_y,
    max(coalesce(end_x,x)) filter (where ord_d=1)                as end_x,
    max(coalesce(end_y,y)) filter (where ord_d=1)                as end_y,
    case when max(x) filter (where ord_a=1) < 33.3 then 'def'
         when max(x) filter (where ord_a=1) < 66.7 then 'mid'
         else 'att' end                                          as start_third,
    case when max(coalesce(end_x,x)) filter (where ord_d=1) < 33.3 then 'def'
         when max(coalesce(end_x,x)) filter (where ord_d=1) < 66.7 then 'mid'
         else 'att' end                                          as end_third,
    (max(coalesce(end_x,x)) filter (where ord_d=1) >= 83
      and max(coalesce(end_y,y)) filter (where ord_d=1) between 21.1 and 78.9) as ended_in_box,
    bool_or(is_shot)                                             as ended_shot,
    bool_or(is_goal)                                             as ended_goal,
    bool_or(is_break=1 and is_setpiece)                          as started_setpiece,
    not bool_or(is_break=1 and is_setpiece)                      as is_open_play
  from ordd
  group by game_id, seq_no;
end;
$$;
