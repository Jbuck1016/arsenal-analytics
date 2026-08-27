alter table leagues drop constraint if exists leagues_competition_type_chk;

update leagues set competition_type = 'domestic_cup'
 where league in ('ENG-FA Cup','ENG-League Cup');
update leagues set competition_type = 'continental'
 where league in ('INT-Champions League');

alter table leagues add constraint leagues_competition_type_chk
  check (competition_type in ('league','domestic_cup','continental'));

create or replace view v_league_competitions as
  select league, display_name, country, tier, season, is_active, expected_teams
  from leagues where competition_type = 'league';

comment on view v_league_competitions is
  'Registered league competitions only. Single source of competition membership for league-scoped analytics.';

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

do $assert$
declare n int;
begin
  select count(*) into n from leagues where competition_type = 'domestic_cup';
  if n <> 2 then raise exception 'ASSERT FAILED. Expected 2 domestic cups, found %.', n; end if;
  select count(*) into n from leagues where competition_type = 'continental';
  if n <> 1 then raise exception 'ASSERT FAILED. Expected 1 continental competition, found %.', n; end if;
  select count(*) into n from leagues where competition_type = 'league';
  if n <> 6 then raise exception 'ASSERT FAILED. Expected 6 league competitions, found %.', n; end if;
  if (select count(*) from v_league_events) >= (select count(*) from events) then
    raise exception 'ASSERT FAILED. v_league_events did not exclude anything.';
  end if;
  if exists (select 1 from v_league_events e join leagues l on l.league = e.league
             where l.competition_type <> 'league') then
    raise exception 'ASSERT FAILED. v_league_events leaked a non-league fixture.';
  end if;
end
$assert$;

select competition_type, count(*)::text as n, string_agg(league, ', ' order by league) as members
from leagues group by competition_type order by 1;
