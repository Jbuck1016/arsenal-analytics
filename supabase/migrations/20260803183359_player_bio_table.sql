
create table if not exists public.player_bio (
  player_id     text primary key,
  age_seen      integer,          -- max age observed (snapshot at match time)
  age_seen_date date,             -- date of the match that age came from
  height_cm     integer,
  weight_kg     integer,
  nationality   text,             -- reserved: needs WhoScored profile page
  foot          text,             -- reserved: derivable from shot foot-quals
  updated_at    timestamptz default now()
);
alter table public.player_bio enable row level security;
drop policy if exists public_read on public.player_bio;
create policy public_read on public.player_bio for select using (true);
grant select on public.player_bio to anon, authenticated;
