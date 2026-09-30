-- Preserve the six exact legacy signature failures before granting them one
-- fresh retry budget under the repaired worker. No other queue row is touched.
create table if not exists public.audit_rescrape_before_20260930 as
select q.*
from public.rescrape_queue q
where false;

do $migration$
declare
  ids text[] := array['1952894','1952984','1952999','1995438','1995443','1995445'];
  eligible integer;
begin
  select count(*) into eligible
  from public.rescrape_queue q
  where q.game_id = any(ids)
    and q.status in ('queued','exhausted')
    and q.last_error = 'TypeError: process_match() got an unexpected keyword argument ''scraper''';
  if eligible <> cardinality(ids) then
    raise exception 'rescrape queue changed: expected 6 legacy failures, found %', eligible;
  end if;

  insert into public.audit_rescrape_before_20260930
  select q.* from public.rescrape_queue q where q.game_id = any(ids)
  and not exists (
    select 1 from public.audit_rescrape_before_20260930 saved
    where saved.game_id = q.game_id
  );

  update public.rescrape_queue
  set status = 'queued', attempts = 0, last_error = null, last_attempt_at = null
  where game_id = any(ids);
end;
$migration$;
