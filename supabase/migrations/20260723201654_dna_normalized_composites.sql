-- Tag each pillar as a quality axis (more is better) or a style axis
-- (high is different, not better). Style axes are described, not scored.
alter table public.pillar_defs add column if not exists kind text not null default 'quality';
update public.pillar_defs set kind='style' where pillar in ('Tempo','Carrying');

drop materialized view if exists mv_player_dna cascade;

create materialized view mv_player_dna as
with kinds as (select distinct pillar, kind from public.pillar_defs),
s as (
  select p.player_id, p.pool, p.pillar, p.score, k.kind,
         row_number() over (partition by p.player_id, k.kind order by p.score desc) as rk_kind,
         row_number() over (partition by p.player_id order by p.score desc) as rk_all
  from mv_player_pillars p join kinds k on k.pillar = p.pillar
),
raw as (
  select player_id, pool,
    -- overall scores use QUALITY pillars only
    round(avg(score) filter (where kind='quality')::numeric,1)                 as mean_quality,
    round(exp(avg(ln(greatest(score,1))) filter (where kind='quality'))::numeric,1) as completeness_raw,
    round(avg(score) filter (where kind='quality' and rk_kind<=2)::numeric,1)  as impact_raw,
    round(stddev_pop(score) filter (where kind='quality')::numeric,1)          as spread,
    max(case when rk_all=1 then pillar end)                                    as top_pillar,
    max(case when rk_all=2 then pillar end)                                    as second_pillar
  from s group by player_id, pool
),
weak as (
  select distinct on (player_id) player_id, pillar as weakest_pillar, score as weakest_score
  from s where kind='quality' order by player_id, score asc
)
select
  r.player_id, r.pool, r.mean_quality, r.spread,
  r.top_pillar, r.second_pillar, w.weakest_pillar, w.weakest_score,
  r.completeness_raw, r.impact_raw,
  -- normalised within pool so 90 means "top 10% of this role"
  round(100*percent_rank() over (partition by r.pool order by r.completeness_raw)) as completeness,
  round(100*percent_rank() over (partition by r.pool order by r.impact_raw))       as impact
from raw r join weak w using (player_id);
create unique index on mv_player_dna (player_id);

grant select on mv_player_dna to anon, authenticated;
notify pgrst, 'reload schema';
