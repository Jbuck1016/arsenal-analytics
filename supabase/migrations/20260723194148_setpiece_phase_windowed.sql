create materialized view mv_event_phase as
with seq as (
  select game_id, ws_id, team, (minute*60+second) as abs_sec,
         case when (not is_open_play and type='Pass') then (minute*60+second) end as delivery_sec
  from public.events
),
carried as (
  select game_id, ws_id, abs_sec,
         max(delivery_sec) over (
           partition by game_id, team order by ws_id
           rows between unbounded preceding and current row
         ) as last_delivery
  from seq
)
select game_id, ws_id,
       (last_delivery is not null and abs_sec - last_delivery between 0 and 10) as set_piece_phase
from carried;
create unique index on mv_event_phase (game_id, ws_id);
create index on mv_event_phase (set_piece_phase);

drop materialized view if exists mv_player_setpiece cascade;
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

grant select on mv_event_phase, mv_player_setpiece to anon, authenticated;
