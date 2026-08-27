
-- "How they break you": route taxonomy per team, with how OFTEN each route is used
-- and how WELL it works. Share alone is style; share plus productivity is a plan.
drop materialized view if exists public.mv_team_breakdown cascade;
create materialized view public.mv_team_breakdown as
with routes as (
  select s.team, r.route, r.used, s.ended_shot, s.ended_in_box, s.xt_sum, s.seq_uid
  from public.sequences s
  cross join lateral (values
    ('Through the middle', s.finds_central),
    ('Around the outside', s.finds_wide),
    ('Switch of play',     s.has_switch),
    ('Over the top',       s.long_ball),
    ('Wide combinations',  s.wide_triangles),
    ('Hold-up and lay',    s.hold_up),
    ('Patient build',      s.structured),
    ('From deep',          s.low_build),
    ('High regain',        s.high_build)
  ) r(route, used)
  where s.is_open_play
),
agg as (
  select team, route,
    count(*) filter (where used) as seqs,
    round(100.0*avg(used::int), 1) as share_pct,
    round(100.0*avg(ended_shot::int) filter (where used), 1) as shot_pct,
    round(100.0*avg(ended_in_box::int) filter (where used), 1) as box_pct,
    round(avg(xt_sum) filter (where used), 4) as xt_per_seq
  from routes group by team, route
),
lg as (
  select route, avg(shot_pct) lg_shot, stddev_samp(shot_pct) sd_shot,
         avg(share_pct) lg_share, stddev_samp(share_pct) sd_share
  from agg group by route
)
select a.*,
  rank() over (partition by a.route order by a.share_pct desc) as share_rank,
  rank() over (partition by a.route order by a.shot_pct desc)  as productivity_rank,
  round(((a.share_pct - lg.lg_share)/nullif(lg.sd_share,0))::numeric, 2) as z_share,
  round(((a.shot_pct - lg.lg_shot)/nullif(lg.sd_shot,0))::numeric, 2)  as z_productivity
from agg a join lg on lg.route = a.route;
create index mv_team_breakdown_team on public.mv_team_breakdown (team);
grant select on public.mv_team_breakdown to anon, authenticated;

-- Signature route: what a side leans on most relative to the league, and whether it pays.
create or replace view public.v_team_signature as
select distinct on (team) team, route as signature_route,
  share_pct, z_share, shot_pct, z_productivity,
  case when z_productivity >= 0.5 then 'effective'
       when z_productivity <= -0.5 then 'unproductive'
       else 'league average' end as signature_verdict
from public.mv_team_breakdown
order by team, z_share desc;
grant select on public.v_team_signature to anon, authenticated;
