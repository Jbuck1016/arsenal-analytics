begin;

-- Evaluate request headers once per statement rather than once per candidate
-- row. This keeps the browser-owned workspace policies efficient as the
-- private editorial archive grows.
drop policy if exists "writing lab browser reads own workspaces" on public.writing_lab_projects;
create policy "writing lab browser reads own workspaces"
on public.writing_lab_projects for select
to anon, authenticated
using (
  length(coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
);

drop policy if exists "writing lab browser creates own workspaces" on public.writing_lab_projects;
create policy "writing lab browser creates own workspaces"
on public.writing_lab_projects for insert
to anon, authenticated
with check (
  length(coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
  and whoscored_url ~* '^https://(www\.)?whoscored\.com/matches/[0-9]+'
);

drop policy if exists "writing lab browser updates own workspaces" on public.writing_lab_projects;
create policy "writing lab browser updates own workspaces"
on public.writing_lab_projects for update
to anon, authenticated
using (
  length(coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
)
with check (
  length(coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), '')) >= 32
  and owner_key_hash = encode(
    extensions.digest(
      coalesce((coalesce(nullif((select current_setting('request.headers', true)), ''), '{}')::jsonb ->> 'x-writing-key'), ''),
      'sha256'
    ),
    'hex'
  )
);

commit;
