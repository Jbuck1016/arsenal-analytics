insert into team_names (league, event_name, match_name, display_name)
values ('ENG-Premier League', 'Man City', 'Manchester City', 'Manchester City')
on conflict do nothing;

select league, event_name, match_name, display_name
from team_names where league='ENG-Premier League' and event_name='Man City';
