begin;

-- One bounded row per local pipeline. This deliberately avoids an append-only
-- task log in Postgres; detailed transcripts remain on the Windows host.
create table if not exists public.pipeline_health (
  pipeline_name text primary key,
  status text not null check (status in ('never_run','running','success','failed','disabled')),
  last_started_at timestamptz,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  next_run_at timestamptz,
  host text,
  detail jsonb not null default '{}'::jsonb,
  last_error text,
  updated_at timestamptz not null default now()
);

create table if not exists public.pipeline_health_expectations (
  pipeline_name text primary key references public.pipeline_health(pipeline_name) on delete cascade,
  max_silence_hours numeric not null check (max_silence_hours > 0),
  enabled boolean not null default true
);

alter table public.pipeline_health enable row level security;
alter table public.pipeline_health_expectations enable row level security;
revoke all on public.pipeline_health from public, anon, authenticated;
revoke all on public.pipeline_health_expectations from public, anon, authenticated;
grant all on public.pipeline_health to service_role;
grant all on public.pipeline_health_expectations to service_role;

create or replace function public.record_pipeline_health(
  p_pipeline_name text,
  p_status text,
  p_observed_at timestamptz default now(),
  p_next_run_at timestamptz default null,
  p_host text default null,
  p_detail jsonb default '{}'::jsonb,
  p_error text default null
) returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $fn$
begin
  if p_status not in ('never_run','running','success','failed','disabled') then
    raise exception 'unsupported pipeline status %', p_status;
  end if;
  insert into public.pipeline_health(
    pipeline_name,status,last_started_at,last_success_at,last_failure_at,
    next_run_at,host,detail,last_error,updated_at
  ) values (
    p_pipeline_name,p_status,
    case when p_status='running' then p_observed_at end,
    case when p_status='success' then p_observed_at end,
    case when p_status='failed' then p_observed_at end,
    p_next_run_at,p_host,coalesce(p_detail,'{}'::jsonb),
    case when p_status='failed' then left(p_error,1000) end,p_observed_at
  )
  on conflict (pipeline_name) do update set
    status=excluded.status,
    last_started_at=case when excluded.status='running' then excluded.updated_at
                         else pipeline_health.last_started_at end,
    last_success_at=case when excluded.status='success' then excluded.updated_at
                         else pipeline_health.last_success_at end,
    last_failure_at=case when excluded.status='failed' then excluded.updated_at
                         else pipeline_health.last_failure_at end,
    next_run_at=excluded.next_run_at,
    host=coalesce(excluded.host,pipeline_health.host),
    detail=excluded.detail,
    last_error=case when excluded.status='failed' then excluded.last_error
                    when excluded.status='success' then null
                    else pipeline_health.last_error end,
    updated_at=excluded.updated_at;
end
$fn$;

revoke all on function public.record_pipeline_health(text,text,timestamptz,timestamptz,text,jsonb,text)
  from public, anon, authenticated;
grant execute on function public.record_pipeline_health(text,text,timestamptz,timestamptz,text,jsonb,text)
  to service_role;

insert into public.pipeline_health(pipeline_name,status) values
  ('nightly_ingestion','never_run'),
  ('match_result_watcher','never_run'),
  ('market_odds_early','never_run'),
  ('market_odds_late','never_run'),
  ('market_odds_thursday','never_run'),
  ('prediction_ledger','never_run'),
  ('shadow_forecast','never_run'),
  ('shadow_scorecard','never_run'),
  ('quick_ingest','never_run'),
  ('pipeline_health_publisher','never_run')
on conflict (pipeline_name) do nothing;

insert into public.pipeline_health_expectations(pipeline_name,max_silence_hours,enabled) values
  ('nightly_ingestion',36,false),
  ('match_result_watcher',30,false),
  ('market_odds_early',30,false),
  ('market_odds_late',30,false),
  ('market_odds_thursday',192,false),
  ('prediction_ledger',30,false),
  ('shadow_forecast',192,false),
  ('shadow_scorecard',192,false),
  ('quick_ingest',1,false),
  ('pipeline_health_publisher',1,false)
on conflict (pipeline_name) do update set
  max_silence_hours=excluded.max_silence_hours,
  enabled=false;

create or replace function public.check_pipeline_health_alerts()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare r record; n integer := 0;
begin
  for r in
    select h.* from public.pipeline_health h
    join public.pipeline_health_expectations e using (pipeline_name)
    where e.enabled and h.status='failed'
      and (h.last_success_at is null or h.last_failure_at >= h.last_success_at)
  loop
    if public.raise_alert('error','pipeline_failed',r.pipeline_name,
         jsonb_build_object('last_failure_at',r.last_failure_at,'error',r.last_error,'detail',r.detail))
    then n := n + 1; end if;
  end loop;

  for r in
    select h.pipeline_name,h.last_success_at,e.max_silence_hours
    from public.pipeline_health h
    join public.pipeline_health_expectations e using (pipeline_name)
    where e.enabled and (
      h.last_success_at is null or
      h.last_success_at < now() - make_interval(hours => e.max_silence_hours::int)
    )
  loop
    if public.raise_alert('error','pipeline_stale',r.pipeline_name,
         jsonb_build_object('last_success_at',r.last_success_at,'max_silence_hours',r.max_silence_hours))
    then n := n + 1; end if;
  end loop;
  return n;
end
$fn$;

revoke all on function public.check_pipeline_health_alerts() from public, anon, authenticated;

select cron.schedule(
  'pipeline-health-alerts',
  '*/5 * * * *',
  $$select public.check_pipeline_health_alerts();$$
);

commit;
