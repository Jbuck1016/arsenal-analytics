
-- Minimal edit to the ACTUAL definitions: add league, partition pools by it, append the
-- column last so no existing column position changes. Pool derivation left untouched.
create or replace view public.pcr_z as
 WITH p AS (
         SELECT c.player_id, c.player, c.team, c.pos, c.inv, c.player_xt, c.hold_secs,
            c.initiator, c.bridge, c.progressor, c.carrier, c.vertical, c.support_angle,
            c.individual, c.creator, c.box_threat, c.finisher,
            COALESCE(r.pool, c.pos) AS pool,
            COALESCE(pl.league, 'USA-MLS'::text) AS league
           FROM player_chain_roles c
             LEFT JOIN mv_player_role r ON r.player_id = c.player_id
             LEFT JOIN mv_player_league pl ON pl.player_id = c.player_id
        )
 SELECT player_id, player, team, pos, pool, inv, player_xt, hold_secs,
    (initiator - avg(initiator) OVER w) / NULLIF(stddev_samp(initiator) OVER w, 0::numeric) AS z_init,
    (bridge - avg(bridge) OVER w) / NULLIF(stddev_samp(bridge) OVER w, 0::numeric) AS z_bridge,
    (progressor - avg(progressor) OVER w) / NULLIF(stddev_samp(progressor) OVER w, 0::numeric) AS z_prog,
    (carrier - avg(carrier) OVER w) / NULLIF(stddev_samp(carrier) OVER w, 0::numeric) AS z_carry,
    (vertical - avg(vertical) OVER w) / NULLIF(stddev_samp(vertical) OVER w, 0::numeric) AS z_vert,
    (support_angle - avg(support_angle) OVER w) / NULLIF(stddev_samp(support_angle) OVER w, 0::numeric) AS z_supp,
    (individual - avg(individual) OVER w) / NULLIF(stddev_samp(individual) OVER w, 0::numeric) AS z_indiv,
    (creator - avg(creator) OVER w) / NULLIF(stddev_samp(creator) OVER w, 0::numeric) AS z_creator,
    (box_threat - avg(box_threat) OVER w) / NULLIF(stddev_samp(box_threat) OVER w, 0::numeric) AS z_box,
    (finisher - avg(finisher) OVER w) / NULLIF(stddev_samp(finisher) OVER w, 0::numeric) AS z_finish,
    (hold_secs - avg(hold_secs) OVER w) / NULLIF(stddev_samp(hold_secs) OVER w, 0::numeric) AS z_ctrl,
    league
   FROM p
  WINDOW w AS (PARTITION BY league, pool);

create or replace view public.player_chain_pct as
 WITH p AS (
         SELECT c.player_id, c.player, c.team, c.pos, c.inv, c.player_xt, c.hold_secs,
            c.initiator, c.bridge, c.progressor, c.carrier, c.vertical, c.support_angle,
            c.individual, c.creator, c.box_threat, c.finisher,
            COALESCE(r.pool, c.pos) AS pool,
            COALESCE(pl.league, 'USA-MLS'::text) AS league
           FROM player_chain_roles c
             LEFT JOIN mv_player_role r ON r.player_id = c.player_id
             LEFT JOIN mv_player_league pl ON pl.player_id = c.player_id
        )
 SELECT p.player_id, p.player, p.pos, p.pool, m.role, m.raw,
    round(100::double precision * percent_rank() OVER (PARTITION BY p.league, p.pool, m.role ORDER BY m.raw))::integer AS pct,
    p.league
   FROM p
     CROSS JOIN LATERAL ( VALUES ('initiator'::text,p.initiator), ('controller'::text,p.hold_secs),
       ('bridge'::text,p.bridge), ('progressor'::text,p.progressor), ('carrier'::text,p.carrier),
       ('vertical'::text,p.vertical), ('support_angle'::text,p.support_angle),
       ('individual'::text,p.individual), ('creator'::text,p.creator),
       ('box_threat'::text,p.box_threat), ('finisher'::text,p.finisher)) m(role, raw);

grant select on public.pcr_z, public.player_chain_pct to anon, authenticated;
