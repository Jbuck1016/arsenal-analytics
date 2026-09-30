-- A one-off historical backfill is not enough: events arriving after it would
-- inherit the old DEFAULT true, including penalties and set-piece shots.
create or replace function public.event_is_open_play(p_qualifiers jsonb)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select not exists (
    select 1
    from jsonb_array_elements(
      case when jsonb_typeof(p_qualifiers) = 'array' then p_qualifiers else '[]'::jsonb end
    ) as q(value)
    where coalesce(q.value->'type'->>'displayName', q.value->>'type') in (
      'ThrowIn', 'FreekickTaken', 'CornerTaken', 'GoalKick', 'KeeperThrow',
      'IndirectFreekickTaken', 'Penalty', 'FromCorner', 'SetPiece',
      'DirectFreekick', 'ThrowinSetPiece', 'DirectCorner'
    )
  );
$$;

revoke all on function public.event_is_open_play(jsonb) from public, anon, authenticated;
grant execute on function public.event_is_open_play(jsonb) to service_role;

create or replace function public.set_event_open_play()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.is_open_play := public.event_is_open_play(new.qualifiers);
  return new;
end;
$$;

revoke all on function public.set_event_open_play() from public, anon, authenticated;
grant execute on function public.set_event_open_play() to service_role;

drop trigger if exists events_classify_open_play on public.events;
create trigger events_classify_open_play
before insert or update of qualifiers, is_open_play on public.events
for each row execute function public.set_event_open_play();

-- Preserve the prior flag for every corrected row so this one-off change is
-- auditable and recoverable without restoring an entire database snapshot.
create table if not exists public.audit_event_open_play_before_20260930 (
  event_id bigint primary key,
  game_id text not null,
  ws_id bigint not null,
  prior_is_open_play boolean,
  captured_at timestamptz not null default now()
);
revoke all on public.audit_event_open_play_before_20260930 from public, anon, authenticated;
grant select on public.audit_event_open_play_before_20260930 to service_role;

insert into public.audit_event_open_play_before_20260930
  (event_id, game_id, ws_id, prior_is_open_play)
select e.id, e.game_id, e.ws_id, e.is_open_play
from public.events e
where e.is_open_play is distinct from public.event_is_open_play(e.qualifiers)
on conflict (event_id) do nothing;

update public.events e
set is_open_play = public.event_is_open_play(e.qualifiers)
where e.is_open_play is distinct from public.event_is_open_play(e.qualifiers);

do $$
begin
  if exists (
    select 1 from public.events e
    where e.is_shot and e.is_open_play and exists (
      select 1 from jsonb_array_elements(e.qualifiers) q
      where coalesce(q->'type'->>'displayName', q->>'type') in
        ('Penalty', 'FromCorner', 'SetPiece', 'DirectFreekick', 'ThrowinSetPiece', 'DirectCorner')
    )
  ) then
    raise exception 'set-piece shot still classified as open play';
  end if;
end;
$$;

-- Dependent materialized views must be refreshed by the governed analytics
-- rebuild after this migration; never claim the UI is corrected before then.
