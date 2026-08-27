alter table leagues add column if not exists competition_type text not null default 'league';

alter table leagues drop constraint if exists leagues_competition_type_chk;
alter table leagues add constraint leagues_competition_type_chk
  check (competition_type in ('league','cup'));

insert into leagues (league, display_name, country, tier, ws_name, season, is_active, expected_teams, competition_type)
values
  ('ENG-FA Cup',           'FA Cup',           'England',       null, null, '2526', false, null, 'cup'),
  ('ENG-League Cup',       'EFL Cup',          'England',       null, null, '2526', false, null, 'cup'),
  ('INT-Champions League', 'Champions League', 'International', null, null, '2526', false, null, 'cup')
on conflict (league) do update
  set competition_type = excluded.competition_type,
      display_name     = excluded.display_name,
      is_active        = excluded.is_active,
      expected_teams   = excluded.expected_teams;

create or replace view v_league_competitions as
  select league, display_name, country, tier, season, is_active, expected_teams
  from leagues where competition_type = 'league';

grant select on v_league_competitions to anon, authenticated, service_role;

select league, competition_type, is_active, expected_teams from leagues order by competition_type, league;
