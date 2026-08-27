create or replace view v_player_sot_fix as
select player_id,
       count(*) filter (where is_open_play and outcome in ('saved','goal')) as sot_true,
       count(*) filter (where is_open_play and outcome='blocked')           as blocked
from mv_shot_xg group by player_id;
grant select on v_player_sot_fix to anon, authenticated;
