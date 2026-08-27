
-- Per-involvement map: which player touched the ball at which point in which possession.
-- Segmentation logic is copied verbatim from build_sequences() so seq_uid values align.
drop materialized view if exists public.mv_seq_events cascade;
create materialized view public.mv_seq_events as
with base as (
  select game_id, period, expanded_minute, second, event_id, team, player, player_id, type, is_shot, is_goal,
    case when jsonb_typeof(qualifiers)='array' then exists (
      select 1 from jsonb_array_elements(qualifiers) q
      where q->'type'->>'displayName' in
        ('ThrowIn','CornerTaken','FreekickTaken','GoalKick','KickOff','Penalty')) else false end as is_setpiece,
    case when type in ('Pass','TakeOn','BallTouch','MissedShots','SavedShot',
                       'ShotOnPost','Goal','KeeperPickup','Claim') then team end as ctrl_team,
    case when type in ('Foul','Card','OffsideGiven','OffsidePass','CornerAwarded','End')
              or is_goal then 1 else 0 end as stop_flag
  from public.events),
cum as (select *, sum(stop_flag) over (partition by game_id
      order by period,expanded_minute,second,event_id
      rows between unbounded preceding and current row) as stop_cum from base),
ctrl as (select *, lag(ctrl_team) over w as prev_ctrl_team, lag(stop_cum) over w as prev_stop_cum,
         lag(period) over w as prev_period from cum where ctrl_team is not null
  window w as (partition by game_id order by period,expanded_minute,second,event_id)),
bounded as (select *, case when prev_ctrl_team is null or period<>prev_period or ctrl_team<>prev_ctrl_team
              or is_setpiece or stop_cum > coalesce(prev_stop_cum,-1) then 1 else 0 end as is_break from ctrl),
seqd as (select *, sum(is_break) over (partition by game_id
      order by period,expanded_minute,second,event_id) as seq_no from bounded)
select game_id||'-'||seq_no as seq_uid, game_id, seq_no, player_id, player, team, type, is_shot,
  row_number() over (partition by game_id, seq_no order by period,expanded_minute,second,event_id) as ord_a,
  count(*) over (partition by game_id, seq_no) as chain_len,
  bool_or(is_break=1 and is_setpiece) over (partition by game_id, seq_no) as seq_setpiece
from seqd;
create index mv_seq_events_seq on public.mv_seq_events (seq_uid);
create index mv_seq_events_player on public.mv_seq_events (player_id);
grant select on public.mv_seq_events to anon, authenticated;

-- Chain-position value: is a player in the dangerous possessions, and how early?
-- "Early" = at least 3 actions before the end of the chain, i.e. not the shot or the assist.
drop materialized view if exists public.mv_player_chain_value cascade;
create materialized view public.mv_player_chain_value as
with inv as (
  select se.player_id, se.player, se.team, se.seq_uid, se.ord_a, se.chain_len,
    (se.chain_len - se.ord_a) as steps_from_end,
    s.ended_shot, s.ended_goal, s.xt_sum, s.n_pass
  from public.mv_seq_events se
  join public.sequences s using (seq_uid)
  where se.seq_setpiece = false and s.is_open_play and se.player_id is not null
),
agg as (
  select player_id, max(player) player, max(team) team,
    count(*) involvements,
    count(*) filter (where ended_shot) shot_chain_inv,
    count(*) filter (where ended_shot and steps_from_end >= 3) early_shot_inv,
    count(*) filter (where ended_goal) goal_chain_inv,
    count(*) filter (where ended_goal and steps_from_end >= 3) early_goal_inv,
    round(avg(steps_from_end)::numeric, 2) mean_steps_from_end,
    round(avg(xt_sum)::numeric, 4) mean_chain_xt,
    round(avg(chain_len)::numeric, 2) mean_chain_len
  from inv group by player_id
)
select a.*, ps.pos, ps.pool, ps.nineties,
  round(100.0*a.shot_chain_inv/nullif(a.involvements,0), 2) as shot_chain_pct,
  round(100.0*a.early_shot_inv/nullif(a.involvements,0), 2) as early_shot_pct,
  round(a.early_shot_inv/nullif(ps.nineties,0), 2) as early_shot_inv_90,
  round(a.shot_chain_inv/nullif(ps.nineties,0), 2) as shot_chain_inv_90,
  round(a.early_goal_inv/nullif(ps.nineties,0), 3) as early_goal_inv_90
from agg a
join public.player_search ps on ps.player_id = a.player_id
where a.involvements >= 120;
create unique index mv_player_chain_value_pk on public.mv_player_chain_value (player_id);
grant select on public.mv_player_chain_value to anon, authenticated;
