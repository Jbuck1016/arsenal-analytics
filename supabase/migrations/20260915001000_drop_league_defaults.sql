-- Section 6. Drop the USA-MLS league defaults.
--
-- Eight tables carried "default 'USA-MLS'": events, events_archive,
-- events_quarantine, lineups, matches, player_chain_roles, sequences,
-- team_names. That default is why 1,573 La Liga sequences were silently written
-- as MLS, and why it recurred on 8 September with 2,834 Premier League rows.
--
-- Every one of those league columns is NOT NULL, so once the default is gone a
-- writer that omits league fails loudly instead of becoming MLS. That makes each
-- such writer a rebuild breaker, so every writer was checked against the live
-- database before dropping, rather than assumed:
--
--   events_swap_tick, events_swap_copy_phase, purge_fixture_events
--       copy whole rows with select *, so league travels with them.
--   rebuild_team_names
--       names league.
--   scrape_and_load.py (matches, lineups, events)
--       sets league explicitly on every payload. Its two function signatures
--       also carried league: str = "USA-MLS" as a Python default, removed in the
--       same change so omission is a TypeError.
--   build_sequences, build_sequences_for
--       never name league. Covered by trg_sequences_league below.
--   build_player_chain_roles
--       never names league either. This one the first draft of this migration
--       missed, and it would have stopped the rebuild at the players step.
--
-- Both builders relied on a later stamping pass. For sequences that pass reads
-- matches, which is always current. For player_chain_roles it reads
-- mv_player_league, which is refreshed at the lookups step, after players, so at
-- insert time it is one rebuild old and a player new this week is not in it.
--
-- The chain-role trigger derives league with the same rule as mv_player_league,
-- the modal league of the player's live events, read from v_league_events so it
-- cannot be stale. Verified against all 857 current chain-role players before
-- relying on it: every one has live events, none has a tied modal league, and
-- mv_player_league's choice is the modal league in every case. So the trigger
-- produces exactly the value the lookups step re-stamps, and no stored value
-- changes. Sequences verified the same way: 1,011 games, none without a
-- fixture, none whose stored league differs from the fixture.

-- Short lock wait: DROP DEFAULT needs ACCESS EXCLUSIVE for an instant, and it
-- must not queue behind a long site read and then block everything behind it.
set local lock_timeout = '10s';

create or replace function public.stamp_row_league()
returns trigger language plpgsql as $fn$
begin
  if new.league is null then
    select m.league into new.league from public.matches m where m.game_id = new.game_id;
  end if;
  return new;
end $fn$;

drop trigger if exists trg_sequences_league on public.sequences;
create trigger trg_sequences_league
  before insert on public.sequences
  for each row execute function public.stamp_row_league();

create or replace function public.stamp_player_league()
returns trigger language plpgsql as $fn$
begin
  if new.league is null then
    select e.league into new.league
      from public.v_league_events e
     where e.player_id = new.player_id
     group by e.league
     order by count(*) desc
     limit 1;
  end if;
  return new;
end $fn$;

drop trigger if exists trg_player_chain_roles_league on public.player_chain_roles;
create trigger trg_player_chain_roles_league
  before insert on public.player_chain_roles
  for each row execute function public.stamp_player_league();

alter table public.sequences          alter column league drop default;
alter table public.player_chain_roles alter column league drop default;
alter table public.events             alter column league drop default;
alter table public.events_quarantine  alter column league drop default;
alter table public.events_archive     alter column league drop default;
alter table public.lineups            alter column league drop default;
alter table public.matches            alter column league drop default;
alter table public.team_names         alter column league drop default;

-- Guards the class: any default on any league column, not only the USA-MLS
-- string, so a different hardcoded league cannot reintroduce the same failure.
insert into public.invariants (name, description, check_sql, severity, enabled) values
('no_defaulted_league',
 'No league column in a public table may carry a default. The USA-MLS default silently rewrote 1,573 La Liga sequences and 2,834 Premier League rows as MLS, because writers that do not name the column took the default and only a later stamping pass corrected it. Every league column is NOT NULL, so without a default an omitted league fails loudly. Sequences and player_chain_roles derive league by trigger. Checks any default, not just the MLS string, so a different hardcoded league cannot reintroduce the same failure.',
 $q$select count(*) from pg_attribute a
     join pg_class c on c.oid = a.attrelid and c.relkind = 'r'
     join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
     join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
    where a.attname = 'league' and not a.attisdropped$q$,
 'error', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;
