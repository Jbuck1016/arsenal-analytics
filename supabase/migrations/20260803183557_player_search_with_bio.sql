
drop materialized view if exists public.player_search;
create materialized view public.player_search as
select
  pcr.player_id, pcr.player, pcr.team, pcr.pos,
  case right(pcr.pos,1) when 'R' then 'R' when 'L' then 'L' else 'C' end as side,
  z.pool,
  m.nineties, pcr.inv,
  -- bio (from cached WhoScored match feed; null until backfill runs)
  b.age_seen, b.age_seen_date, b.height_cm, b.weight_kg, b.nationality, b.foot,
  -- chain-role profile
  pcr.initiator, pcr.bridge, pcr.progressor, pcr.carrier, pcr.vertical,
  pcr.support_angle, pcr.individual, pcr.creator, pcr.box_threat, pcr.finisher,
  pcr.hold_secs, pcr.player_xt,
  -- progression / passing
  m.pass_cmp_90, m.pass_pct, m.prog_cmp_90, m.prog_pct, m.into_box_90, m.final_third_90,
  m.through_90, m.cross_90, m.cross_pct, m.key_pass_90, m.assist_90, m.bcc_90, m.long_90, m.long_pct,
  -- carrying
  m.carries_90, m.prog_carries_90, m.carry_box_90, m.mean_carry_m, m.carry_pen_90,
  m.takeon_90, m.takeon_pct, m.disp_90,
  -- shooting / finishing
  m.shots_90, m.sot_90, m.goals_90, m.xg_90, m.xg_per_shot, m.conversion, m.bigchance_90, m.finishing,
  -- threat / creation
  m.xt_90, m.xt_pass_90, m.xt_carry_90, m.xa_90, m.sca_90,
  -- defending
  m.tackle_90, m.tackle_pct, m.int_90, m.recov_90, m.aerial_90, m.aerial_pct,
  m.counterpress_90, m.def_action_90, m.box_def_90, m.channel_def_90, m.flank_def_90
from public.player_chain_roles pcr
join public.pcr_z z on z.player_id = pcr.player_id
left join public.v_player_metrics_ext m on m.player_id = pcr.player_id
left join public.player_bio b on b.player_id = pcr.player_id;

create unique index player_search_pk on public.player_search (player_id);
create index player_search_side on public.player_search (side);
create index player_search_pool on public.player_search (pool);
create index player_search_pos  on public.player_search (pos);
create index player_search_age  on public.player_search (age_seen);
grant select on public.player_search to anon, authenticated;

-- add a search-refresh step so the index stays current each matchweek
create or replace function public.rebuild_step(p_step text)
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare wl_ct int; bad_teams text; seq_games int; evt_games int; null_xt int; n_seq int; n_pcr int; n_srch int;
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
    when 'search'    then
      refresh materialized view public.player_search;
      select count(*) into n_srch from public.player_search;
      return format('search index refreshed (%s players)', n_srch);
    when 'insights'  then return public.build_insights();
    when 'verify' then
      select count(*) into null_xt from public.sequences where xt_sum is null;
      if null_xt > 0 then raise exception 'verify failed -- % sequences with null xt_sum', null_xt; end if;
      select count(distinct game_id) into seq_games from public.sequences;
      select count(distinct game_id) into evt_games from public.events;
      if seq_games <> evt_games then raise exception 'verify failed -- game-count sequences % vs events %', seq_games, evt_games; end if;
      select count(*) into n_seq from public.sequences;
      select count(*) into n_pcr from public.player_chain_roles;
      return format('verified -- %s sequences over %s games, %s outfield players', n_seq, seq_games, n_pcr);
    else raise exception 'unknown rebuild step: %', p_step;
  end case;
end $fn$;
revoke execute on function public.rebuild_step(text) from public, anon, authenticated;
grant execute on function public.rebuild_step(text) to service_role;
