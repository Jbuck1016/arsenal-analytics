
-- Ball progression: separates TENDENCY (how often he tries it) from SUCCESS (how often it works).
-- Progressive pass = forward pass advancing >= 10 pitch units (~10m), consistent with the chain-role layer.
drop materialized view if exists public.mv_player_progression cascade;
create materialized view public.mv_player_progression as
with pa as (
  select e.player_id,
    count(*) filter (where e.type='Pass') as passes_att,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful') as passes_cmp,
    count(*) filter (where e.type='Pass' and e.end_x is not null and (e.end_x-e.x) >= 10) as prog_att,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful'
                      and e.end_x is not null and (e.end_x-e.x) >= 10) as prog_cmp,
    count(*) filter (where e.type='Pass' and e.outcome_type='Successful'
                      and e.end_x is not null and (e.end_x-e.x) >= 10 and e.end_x >= 66.7) as prog_into_final,
    sum(case when e.type='Pass' and e.outcome_type='Successful' and e.end_x is not null
             then coalesce(public.xt_val(e.end_x,e.end_y),0)-coalesce(public.xt_val(e.x,e.y),0) else 0 end) as xt_pass
  from public.events e
  where e.player_id is not null
  group by e.player_id
)
select pa.player_id, m.player, m.team, m.pos, m.pool, m.nineties,
  pa.passes_att, pa.prog_att, pa.prog_cmp,
  round(pa.passes_att / nullif(m.nineties,0), 2) as passes_90,
  round(pa.prog_att  / nullif(m.nineties,0), 2) as prog_att_90,
  round(pa.prog_cmp  / nullif(m.nineties,0), 2) as prog_cmp_90,
  round(pa.prog_into_final / nullif(m.nineties,0), 2) as prog_into_final_90,
  round(100.0*pa.prog_cmp / nullif(pa.prog_att,0), 1) as prog_completion,
  -- tendency: share of his passing that is progressive
  round(100.0*pa.prog_att / nullif(pa.passes_att,0), 1) as prog_tendency_pct,
  round((pa.xt_pass / nullif(m.nineties,0))::numeric, 3) as xt_pass_90
from pa
join public.player_search m on m.player_id = pa.player_id
where m.nineties >= 3;
create unique index mv_player_progression_pk on public.mv_player_progression (player_id);
grant select on public.mv_player_progression to anon, authenticated;

-- Footedness derived from WhoScored foot qualifiers (passes, shots, take-ons).
-- Coverage is partial: the qualifier is not present on every event.
drop materialized view if exists public.mv_player_foot cascade;
create materialized view public.mv_player_foot as
with f as (
  select e.player_id,
    count(*) filter (where q.dn='LeftFoot')  as left_ct,
    count(*) filter (where q.dn='RightFoot') as right_ct
  from public.events e
  cross join lateral (select qq->'type'->>'displayName' dn from jsonb_array_elements(e.qualifiers) qq) q
  where e.player_id is not null and q.dn in ('LeftFoot','RightFoot')
  group by e.player_id
)
select player_id, left_ct, right_ct, (left_ct+right_ct) as foot_events,
  round(100.0*left_ct/nullif(left_ct+right_ct,0), 1) as left_share,
  case
    when (left_ct+right_ct) < 8 then null
    when left_ct::numeric/(left_ct+right_ct) >= 0.65 then 'left'
    when left_ct::numeric/(left_ct+right_ct) <= 0.35 then 'right'
    else 'either'
  end as foot,
  case when (left_ct+right_ct) >= 25 then 'high'
       when (left_ct+right_ct) >= 8 then 'medium' else 'low' end as foot_confidence
from f;
create unique index mv_player_foot_pk on public.mv_player_foot (player_id);
grant select on public.mv_player_foot to anon, authenticated;
