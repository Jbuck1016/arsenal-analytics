-- Hold-up play: final third only, otherwise it just rewards centre-backs
-- who stand on the ball in their own half.
create materialized view mv_player_holdup as
with h as (
  select r.player_id, r.game_id, r.ws_id, r.ttr, r.release_type, r.is_progressive,
         (r.end_x >= 66.7) as final_third
  from mv_receipt_events r
  where r.ttr >= 5 and r.end_x >= 66.7
),
nxt as (
  select h.player_id, h.ttr, h.release_type, h.is_progressive,
         e2.type as next_type, e2.team as next_team, e1.team as own_team
  from h
  join public.events e1 on e1.game_id=h.game_id and e1.ws_id=h.ws_id
  left join lateral (
    select e.type, e.team from public.events e
    where e.game_id=h.game_id and e.ws_id > h.ws_id
    order by e.ws_id limit 1
  ) e2 on true
)
select player_id,
  count(*)                                                    as holds,
  count(*) filter (where next_team = own_team)                as holds_retained,
  count(*) filter (where is_progressive)                      as holds_prog_carry,
  count(*) filter (where release_type='Pass')                 as holds_passed,
  count(*) filter (where release_type in ('SavedShot','MissedShots','Goal','ShotOnPost')) as holds_shot
from nxt group by player_id;
create unique index on mv_player_holdup (player_id);

-- Shot-creating actions: the two offensive actions immediately preceding a shot,
-- credited to distinct team-mates (FBref convention).
create materialized view mv_player_sca as
with seq as (
  select game_id, ws_id, team, player_id, type, is_shot,
         lag(player_id,1) over w as p1, lag(team,1) over w as t1, lag(type,1) over w as ty1,
         lag(player_id,2) over w as p2, lag(team,2) over w as t2, lag(type,2) over w as ty2
  from public.events
  where type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded',
                     'OffsideGiven','OffsideProvoked')
  window w as (partition by game_id order by ws_id)
),
sh as (select * from seq where is_shot),
credits as (
  select p1 as player_id from sh where t1 = team and p1 is not null
     and ty1 in ('Pass','TakeOn','BallTouch','BallRecovery')
  union all
  select p2 from sh where t2 = team and p2 is not null and p2 <> coalesce(p1,'')
     and ty2 in ('Pass','TakeOn','BallTouch','BallRecovery')
)
select player_id, count(*) as sca from credits group by player_id;
create unique index on mv_player_sca (player_id);

-- Counter-pressing: defensive actions within 5 seconds of the team losing the ball.
create materialized view mv_player_counterpress as
with seq as (
  select game_id, ws_id, team, player_id, type,
         (minute*60+second) as abs_sec,
         lag(team) over w as prev_team,
         lag(minute*60+second) over w as prev_sec,
         lag(type) over w as prev_type
  from public.events
  where type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded',
                     'OffsideGiven','OffsideProvoked')
  window w as (partition by game_id order by ws_id)
)
select player_id, count(*) as counterpress
from seq
where type in ('Tackle','Interception','BallRecovery','Challenge','BlockedPass')
  and prev_team <> team                       -- opposition had just taken it
  and (abs_sec - prev_sec) between 0 and 5
group by player_id;
create unique index on mv_player_counterpress (player_id);

-- Set-piece threat, split from open play
create materialized view mv_player_setpiece as
select
  e.player_id,
  count(*) filter (where e.is_shot and not e.is_open_play)                as sp_shots,
  round(sum(x.xg) filter (where not x.is_open_play and not x.is_pen)::numeric,3) as sp_xg,
  count(*) filter (where e.type='Pass' and not e.is_open_play
    and e.qualifiers @> '[{"type":{"displayName":"KeyPass"}}]'::jsonb)    as sp_key_passes
from public.events e
left join mv_shot_xg x on x.game_id=e.game_id and x.ws_id=e.ws_id
where e.player_id is not null
group by e.player_id;
create unique index on mv_player_setpiece (player_id);

grant select on mv_player_holdup, mv_player_sca, mv_player_counterpress, mv_player_setpiece
  to anon, authenticated;
