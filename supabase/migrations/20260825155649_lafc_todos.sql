create table if not exists public.lafc_todos (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  done boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
alter table public.lafc_todos enable row level security;
revoke all on public.lafc_todos from anon, authenticated;

create or replace function public.lafc_todos_list(p_secret text)
returns setof public.lafc_todos language plpgsql security definer set search_path=public,extensions as $$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  return query select * from public.lafc_todos order by done asc, sort_order asc, created_at asc;
end;$$;

create or replace function public.lafc_todos_save(p_secret text,p_id uuid,p_text text,p_done boolean,p_sort int)
returns public.lafc_todos language plpgsql security definer set search_path=public,extensions as $$
declare r public.lafc_todos;
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  if p_text is null or length(trim(p_text))=0 then raise exception 'text required' using errcode='22000'; end if;
  if p_id is null then
    insert into public.lafc_todos(text,done,sort_order,completed_at)
      values(trim(p_text),coalesce(p_done,false),coalesce(p_sort,0), case when coalesce(p_done,false) then now() else null end)
      returning * into r;
  else
    update public.lafc_todos
      set text=trim(p_text), done=coalesce(p_done,done), sort_order=coalesce(p_sort,sort_order),
          completed_at = case when coalesce(p_done,done) then coalesce(completed_at,now()) else null end
      where id=p_id returning * into r;
    if not found then raise exception 'not found' using errcode='P0002'; end if;
  end if;
  return r;
end;$$;

create or replace function public.lafc_todos_delete(p_secret text,p_id uuid)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  delete from public.lafc_todos where id=p_id;
end;$$;

create or replace function public.lafc_todos_clear_done(p_secret text)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  delete from public.lafc_todos where done;
end;$$;

grant execute on function public.lafc_todos_list(text) to anon,authenticated;
grant execute on function public.lafc_todos_save(text,uuid,text,boolean,int) to anon,authenticated;
grant execute on function public.lafc_todos_delete(text,uuid) to anon,authenticated;
grant execute on function public.lafc_todos_clear_done(text) to anon,authenticated;
