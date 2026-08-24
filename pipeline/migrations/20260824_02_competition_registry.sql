-- =====================================================================
-- 20260824_02_competition_registry.sql
-- Project: xrsilhiffjoulyoqhdmp
-- Status:  ALREADY APPLIED to the live database. Captured here so the
--          schema can be reconstructed from source control.
--
-- Prerequisite for 20260824_03_cup_isolation.sql, which reads
-- leagues.competition_type and assumes these mappings exist.
--
-- Idempotent: safe to run against a database that already has them.
--
-- WHY THE PRIMARY KEY CHANGED
--   team_names had its primary key on event_name alone, globally. A club
--   could therefore be mapped in exactly one competition across the whole
--   database, so Arsenal could not exist in both the Premier League and
--   the FA Cup. Worse, rebuild_team_names(p_league) inserts per league
--   with no conflict clause, so it would have raised outright the first
--   time a club appeared in two registered competitions. The key is now
--   (league, event_name), which is the grain the table always meant.
--   No foreign keys and no views depend on it.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Competition classification on the registry.
--    Membership is read from here and is never inferred from team names.
-- ---------------------------------------------------------------------
alter table leagues add column if not exists competition_type text not null default 'league';

alter table leagues drop constraint if exists leagues_competition_type_chk;
alter table leagues add constraint leagues_competition_type_chk
  check (competition_type in ('league','cup'));

-- ---------------------------------------------------------------------
-- 2. Register the three cup competitions already present in events.
--    is_active false and expected_teams null: they are known competitions,
--    not leagues, and no whitelist completeness guard applies to them.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 3. League-only view of the registry.
-- ---------------------------------------------------------------------
create or replace view v_league_competitions as
  select league, display_name, country, tier, season, is_active, expected_teams
  from leagues where competition_type = 'league';

alter view v_league_competitions owner to postgres;
grant all on v_league_competitions to anon, authenticated, service_role;

comment on view v_league_competitions is
  'Registered league competitions only. The single source of competition membership for league-scoped analytics. Cup competitions are registered in leagues but excluded here.';

-- ---------------------------------------------------------------------
-- 4. Primary key at the correct grain.
-- ---------------------------------------------------------------------
do $pk$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.team_names'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) = 'PRIMARY KEY (event_name)'
  ) then
    alter table team_names drop constraint team_names_pkey;
    alter table team_names add constraint team_names_pkey primary key (league, event_name);
    raise notice 'team_names primary key moved to (league, event_name).';
  else
    raise notice 'team_names primary key already at the correct grain, no change.';
  end if;
end
$pk$;

-- ---------------------------------------------------------------------
-- 5. Cup name mappings.
--    Schedule names on the left of match_name, event-feed names in
--    event_name. Note Leverkusen and Bayern: the event feed shortens
--    both, which is what broke goal reconciliation for four fixtures.
--    Manchester City in the Premier League is included here because it
--    was the same defect in a league competition.
-- ---------------------------------------------------------------------
insert into team_names (league, event_name, match_name, display_name) values
  ('ENG-Premier League','Man City','Manchester City','Manchester City'),
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
  ('INT-Champions League','Bayern','Bayern Munich','Bayern Munich'),
  ('INT-Champions League','Club Brugge','Club Brugge','Club Brugge'),
  ('INT-Champions League','Inter','Inter','Inter'),
  ('INT-Champions League','Kairat Almaty','Kairat Almaty','Kairat Almaty'),
  ('INT-Champions League','Leverkusen','Bayer Leverkusen','Bayer Leverkusen'),
  ('INT-Champions League','Olympiacos','Olympiacos','Olympiacos'),
  ('INT-Champions League','Slavia Prague','Slavia Prague','Slavia Prague'),
  ('INT-Champions League','Sporting','Sporting CP','Sporting CP')
on conflict (league, event_name) do update
  set match_name   = excluded.match_name,
      display_name = excluded.display_name;

-- ---------------------------------------------------------------------
-- 6. Invariant: no club may be silently filed under the wrong league.
--    Guards the class of defect that coalesce(tl.league, 'USA-MLS')
--    created: an unresolved club being assigned a league it never
--    played in. Two checks in one count.
-- ---------------------------------------------------------------------
insert into invariants (name, description, check_sql, severity, enabled)
values (
  'team_league_resolves',
  'Every club appearing in a registered league competition must resolve in mv_team_league, and no club may resolve to a league it never played in. Guards against silent league assignment, which previously filed unresolved clubs as MLS.',
  'select
     (select count(*) from (
        select distinct e.team from events e
        join leagues l on l.league = e.league and l.competition_type = ''league''
        where e.team is not null) t
      where not exists (select 1 from mv_team_league tl where tl.team = t.team))
   + (select count(*) from mv_team_league tl
      where not exists (select 1 from events e
                        where e.team = tl.team and e.league = tl.league))',
  'error',
  true
)
on conflict (name) do update
  set description = excluded.description,
      check_sql   = excluded.check_sql,
      severity    = excluded.severity,
      enabled     = excluded.enabled;

-- ---------------------------------------------------------------------
-- 7. Assertions
-- ---------------------------------------------------------------------
do $assert$
declare n int;
begin
  select count(*) into n from leagues where competition_type = 'cup';
  if n <> 3 then raise exception 'Expected 3 cup competitions, found %.', n; end if;

  select count(*) into n from pg_constraint
   where conrelid = 'public.team_names'::regclass and contype = 'p'
     and pg_get_constraintdef(oid) = 'PRIMARY KEY (league, event_name)';
  if n <> 1 then raise exception 'team_names primary key is not (league, event_name).'; end if;

  select count(*) into n from (
    select league, match_name from team_names group by league, match_name having count(*) > 1) d;
  if n <> 0 then raise exception 'team_names has % duplicate (league, match_name) pairs.', n; end if;

  select count(*) into n from (select distinct league from events) e
   where not exists (select 1 from leagues l where l.league = e.league);
  if n <> 0 then raise exception '% competitions in events are not registered.', n; end if;

  raise notice 'Competition registry verified.';
end
$assert$;

select league, competition_type, is_active,
       (select count(*) from team_names t where t.league = l.league) as mappings
from leagues l order by competition_type, league;
