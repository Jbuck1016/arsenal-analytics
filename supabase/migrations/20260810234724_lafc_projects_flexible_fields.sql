-- New flexible fields
alter table public.lafc_projects
  add column if not exists due_date date,
  add column if not exists category text not null default '',
  add column if not exists subtasks jsonb not null default '[]'::jsonb;

-- Replace save function with the extended signature
drop function if exists public.lafc_projects_save(text, uuid, text, text, text, text, text, int);

create or replace function public.lafc_projects_save(
  p_secret text,
  p_id uuid,
  p_name text,
  p_status text,
  p_priority text,
  p_next_action text,
  p_notes text,
  p_sort_order int,
  p_due_date date,
  p_category text,
  p_subtasks jsonb
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
    insert into public.lafc_projects
      (name, status, priority, next_action, notes, sort_order, due_date, category, subtasks)
    values
      (trim(p_name), coalesce(p_status,'In progress'), coalesce(p_priority,'Medium'),
       coalesce(p_next_action,''), coalesce(p_notes,''), coalesce(p_sort_order,0),
       p_due_date, coalesce(p_category,''), coalesce(p_subtasks,'[]'::jsonb))
    returning * into r;
  else
    update public.lafc_projects
       set name = trim(p_name),
           status = coalesce(p_status, status),
           priority = coalesce(p_priority, priority),
           next_action = coalesce(p_next_action, next_action),
           notes = coalesce(p_notes, notes),
           sort_order = coalesce(p_sort_order, sort_order),
           due_date = p_due_date,
           category = coalesce(p_category, category),
           subtasks = coalesce(p_subtasks, subtasks)
     where id = p_id
    returning * into r;
    if not found then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;

  return r;
end;
$$;

grant execute on function public.lafc_projects_save(text, uuid, text, text, text, text, text, int, date, text, jsonb)
  to anon, authenticated;
