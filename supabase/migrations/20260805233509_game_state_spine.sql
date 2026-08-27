
-- Goal timeline per match, with own goals credited to the correct side.
-- WhoScored logs an own goal against the scoring player's own team, so it must be flipped.
drop materialized view if exists public.mv_game_goals cascade;
create materialized view public.mv_game_goals as
with gteams as (
  select game_id, array_agg(distinct team) tms from public.events where team is not null group by game_id
),
g as (
  select e.game_id, e.expanded_minute, e.second, e.team,
    case when e.qualifiers is null then false else exists (
      select 1 from jsonb_array_elements(e.qualifiers) q
      where q->'type'->>'displayName' ilike '%own%') end as is_og
  from public.events e where e.is_goal
)
select g.game_id, g.expanded_minute, g.second,
  case when g.is_og then (select t from unnest(gt.tms) t where t <> g.team limit 1) else g.team end as scoring_team,
  g.is_og
from g join gteams gt using (game_id)
where not g.is_og or (select count(*) from unnest(gt.tms) t where t <> g.team) = 1;
create index mv_game_goals_idx on public.mv_game_goals (game_id, expanded_minute);
grant select on public.mv_game_goals to anon, authenticated;

-- Score state at the moment each possession began, from that team's point of view.
drop materialized view if exists public.mv_seq_state cascade;
create materialized view public.mv_seq_state as
select s.seq_uid, s.game_id, s.team, s.start_min,
  count(*) filter (where gg.scoring_team = s.team) as goals_for,
  count(*) filter (where gg.scoring_team is not null and gg.scoring_team <> s.team) as goals_against,
  count(*) filter (where gg.scoring_team = s.team)
    - count(*) filter (where gg.scoring_team is not null and gg.scoring_team <> s.team) as margin,
  case
    when count(*) filter (where gg.scoring_team = s.team)
       > count(*) filter (where gg.scoring_team is not null and gg.scoring_team <> s.team) then 'winning'
    when count(*) filter (where gg.scoring_team = s.team)
       < count(*) filter (where gg.scoring_team is not null and gg.scoring_team <> s.team) then 'losing'
    else 'drawing' end as state,
  -- close game = within one goal, the leverage frame
  (abs(count(*) filter (where gg.scoring_team = s.team)
     - count(*) filter (where gg.scoring_team is not null and gg.scoring_team <> s.team)) <= 1) as is_close
from public.sequences s
left join public.mv_game_goals gg
  on gg.game_id = s.game_id
 and (gg.expanded_minute < s.start_min
      or (gg.expanded_minute = s.start_min and gg.second <= coalesce(s.start_sec, 0)))
group by s.seq_uid, s.game_id, s.team, s.start_min;
create unique index mv_seq_state_pk on public.mv_seq_state (seq_uid);
create index mv_seq_state_team on public.mv_seq_state (team, state);
grant select on public.mv_seq_state to anon, authenticated;
