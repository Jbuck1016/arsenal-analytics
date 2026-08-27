insert into team_names (league, event_name, match_name, display_name) values
  ('ENG-FA Cup','Arsenal','Arsenal','Arsenal'),
  ('ENG-FA Cup','Mansfield','Mansfield','Mansfield Town'),
  ('ENG-FA Cup','Portsmouth','Portsmouth','Portsmouth'),
  ('ENG-FA Cup','Southampton','Southampton','Southampton'),
  ('ENG-FA Cup','Wigan','Wigan','Wigan Athletic'),
  ('ENG-League Cup','Arsenal','Arsenal','Arsenal'),
  ('ENG-League Cup','Brighton','Brighton','Brighton'),
  ('ENG-League Cup','Chelsea','Chelsea','Chelsea'),
  ('ENG-League Cup','Crystal Palace','Crystal Palace','Crystal Palace'),
  ('ENG-League Cup','Man City','Manchester City','Manchester City'),
  ('ENG-League Cup','Port Vale','Port Vale','Port Vale'),
  ('INT-Champions League','Arsenal','Arsenal','Arsenal'),
  ('INT-Champions League','Athletic Club','Athletic Club','Athletic Club'),
  ('INT-Champions League','Atletico','Atletico Madrid','Atletico Madrid'),
  ('INT-Champions League','Bayer Leverkusen','Bayer Leverkusen','Bayer Leverkusen'),
  ('INT-Champions League','Bayern','Bayern Munich','Bayern Munich'),
  ('INT-Champions League','Club Brugge','Club Brugge','Club Brugge'),
  ('INT-Champions League','Inter','Inter','Inter'),
  ('INT-Champions League','Kairat Almaty','Kairat Almaty','Kairat Almaty'),
  ('INT-Champions League','Leverkusen','Bayer Leverkusen','Bayer Leverkusen'),
  ('INT-Champions League','Olympiacos','Olympiacos','Olympiacos'),
  ('INT-Champions League','Slavia Prague','Slavia Prague','Slavia Prague'),
  ('INT-Champions League','Sporting','Sporting CP','Sporting CP')
on conflict do nothing;

select league, count(*)::text as mappings from team_names group by league order by 1;
