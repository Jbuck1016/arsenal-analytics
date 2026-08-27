-- Finalize the production cup-isolation migration after its long-running
-- connector request returned HTTP 504 after the database transaction committed.
-- The isolation transaction refreshed mv_invariant_status before promoting the
-- four scoping invariants from warn to error, so refresh once more to publish
-- their final severities and assert the committed state.
begin;

refresh materialized view public.mv_invariant_status;

do $assert$
declare
  bad integer;
begin
  if pg_get_viewdef('public.mv_game_goals'::regclass, true)
       not ilike '%period is distinct from 5%' then
    raise exception 'ASSERT FAILED. Period 5 is still included in match goals.';
  end if;

  if pg_get_viewdef('public.mv_team_league'::regclass, true)
       not ilike '%v_league_events%' then
    raise exception 'ASSERT FAILED. Team league resolution is not scoped.';
  end if;

  select count(*) into bad
  from public.mv_invariant_status
  where name in (
    'league_mart_reads_scoped_sources',
    'no_non_league_fixture_in_metrics',
    'no_non_league_row_in_league_outputs',
    'team_league_resolves'
  )
  and (severity <> 'error' or violations <> 0);
  if bad <> 0 then
    raise exception 'ASSERT FAILED. % scoping invariant rows are not zero/error.', bad;
  end if;

  if exists (
    select 1
    from public.mv_team_league tl
    where not exists (
      select 1 from public.v_league_events e
      where e.team = tl.team and e.league = tl.league
    )
  ) then
    raise exception 'ASSERT FAILED. Cup-only club remains in league resolution.';
  end if;
end
$assert$;

commit;
