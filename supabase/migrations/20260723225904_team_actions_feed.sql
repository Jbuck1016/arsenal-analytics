create index if not exists idx_events_team_type on public.events (team, type);

-- Minimal per-team action feed for drawing real events rather than zone grids.
create or replace view v_team_actions as
select
  e.team, e.type, e.x, e.y, e.end_x, e.end_y,
  (e.outcome_type='Successful') as ok,
  e.is_shot,
  (e.type='Pass' and e.x is not null and e.end_x is not null and (
     (e.x<50 and e.end_x<50  and (e.end_x-e.x)>=30) or
     (e.x<50 and e.end_x>=50 and (e.end_x-e.x)>=15) or
     (e.x>=50 and e.end_x>=50 and (e.end_x-e.x)>=10)))            as prog,
  (e.type='Pass' and e.end_x >= 83 and e.end_y between 21 and 79) as into_box
from public.events e
where e.team is not null and e.x is not null and e.y is not null
  and e.is_open_play
  and e.type in ('Pass','Tackle','Interception','BallRecovery','Clearance',
                 'BlockedPass','Challenge','TakeOn','Aerial')
;
grant select on v_team_actions to anon, authenticated;
notify pgrst, 'reload schema';
