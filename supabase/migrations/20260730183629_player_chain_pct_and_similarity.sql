
create or replace view public.pcr_z as
with p as (
  select c.*, coalesce(r.pool, c.pos) as pool
  from public.player_chain_roles c
  left join public.mv_player_role r on r.player_id=c.player_id
)
select player_id, player, team, pos, pool, inv, player_xt, hold_secs,
  (initiator   -avg(initiator)   over w)/nullif(stddev_samp(initiator)   over w,0) z_init,
  (bridge      -avg(bridge)      over w)/nullif(stddev_samp(bridge)      over w,0) z_bridge,
  (progressor  -avg(progressor)  over w)/nullif(stddev_samp(progressor)  over w,0) z_prog,
  (carrier     -avg(carrier)     over w)/nullif(stddev_samp(carrier)     over w,0) z_carry,
  (vertical    -avg(vertical)    over w)/nullif(stddev_samp(vertical)    over w,0) z_vert,
  (support_angle-avg(support_angle) over w)/nullif(stddev_samp(support_angle) over w,0) z_supp,
  (individual  -avg(individual)  over w)/nullif(stddev_samp(individual)  over w,0) z_indiv,
  (creator     -avg(creator)     over w)/nullif(stddev_samp(creator)     over w,0) z_creator,
  (box_threat  -avg(box_threat)  over w)/nullif(stddev_samp(box_threat)  over w,0) z_box,
  (finisher    -avg(finisher)    over w)/nullif(stddev_samp(finisher)    over w,0) z_finish,
  (hold_secs   -avg(hold_secs)   over w)/nullif(stddev_samp(hold_secs)   over w,0) z_ctrl
from p window w as (partition by pool);

create or replace view public.player_chain_pct as
with p as (
  select c.*, coalesce(r.pool,c.pos) as pool
  from public.player_chain_roles c left join public.mv_player_role r on r.player_id=c.player_id
)
select player_id, player, pos, pool, m.role, m.raw,
  round(100*percent_rank() over (partition by pool, m.role order by m.raw))::int as pct
from p cross join lateral (values
  ('initiator',initiator),('controller',hold_secs),('bridge',bridge),('progressor',progressor),
  ('carrier',carrier),('vertical',vertical),('support_angle',support_angle),('individual',individual),
  ('creator',creator),('box_threat',box_threat),('finisher',finisher)
) m(role,raw);

create or replace function public.similar_players_chain(p_id text, p_n int default 12)
returns table(rank int, player_id text, player text, team text, pos text, inv integer, player_xt numeric,
              sim_pct numeric, initiator numeric, hold_secs numeric, bridge numeric, progressor numeric,
              carrier numeric, vertical numeric, support_angle numeric)
language sql stable as $$
  with q as (select * from public.pcr_z where player_id=p_id)
  select row_number() over (order by d.cos desc)::int, d.player_id, c.player, c.team, c.pos, c.inv, c.player_xt,
    round((d.cos*100)::numeric,1), c.initiator, c.hold_secs, c.bridge, c.progressor, c.carrier, c.vertical, c.support_angle
  from (
    select z.player_id,
      ( coalesce(z.z_init,0)*coalesce(q.z_init,0)+coalesce(z.z_bridge,0)*coalesce(q.z_bridge,0)
       +coalesce(z.z_prog,0)*coalesce(q.z_prog,0)+coalesce(z.z_carry,0)*coalesce(q.z_carry,0)
       +coalesce(z.z_vert,0)*coalesce(q.z_vert,0)+coalesce(z.z_supp,0)*coalesce(q.z_supp,0)
       +coalesce(z.z_indiv,0)*coalesce(q.z_indiv,0)+coalesce(z.z_creator,0)*coalesce(q.z_creator,0)
       +coalesce(z.z_box,0)*coalesce(q.z_box,0)+coalesce(z.z_finish,0)*coalesce(q.z_finish,0)
       +coalesce(z.z_ctrl,0)*coalesce(q.z_ctrl,0) )
      / nullif( sqrt(coalesce(z.z_init,0)^2+coalesce(z.z_bridge,0)^2+coalesce(z.z_prog,0)^2+coalesce(z.z_carry,0)^2
       +coalesce(z.z_vert,0)^2+coalesce(z.z_supp,0)^2+coalesce(z.z_indiv,0)^2+coalesce(z.z_creator,0)^2
       +coalesce(z.z_box,0)^2+coalesce(z.z_finish,0)^2+coalesce(z.z_ctrl,0)^2)
       * sqrt(coalesce(q.z_init,0)^2+coalesce(q.z_bridge,0)^2+coalesce(q.z_prog,0)^2+coalesce(q.z_carry,0)^2
       +coalesce(q.z_vert,0)^2+coalesce(q.z_supp,0)^2+coalesce(q.z_indiv,0)^2+coalesce(q.z_creator,0)^2
       +coalesce(q.z_box,0)^2+coalesce(q.z_finish,0)^2+coalesce(q.z_ctrl,0)^2), 0) as cos
    from public.pcr_z z, q
    where z.pool=q.pool and z.player_id<>q.player_id
  ) d
  join public.player_chain_roles c on c.player_id=d.player_id
  where d.cos is not null
  order by d.cos desc limit p_n;
$$;

grant select on public.player_chain_roles to anon, authenticated;
grant select on public.pcr_z to anon, authenticated;
grant select on public.player_chain_pct to anon, authenticated;
grant execute on function public.similar_players_chain(text,int) to anon, authenticated;
