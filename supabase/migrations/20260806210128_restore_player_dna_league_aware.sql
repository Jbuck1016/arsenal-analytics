
-- Restore mv_player_dna (lost to a cascade two levels deep off mv_player_percentiles).
-- Completeness/impact percentiles now rank within league as well as pool.
create unique index if not exists mv_player_pillars_uq on public.mv_player_pillars (player_id, pillar);

drop materialized view if exists public.mv_player_dna cascade;
create materialized view public.mv_player_dna as
with w as (
  select p.player_id, p.pool, p.pillar, p.score, p.league, coalesce(rw.weight,0) as weight
  from public.mv_player_pillars p
  left join public.role_pillar_weights rw on rw.pool = p.pool and rw.pillar = p.pillar
),
ranked as (
  select *, row_number() over (partition by player_id order by score desc) as rk_all,
            row_number() over (partition by player_id order by (score*weight) desc) as rk_rel
  from w
),
raw as (
  select player_id, pool, min(league) as league,
    round(exp( sum(weight * ln(greatest(score,1))) filter (where weight > 0)
             / nullif(sum(weight) filter (where weight > 0),0) )::numeric, 1) as completeness_raw,
    round(avg(score) filter (where weight > 0 and rk_rel <= 2)::numeric,1)     as impact_raw,
    round(avg(score) filter (where weight > 0)::numeric,1)                     as mean_relevant,
    round(stddev_pop(score) filter (where weight > 0)::numeric,1)              as spread,
    max(case when rk_all = 1 then pillar end)                                  as top_pillar,
    max(case when rk_all = 2 then pillar end)                                  as second_pillar
  from ranked group by player_id, pool
),
weak as (
  select distinct on (player_id) player_id, pillar as weakest_pillar, score as weakest_score
  from ranked where weight > 0 order by player_id, score asc
)
select r.player_id, r.pool, r.mean_relevant, r.spread,
       r.top_pillar, r.second_pillar, w2.weakest_pillar, w2.weakest_score,
       r.completeness_raw, r.impact_raw,
       round(100*percent_rank() over (partition by r.league, r.pool order by r.completeness_raw)) as completeness,
       round(100*percent_rank() over (partition by r.league, r.pool order by r.impact_raw))       as impact,
       r.league
from raw r join weak w2 using (player_id);
create unique index mv_player_dna_pk on public.mv_player_dna (player_id);
grant select on public.mv_player_dna to anon, authenticated;
notify pgrst, 'reload schema';
