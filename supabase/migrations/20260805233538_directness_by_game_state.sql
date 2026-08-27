
-- Possession directness = net upfield progress as a share of total distance travelled.
-- 1.0 = straight at goal, 0 = sideways/backwards churn. Open play only.
drop view if exists public.v_seq_directness cascade;
create view public.v_seq_directness as
select s.seq_uid, s.game_id, s.team, s.n_pass, s.dur_s,
  greatest(-1.0, least(1.0,
    (s.end_x - s.start_x)::numeric / nullif(s.mean_pass_len * s.n_pass, 0)
  )) as directness,
  st.state, st.margin, st.is_close
from public.sequences s
join public.mv_seq_state st using (seq_uid)
where s.is_open_play and s.n_pass >= 2 and coalesce(s.mean_pass_len,0) > 0;

-- Team directness split by game state, with the losing-minus-winning swing.
drop materialized view if exists public.mv_team_directness_state cascade;
create materialized view public.mv_team_directness_state as
with base as (
  select team, state, round(avg(directness)::numeric, 4) directness, count(*) n
  from public.v_seq_directness group by team, state
),
piv as (
  select team,
    max(directness) filter (where state='winning') dir_winning,
    max(directness) filter (where state='drawing') dir_drawing,
    max(directness) filter (where state='losing')  dir_losing,
    sum(n) filter (where state='winning') n_winning,
    sum(n) filter (where state='drawing') n_drawing,
    sum(n) filter (where state='losing')  n_losing,
    round(avg(directness)::numeric,4) dir_overall
  from base group by team
)
select *,
  round((dir_losing - dir_winning)::numeric, 4) as swing_l_minus_w,
  rank() over (order by (dir_losing - dir_winning) desc) as swing_rank
from piv;
create unique index mv_team_directness_state_pk on public.mv_team_directness_state (team);
grant select on public.v_seq_directness, public.mv_team_directness_state to anon, authenticated;
