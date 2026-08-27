-- The five views introduced by Stage 3 defaulted to SECURITY DEFINER
-- semantics, so they would enforce the view owner's permissions rather
-- than the caller's. Every one is a read-only scoped projection and anon
-- already holds SELECT on the underlying tables, so switching to
-- security_invoker narrows the trust boundary without changing what the
-- dashboard can read. This does not touch the ~30 pre-existing
-- SECURITY DEFINER views, which predate Stage 3.
alter view public.v_league_events       set (security_invoker = true);
alter view public.v_league_matches      set (security_invoker = true);
alter view public.v_league_sequences    set (security_invoker = true);
alter view public.v_league_lineups      set (security_invoker = true);
alter view public.v_league_competitions set (security_invoker = true);

do $assert$
declare bad text;
begin
  select string_agg(c.relname, ', ') into bad
  from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where c.relname in ('v_league_events','v_league_matches','v_league_sequences',
                      'v_league_lineups','v_league_competitions')
    and not coalesce(array_to_string(c.reloptions,',') like '%security_invoker=true%', false);
  if bad is not null then
    raise exception 'ASSERT FAILED. security_invoker not set on: %', bad;
  end if;

  -- reads must still work and still exclude non-league competitions
  if (select count(*) from v_league_events) = 0 then
    raise exception 'ASSERT FAILED. v_league_events returned no rows after the change.';
  end if;
  if exists (select 1 from v_league_events e join leagues l on l.league=e.league
             where l.competition_type <> 'league') then
    raise exception 'ASSERT FAILED. v_league_events leaked a non-league competition.';
  end if;
end
$assert$;

select 'security_invoker applied' as status;
