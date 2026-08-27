
-- Raw containment is dominated by build-up mechanics (direct play travels further by
-- definition), so team quality only shows up RELATIVE TO THE LEAGUE for the same type.
drop view if exists public.v_press_profile cascade;
create view public.v_press_profile as
with lg as (
  select buildup_type,
    avg(contained_pct) lg_contained, stddev_samp(contained_pct) sd_contained,
    avg(conceded_shot_pct) lg_shot,   stddev_samp(conceded_shot_pct) sd_shot
  from public.mv_press_vs_buildup group by buildup_type
),
z as (
  select p.defending_team as team, p.buildup_type, p.n, p.contained_pct, p.conceded_shot_pct,
    round(((p.contained_pct - lg.lg_contained)/nullif(lg.sd_contained,0))::numeric, 2) as z_contained,
    round(((lg.lg_shot - p.conceded_shot_pct)/nullif(lg.sd_shot,0))::numeric, 2) as z_shot_prevention
  from public.mv_press_vs_buildup p join lg using (buildup_type)
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
  max(contained_pct) filter (where buildup_type='direct')      as raw_vs_direct
from z group by team;
grant select on public.v_press_profile to anon, authenticated;
