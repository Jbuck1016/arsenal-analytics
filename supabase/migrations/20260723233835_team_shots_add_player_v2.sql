drop view if exists v_team_shots;
create view v_team_shots as
select x.team, x.game_id, x.player, x.is_goal, x.is_open_play, x.is_pen, x.xg,
       x.is_header, x.is_bigchance, f.x, f.y,
       round(f.dist_m::numeric,1) as dist_m
from mv_shot_xg x
join mv_shot_features f on f.game_id=x.game_id and f.ws_id=x.ws_id;
grant select on v_team_shots to anon, authenticated;
notify pgrst, 'reload schema';
