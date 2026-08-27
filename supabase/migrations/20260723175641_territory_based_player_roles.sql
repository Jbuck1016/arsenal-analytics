-- Corrected slot mapping. DML/DMR are WIDE defensive midfielders (wing-backs),
-- not central midfielders -- previously folded into CM, which was wrong.
drop materialized view if exists mv_player_pool cascade;

create materialized view mv_player_pool as
with mins_by_pos as (
  select player_id, position, sum(minutes) as mins
  from mv_player_minutes
  where is_starter and position <> 'Sub'
  group by player_id, position
),
modal as (
  select distinct on (player_id) player_id, position as modal_position
  from mins_by_pos order by player_id, mins desc, position
)
select
  player_id, modal_position,
  case modal_position
    when 'GK'  then 'GK'
    when 'DC'  then 'CB'
    when 'DR'  then 'FB'  when 'DL'  then 'FB'
    when 'DML' then 'FB'  when 'DMR' then 'FB'   -- wing-backs, corrected
    when 'DMC' then 'CM'  when 'MC'  then 'CM'
    when 'AMC' then 'AM'
    when 'ML'  then 'W'   when 'MR'  then 'W'
    when 'AML' then 'W'   when 'AMR' then 'W'
    when 'FWL' then 'W'   when 'FWR' then 'W'
    when 'FW'  then 'ST'
  end as listed_pool,
  case
    when modal_position in ('DL','ML','AML','FWL','DML') then 'L'
    when modal_position in ('DR','MR','AMR','FWR','DMR') then 'R'
    else 'C'
  end as nominal_side
from modal;
create unique index on mv_player_pool (player_id);

-- Territory-based role assignment.
-- Nearest-centroid in z-scored spatial feature space, centroids seeded from the
-- corrected listed pools. Outfield only; keepers pass through untouched.
-- Players below the confidence threshold keep their listed pool.
create materialized view mv_player_role as
with elig as (
  select p.player_id, p.modal_position, p.listed_pool, p.nominal_side,
         s.nineties, t.touches,
         t.avg_x, t.centrality, t.pct_box, t.pct_def_third, d.pct_def_actions,
         (s.nineties >= 6 and t.touches >= 200 and p.listed_pool <> 'GK') as classifiable
  from mv_player_pool p
  join mv_player_season s using (player_id)
  left join mv_player_territory t using (player_id)
  left join mv_player_defload d using (player_id)
),
pop as (select * from elig where classifiable),
st as (
  select avg(avg_x) ax, stddev_pop(avg_x) sx, avg(centrality) ac, stddev_pop(centrality) sc,
         avg(pct_box) ab, stddev_pop(pct_box) sb, avg(pct_def_third) ad, stddev_pop(pct_def_third) sd,
         avg(pct_def_actions) af, stddev_pop(pct_def_actions) sf
  from pop
),
z as (
  select p.*, (p.avg_x-st.ax)/nullif(st.sx,0) zx, (p.centrality-st.ac)/nullif(st.sc,0) zc,
         (p.pct_box-st.ab)/nullif(st.sb,0) zb, (p.pct_def_third-st.ad)/nullif(st.sd,0) zd,
         (p.pct_def_actions-st.af)/nullif(st.sf,0) zf
  from pop p cross join st
),
cent as (select listed_pool as pool, avg(zx) cx, avg(zc) cc, avg(zb) cb, avg(zd) cd, avg(zf) cf
         from z group by listed_pool),
dist as (
  select z.player_id, c.pool as cand,
         sqrt(power(z.zx-c.cx,2)+power(z.zc-c.cc,2)+power(z.zb-c.cb,2)
              +power(z.zd-c.cd,2)+power(z.zf-c.cf,2)) as d
  from z cross join cent c
),
ranked as (
  select player_id, cand, d, row_number() over (partition by player_id order by d) as rn
  from dist
),
assigned as (
  select a.player_id, a.cand as territory_pool, round(a.d::numeric,3) as dist_best,
         round(b.d::numeric,3) as dist_next,
         round((b.d - a.d)::numeric, 3) as margin
  from ranked a join ranked b on b.player_id = a.player_id and b.rn = 2
  where a.rn = 1
)
select
  e.player_id, e.modal_position, e.listed_pool, e.nominal_side,
  e.nineties, e.touches, e.classifiable,
  coalesce(a.territory_pool, e.listed_pool) as pool,
  a.dist_best, a.dist_next, a.margin,
  (a.territory_pool is not null and a.territory_pool <> e.listed_pool) as reassigned,
  case
    when not e.classifiable       then 'low_sample'
    when a.margin >= 0.75         then 'high'
    when a.margin >= 0.35         then 'medium'
    else 'low'
  end as confidence
from elig e
left join assigned a using (player_id);
create unique index on mv_player_role (player_id);

grant select on mv_player_pool, mv_player_role to anon, authenticated;
