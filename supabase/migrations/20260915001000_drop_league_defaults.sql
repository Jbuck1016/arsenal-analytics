-- Section 6. Drop the USA-MLS league defaults.
--
-- Seven tables carried "default 'USA-MLS'", not the four the brief named:
-- events, events_quarantine, lineups, matches, player_chain_roles, sequences,
-- team_names. That default is why 1,573 La Liga sequences were silently written
-- as MLS, and why it recurred on 8 September with 2,834 Premier League rows.
--
-- Before dropping, every write path was checked rather than assumed.
--
-- build_sequences and build_sequences_for do not name the league column at all.
-- Confirmed by reading the real definitions: position('league' in def) is zero
-- for both. Every row they insert therefore takes the column default. The only
-- reason the data is currently correct is that build_sequences_incremental
-- calls stamp_sequence_leagues() immediately afterwards to fix it up. A direct
-- call to build_sequences_for skips that entirely, which is precisely how the
-- contamination happened twice.
--
-- Rather than rewrite a 7KB function and hope no other writer appears, the
-- league is derived at the table. A BEFORE INSERT trigger fills it from the
-- fixture whenever it is not supplied, so every present and future write path is
-- covered, including build_sequences_for called directly.
--
-- Checked before dropping, all zero:
--   events   vs matches league mismatch: 0
--   lineups  vs matches league mismatch: 0
--   sequences vs matches league mismatch: 0
--   events with mixed leagues inside one fixture: 0

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

alter table public.sequences          alter column league drop default;
alter table public.events             alter column league drop default;
alter table public.events_quarantine  alter column league drop default;
alter table public.events_archive     alter column league drop default;
alter table public.lineups            alter column league drop default;
alter table public.matches            alter column league drop default;
alter table public.player_chain_roles alter column league drop default;
alter table public.team_names         alter column league drop default;

-- A league that silently becomes MLS is worse than one that fails loudly, so
-- make the absence of a value an error rather than a guess.
insert into public.invariants (name, description, check_sql, severity, enabled) values
('no_defaulted_league',
 'No table may carry a league column default. The USA-MLS default silently rewrote 1,573 La Liga sequences and 2,834 Premier League rows as MLS, because build_sequences_for does not name the column and a later stamping pass is the only thing that corrected it. Sequences now derive league from the fixture by trigger, and the absence of a value is an error rather than a guess.',
 $q$select count(*) from pg_attribute a
     join pg_class c on c.oid = a.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
    where n.nspname = 'public' and a.attname = 'league'
      and pg_get_expr(d.adbin, d.adrelid) like '%USA-MLS%'$q$,
 'error', true)
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity, enabled=excluded.enabled;
