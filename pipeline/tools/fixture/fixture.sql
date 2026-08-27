\set ON_ERROR_STOP on
do $roles$
begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
 if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
end $roles$;

create table events(game_id text,ws_id int,team text,league text,period int,is_goal bool,player_id int);
create table matches(game_id text primary key,league text,season text,home_team text,away_team text,home_score int,away_score int);
create table sequences(seq_uid text primary key,game_id text,team text,league text,is_open_play bool);
create table lineups(game_id text,player_id int,team text,league text,is_starter bool);
create table leagues(league text primary key,competition_type text not null);
insert into leagues values
 ('USA-MLS','league'),('ENG-Premier League','league'),
 ('ENG-FA Cup','domestic_cup'),('INT-Champions League','continental');
insert into events values
 ('g1',1,'Arsenal','ENG-Premier League',2,true,10),
 ('g2',2,'Arsenal','ENG-FA Cup',5,true,10),
 ('g3',3,'LAFC','USA-MLS',1,false,20);
insert into matches values
 ('g1','ENG-Premier League','2627','Arsenal','Chelsea',1,0),
 ('g2','ENG-FA Cup','2526','Arsenal','Wigan',1,1),
 ('g3','USA-MLS','2026','LAFC','Austin',0,0);
insert into sequences values
 ('s1','g1','Arsenal','ENG-Premier League',true),
 ('s2','g2','Arsenal','ENG-FA Cup',true),
 ('s3','g3','LAFC','USA-MLS',true);
insert into lineups values ('g1',10,'Arsenal','ENG-Premier League',true);

create view v_league_events with(security_invoker=true) as
 select e.* from events e join leagues l on l.league=e.league and l.competition_type='league';
create view v_league_matches with(security_invoker=true) as
 select m.* from matches m join leagues l on l.league=m.league and l.competition_type='league';
create view v_league_sequences with(security_invoker=true) as
 select s.* from sequences s join leagues l on l.league=s.league and l.competition_type='league';
create view v_league_lineups with(security_invoker=true) as
 select li.* from lineups li join leagues l on l.league=li.league and l.competition_type='league';

create materialized view mv_game_goals as
 select game_id,team scoring_team from events e where e.is_goal;
create index mv_game_goals_idx on mv_game_goals(game_id);
comment on materialized view mv_game_goals is 'fixture: exact original comment';

create materialized view mv_team_league as
 select team,min(league) league from events where team is not null group by team;
create unique index mv_team_league_pk on mv_team_league(team);
create materialized view mv_team_match as
 select game_id,team,count(*) n from events group by game_id,team;
create materialized view mv_team_lanes as
 select m.game_id,m.home_team team from matches m;
create view v_season_stats as
 select m.game_id,e.team from events e join matches m on m.game_id=e.game_id;
create materialized view mv_state_segments as
 select events.game_id,events.team from events where events.team is not null;
create view v_team_sample with(security_invoker=true) as
 select s.team,min(s.league) league,count(*) matches from sequences s group by s.team;

create materialized view mv_team_percentiles as
 select t.team,coalesce(tl.league,'USA-MLS'::text) league
 from mv_team_match t left join mv_team_league tl on tl.team=t.team;
create materialized view mv_player_percentiles as
 select p.team,coalesce(pl.league,'USA-MLS'::text) league
 from mv_team_match p left join mv_team_league pl on pl.team=p.team;
-- Both mv_team_breakdown and v_team_sample are seeds. This edge is the
-- regression case that the old topology incorrectly discarded.
create materialized view mv_team_breakdown as
 select b.team,coalesce(zz.league,'USA-MLS') league,s.matches
 from mv_team_match b left join mv_team_league zz on zz.team=b.team
 join v_team_sample s on s.team=b.team;
create view v_team_directory as select d.team,d.league from mv_team_percentiles d;
create materialized view mv_team_all as select a.team from mv_team_percentiles a;

-- Kept as a table so the fixture can exercise relational coverage assertions
-- without enlarging the view dependency closure.
create table mv_seq_state as select seq_uid from v_league_sequences;

alter materialized view mv_game_goals owner to postgres;
grant select on mv_game_goals to anon,authenticated;
grant all on mv_game_goals to service_role with grant option;
grant select on mv_team_league,mv_team_match,mv_team_lanes,v_season_stats,
 mv_state_segments,v_team_sample,mv_team_percentiles,mv_player_percentiles,
 mv_team_breakdown,v_team_directory,mv_team_all to anon,authenticated;
grant select on mv_team_league to service_role;

create table league_mart_entry_objects(object_name text primary key,note text,enabled bool not null default true);
insert into league_mart_entry_objects values
 ('mv_game_goals','fixture original registry note -- do not hardcode',false);
create table invariants(name text primary key,severity text not null);
insert into invariants values
 ('goals_reconcile','error'),
 ('league_mart_reads_scoped_sources','warn'),
 ('no_non_league_fixture_in_metrics','info'),
 ('no_non_league_row_in_league_outputs','warn'),
 ('team_league_resolves','error');

create function run_invariants()
returns table(name text,severity text,violations int)
language sql stable as $fn$
 select i.name,i.severity,
  case i.name
   when 'goals_reconcile' then (select count(*)::int from mv_game_goals where game_id='g2')
   when 'league_mart_reads_scoped_sources' then
    (select count(*)::int from league_mart_entry_objects where object_name='mv_game_goals')
   when 'no_non_league_fixture_in_metrics' then
    (select count(*)::int from mv_team_match tm join matches m using(game_id)
      join leagues l on l.league=m.league where l.competition_type<>'league')
   when 'no_non_league_row_in_league_outputs' then
    (select count(*)::int from mv_team_league tl join leagues l using(league)
      where l.competition_type<>'league')
   when 'team_league_resolves' then
    case when (select league from mv_team_league where team='Arsenal')='ENG-Premier League' then 0 else 1 end
  end
 from invariants i
$fn$;

create function build_insights() returns void language sql as 'select';
create function polish_insights() returns void language sql as 'select';
create function refresh_site_summaries() returns void language sql as 'select';
create function verify_rebuild() returns void language plpgsql as $fn$
declare n int;
begin
 select coalesce(sum(violations),0) into n from run_invariants() where severity='error';
 if n<>0 then raise exception 'verify_rebuild: % error violations',n; end if;
end $fn$;

-- The baseline intentionally fails goals_reconcile. Reverse must therefore
-- compare exact captured results and must not call verify_rebuild().
do $baseline$
begin
 if (select violations from run_invariants() where name='goals_reconcile')<>1 then
  raise exception 'Fixture baseline must contain goals_reconcile=1'; end if;
end $baseline$;
