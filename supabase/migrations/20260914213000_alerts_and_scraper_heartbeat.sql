-- Make the gate audible, and give the scraper a pulse.
--
-- The 31 August run blocked at the gate, correctly, and then nothing told
-- anybody. The site served 1 September data for thirteen days while presenting
-- it as current. Every guard in the system worked; none of them could speak.
--
-- pg_net turned out to be installable from SQL (0.20.4, into the extensions
-- schema), so delivery is a real webhook POST from the database and no edge
-- function is needed. The brief expected only http 1.6 to be available.

create extension if not exists pg_net with schema extensions;

create table if not exists public.rebuild_alerts (
  id          bigint generated always as identity primary key,
  raised_at   timestamptz not null default now(),
  severity    text not null check (severity in ('error','warn')),
  kind        text not null,
  subject     text not null,
  detail      jsonb not null default '{}'::jsonb,
  notified_at timestamptz,
  notify_error text
);
create index if not exists idx_rebuild_alerts_pending
  on public.rebuild_alerts (raised_at) where notified_at is null;
-- One open alert per kind and subject, so a condition that persists for days
-- raises once rather than once per cron tick. Re-raising means clearing
-- notified_at.
create unique index if not exists uq_rebuild_alerts_open
  on public.rebuild_alerts (kind, subject) where notified_at is null;

create or replace view public.pending_alerts as
  select id, raised_at, severity, kind, subject, detail
  from public.rebuild_alerts
  where notified_at is null
  order by raised_at;

-- Delivery target lives in the database, not the repo, and is readable only by
-- the roles that dispatch. Set it with:
--   insert into public.alert_settings values ('webhook_url','https://...')
--   on conflict (key) do update set value = excluded.value;
create table if not exists public.alert_settings (
  key   text primary key,
  value text not null
);
revoke all on public.alert_settings from anon, authenticated;

-- Section 12. The only signal that can detect the laptop never waking up.
-- Every event-derived freshness check is blind to that case, because no new
-- events looks identical to no matches played.
create table if not exists public.scraper_runs (
  id                bigint generated always as identity primary key,
  started_at        timestamptz not null default now(),
  finished_at       timestamptz,
  host              text,
  leagues           text[],
  matches_attempted integer,
  matches_written   integer,
  events_written    integer,
  status            text not null check (status in ('running','success','partial','failed')),
  error             text
);
create index if not exists idx_scraper_runs_recent on public.scraper_runs (started_at desc);
grant select on public.scraper_runs to anon, authenticated;

-- Stamped server side so a client that dies mid-write cannot leave a settled row
-- without an end time.
create or replace function public.stamp_scraper_run_finished()
returns trigger language plpgsql as $fn$
begin
  if new.status <> 'running' and old.status = 'running' and new.finished_at is null then
    new.finished_at := now();
  end if;
  return new;
end $fn$;

drop trigger if exists trg_scraper_run_finished on public.scraper_runs;
create trigger trg_scraper_run_finished
  before update on public.scraper_runs
  for each row execute function public.stamp_scraper_run_finished();

create or replace function public.raise_alert(
  p_severity text, p_kind text, p_subject text, p_detail jsonb default '{}'::jsonb)
returns boolean
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
begin
  insert into public.rebuild_alerts (severity, kind, subject, detail)
  values (p_severity, p_kind, p_subject, p_detail)
  on conflict (kind, subject) where notified_at is null do nothing;
  return found;
end $fn$;

create or replace function public.check_and_raise_alerts()
returns integer
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare n integer := 0; r record; v_hours numeric;
begin
  for r in
    select run_id, error_message, finished_at
    from public.analytics_rebuild_runs
    where status in ('failed','abandoned')
      and finished_at > now() - interval '24 hours'
  loop
    if public.raise_alert(
         'error',
         case when r.error_message like 'rebuild verification FAILED%'
              then 'gate_blocked' else 'rebuild_failed' end,
         r.run_id::text,
         jsonb_build_object('error', r.error_message, 'finished_at', r.finished_at))
    then n := n + 1; end if;
  end loop;

  select extract(epoch from now() - max(finished_at))/3600 into v_hours
  from public.analytics_rebuild_runs where status='complete';
  if v_hours is null or v_hours > 48 then
    if public.raise_alert('error','rebuild_stale','analytics',
         jsonb_build_object('hours_since_complete', round(coalesce(v_hours,-1),1))) then
      n := n + 1; end if;
  end if;

  -- Warn travels its own path here, independent of the gate, so a warning
  -- reaches a human without blocking a publish.
  for r in select name, severity, violations from public.mv_invariant_status
            where violations <> 0 and severity in ('error','warn')
  loop
    if public.raise_alert(r.severity, 'invariant_'||r.severity, r.name,
         jsonb_build_object('violations', r.violations)) then n := n + 1; end if;
  end loop;

  if not exists (select 1 from public.scraper_runs
                  where status='success' and started_at > now() - interval '36 hours') then
    if public.raise_alert('error','scraper_silent','windows-scraper',
         jsonb_build_object('last_success',
           (select max(started_at) from public.scraper_runs where status='success'))) then
      n := n + 1; end if;
  end if;

  return n;
end $fn$;

create or replace function public.dispatch_pending_alerts()
returns integer
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_url text; r record; v_req bigint; n integer := 0;
begin
  select value into v_url from public.alert_settings where key='webhook_url';
  if v_url is null or v_url = '' then
    return -1;  -- nothing configured; alerts accumulate in pending_alerts
  end if;

  for r in select * from public.pending_alerts loop
    begin
      select net.http_post(
        url     := v_url,
        body    := jsonb_build_object(
                     'severity', r.severity, 'kind', r.kind, 'subject', r.subject,
                     'detail', r.detail, 'raised_at', r.raised_at,
                     'source', 'futscout-analytics'),
        headers := '{"Content-Type":"application/json"}'::jsonb,
        timeout_milliseconds := 8000
      ) into v_req;

      update public.rebuild_alerts
         set notified_at = now(),
             detail = detail || jsonb_build_object('net_request_id', v_req),
             notify_error = null
       where id = r.id;
      n := n + 1;
    exception when others then
      update public.rebuild_alerts set notify_error = left(sqlerrm,200) where id = r.id;
    end;
  end loop;
  return n;
end $fn$;

-- cron: alerts every 5 minutes, reaper every 2. Scheduled separately from the
-- rebuild worker so an alert can fire while a rebuild is stuck.
select cron.schedule('analytics-alerts', '*/5 * * * *',
  $$select public.check_and_raise_alerts(); select public.dispatch_pending_alerts();$$);
