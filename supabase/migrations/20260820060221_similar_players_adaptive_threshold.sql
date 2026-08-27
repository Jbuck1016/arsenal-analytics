
-- The shared-dimension floor was a flat 12, which is fine for a full style match (32
-- dimensions) but silently returns nothing when the query is narrowed to one family:
-- Shooting only has 8. Scale the requirement to the size of the requested feature set.
create or replace function public.similar_players_full(
  p_id text, p_n integer default 8, p_metrics text[] default null)
returns table(rank integer, player_id text, player text, team text, pos text,
              sim_pct numeric, shared_metrics integer)
language sql stable set search_path = public as $fn$
  with feats as (
    select coalesce(p_metrics, array[
      'role_progressor','role_creator','role_carrier','role_box_threat','role_finisher',
      'role_initiator','role_bridge','role_vertical','role_support_angle','role_individual','role_controller',
      'pct_over','pct_around','pct_through','pct_in_behind','pct_inside','pct_outside',
      'prog_tendency_pct','prog_completion','prog_into_final_90',
      'early_shot_pct','shot_chain_pct','prog_carries_90','takeon_90','carry_box_90',
      'xa_90','key_pass_90','xg_90','xt_90','def_action_90','aerial_90','recov_90'
    ]) as m
  ),
  tgt as (select a.pool, a.metric, a.pct from public.v_player_pct_all a, feats
          where a.player_id = p_id and a.metric = any(feats.m)),
  need as (
    -- at least 60% of what the target actually has, floor of 3, so a narrow query works
    select greatest(3, ceil(0.6 * count(*))::int) as k from tgt
  ),
  cand as (select a.player_id, a.metric, a.pct from public.v_player_pct_all a, feats
           where a.metric = any(feats.m) and a.player_id <> p_id
             and a.pool = (select pool from tgt limit 1)),
  d as (
    select c.player_id, sqrt(sum(power(c.pct - t.pct, 2)))/sqrt(count(*)) as dist, count(*)::int as shared
    from cand c join tgt t on t.metric = c.metric
    group by c.player_id
    having count(*) >= (select k from need)
  )
  select row_number() over (order by d.dist)::int, d.player_id, ps.player, ps.team, ps.pos,
         round(greatest(0, 100 - d.dist)::numeric, 1), d.shared
  from d join public.player_search ps on ps.player_id = d.player_id
  order by d.dist limit p_n;
$fn$;
grant execute on function public.similar_players_full(text,integer,text[]) to anon, authenticated;
