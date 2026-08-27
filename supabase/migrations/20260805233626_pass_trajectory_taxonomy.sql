
-- Forward passes classified by HOW they beat the block and WHERE they land.
-- NOTE: WhoScored carries no defender positions, so this is pass trajectory,
-- not verified line-breaking. Labelled honestly wherever it surfaces.
drop materialized view if exists public.mv_pass_traj cascade;
create materialized view public.mv_pass_traj as
with p as (
  select e.id, e.game_id, e.player_id, e.player, e.team,
    e.x, e.y, e.end_x, e.end_y, e.outcome_type,
    z.aerial, z.thru
  from public.events e
  left join lateral (
    select coalesce(bool_or(dn in ('Chipped','Longball')), false) aerial,
           coalesce(bool_or(dn = 'Throughball'), false) thru
    from (select q->'type'->>'displayName' dn from jsonb_array_elements(e.qualifiers) q) qq
  ) z on true
  where e.type = 'Pass'
    and e.end_x is not null and e.x is not null
    and (e.end_x - e.x) >= 5
)
select id, game_id, player_id, player, team,
  (outcome_type = 'Successful') as completed,
  case
    when aerial then 'over'
    when thru or (((y + end_y)/2.0) between 33.3 and 66.7 and (end_x - x) >= 12) then 'through'
    else 'around'
  end as trajectory,
  case
    when end_x >= 78 then 'in_behind'
    when end_y < 21.1 or end_y > 78.9 then 'outside'
    else 'inside'
  end as destination
from p;
create index mv_pass_traj_player on public.mv_pass_traj (player_id);
grant select on public.mv_pass_traj to anon, authenticated;

-- Per-player profile: share of forward passes by trajectory, by destination,
-- the 9-cell cross, and completion rate for each trajectory.
drop materialized view if exists public.mv_player_pass_traj cascade;
create materialized view public.mv_player_pass_traj as
select t.player_id, max(t.player) player, max(t.team) team,
  count(*) fwd_passes,
  round(100.0*avg((t.trajectory='over')::int), 1)    pct_over,
  round(100.0*avg((t.trajectory='around')::int), 1)  pct_around,
  round(100.0*avg((t.trajectory='through')::int), 1) pct_through,
  round(100.0*avg((t.destination='inside')::int), 1)    pct_inside,
  round(100.0*avg((t.destination='in_behind')::int), 1) pct_in_behind,
  round(100.0*avg((t.destination='outside')::int), 1)   pct_outside,
  round(100.0*avg((t.trajectory='over'    and t.destination='inside')::int),1)    over_inside,
  round(100.0*avg((t.trajectory='over'    and t.destination='in_behind')::int),1) over_in_behind,
  round(100.0*avg((t.trajectory='over'    and t.destination='outside')::int),1)   over_outside,
  round(100.0*avg((t.trajectory='around'  and t.destination='inside')::int),1)    around_inside,
  round(100.0*avg((t.trajectory='around'  and t.destination='in_behind')::int),1) around_in_behind,
  round(100.0*avg((t.trajectory='around'  and t.destination='outside')::int),1)   around_outside,
  round(100.0*avg((t.trajectory='through' and t.destination='inside')::int),1)    through_inside,
  round(100.0*avg((t.trajectory='through' and t.destination='in_behind')::int),1) through_in_behind,
  round(100.0*avg((t.trajectory='through' and t.destination='outside')::int),1)   through_outside,
  round(100.0*avg(t.completed::int), 1) fwd_completion,
  round(100.0*avg(t.completed::int) filter (where t.trajectory='over'), 1)    comp_over,
  round(100.0*avg(t.completed::int) filter (where t.trajectory='around'), 1)  comp_around,
  round(100.0*avg(t.completed::int) filter (where t.trajectory='through'), 1) comp_through
from public.mv_pass_traj t
group by t.player_id
having count(*) >= 60;
create unique index mv_player_pass_traj_pk on public.mv_player_pass_traj (player_id);
grant select on public.mv_player_pass_traj to anon, authenticated;
