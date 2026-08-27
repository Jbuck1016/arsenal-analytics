create materialized view mv_team_buildphase as
with m as (select team, count(*) as matches from mv_team_match group by team),
gk as (
  select e.team,
    count(*) filter (where e.type='Pass')                                        as gk_passes,
    count(*) filter (where e.type='Pass'
      and e.qualifiers @> '[{"type":{"displayName":"Longball"}}]'::jsonb)        as gk_long
  from public.events e
  join mv_player_pool p on p.player_id = e.player_id and p.modal_position='GK'
  group by e.team
),
deep as (
  select e.team,
    count(*) filter (where e.type='Pass' and e.x < 33.3)                         as d3_passes,
    count(*) filter (where e.type='Pass' and e.x < 33.3 and e.outcome_type='Successful') as d3_ok,
    count(*) filter (where e.type='Pass' and e.x < 33.3
      and e.qualifiers @> '[{"type":{"displayName":"Longball"}}]'::jsonb)        as d3_long,
    count(*) filter (where e.type='Pass' and e.x < 33.3 and e.end_x < 33.3
      and e.outcome_type='Successful')                                          as d3_circulate,
    count(*) filter (where e.type='Pass')                                        as all_passes,
    count(*) filter (where e.is_touch and e.x < 33.3)                            as d3_touches,
    count(*) filter (where e.is_touch)                                           as all_touches
  from public.events e where e.team is not null and e.x is not null
  group by e.team
),
cb as (
  select e.team,
    count(*) filter (where e.outcome_type='Successful' and (
      (e.x<50 and e.end_x<50 and (e.end_x-e.x)>=30) or
      (e.x<50 and e.end_x>=50 and (e.end_x-e.x)>=15) or
      (e.x>=50 and e.end_x>=50 and (e.end_x-e.x)>=10)))                          as cb_prog
  from public.events e
  join mv_player_role r on r.player_id = e.player_id and r.pool='CB'
  where e.type='Pass'
  group by e.team
),
exits as (
  select team,
    count(*) filter (where start_x < 33.3)                       as deep_starts,
    count(*) filter (where start_x < 33.3 and max_x >= 66.7)     as deep_to_final,
    count(*) filter (where start_x < 33.3 and max_x >= 50)       as deep_to_half
  from mv_team_sequences group by team
)
select
  d.team,
  round(100.0*g.gk_long/nullif(g.gk_passes,0),1)              as gk_long_pct,
  round(d.d3_passes::numeric/nullif(m.matches,0),1)           as d3_passes_pg,
  round(100.0*d.d3_passes/nullif(d.all_passes,0),1)           as d3_pass_share,
  round(100.0*d.d3_ok/nullif(d.d3_passes,0),1)                as d3_accuracy,
  round(100.0*d.d3_long/nullif(d.d3_passes,0),1)              as d3_long_pct,
  round(d.d3_circulate::numeric/nullif(m.matches,0),1)        as deep_circulation_pg,
  round(100.0*d.d3_touches/nullif(d.all_touches,0),1)         as d3_touch_share,
  round(c.cb_prog::numeric/nullif(m.matches,0),1)             as cb_prog_pg,
  round(100.0*e.deep_to_half/nullif(e.deep_starts,0),1)       as escape_pct,
  round(100.0*e.deep_to_final/nullif(e.deep_starts,0),1)      as deep_to_final_pct
from deep d
join m on m.team=d.team
left join gk g on g.team=d.team
left join cb c on c.team=d.team
left join exits e on e.team=d.team;
create unique index on mv_team_buildphase (team);

create materialized view mv_team_attackphase as
with m as (select team, count(*) as matches from mv_team_match group by team),
att as (
  select e.team,
    count(*) filter (where e.type='Pass' and e.x>=50 and e.outcome_type='Successful') as att_passes,
    coalesce(sum(greatest(0,e.end_x-e.x)*1.05) filter
      (where e.type='Pass' and e.x>=50 and e.outcome_type='Successful'),0)            as att_territory,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful'
      and e.x<66.7 and e.end_x>=66.7)                                                 as ft_entries,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful'
      and e.end_x>=83 and e.end_y between 21 and 79)                                  as box_entries,
    count(*) filter (where e.is_shot)                                                 as shots,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful')             as all_ok_passes
  from public.events e where e.team is not null and e.x is not null
  group by e.team
),
tempo as (
  select team,
    percentile_cont(0.5) within group (order by ttr) filter (where end_x>=66.7) as ft_ttr,
    percentile_cont(0.5) within group (order by ttr) filter (where end_x>=33.3 and end_x<66.7) as mid_ttr
  from mv_receipt_events group by team
),
carries as (
  select team, count(*) filter (where start_x<66.7 and end_x>=66.7) as carry_entries
  from mv_receipt_events where is_carry group by team
),
seq as (
  select team,
    count(*) filter (where max_x>=66.7)                        as reached_final,
    count(*) filter (where max_x>=66.7 and ended_in_shot)      as final_to_shot
  from mv_team_sequences group by team
)
select
  a.team,
  round((a.att_territory/nullif(a.att_passes,0))::numeric,2)      as att_directness,
  round(t.ft_ttr::numeric,2)                                      as ft_release,
  round(t.mid_ttr::numeric,2)                                     as mid_release,
  round(a.all_ok_passes::numeric/nullif(a.shots,0),1)             as passes_per_shot,
  round((a.ft_entries + coalesce(c.carry_entries,0))::numeric/nullif(m.matches,0),1) as ft_entries_pg,
  round(a.box_entries::numeric/nullif(m.matches,0),1)             as box_entries_pg2,
  round(100.0*a.box_entries/nullif(a.ft_entries + coalesce(c.carry_entries,0),0),1) as box_per_entry,
  round(100.0*s.final_to_shot/nullif(s.reached_final,0),1)        as final_to_shot_pct
from att a
join m on m.team=a.team
left join tempo t on t.team=a.team
left join carries c on c.team=a.team
left join seq s on s.team=a.team;
create unique index on mv_team_attackphase (team);

grant select on mv_team_buildphase, mv_team_attackphase to anon, authenticated;
