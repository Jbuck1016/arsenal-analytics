
-- Archetype from the two roles a player ranks highest in within his position pool.
-- Rule-based rather than clustered: transparent and defensible, which matters more
-- than marginal fit when someone asks "why is he labelled that".
drop materialized view if exists public.mv_player_archetype cascade;
create materialized view public.mv_player_archetype as
with names(role, label) as (values
  ('progressor','Progressor'), ('initiator','Deep Initiator'), ('creator','Creator'),
  ('box_threat','Box Threat'), ('finisher','Finisher'), ('carrier','Carrier'),
  ('vertical','Vertical Passer'), ('support_angle','Link Player'),
  ('bridge','Third-Man Bridge'), ('individual','Dribbler'), ('controller','Tempo Setter')
),
r as (
  select p.player_id, p.player, p.pool, p.role, p.pct,
    row_number() over (partition by p.player_id order by p.pct desc, p.role) rk
  from public.player_chain_pct p
),
top2 as (
  select player_id, max(player) player, max(pool) pool,
    max(role) filter (where rk=1) primary_role,
    max(pct)  filter (where rk=1) primary_pct,
    max(role) filter (where rk=2) secondary_role,
    max(pct)  filter (where rk=2) secondary_pct
  from r where rk <= 2 group by player_id
)
select t.player_id, t.player, t.pool,
  t.primary_role, t.primary_pct, t.secondary_role, t.secondary_pct,
  n1.label as primary_label, n2.label as secondary_label,
  n1.label || ' / ' || n2.label as archetype,
  t.pool || ' · ' || n1.label as pool_archetype
from top2 t
left join names n1 on n1.role = t.primary_role
left join names n2 on n2.role = t.secondary_role;
create unique index mv_player_archetype_pk on public.mv_player_archetype (player_id);
create index mv_player_archetype_cohort on public.mv_player_archetype (pool_archetype);
grant select on public.mv_player_archetype to anon, authenticated;
