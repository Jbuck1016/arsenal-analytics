create table if not exists public.lafc_events (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('fixture','meeting')),
  title        text not null,
  starts_at    timestamptz not null,
  ends_at      timestamptz,
  all_day      boolean not null default false,
  location     text default '',
  link         text default '',
  competition  text default '',
  home         boolean,
  source_id    text,
  synced_at    timestamptz not null default now()
);

create index if not exists lafc_events_starts_idx on public.lafc_events (starts_at);

alter table public.lafc_events enable row level security;
revoke all on public.lafc_events from anon, authenticated;

create or replace function public.lafc_events_list(p_secret text)
returns setof public.lafc_events
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;
  return query select * from public.lafc_events order by starts_at asc;
end;
$$;

grant execute on function public.lafc_events_list(text) to anon, authenticated;
