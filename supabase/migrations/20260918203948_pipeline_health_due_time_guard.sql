begin;

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
    select h.pipeline_name,h.last_success_at,h.next_run_at,e.max_silence_hours
    from public.pipeline_health h
    join public.pipeline_health_expectations e using (pipeline_name)
    where e.enabled and h.status <> 'disabled' and (
      (h.last_success_at is null and h.next_run_at is not null
       and h.next_run_at < now() - interval '15 minutes')
      or
      (h.last_success_at is not null
       and h.last_success_at < now() - make_interval(hours => e.max_silence_hours::int))
    )
  loop
    if public.raise_alert('error','pipeline_stale',r.pipeline_name,
         jsonb_build_object(
           'last_success_at',r.last_success_at,
           'next_run_at',r.next_run_at,
           'max_silence_hours',r.max_silence_hours))
    then n := n + 1; end if;
  end loop;
  return n;
end
$fn$;

commit;
