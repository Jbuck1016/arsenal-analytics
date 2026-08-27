-- =====================================================================
-- 20260824_02_competition_registry.sql
-- Stage 3, migration 02. APPLIED 2026-08-24.
-- Replayable from the established Stage 2 schema baseline. Requires
-- migration 01; this is not a complete empty-database baseline.
--
-- Three-way competition classification, plus the canonical league-scoped
-- sources that every league-mart entry object must read.
--
-- WHY THREE VALUES, NOT TWO
--   Domestic cups draw from the same national pyramid: Arsenal's cup
--   opponents include Mansfield, Port Vale and Wigan, so pooling them
--   into Premier League metrics compares a top-flight side against lower
--   tiers. The Champions League is different in kind: its clubs come from
--   other domestic leagues entirely. Both must be excluded from league
--   metrics, but continental fixtures are the only common-opponent data
--   across leagues this platform has, which is exactly what the parked
--   league-strength bridge lacks. Collapsing them into one "cup" bucket
--   would discard that.
-- =====================================================================
begin;

-- 1. Registry column and classification.
alter table leagues add column if not exists competition_type text not null default 'league';
alter table leagues drop constraint if exists leagues_competition_type_chk;

insert into leagues (league, display_name, country, tier, ws_name, season, is_active, expected_teams, competition_type)
values
  ('ENG-FA Cup',           'FA Cup',           'England',       null, null, '2526', false, null, 'domestic_cup'),
  ('ENG-League Cup',       'EFL Cup',          'England',       null, null, '2526', false, null, 'domestic_cup'),
  ('INT-Champions League', 'Champions League', 'International', null, null, '2526', false, null, 'continental')
on conflict (league) do update
  set competition_type = excluded.competition_type,
      display_name     = excluded.display_name,
      is_active        = excluded.is_active,
      expected_teams   = excluded.expected_teams;

-- Reclassify before constraining, or the constraint rejects existing rows.
update leagues set competition_type = 'domestic_cup' where league in ('ENG-FA Cup','ENG-League Cup');
update leagues set competition_type = 'continental'  where league in ('INT-Champions League');

alter table leagues add constraint leagues_competition_type_chk
  check (competition_type in ('league','domestic_cup','continental'));

-- 2. team_names primary key at the correct grain.
--    Was PRIMARY KEY (event_name) alone, globally, so a club could be
--    mapped in exactly one competition across the whole database.
do $pk$
begin
  if exists (select 1 from pg_constraint
             where conrelid='public.team_names'::regclass and contype='p'
               and pg_get_constraintdef(oid)='PRIMARY KEY (event_name)') then
    alter table team_names drop constraint team_names_pkey;
    alter table team_names add constraint team_names_pkey primary key (league, event_name);
  end if;
end
$pk$;

-- 3. Name mappings. The event feed shortens several clubs, which is what
--    broke goal reconciliation across five fixtures.
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
  set match_name = excluded.match_name, display_name = excluded.display_name;

-- 4. Canonical league-scoped sources.
create or replace view v_league_competitions as
  select league, display_name, country, tier, season, is_active, expected_teams
  from leagues where competition_type = 'league';

create or replace view v_league_matches as
  select m.* from matches m
  join leagues l on l.league = m.league and l.competition_type = 'league';

create or replace view v_league_events as
  select e.* from events e
  join leagues l on l.league = e.league and l.competition_type = 'league';

create or replace view v_league_sequences as
  select s.* from sequences s
  join leagues l on l.league = s.league and l.competition_type = 'league';

create or replace view v_league_lineups as
  select li.* from lineups li
  join leagues l on l.league = li.league and l.competition_type = 'league';

comment on view v_league_competitions is
  'Registered league competitions only. Single source of competition membership for league-scoped analytics.';
comment on view v_league_events is
  'Canonical league-scoped event source. Excludes domestic_cup and continental fixtures. League-mart objects must read this, not events.';

do $g$
declare r text;
begin
  foreach r in array array['v_league_competitions','v_league_matches','v_league_events',
                           'v_league_sequences','v_league_lineups'] loop
    execute format('alter view public.%I owner to postgres', r);
    execute format('revoke all on public.%I from public, anon, authenticated', r);
    execute format('grant select on public.%I to anon, authenticated', r);
    execute format('grant all on public.%I to service_role', r);
  end loop;
end
$g$;

-- 5. Raising assertions.
do $assert$
declare n int;
begin
  select count(*) into n from leagues where competition_type='domestic_cup';
  if n <> 2 then raise exception 'ASSERT FAILED. Expected 2 domestic cups, found %.', n; end if;
  select count(*) into n from leagues where competition_type='continental';
  if n <> 1 then raise exception 'ASSERT FAILED. Expected 1 continental competition, found %.', n; end if;
  select count(*) into n from leagues where competition_type='league';
  if n <> 6 then raise exception 'ASSERT FAILED. Expected 6 league competitions, found %.', n; end if;

  if not exists (select 1 from pg_constraint where conrelid='public.team_names'::regclass
                 and contype='p' and pg_get_constraintdef(oid)='PRIMARY KEY (league, event_name)') then
    raise exception 'ASSERT FAILED. team_names key is not (league, event_name).';
  end if;

  select count(*) into n from (select league, match_name from team_names
                               group by league, match_name having count(*) > 1) d;
  if n <> 0 then raise exception 'ASSERT FAILED. % duplicate (league, match_name) pairs.', n; end if;

  select count(*) into n from (select distinct league from events) e
   where not exists (select 1 from leagues l where l.league = e.league);
  if n <> 0 then raise exception 'ASSERT FAILED. % competitions in events are unregistered.', n; end if;

  if (select count(*) from v_league_events) >= (select count(*) from events) then
    raise exception 'ASSERT FAILED. v_league_events excluded nothing.';
  end if;
  if exists (select 1 from v_league_events e join leagues l on l.league=e.league
             where l.competition_type <> 'league') then
    raise exception 'ASSERT FAILED. v_league_events leaked a non-league fixture.';
  end if;
end
$assert$;

commit;
