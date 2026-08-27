-- Pillar definitions are data-driven so the taxonomy can be edited without
-- touching the views. Markers are deliberately chosen to be near-independent:
-- correlated metrics inside one pillar would double-count the same trait.
create table if not exists public.pillar_defs (
  pillar   text not null,
  metric   text not null references public.metric_defs(key),
  weight   numeric not null default 1,
  ord      int,
  primary key (pillar, metric)
);
truncate public.pillar_defs;
insert into public.pillar_defs (pillar, metric, weight, ord) values
 ('Progression','prog_cmp_90',1,1),('Progression','xt_pass_90',1,1),
 ('Creation','xa_90',1,2),('Creation','sca_90',1,2),
 ('Finishing','xg_90',1,3),('Finishing','finishing',1,3),('Finishing','box_share',1,3),
 ('Carrying','prog_carries_90',1,4),('Carrying','takeon_pct',1,4),('Carrying','carry_box_90',1,4),
 ('Tempo','median_ttr',1,5),('Tempo','one_touch_pct',1,5),('Tempo','quick_pct',1,5),
 ('Defending','padj_def_90',1,6),('Defending','tackle_pct',1,6),
 ('Defending','counterpress_90',1,6),('Defending','aq_per_duel',1,6),
 ('Security','pass_pct',1,7),('Security','disp_90',1,7),
 ('Security','badtouch_90',1,7),('Security','error_90',1,7);

create materialized view mv_player_pillars as
select
  p.player_id, p.pool, d.pillar, min(d.ord) as ord,
  round((sum(p.pct * d.weight) / nullif(sum(d.weight),0))::numeric, 1) as score,
  count(*) as markers_used
from mv_player_percentiles p
join public.pillar_defs d on d.metric = p.metric
where p.pool <> 'GK'
group by p.player_id, p.pool, d.pillar;
create index on mv_player_pillars (player_id);
create unique index on mv_player_pillars (player_id, pillar);

-- Two overall scores, deliberately answering different questions:
--   Completeness: geometric mean, so a weak pillar cannot be bought back
--                 by strength elsewhere. Rewards the floor.
--   Impact:       mean of the two strongest pillars, so a specialist is not
--                 punished for specialising. Rewards the ceiling.
create materialized view mv_player_dna as
with s as (
  select player_id, pool, pillar, score,
         row_number() over (partition by player_id order by score desc) as rk
  from mv_player_pillars
),
agg as (
  select player_id, pool,
    count(*) as pillars,
    round(avg(score)::numeric,1)                                   as mean_score,
    round(exp(avg(ln(greatest(score,1))))::numeric,1)              as completeness,
    round(avg(score) filter (where rk <= 2)::numeric,1)            as impact,
    round(stddev_pop(score)::numeric,1)                            as spread,
    max(case when rk=1 then pillar end)                            as top_pillar,
    max(case when rk=2 then pillar end)                            as second_pillar,
    min(score)                                                     as weakest_score,
    max(case when rk=(select count(*) from s s2 where s2.player_id=s.player_id) then pillar end) as weakest_pillar
  from s group by player_id, pool
)
select * from agg;
create unique index on mv_player_dna (player_id);

grant select on public.pillar_defs, mv_player_pillars, mv_player_dna to anon, authenticated;
notify pgrst, 'reload schema';
