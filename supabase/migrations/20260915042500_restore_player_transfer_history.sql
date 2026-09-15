-- Restore the normalized transfer-history API after the PostgREST recovery.

create table if not exists public.player_transfer_events (
  transfermarkt_player_id text not null
    references public.transfermarkt_player_links(transfermarkt_player_id) on delete restrict,
  transfer_key text not null,
  transfer_date date,
  season text,
  from_club_id text,
  from_club_name text,
  from_competition text,
  to_club_id text,
  to_club_name text,
  to_competition text,
  fee_eur bigint,
  fee_display text,
  market_value_eur bigint,
  market_value_display text,
  transfer_type text,
  is_loan boolean not null default false,
  player_age numeric(4,1),
  contract_until date,
  provider text not null default 'transfermarkt' check (provider = 'transfermarkt'),
  retrieved_at timestamptz not null default now(),
  source_payload jsonb not null default '{}'::jsonb,
  primary key (transfermarkt_player_id, transfer_key),
  check (fee_eur is null or fee_eur >= 0),
  check (market_value_eur is null or market_value_eur >= 0)
);

comment on table public.player_transfer_events is
  'Normalized completed and pending Transfermarkt player moves. Fees and valuations retain their original display strings.';

create index if not exists player_transfer_events_date_idx
  on public.player_transfer_events (transfermarkt_player_id, transfer_date desc nulls last);

alter table public.player_transfer_events enable row level security;
revoke all on table public.player_transfer_events from anon, authenticated;
grant select on table public.player_transfer_events to anon, authenticated;
grant select, insert, update, delete on table public.player_transfer_events to service_role;

drop policy if exists player_transfer_events_public_read on public.player_transfer_events;
create policy player_transfer_events_public_read
  on public.player_transfer_events for select to anon, authenticated using (true);

create or replace view public.v_player_transfer_history
with (security_invoker = true)
as
select
  l.player_id,
  l.canonical_player_name as player_name,
  l.team as current_team,
  l.league as current_league,
  e.transfermarkt_player_id,
  e.transfer_key,
  e.transfer_date,
  e.season,
  e.from_club_id,
  e.from_club_name,
  e.from_competition,
  e.to_club_id,
  e.to_club_name,
  e.to_competition,
  e.fee_eur,
  e.fee_display,
  e.market_value_eur,
  e.market_value_display,
  e.transfer_type,
  e.is_loan,
  e.player_age,
  e.contract_until,
  e.retrieved_at
from public.transfermarkt_player_links l
join public.player_transfer_events e
  on e.transfermarkt_player_id = l.transfermarkt_player_id
where l.player_id is not null;

create or replace view public.v_player_market_value_history
with (security_invoker = true)
as
select
  l.player_id,
  l.canonical_player_name as player_name,
  l.team as current_team,
  l.league as current_league,
  s.transfermarkt_player_id,
  s.observed_on,
  s.season,
  s.market_value_eur,
  s.market_value_display,
  s.currency,
  s.retrieved_at
from public.transfermarkt_player_links l
join public.player_market_value_snapshots s
  on s.transfermarkt_player_id = l.transfermarkt_player_id
where l.player_id is not null;

revoke all on table public.v_player_transfer_history from anon, authenticated;
revoke all on table public.v_player_market_value_history from anon, authenticated;
grant select on table public.v_player_transfer_history to anon, authenticated;
grant select on table public.v_player_market_value_history to anon, authenticated;

notify pgrst, 'reload schema';
