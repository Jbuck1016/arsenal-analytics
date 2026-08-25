\set ON_ERROR_STOP on
do $assert$
declare n int;
begin
 select coalesce(sum(violations),0) into n from run_invariants() where severity='error';
 if n<>0 then raise exception 'forward fixture has % error violations',n; end if;
 if exists(select 1 from league_mart_entry_objects where object_name='mv_game_goals') then
  raise exception 'mv_game_goals registry exception was not removed'; end if;
 if exists(select 1 from invariants where name in
  ('league_mart_reads_scoped_sources','no_non_league_fixture_in_metrics',
   'no_non_league_row_in_league_outputs','team_league_resolves') and severity<>'error') then
  raise exception 'scoping invariant promotion incomplete'; end if;
 if (select count(*) from mv_team_match tm join matches m using(game_id)
     join leagues l on l.league=m.league where l.competition_type<>'league')<>0 then
  raise exception 'cup fixture remains in mv_team_match'; end if;
 if (select count(*) from mv_game_goals where game_id='g2')<>0 then
  raise exception 'shootout goal remains in mv_game_goals'; end if;
end $assert$;
select 'FORWARD_ASSERTIONS_OK';
