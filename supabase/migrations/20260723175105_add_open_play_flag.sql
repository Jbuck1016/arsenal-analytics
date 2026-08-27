alter table public.events add column if not exists is_open_play boolean not null default true;

update public.events e
set is_open_play = false
where exists (
  select 1 from jsonb_array_elements(e.qualifiers) q
  where q->'type'->>'displayName' in (
    'ThrowIn','FreekickTaken','CornerTaken','GoalKick',
    'KeeperThrow','IndirectFreekickTaken','Penalty'
  )
);

create index if not exists idx_events_open_play on public.events (is_open_play);
