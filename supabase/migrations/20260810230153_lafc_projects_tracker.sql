-- pgcrypto for passphrase hashing (installs into `extensions` schema on Supabase)
create extension if not exists pgcrypto with schema extensions;

-- Main tracker table
create table if not exists public.lafc_projects (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  status       text not null default 'In progress',
  priority     text not null default 'Medium',
  next_action  text default '',
  notes        text default '',
  sort_order   int  not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Passphrase config (single row). Stores only a bcrypt hash, never plaintext.
create table if not exists public.lafc_tracker_config (
  id          int primary key default 1,
  secret_hash text not null,
  constraint one_row check (id = 1)
);

-- Lock both tables: RLS on, NO policies => anon & authenticated get nothing directly.
-- The Supabase dashboard (service_role) still bypasses RLS, so backend editing works.
alter table public.lafc_projects enable row level security;
alter table public.lafc_tracker_config enable row level security;

-- Revoke direct table access from the browser roles for good measure
revoke all on public.lafc_projects from anon, authenticated;
revoke all on public.lafc_tracker_config from anon, authenticated;

-- Auto-stamp updated_at on any update (including edits made in the dashboard)
create or replace function public.lafc_projects_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_lafc_projects_touch on public.lafc_projects;
create trigger trg_lafc_projects_touch
  before update on public.lafc_projects
  for each row execute function public.lafc_projects_touch();

-- Passphrase check
create or replace function public.lafc_tracker_auth(p_secret text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.lafc_tracker_config
    where id = 1 and secret_hash = extensions.crypt(p_secret, secret_hash)
  );
$$;

-- LIST
create or replace function public.lafc_projects_list(p_secret text)
returns setof public.lafc_projects
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;
  return query
    select * from public.lafc_projects
    order by sort_order asc, updated_at desc;
end;
$$;

-- SAVE (insert when p_id is null, else update)
create or replace function public.lafc_projects_save(
  p_secret text,
  p_id uuid,
  p_name text,
  p_status text,
  p_priority text,
  p_next_action text,
  p_notes text,
  p_sort_order int
)
returns public.lafc_projects
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  r public.lafc_projects;
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'name required' using errcode = '22000';
  end if;

  if p_id is null then
    insert into public.lafc_projects (name, status, priority, next_action, notes, sort_order)
    values (trim(p_name), coalesce(p_status,'In progress'), coalesce(p_priority,'Medium'),
            coalesce(p_next_action,''), coalesce(p_notes,''), coalesce(p_sort_order,0))
    returning * into r;
  else
    update public.lafc_projects
       set name = trim(p_name),
           status = coalesce(p_status, status),
           priority = coalesce(p_priority, priority),
           next_action = coalesce(p_next_action, next_action),
           notes = coalesce(p_notes, notes),
           sort_order = coalesce(p_sort_order, sort_order)
     where id = p_id
    returning * into r;
    if not found then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;

  return r;
end;
$$;

-- DELETE
create or replace function public.lafc_projects_delete(p_secret text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.lafc_tracker_auth(p_secret) then
    raise exception 'unauthorized' using errcode = '28000';
  end if;
  delete from public.lafc_projects where id = p_id;
end;
$$;

-- Expose ONLY the functions to the browser role
grant execute on function public.lafc_tracker_auth(text)      to anon, authenticated;
grant execute on function public.lafc_projects_list(text)     to anon, authenticated;
grant execute on function public.lafc_projects_save(text, uuid, text, text, text, text, text, int) to anon, authenticated;
grant execute on function public.lafc_projects_delete(text, uuid) to anon, authenticated;
