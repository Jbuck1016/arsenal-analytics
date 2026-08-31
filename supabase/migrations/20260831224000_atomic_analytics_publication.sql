begin;

create table if not exists public.analytics_rebuild_runs (
  run_id uuid primary key,
  status text not null check (status in ('pending','running','complete','failed')),
  requested_league text,
  current_step text,
  messages jsonb not null default '[]'::jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

alter table public.analytics_rebuild_runs enable row level security;
revoke all on public.analytics_rebuild_runs from public, anon, authenticated;
grant all on public.analytics_rebuild_runs to service_role;

create table if not exists public.analytics_publication_probe (
  singleton boolean primary key default true check (singleton),
  value bigint not null default 0
);
insert into public.analytics_publication_probe(singleton,value)
values (true,0) on conflict (singleton) do nothing;
alter table public.analytics_publication_probe enable row level security;
revoke all on public.analytics_publication_probe from public, anon, authenticated;
grant all on public.analytics_publication_probe to service_role;

create or replace function public.create_analytics_rebuild_run(
  p_run_id uuid,
  p_league text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  insert into public.analytics_rebuild_runs(run_id,status,requested_league)
  values (p_run_id,'pending',p_league);
  return jsonb_build_object('run_id',p_run_id,'status','pending');
end $fn$;

create or replace function public.analytics_rebuild_run_status(p_run_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select to_jsonb(r) from public.analytics_rebuild_runs r where r.run_id=p_run_id;
$fn$;

create or replace function public.rebuild_all_verified(
  p_run_id uuid,
  p_league text default null,
  p_fail_after_step text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set statement_timeout = '0'
as $fn$
declare
  steps constant text[] := array[
    'preflight','metrics1','metrics2','metrics3','metrics4',
    'sequences','players','seqfz','lookups','state','chains','traj',
    'profiles','usage','teamstyle','search','percentiles','insights','verify'
  ];
  step text;
  result text;
  output jsonb := '[]'::jsonb;
  failure text;
begin
  update public.analytics_rebuild_runs
  set status='running', started_at=now(), current_step='starting',
      error_message=null, messages='[]'::jsonb
  where run_id=p_run_id and status='pending';
  if not found then
    raise exception 'unknown or non-pending analytics rebuild run %', p_run_id;
  end if;

  begin
    if p_fail_after_step is not null then
      update public.analytics_publication_probe set value=value+1 where singleton;
    end if;

    foreach step in array steps loop
      update public.analytics_rebuild_runs set current_step=step where run_id=p_run_id;
      result := public.rebuild_step(step,p_league);
      output := output || jsonb_build_array(jsonb_build_object('step',step,'result',result));
      if p_fail_after_step = step then
        raise exception 'deliberate publication-gate test failure after %', step;
      end if;
    end loop;
  exception when others then
    failure := sqlerrm;
  end;

  if failure is not null then
    update public.analytics_rebuild_runs
    set status='failed', current_step=null, error_message=failure,
        messages=output, finished_at=now()
    where run_id=p_run_id;
    return jsonb_build_object('run_id',p_run_id,'status','failed','error',failure,'steps',output);
  end if;

  update public.analytics_rebuild_runs
  set status='complete', current_step=null, messages=output, finished_at=now()
  where run_id=p_run_id;
  return jsonb_build_object('run_id',p_run_id,'status','complete','steps',output);
end $fn$;

revoke all on function public.create_analytics_rebuild_run(uuid,text) from public,anon,authenticated;
revoke all on function public.analytics_rebuild_run_status(uuid) from public,anon,authenticated;
revoke all on function public.rebuild_all_verified(uuid,text,text) from public,anon,authenticated;
grant execute on function public.create_analytics_rebuild_run(uuid,text) to service_role;
grant execute on function public.analytics_rebuild_run_status(uuid) to service_role;
grant execute on function public.rebuild_all_verified(uuid,text,text) to service_role;

comment on function public.rebuild_all_verified(uuid,text,text) is
  'Refreshes every analytical layer and publishes summaries in one rollback-safe transaction. p_fail_after_step is a service-role-only verification hook.';

do $assert$
begin
  if has_function_privilege('anon','public.rebuild_all_verified(uuid,text,text)','execute')
     or has_function_privilege('authenticated','public.rebuild_all_verified(uuid,text,text)','execute') then
    raise exception 'public role can execute rebuild_all_verified';
  end if;
  if not has_function_privilege('service_role','public.rebuild_all_verified(uuid,text,text)','execute') then
    raise exception 'service_role cannot execute rebuild_all_verified';
  end if;
end $assert$;

commit;
