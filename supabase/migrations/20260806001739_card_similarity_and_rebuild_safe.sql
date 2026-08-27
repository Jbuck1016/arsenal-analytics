
create or replace function public.player_card(p_id text)
returns jsonb language sql stable set search_path = public as $fn$
  with ps as (select * from public.player_search where player_id = p_id),
  pct as (
    select p.metric, d.label, d.grp, d.unit, p.raw, p.pct_pool, p.pct_archetype,
      case when p.pct_pool >= 90 then 'Elite' when p.pct_pool >= 75 then 'Strong'
           when p.pct_pool >= 40 then 'Average' when p.pct_pool >= 20 then 'Below Par'
           else 'Limited' end as band
    from public.mv_player_pct p join public.metric_catalog d on d.metric = p.metric
    where p.player_id = p_id
  ),
  roles as (select role, raw, pct from public.player_chain_pct where player_id = p_id order by pct desc),
  usage as (select squad_role, selection_pct, leverage_pct, minutes_inflated, starts, appearances
            from public.v_squad_role where player_id = p_id limit 1),
  comps as (select * from public.similar_players_chain(p_id, 5))
  select jsonb_build_object(
    'player', to_jsonb((select row_to_json(x) from (
        select ps.player_id, ps.player, ps.team, ps.pos, ps.side, ps.pool,
               ps.age_seen, ps.height_cm, ps.weight_kg, ps.foot, ps.foot_confidence,
               ps.nineties, ps.inv, ps.archetype, ps.archetype_primary, ps.archetype_secondary
        from ps) x)),
    'usage', (select to_jsonb(u) from usage u),
    'traits', (select jsonb_agg(jsonb_build_object('metric',metric,'label',label,'group',grp,'unit',unit,
        'value',raw,'pct',pct_pool,'pct_archetype',pct_archetype,'band',band) order by pct_pool desc) from pct),
    'strengths', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct_pool,'value',raw) order by pct_pool desc)
        from (select * from pct where pct_pool >= 80 order by pct_pool desc limit 6) s),
    'weaknesses', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct_pool,'value',raw) order by pct_pool asc)
        from (select * from pct where pct_pool <= 25 order by pct_pool asc limit 4) w),
    'roles', (select jsonb_agg(jsonb_build_object('role',role,'value',raw,'pct',pct) order by pct desc) from roles),
    'similar', (select jsonb_agg(to_jsonb(c) order by c.rank) from comps c)
  );
$fn$;
grant execute on function public.player_card(text) to anon, authenticated;

create or replace view public.v_player_pct_all as
  select player_id, player, pool, metric, pct_pool as pct from public.mv_player_pct
  union all
  select p.player_id, p.player, p.pool, 'role_'||p.role, p.pct from public.player_chain_pct p;
grant select on public.v_player_pct_all to anon, authenticated;

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
  cand as (select a.player_id, a.metric, a.pct from public.v_player_pct_all a, feats
           where a.metric = any(feats.m) and a.player_id <> p_id
             and a.pool = (select pool from tgt limit 1)),
  d as (
    select c.player_id, sqrt(sum(power(c.pct - t.pct, 2)))/sqrt(count(*)) as dist, count(*)::int as shared
    from cand c join tgt t on t.metric = c.metric group by c.player_id having count(*) >= 12
  )
  select row_number() over (order by d.dist)::int, d.player_id, ps.player, ps.team, ps.pos,
         round(greatest(0, 100 - d.dist)::numeric, 1), d.shared
  from d join public.player_search ps on ps.player_id = d.player_id
  order by d.dist limit p_n;
$fn$;
grant execute on function public.similar_players_full(text,integer,text[]) to anon, authenticated;

create or replace function public.rebuild_step(p_step text)
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare wl_ct int; bad_teams text; seq_games int; evt_games int; null_xt int;
        n_seq int; n_pcr int; n_srch int; n_st int; n_ce int; n_tj int; n_sq int; n_pct int;
begin
  case p_step
    when 'preflight' then
      select count(*) into wl_ct from public.team_names;
      if wl_ct > 0 then
        select string_agg(distinct team, ', ') into bad_teams from public.events
          where team is not null and team not in (select event_name from public.team_names);
        if bad_teams is not null then
          raise exception 'rebuild aborted -- events contain team(s) not in team_names whitelist: %', bad_teams;
        end if;
      end if;
      return 'preflight ok';
    when 'metrics'   then perform public.refresh_analytics();       return 'metrics refreshed';
    when 'sequences' then perform public.build_sequences();          return 'sequences built';
    when 'players'   then perform public.build_player_chain_roles(); return 'players built';
    when 'seqfz'     then refresh materialized view public.seq_fz;   return 'seq_fz refreshed';
    when 'state' then
      refresh materialized view public.mv_game_goals;
      refresh materialized view public.mv_seq_state;
      refresh materialized view public.mv_state_segments;
      select count(*) into n_st from public.mv_seq_state;
      return format('game state built (%s possessions tagged)', n_st);
    when 'chains' then
      refresh materialized view public.mv_seq_events;
      refresh materialized view public.mv_player_chain_value;
      select count(*) into n_ce from public.mv_player_chain_value;
      return format('chain value built (%s players)', n_ce);
    when 'traj' then
      refresh materialized view public.mv_pass_traj;
      refresh materialized view public.mv_player_pass_traj;
      select count(*) into n_tj from public.mv_player_pass_traj;
      return format('pass trajectory built (%s players)', n_tj);
    when 'profiles' then
      refresh materialized view public.mv_player_foot;
      refresh materialized view public.mv_player_archetype;
      refresh materialized view public.mv_player_progression;
      return 'foot / archetype / progression refreshed';
    when 'usage' then
      refresh materialized view public.mv_player_stints;
      refresh materialized view public.mv_player_leverage;
      refresh materialized view public.mv_squad_role;
      refresh materialized view public.mv_player_state_output;
      select count(*) into n_sq from public.mv_squad_role;
      return format('squad usage + state-adjusted output built (%s rows)', n_sq);
    when 'teamstyle' then
      refresh materialized view public.mv_team_directness_state;
      refresh materialized view public.mv_press_vs_buildup;
      refresh materialized view public.mv_team_breakdown;
      return 'directness / press / breakdown refreshed';
    when 'search' then
      refresh materialized view public.player_search;
      select count(*) into n_srch from public.player_search;
      return format('search index refreshed (%s players)', n_srch);
    when 'percentiles' then
      refresh materialized view public.mv_player_pct;
      select count(*) into n_pct from public.mv_player_pct;
      return format('percentile layer refreshed (%s rows)', n_pct);
    when 'insights'  then return public.build_insights();
    when 'verify' then
      select count(*) into null_xt from public.sequences where xt_sum is null;
      if null_xt > 0 then raise exception 'verify failed -- % sequences with null xt_sum', null_xt; end if;
      select count(distinct game_id) into seq_games from public.sequences;
      select count(distinct game_id) into evt_games from public.events;
      if seq_games <> evt_games then raise exception 'verify failed -- game-count sequences % vs events %', seq_games, evt_games; end if;
      select count(*) into n_seq from public.sequences;
      select count(*) into n_pcr from public.player_chain_roles;
      select count(*) into n_srch from public.player_search;
      return format('verified -- %s sequences over %s games, %s outfield players, %s in search index',
                    n_seq, seq_games, n_pcr, n_srch);
    else raise exception 'unknown rebuild step: %', p_step;
  end case;
end $fn$;
revoke execute on function public.rebuild_step(text) from public, anon, authenticated;
grant execute on function public.rebuild_step(text) to service_role;
