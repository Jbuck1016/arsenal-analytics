-- Add the match context required by the player evidence browser. Existing
-- columns remain first and unchanged so every current consumer remains valid.
create or replace view public.v_player_actions
with (security_invoker = true)
as
select
  e.player_id,
  e.game_id,
  e.type,
  e.x,
  e.y,
  e.end_x,
  e.end_y,
  e.outcome_type = 'Successful' as ok,
  e.is_shot,
  e.is_goal,
  e.is_open_play,
  coalesce(ph.set_piece_phase, false) as sp_phase,
  e.type = 'Pass'
    and e.x is not null and e.end_x is not null
    and (
      (e.x < 50 and e.end_x < 50 and e.end_x - e.x >= 30)
      or (e.x < 50 and e.end_x >= 50 and e.end_x - e.x >= 15)
      or (e.x >= 50 and e.end_x >= 50 and e.end_x - e.x >= 10)
    ) as prog,
  e.type = 'Pass'
    and e.end_x >= 83 and e.end_y between 21 and 79 as into_box,
  e.qualifiers @> '[{"type":{"displayName":"Cross"}}]'::jsonb as cross_,
  e.qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb as keypass,
  e.qualifiers @> '[{"type":{"displayName":"IntentionalGoalAssist"}}]'::jsonb as assist,
  e.qualifiers @> '[{"type":{"displayName":"Throughball"}}]'::jsonb as through,
  e.qualifiers @> '[{"type":{"displayName":"Head"}}]'::jsonb as head,
  e.qualifiers @> '[{"type":{"displayName":"BigChance"}}]'::jsonb as bigchance,
  x.xg,
  x.outcome as shot_outcome,
  e.team,
  e.period,
  e.expanded_minute as minute,
  e.second,
  m.date as kickoff,
  case
    when coalesce(tn.match_name, e.team) = m.home_team then m.away_team
    else m.home_team
  end as opponent,
  case
    when sg.margin > 0 then 'winning'
    when sg.margin < 0 then 'losing'
    when sg.margin = 0 then 'drawing'
  end as score_state,
  sg.margin::integer as score_margin,
  e.league
from public.v_league_events e
left join public.mv_event_phase ph
  on ph.game_id = e.game_id and ph.ws_id = e.ws_id
left join public.mv_shot_xg x
  on x.game_id = e.game_id and x.ws_id = e.ws_id
join public.v_league_matches m
  on m.game_id = e.game_id and m.league = e.league
left join public.team_names tn
  on tn.league = e.league and tn.event_name = e.team
left join public.mv_state_segments sg
  on sg.game_id = e.game_id
 and sg.team = e.team
 and e.expanded_minute >= sg.seg_start
 and e.expanded_minute < sg.seg_end
where e.player_id is not null
  and e.x is not null
  and e.y is not null
  and e.type <> all (array[
    'Start','End','FormationSet','FormationChange','Card',
    'SubstitutionOn','SubstitutionOff','OffsideProvoked'
  ]);

grant select on public.v_player_actions to anon, authenticated;

comment on view public.v_player_actions is
  'Current-season player actions with spatial, fixture, clock, opponent and score-state context for public analytics views.';

-- Carry and receipt layers are derived from the release event.  Expose the
-- same context so a Plot Studio filter never applies to passes while silently
-- leaving the other selected layers unfiltered.
create or replace view public.v_player_carries
with (security_invoker = true)
as
select
  r.player_id,
  r.game_id,
  r.start_x,
  r.start_y,
  r.end_x,
  r.end_y,
  r.carry_m,
  r.is_progressive,
  r.into_box,
  r.ttr,
  r.release_type,
  r.team,
  e.period,
  e.expanded_minute as minute,
  e.second,
  m.date as kickoff,
  case
    when coalesce(tn.match_name, r.team) = m.home_team then m.away_team
    else m.home_team
  end as opponent,
  case
    when sg.margin > 0 then 'winning'
    when sg.margin < 0 then 'losing'
    when sg.margin = 0 then 'drawing'
  end as score_state,
  sg.margin::integer as score_margin,
  coalesce(ph.set_piece_phase, false) as sp_phase,
  e.league
from public.mv_receipt_events r
join public.v_league_events e
  on e.game_id = r.game_id and e.ws_id = r.ws_id
join public.v_league_matches m
  on m.game_id = r.game_id and m.league = e.league
left join public.team_names tn
  on tn.league = e.league and tn.event_name = r.team
left join public.mv_event_phase ph
  on ph.game_id = e.game_id and ph.ws_id = e.ws_id
left join public.mv_state_segments sg
  on sg.game_id = r.game_id
 and sg.team = r.team
 and e.expanded_minute >= sg.seg_start
 and e.expanded_minute < sg.seg_end
where r.is_carry;

create or replace view public.v_player_receipts
with (security_invoker = true)
as
select
  r.player_id,
  r.game_id,
  r.start_x,
  r.start_y,
  r.end_x,
  r.end_y,
  r.ttr,
  r.release_type,
  r.is_carry,
  r.team,
  e.period,
  e.expanded_minute as minute,
  e.second,
  m.date as kickoff,
  case
    when coalesce(tn.match_name, r.team) = m.home_team then m.away_team
    else m.home_team
  end as opponent,
  case
    when sg.margin > 0 then 'winning'
    when sg.margin < 0 then 'losing'
    when sg.margin = 0 then 'drawing'
  end as score_state,
  sg.margin::integer as score_margin,
  coalesce(ph.set_piece_phase, false) as sp_phase,
  e.league
from public.mv_receipt_events r
join public.v_league_events e
  on e.game_id = r.game_id and e.ws_id = r.ws_id
join public.v_league_matches m
  on m.game_id = r.game_id and m.league = e.league
left join public.team_names tn
  on tn.league = e.league and tn.event_name = r.team
left join public.mv_event_phase ph
  on ph.game_id = e.game_id and ph.ws_id = e.ws_id
left join public.mv_state_segments sg
  on sg.game_id = r.game_id
 and sg.team = r.team
 and e.expanded_minute >= sg.seg_start
 and e.expanded_minute < sg.seg_end;

grant select on public.v_player_carries, public.v_player_receipts to anon, authenticated;

comment on view public.v_player_carries is
  'Current-season inferred carries with fixture, clock, opponent and score-state context for public analytics views.';
comment on view public.v_player_receipts is
  'Current-season inferred receipts with fixture, clock, opponent and score-state context for public analytics views.';

notify pgrst, 'reload schema';
