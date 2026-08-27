
-- Declarative data-quality checks, run on every rebuild.
--
-- The bug this exists to prevent: a column is added (league), an older build function
-- does not populate it, and a column default quietly fills in a wrong value. Nothing
-- errors. Row counts still look right. The data is simply incorrect.
--
-- Each check returns a COUNT OF VIOLATIONS. Zero is healthy. Adding a new check is an
-- insert, not a code change, so the cost of adding one is near zero and there is no
-- excuse for skipping it.
create table if not exists public.invariants (
  name        text primary key,
  description text not null,
  check_sql   text not null,          -- must return a single integer
  severity    text not null default 'error' check (severity in ('error','warn')),
  enabled     boolean not null default true
);

insert into public.invariants (name, description, check_sql, severity) values

-- league integrity: the exact class of bug that motivated this
('seq_league_matches_events',
 'Every sequence carries the same league as the events it was built from.',
 $q$select count(*) from public.sequences s
    join (select distinct game_id, league from public.events) e using (game_id)
    where s.league is distinct from e.league$q$, 'error'),

('pcr_league_matches_player',
 'Every player chain-role row carries the league the player actually played in.',
 $q$select count(*) from public.player_chain_roles p
    join public.mv_player_league l using (player_id)
    where p.league is distinct from l.league$q$, 'error'),

('no_null_league',
 'No ingest row is missing a league.',
 $q$select (select count(*) from public.events where league is null)
         + (select count(*) from public.matches where league is null)
         + (select count(*) from public.lineups where league is null)
         + (select count(*) from public.sequences where league is null)$q$, 'error'),

('league_registered',
 'Every league present in events is registered in the leagues table.',
 $q$select count(*) from (select distinct league from public.events) e
    where not exists (select 1 from public.leagues l where l.league = e.league)$q$, 'error'),

-- contamination: the original incident, now checked per league
('no_foreign_teams',
 'No team appears in a league whose whitelist does not contain it.',
 $q$select count(*) from (select distinct league, team from public.events where team is not null) e
    where exists (select 1 from public.team_names t where t.league = e.league)
      and not exists (select 1 from public.team_names t
                      where t.league = e.league and t.event_name = e.team)$q$, 'error'),

-- referential integrity between layers
('events_have_matches',
 'Every game with events has a matching row in matches.',
 $q$select count(*) from (select distinct game_id from public.events) e
    where not exists (select 1 from public.matches m where m.game_id = e.game_id)$q$, 'error'),

('seq_covers_events',
 'The sequence layer covers exactly the games that have events.',
 $q$select abs((select count(distinct game_id) from public.sequences)
             - (select count(distinct game_id) from public.events))$q$, 'error'),

-- model sanity
('no_null_xt',
 'No sequence has a null threat value.',
 $q$select count(*) from public.sequences where xt_sum is null$q$, 'error'),

('percentiles_in_range',
 'Every percentile falls between 0 and 100.',
 $q$select count(*) from public.mv_player_pct
    where pct_pool < 0 or pct_pool > 100$q$, 'error'),

('search_matches_roles',
 'The search index contains every profiled player and no others.',
 $q$select abs((select count(*) from public.player_search)
             - (select count(*) from public.player_chain_roles))$q$, 'error'),

-- worth knowing, not worth failing on
('played_without_events',
 'Played matches that have no event data (WhoScored sometimes publishes none).',
 $q$select count(*) from public.matches m where m.home_score is not null
    and not exists (select 1 from public.events e where e.game_id = m.game_id)$q$, 'warn'),

('leagues_without_whitelist',
 'Active leagues with no team whitelist yet, so the contamination guard fails open.',
 $q$select count(*) from public.leagues l where l.is_active
    and not exists (select 1 from public.team_names t where t.league = l.league)$q$, 'warn')

on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity;

grant select on public.invariants to anon, authenticated;

-- Runs every enabled check. A broken check reports as a failure rather than aborting
-- the run, so one bad expression cannot mask the others.
create or replace function public.run_invariants()
returns table(name text, severity text, violations bigint, description text, note text)
language plpgsql security definer set search_path = public as $fn$
declare r record; v bigint; err text;
begin
  for r in select * from public.invariants where enabled order by severity, name loop
    v := null; err := null;
    begin
      execute r.check_sql into v;
    exception when others then
      err := left(sqlerrm, 200);
      v := -1;
    end;
    name := r.name; severity := r.severity; violations := coalesce(v, -1);
    description := r.description; note := err;
    return next;
  end loop;
end $fn$;
revoke execute on function public.run_invariants() from public, anon;
grant execute on function public.run_invariants() to service_role, authenticated;
