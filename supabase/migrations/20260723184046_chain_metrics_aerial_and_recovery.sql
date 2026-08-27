-- "What happens next" metrics: an action judged by the outcome it produces,
-- not just by whether it was completed.
--   Aerial Quality: +2 keep it yourself, +1 to a teammate, -1 to the opposition.
--   Post-recovery:  what the player does in the action after winning the ball.
create materialized view mv_player_chains as
with seq as (
  select
    game_id, ws_id, team, player_id, type, outcome_type, x, y, end_x, end_y,
    (minute*60 + second) as abs_sec,
    lead(team)      over w as n_team,
    lead(player_id) over w as n_player,
    lead(type)      over w as n_type,
    lead(outcome_type) over w as n_outcome,
    lead(x)         over w as n_x,
    lead(end_x)     over w as n_end_x,
    lead(minute*60 + second) over w as n_sec
  from public.events
  where type not in ('Start','End','FormationSet','FormationChange','Card',
                     'SubstitutionOn','SubstitutionOff','CornerAwarded',
                     'OffsideGiven','OffsideProvoked')
  window w as (partition by game_id order by ws_id)
),
aer as (
  select player_id,
    count(*)                                                         as aerials_won,
    count(*) filter (where n_player = player_id)                     as aq_self,
    count(*) filter (where n_team = team and n_player <> player_id)  as aq_mate,
    count(*) filter (where n_team <> team)                           as aq_opp
  from seq
  where type='Aerial' and outcome_type='Successful' and n_team is not null
  group by player_id
),
rec as (
  select player_id,
    count(*)                                                          as recoveries,
    count(*) filter (where n_player = player_id and n_type='Pass'
                       and n_outcome='Successful')                    as recov_pass_ok,
    count(*) filter (where n_player = player_id and n_type='Pass')     as recov_pass_att,
    count(*) filter (where n_player = player_id and n_type='Pass'
                       and n_outcome='Successful'
                       and n_end_x is not null and n_x is not null and (
                         (n_x<50 and n_end_x<50  and (n_end_x-n_x)>=30) or
                         (n_x<50 and n_end_x>=50 and (n_end_x-n_x)>=15) or
                         (n_x>=50 and n_end_x>=50 and (n_end_x-n_x)>=10)))  as recov_prog_pass
  from seq
  where type='BallRecovery' and (n_sec - abs_sec) between 0 and 10
  group by player_id
)
select
  coalesce(a.player_id, r.player_id) as player_id,
  a.aerials_won, a.aq_self, a.aq_mate, a.aq_opp,
  case when a.aerials_won > 0
       then round(((2.0*a.aq_self + a.aq_mate - a.aq_opp)/a.aerials_won)::numeric,2) end as aq_per_duel,
  case when a.aerials_won >= 10
       then round(100.0*(a.aq_self + a.aq_mate)/a.aerials_won,1) end as duel_quality,
  r.recoveries, r.recov_pass_att, r.recov_pass_ok, r.recov_prog_pass,
  case when r.recov_pass_att >= 10
       then round(100.0*r.recov_pass_ok/r.recov_pass_att,1) end as recov_retention
from aer a
full outer join rec r on r.player_id = a.player_id;

create unique index on mv_player_chains (player_id);
grant select on mv_player_chains to anon, authenticated;
