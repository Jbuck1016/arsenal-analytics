create materialized view mv_player_xa as
with seq as (
  select game_id, ws_id, team, player_id, type, is_shot,
         lag(player_id) over w as prev_player,
         lag(team)      over w as prev_team,
         lag(type)      over w as prev_type,
         lag(qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb) over w as prev_keypass,
         lag(qualifiers @> '[{"type":{"displayName":"ShotAssist"}}]'::jsonb) over w as prev_shotassist
  from public.events
  where type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded',
                     'OffsideGiven','OffsideProvoked')
  window w as (partition by game_id order by ws_id)
)
select s.prev_player as player_id,
       count(*)                    as chances_created,
       round(sum(x.xg)::numeric,3) as xa
from seq s
join mv_shot_xg x on x.game_id = s.game_id and x.ws_id = s.ws_id
where s.is_shot and s.prev_team = s.team and s.prev_type='Pass'
  and (s.prev_keypass or s.prev_shotassist) and s.prev_player is not null
group by s.prev_player;
create unique index on mv_player_xa (player_id);

create materialized view mv_player_setpiece as
select
  e.player_id,
  count(*) filter (where e.is_shot and p.set_piece_phase)                  as sp_shots,
  round(sum(x.xg) filter (where p.set_piece_phase and not x.is_pen)::numeric,3) as sp_xg,
  count(*) filter (where e.is_shot and p.set_piece_phase and e.is_goal)    as sp_goals,
  count(*) filter (where e.type='Pass' and not e.is_open_play
      and e.qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb)   as sp_key_passes,
  count(*) filter (where e.type='Aerial' and p.set_piece_phase
      and e.outcome_type='Successful')                                    as sp_aerials_won
from public.events e
join mv_event_phase p on p.game_id=e.game_id and p.ws_id=e.ws_id
left join mv_shot_xg x on x.game_id=e.game_id and x.ws_id=e.ws_id
where e.player_id is not null
group by e.player_id;
create unique index on mv_player_setpiece (player_id);

create or replace view v_team_shots as
select x.team, x.game_id, x.player, x.is_goal, x.is_open_play, x.is_pen, x.xg,
       x.is_header, x.is_bigchance, x.is_blocked, x.outcome, f.x, f.y,
       round(f.dist_m::numeric,1) as dist_m
from mv_shot_xg x join mv_shot_features f on f.game_id=x.game_id and f.ws_id=x.ws_id;

grant select on mv_player_xa, mv_player_setpiece, v_team_shots to anon, authenticated;
