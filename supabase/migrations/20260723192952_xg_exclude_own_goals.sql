drop materialized view if exists mv_shot_xg cascade;
drop materialized view if exists mv_xg_bins cascade;
drop materialized view if exists mv_shot_features cascade;

create materialized view mv_shot_features as
select
  e.game_id, e.ws_id, e.player_id, e.player, e.team, e.is_goal, e.is_open_play,
  e.x, e.y,
  sqrt(power((100-e.x)*1.05,2) + power((50-e.y)*0.68,2))            as dist_m,
  degrees(
    case when (power((100-e.x)*1.05,2) + power((e.y-50)*0.68,2) - power(3.66,2)) <= 0 then pi()
         else atan( (7.32*((100-e.x)*1.05)) /
                    (power((100-e.x)*1.05,2) + power((e.y-50)*0.68,2) - power(3.66,2)) ) end
  )                                                                  as angle_deg,
  e.qualifiers @> '[{"type":{"displayName":"Head"}}]'::jsonb         as is_header,
  e.qualifiers @> '[{"type":{"displayName":"BigChance"}}]'::jsonb    as is_bigchance,
  e.qualifiers @> '[{"type":{"displayName":"Penalty"}}]'::jsonb      as is_pen
from public.events e
where e.is_shot and e.x is not null and e.y is not null
  -- own goals are logged at the shooter's own end and would wreck the fit
  and not (e.qualifiers @> '[{"type":{"displayName":"OwnGoal"}}]'::jsonb);
create unique index on mv_shot_features (game_id, ws_id);

create materialized view mv_xg_bins as
with s as (
  select *,
    case when dist_m < 6 then 1 when dist_m < 11 then 2 when dist_m < 16 then 3
         when dist_m < 22 then 4 when dist_m < 30 then 5 else 6 end as d_bin,
    case when angle_deg < 12 then 1 when angle_deg < 25 then 2 else 3 end as a_bin
  from mv_shot_features where not is_pen
),
g as (select avg(case when is_goal then 1.0 else 0 end) as base from s)
select s.d_bin, s.a_bin, s.is_header, s.is_bigchance,
  count(*) as n, sum(case when s.is_goal then 1 else 0 end) as goals,
  round(((sum(case when s.is_goal then 1 else 0 end) + 20*g.base)/(count(*) + 20))::numeric,4) as xg
from s cross join g
group by s.d_bin, s.a_bin, s.is_header, s.is_bigchance, g.base;
create unique index on mv_xg_bins (d_bin, a_bin, is_header, is_bigchance);

create materialized view mv_shot_xg as
select f.game_id, f.ws_id, f.player_id, f.player, f.team, f.is_goal, f.is_open_play, f.is_pen,
  round(f.dist_m::numeric,1) as dist_m, round(f.angle_deg::numeric,1) as angle_deg,
  f.is_header, f.is_bigchance,
  case when f.is_pen then 0.76 else coalesce(b.xg,0.05) end as xg
from mv_shot_features f
left join mv_xg_bins b
  on b.d_bin = case when f.dist_m < 6 then 1 when f.dist_m < 11 then 2 when f.dist_m < 16 then 3
                    when f.dist_m < 22 then 4 when f.dist_m < 30 then 5 else 6 end
 and b.a_bin = case when f.angle_deg < 12 then 1 when f.angle_deg < 25 then 2 else 3 end
 and b.is_header = f.is_header and b.is_bigchance = f.is_bigchance;
create unique index on mv_shot_xg (game_id, ws_id);
create index on mv_shot_xg (player_id);

grant select on mv_shot_features, mv_xg_bins, mv_shot_xg to anon, authenticated;
