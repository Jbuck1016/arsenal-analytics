
-- Directness swing ranked within league
drop materialized view if exists public.mv_team_directness_state cascade;
create materialized view public.mv_team_directness_state as
with base as (
  select d.team, coalesce(tl.league,'USA-MLS') league, d.state,
    round(avg(d.directness)::numeric,4) directness, count(*) n
  from public.v_seq_directness d
  left join public.mv_team_league tl on tl.team = d.team
  group by d.team, coalesce(tl.league,'USA-MLS'), d.state
),
piv as (
  select team, league,
    max(directness) filter (where state='winning') dir_winning,
    max(directness) filter (where state='drawing') dir_drawing,
    max(directness) filter (where state='losing')  dir_losing,
    sum(n) filter (where state='winning') n_winning,
    sum(n) filter (where state='drawing') n_drawing,
    sum(n) filter (where state='losing')  n_losing,
    round(avg(directness)::numeric,4) dir_overall
  from base group by team, league
)
select *, round((dir_losing - dir_winning)::numeric,4) as swing_l_minus_w,
  rank() over (partition by league order by (dir_losing - dir_winning) desc) as swing_rank
from piv;
create unique index mv_team_directness_state_pk on public.mv_team_directness_state (team);
grant select on public.mv_team_directness_state to anon, authenticated;

-- Route taxonomy: share and productivity z-scored within league
drop materialized view if exists public.mv_team_breakdown cascade;
create materialized view public.mv_team_breakdown as
with routes as (
  select s.team, coalesce(tl.league,'USA-MLS') league, r.route, r.used,
    s.ended_shot, s.ended_in_box, s.xt_sum
  from public.sequences s
  left join public.mv_team_league tl on tl.team = s.team
  cross join lateral (values
    ('Through the middle', s.finds_central),('Around the outside', s.finds_wide),
    ('Switch of play', s.has_switch),('Over the top', s.long_ball),
    ('Wide combinations', s.wide_triangles),('Hold-up and lay', s.hold_up),
    ('Patient build', s.structured),('From deep', s.low_build),('High regain', s.high_build)
  ) r(route, used)
  where s.is_open_play
),
agg as (
  select team, league, route,
    count(*) filter (where used) as seqs,
    round(100.0*avg(used::int), 1) as share_pct,
    round(100.0*avg(ended_shot::int) filter (where used), 1) as shot_pct,
    round(100.0*avg(ended_in_box::int) filter (where used), 1) as box_pct,
    round(avg(xt_sum) filter (where used), 4) as xt_per_seq
  from routes group by team, league, route
),
lg as (
  select league, route, avg(shot_pct) lg_shot, stddev_samp(shot_pct) sd_shot,
         avg(share_pct) lg_share, stddev_samp(share_pct) sd_share
  from agg group by league, route
)
select a.*,
  rank() over (partition by a.league, a.route order by a.share_pct desc) as share_rank,
  rank() over (partition by a.league, a.route order by a.shot_pct desc)  as productivity_rank,
  round(((a.share_pct - lg.lg_share)/nullif(lg.sd_share,0))::numeric, 2) as z_share,
  round(((a.shot_pct - lg.lg_shot)/nullif(lg.sd_shot,0))::numeric, 2)  as z_productivity
from agg a join lg on lg.league = a.league and lg.route = a.route;
create index mv_team_breakdown_team on public.mv_team_breakdown (team);
grant select on public.mv_team_breakdown to anon, authenticated;

create or replace view public.v_team_signature as
select distinct on (team) team, route as signature_route,
  share_pct, z_share, shot_pct, z_productivity,
  case when z_productivity >= 0.5 then 'effective'
       when z_productivity <= -0.5 then 'unproductive'
       else 'league average' end as signature_verdict,
  league
from public.mv_team_breakdown
order by team, z_share desc;
grant select on public.v_team_signature to anon, authenticated;

-- Press containment: league baseline per build-up type must be per league
drop materialized view if exists public.mv_press_vs_buildup cascade;
create materialized view public.mv_press_vs_buildup as
with gteams as (select game_id, array_agg(distinct team) tms from public.sequences group by game_id),
opp as (
  select s.seq_uid, s.game_id, s.team as attacking_team,
    (select t from unnest(gt.tms) t where t <> s.team limit 1) as defending_team,
    s.league,
    case when s.long_ball then 'direct' when s.start_x < 33.3 then 'short_build'
         when s.start_x >= 50 then 'high_start' else 'mid_start' end as buildup_type,
    s.end_x, s.end_third, s.ended_shot, s.ended_in_box, s.n_pass, s.dur_s
  from public.sequences s join gteams gt using (game_id) where s.is_open_play
)
select defending_team, league, buildup_type, count(*) as n,
  round(100.0*avg((end_x < 66.7 and not ended_shot)::int), 1) as contained_pct,
  round(100.0*avg((end_third = 'def')::int), 1) as died_in_their_third_pct,
  round(100.0*avg(ended_shot::int), 1) as conceded_shot_pct,
  round(100.0*avg(ended_in_box::int), 1) as conceded_box_pct,
  round(avg(n_pass)::numeric, 2) as opp_passes_per_seq,
  round(avg(dur_s)::numeric, 1) as opp_secs_per_seq
from opp where defending_team is not null
group by defending_team, league, buildup_type;
create index mv_press_vs_buildup_team on public.mv_press_vs_buildup (defending_team);
grant select on public.mv_press_vs_buildup to anon, authenticated;

create or replace view public.v_press_profile as
with lg as (
  select league, buildup_type,
    avg(contained_pct) lg_contained, stddev_samp(contained_pct) sd_contained,
    avg(conceded_shot_pct) lg_shot,  stddev_samp(conceded_shot_pct) sd_shot
  from public.mv_press_vs_buildup group by league, buildup_type
),
z as (
  select p.defending_team as team, p.league, p.buildup_type, p.n, p.contained_pct, p.conceded_shot_pct,
    round(((p.contained_pct - lg.lg_contained)/nullif(lg.sd_contained,0))::numeric, 2) as z_contained,
    round(((lg.lg_shot - p.conceded_shot_pct)/nullif(lg.sd_shot,0))::numeric, 2) as z_shot_prevention
  from public.mv_press_vs_buildup p join lg on lg.league=p.league and lg.buildup_type=p.buildup_type
)
select team,
  max(z_contained) filter (where buildup_type='short_build') as z_vs_short_build,
  max(z_contained) filter (where buildup_type='direct')      as z_vs_direct,
  max(z_contained) filter (where buildup_type='high_start')  as z_vs_high_start,
  max(z_shot_prevention) filter (where buildup_type='short_build') as z_shotprev_vs_short,
  max(z_shot_prevention) filter (where buildup_type='direct')      as z_shotprev_vs_direct,
  round((max(z_contained) filter (where buildup_type='short_build')
       - max(z_contained) filter (where buildup_type='direct'))::numeric, 2) as short_vs_direct_tilt,
  max(contained_pct) filter (where buildup_type='short_build') as raw_vs_short_build,
  max(contained_pct) filter (where buildup_type='direct')      as raw_vs_direct,
  min(league) as league
from z group by team;
grant select on public.v_press_profile to anon, authenticated;
