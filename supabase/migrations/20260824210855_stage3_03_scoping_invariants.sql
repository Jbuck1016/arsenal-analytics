-- Audited league-mart entry objects. Each must read the canonical scoped
-- sources, never the raw tables. Maintained deliberately as a list so
-- that adding an object to the mart is an explicit decision.
create table if not exists league_mart_entry_objects (
  object_name text primary key,
  note        text
);

insert into league_mart_entry_objects (object_name, note) values
  ('mv_team_match',            'per-match team metrics, feature source'),
  ('mv_team_season',           'season aggregate over mv_team_match'),
  ('mv_team_lanes',            'feeds mv_team_all, absent from the dependency tree'),
  ('mv_team_attackphase',      'feeds mv_team_all'),
  ('mv_team_buildphase',       'feeds mv_team_all'),
  ('mv_team_zones',            'territory'),
  ('mv_team_sequences',        'sequence counts'),
  ('mv_team_league',           'club to league resolution'),
  ('mv_game_goals',            'match goals, shootout rule'),
  ('mv_state_segments',        'game state spine'),
  ('mv_squad_role',            'squad usage'),
  ('mv_league_summary',        'league totals'),
  ('mv_league_availability',   'insight availability'),
  ('mv_team_breakdown',        'route breakdown'),
  ('mv_player_state_output',   'state adjusted player output'),
  ('mv_player_percentiles',    'player percentile layer'),
  ('v_season_stats',           'season stat source for ranks'),
  ('v_seq_directness',         'directness'),
  ('v_team_sample',            'team evidence base, six match minimum'),
  ('v_team_directory',         'team directory')
on conflict (object_name) do update set note = excluded.note;

revoke all on league_mart_entry_objects from public, anon, authenticated;
grant select on league_mart_entry_objects to anon, authenticated;
grant all on league_mart_entry_objects to service_role;

-- Structural invariant: an audited entry object may not depend directly
-- on a raw unscoped table. Catalog driven, so a future object that reads
-- events fails the rebuild instead of silently pooling competitions.
insert into invariants (name, description, check_sql, severity, enabled)
values (
  'league_mart_reads_scoped_sources',
  'Audited league-mart entry objects must read the canonical scoped sources (v_league_events, v_league_matches, v_league_sequences, v_league_lineups) rather than the raw events, matches, sequences or lineups tables. Structural rather than value based: it catches a new object that pools competitions before any wrong number is published.',
  'select count(*) from (
     select distinct c.relname
     from pg_depend d
     join pg_rewrite r on r.oid = d.objid
     join pg_class c on c.oid = r.ev_class
     join pg_class src on src.oid = d.refobjid
     join pg_namespace sn on sn.oid = src.relnamespace and sn.nspname = ''public''
     where src.relname in (''events'',''matches'',''sequences'',''lineups'')
       and c.relname in (select object_name from league_mart_entry_objects)
   ) z',
  'warn',
  true
)
on conflict (name) do update
  set description = excluded.description, check_sql = excluded.check_sql,
      severity = excluded.severity, enabled = excluded.enabled;

-- Output invariant: no non-league fixture may contribute to a league
-- metric grain. Checks the actual contributing matches, not labels.
insert into invariants (name, description, check_sql, severity, enabled)
values (
  'no_non_league_fixture_in_metrics',
  'No domestic_cup or continental fixture may contribute to team metric grains. Counts contributing matches in mv_team_match whose competition is not a league.',
  'select count(*) from mv_team_match tm
     join matches m on m.game_id = tm.game_id
     join leagues l on l.league = m.league
    where l.competition_type <> ''league''',
  'warn',
  true
)
on conflict (name) do update
  set description = excluded.description, check_sql = excluded.check_sql,
      severity = excluded.severity, enabled = excluded.enabled;

insert into invariants (name, description, check_sql, severity, enabled)
values (
  'no_non_league_row_in_league_outputs',
  'No league-scoped output object may carry a row labelled with a domestic_cup or continental competition.',
  'select
     (select count(*) from v_team_sample where league in (select league from leagues where competition_type <> ''league''))
   + (select count(*) from mv_team_league where league in (select league from leagues where competition_type <> ''league''))
   + (select count(*) from mv_team_percentiles where league in (select league from leagues where competition_type <> ''league''))
   + (select count(*) from mv_team_stat_ranks where league in (select league from leagues where competition_type <> ''league''))
   + (select count(*) from mv_team_breakdown where league in (select league from leagues where competition_type <> ''league''))
   + (select count(*) from mv_team_directness_state where league in (select league from leagues where competition_type <> ''league''))',
  'warn',
  true
)
on conflict (name) do update
  set description = excluded.description, check_sql = excluded.check_sql,
      severity = excluded.severity, enabled = excluded.enabled;

insert into invariants (name, description, check_sql, severity, enabled)
values (
  'team_league_resolves',
  'Every club appearing in a registered league competition must resolve in mv_team_league, and no club may resolve to a league it never played in. Guards the silent MLS fallback class of defect.',
  'select
     (select count(*) from (
        select distinct e.team from events e
        join leagues l on l.league = e.league and l.competition_type = ''league''
        where e.team is not null) t
      where not exists (select 1 from mv_team_league tl where tl.team = t.team))
   + (select count(*) from mv_team_league tl
      where not exists (select 1 from events e where e.team = tl.team and e.league = tl.league))',
  'warn',
  true
)
on conflict (name) do update
  set description = excluded.description, check_sql = excluded.check_sql,
      severity = excluded.severity, enabled = excluded.enabled;

select name, severity, violations from run_invariants()
where name in ('league_mart_reads_scoped_sources','no_non_league_fixture_in_metrics',
               'no_non_league_row_in_league_outputs','team_league_resolves')
order by name;
