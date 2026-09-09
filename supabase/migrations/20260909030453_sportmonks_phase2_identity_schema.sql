-- Sportmonks phase 2: identity mapping.
-- Additive only. No existing table is modified beyond one nullable column.

create table if not exists public.sm_team_link (
  id            bigint generated always as identity primary key,
  sm_team_id    integer,
  sm_team_name  text,
  league        text not null references public.leagues(league),
  our_team      text,
  match_method  text not null check (match_method in ('exact','manual','unresolved')),
  confidence    numeric(3,2) check (confidence >= 0 and confidence <= 1),
  verified_at   timestamptz,
  -- a row must describe at least one side, so an unmatched team on either side
  -- is still recorded rather than silently dropped
  constraint sm_team_link_one_side check (sm_team_id is not null or our_team is not null)
);

comment on table public.sm_team_link is
  'Sportmonks team id to our team string. our_team uses the matches vocabulary (team_names.match_name); team_names.event_name is the alias used by players.team and lineups.team.';

-- a resolved link may not be many-to-one or one-to-many in either direction.
-- unresolved rows are exempt, which is what lets them be recorded at all.
create unique index if not exists sm_team_link_sm_uniq
  on public.sm_team_link (sm_team_id)
  where sm_team_id is not null and match_method <> 'unresolved';
create unique index if not exists sm_team_link_our_uniq
  on public.sm_team_link (league, our_team)
  where our_team is not null and match_method <> 'unresolved';

create table if not exists public.sm_player_link (
  id              bigint generated always as identity primary key,
  sm_player_id    integer,
  sm_player_name  text,
  sm_date_of_birth date,
  our_player_id   text,
  our_player_name text,
  league          text not null references public.leagues(league),
  team            text,
  match_method    text not null check (match_method in (
                    'exact_name_in_team','normalised_name_in_team',
                    'exact_name_in_league','normalised_name_in_league',
                    'manual','unresolved')),
  confidence      numeric(3,2) check (confidence >= 0 and confidence <= 1),
  verified_at     timestamptz,
  notes           text,
  constraint sm_player_link_one_side check (sm_player_id is not null or our_player_id is not null)
);

comment on table public.sm_player_link is
  'Sportmonks player id to our WhoScored player_id. Ambiguous candidates are recorded as unresolved on both sides rather than resolved arbitrarily.';

-- identity is league independent, so these are unique across the whole table
create unique index if not exists sm_player_link_sm_uniq
  on public.sm_player_link (sm_player_id)
  where sm_player_id is not null and match_method <> 'unresolved';
create unique index if not exists sm_player_link_our_uniq
  on public.sm_player_link (our_player_id)
  where our_player_id is not null and match_method <> 'unresolved';

-- Nullable, so nothing that reads players breaks. Deliberately NOT backfilled
-- from Sportmonks: populating it from the source we verify against would make
-- the verification circular.
alter table public.players add column if not exists date_of_birth date;
comment on column public.players.date_of_birth is
  'Nullable. Added in Sportmonks phase 2. Not populated from Sportmonks by design; a value here must come from an independent source so it can corroborate a link.';
