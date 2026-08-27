-- Completeness is role-relative: what makes a forward "complete" is not what
-- makes a centre-back complete. Weights are 0-5 per role per pillar and replace
-- the earlier blanket quality/style split, which mishandled Carrying (style for
-- a CB, core for a winger).
create table if not exists public.role_pillar_weights (
  pool   text not null,
  pillar text not null,
  weight numeric not null default 0,
  primary key (pool, pillar)
);
truncate public.role_pillar_weights;
insert into public.role_pillar_weights (pool,pillar,weight) values
 ('CB','Progression',3),('CB','Creation',0),('CB','Finishing',0),('CB','Carrying',1),('CB','Defending',5),('CB','Security',4),('CB','Tempo',0),
 ('FB','Progression',4),('FB','Creation',3),('FB','Finishing',1),('FB','Carrying',3),('FB','Defending',4),('FB','Security',3),('FB','Tempo',0),
 ('CM','Progression',5),('CM','Creation',4),('CM','Finishing',1),('CM','Carrying',3),('CM','Defending',4),('CM','Security',4),('CM','Tempo',0),
 ('AM','Progression',4),('AM','Creation',5),('AM','Finishing',3),('AM','Carrying',4),('AM','Defending',1),('AM','Security',3),('AM','Tempo',0),
 ('W','Progression',3), ('W','Creation',5), ('W','Finishing',4), ('W','Carrying',5), ('W','Defending',1), ('W','Security',2), ('W','Tempo',0),
 ('ST','Progression',2),('ST','Creation',3),('ST','Finishing',5),('ST','Carrying',3),('ST','Defending',1),('ST','Security',2),('ST','Tempo',0);

drop materialized view if exists mv_player_dna cascade;

create materialized view mv_player_dna as
with w as (
  select p.player_id, p.pool, p.pillar, p.score, coalesce(rw.weight,0) as weight
  from mv_player_pillars p
  left join public.role_pillar_weights rw on rw.pool = p.pool and rw.pillar = p.pillar
),
ranked as (
  select *, row_number() over (partition by player_id order by score desc) as rk_all,
            row_number() over (partition by player_id order by (score*weight) desc) as rk_rel
  from w
),
raw as (
  select player_id, pool,
    -- weighted geometric mean over the pillars that matter for the role
    round(exp( sum(weight * ln(greatest(score,1))) filter (where weight > 0)
             / nullif(sum(weight) filter (where weight > 0),0) )::numeric, 1) as completeness_raw,
    -- ceiling: the two strongest role-relevant pillars
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
       round(100*percent_rank() over (partition by r.pool order by r.completeness_raw)) as completeness,
       round(100*percent_rank() over (partition by r.pool order by r.impact_raw))       as impact
from raw r join weak w2 using (player_id);
create unique index on mv_player_dna (player_id);

grant select on public.role_pillar_weights, mv_player_dna to anon, authenticated;
notify pgrst, 'reload schema';
