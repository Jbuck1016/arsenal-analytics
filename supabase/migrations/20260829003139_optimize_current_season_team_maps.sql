begin;

create index if not exists idx_events_team_game_id
  on public.events(team,game_id);

analyze public.events;

commit;
