-- Transfermarkt market-value enrichment.
-- Parse is an ingestion provider only; the browser reads normalized Supabase rows.

create table if not exists public.transfermarkt_player_links (
  transfermarkt_player_id text primary key,
  transfermarkt_player_name text not null,
  transfermarkt_club_id text,
  transfermarkt_club_name text,
  player_id text references public.players(player_id) on delete set null,
  canonical_player_name text,
  team text,
  league text references public.leagues(league),
  match_method text not null check (match_method in (
    'exact_name_in_team', 'normalized_name_in_team', 'fuzzy_name_in_team', 'manual', 'unresolved'
  )),
  confidence numeric(4,3) not null check (confidence >= 0 and confidence <= 1),
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);

comment on table public.transfermarkt_player_links is
  'Transfermarkt player identity mapped to the canonical WhoScored player. Ambiguous rows remain unresolved.';

create unique index if not exists transfermarkt_player_links_player_uniq
  on public.transfermarkt_player_links (player_id)
  where player_id is not null and match_method <> 'unresolved';
create index if not exists transfermarkt_player_links_team_idx
  on public.transfermarkt_player_links (league, team);

create table if not exists public.player_market_value_snapshots (
  transfermarkt_player_id text not null
    references public.transfermarkt_player_links(transfermarkt_player_id) on delete restrict,
  observed_on date not null,
  season text not null,
  market_value_eur bigint,
  market_value_display text,
  currency text not null default 'EUR' check (currency = 'EUR'),
  provider text not null default 'transfermarkt' check (provider = 'transfermarkt'),
  retrieved_at timestamptz not null default now(),
  primary key (transfermarkt_player_id, observed_on),
  check (market_value_eur is null or market_value_eur >= 0)
);

comment on table public.player_market_value_snapshots is
  'One normalized Transfermarkt market-value observation per player per retrieval date. Values are estimates, not transfer fees.';

create index if not exists player_market_value_snapshots_latest_idx
  on public.player_market_value_snapshots (transfermarkt_player_id, observed_on desc);

alter table public.transfermarkt_player_links enable row level security;
alter table public.player_market_value_snapshots enable row level security;

revoke all on table public.transfermarkt_player_links from anon, authenticated;
revoke all on table public.player_market_value_snapshots from anon, authenticated;
grant select on table public.transfermarkt_player_links to anon, authenticated;
grant select on table public.player_market_value_snapshots to anon, authenticated;
grant select, insert, update, delete on table public.transfermarkt_player_links to service_role;
grant select, insert, update, delete on table public.player_market_value_snapshots to service_role;

drop policy if exists transfermarkt_player_links_public_read on public.transfermarkt_player_links;
create policy transfermarkt_player_links_public_read
  on public.transfermarkt_player_links for select to anon, authenticated using (true);

drop policy if exists player_market_value_snapshots_public_read on public.player_market_value_snapshots;
create policy player_market_value_snapshots_public_read
  on public.player_market_value_snapshots for select to anon, authenticated using (true);

create or replace view public.v_player_market_values_latest
with (security_invoker = true)
as
select distinct on (l.player_id)
  l.player_id,
  l.canonical_player_name as player_name,
  l.team,
  l.league,
  l.transfermarkt_player_id,
  s.season,
  s.market_value_eur,
  s.market_value_display,
  s.currency,
  s.observed_on,
  s.retrieved_at,
  l.match_method,
  l.confidence
from public.transfermarkt_player_links l
join public.player_market_value_snapshots s
  on s.transfermarkt_player_id = l.transfermarkt_player_id
where l.player_id is not null
order by l.player_id, s.observed_on desc, s.retrieved_at desc;

revoke all on table public.v_player_market_values_latest from anon, authenticated;
grant select on table public.v_player_market_values_latest to anon, authenticated;

notify pgrst, 'reload schema';
