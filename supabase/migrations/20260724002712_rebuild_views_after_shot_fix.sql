create or replace view v_team_shots as
select x.team, x.game_id, x.player, x.is_goal, x.is_open_play, x.is_pen, x.xg,
       x.is_header, x.is_bigchance, x.is_blocked, x.outcome, f.x, f.y,
       round(f.dist_m::numeric,1) as dist_m
from mv_shot_xg x join mv_shot_features f on f.game_id=x.game_id and f.ws_id=x.ws_id;

create or replace view v_player_actions as
select
  e.player_id, e.game_id, e.type,
  e.x, e.y, e.end_x, e.end_y,
  (e.outcome_type = 'Successful')                                   as ok,
  e.is_shot, e.is_goal, e.is_open_play,
  coalesce(ph.set_piece_phase,false)                                as sp_phase,
  (e.type='Pass' and e.x is not null and e.end_x is not null and (
     (e.x<50 and e.end_x<50  and (e.end_x-e.x)>=30) or
     (e.x<50 and e.end_x>=50 and (e.end_x-e.x)>=15) or
     (e.x>=50 and e.end_x>=50 and (e.end_x-e.x)>=10)))              as prog,
  (e.type='Pass' and e.end_x >= 83 and e.end_y between 21 and 79)   as into_box,
  e.qualifiers @> '[{"type":{"displayName":"Cross"}}]'::jsonb                 as cross_,
  e.qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb               as keypass,
  e.qualifiers @> '[{"type":{"displayName":"IntentionalGoalAssist"}}]'::jsonb as assist,
  e.qualifiers @> '[{"type":{"displayName":"Throughball"}}]'::jsonb           as through,
  e.qualifiers @> '[{"type":{"displayName":"Head"}}]'::jsonb                  as head,
  e.qualifiers @> '[{"type":{"displayName":"BigChance"}}]'::jsonb             as bigchance,
  x.xg, x.outcome as shot_outcome
from public.events e
left join mv_event_phase ph on ph.game_id = e.game_id and ph.ws_id = e.ws_id
left join mv_shot_xg     x  on x.game_id  = e.game_id and x.ws_id  = e.ws_id
where e.player_id is not null
  and e.x is not null and e.y is not null
  and e.type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','OffsideProvoked');

grant select on v_team_shots, v_player_actions to anon, authenticated;
notify pgrst, 'reload schema';
