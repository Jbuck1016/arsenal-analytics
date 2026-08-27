create table if not exists public.lafc_links (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  url text default '',
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.lafc_links enable row level security;
revoke all on public.lafc_links from anon, authenticated;

drop trigger if exists trg_lafc_links_touch on public.lafc_links;
create trigger trg_lafc_links_touch before update on public.lafc_links
  for each row execute function public.lafc_projects_touch();

create or replace function public.lafc_links_list(p_secret text)
returns setof public.lafc_links language plpgsql security definer set search_path=public,extensions as $$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  return query select * from public.lafc_links order by sort_order asc, created_at asc;
end;$$;

create or replace function public.lafc_links_save(p_secret text,p_id uuid,p_label text,p_url text,p_sort int)
returns public.lafc_links language plpgsql security definer set search_path=public,extensions as $$
declare r public.lafc_links;
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  if p_label is null or length(trim(p_label))=0 then raise exception 'label required' using errcode='22000'; end if;
  if p_id is null then
    insert into public.lafc_links(label,url,sort_order) values(trim(p_label),coalesce(p_url,''),coalesce(p_sort,0)) returning * into r;
  else
    update public.lafc_links set label=trim(p_label),url=coalesce(p_url,''),sort_order=coalesce(p_sort,sort_order) where id=p_id returning * into r;
    if not found then raise exception 'not found' using errcode='P0002'; end if;
  end if;
  return r;
end;$$;

create or replace function public.lafc_links_delete(p_secret text,p_id uuid)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  if not public.lafc_tracker_auth(p_secret) then raise exception 'unauthorized' using errcode='28000'; end if;
  delete from public.lafc_links where id=p_id;
end;$$;

grant execute on function public.lafc_links_list(text) to anon,authenticated;
grant execute on function public.lafc_links_save(text,uuid,text,text,int) to anon,authenticated;
grant execute on function public.lafc_links_delete(text,uuid) to anon,authenticated;
