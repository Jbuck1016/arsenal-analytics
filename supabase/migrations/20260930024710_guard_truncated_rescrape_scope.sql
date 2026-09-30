-- Incomplete event feeds must not remain eligible for published analytics.
create table if not exists public.audit_truncated_match_scope_before_20260930 as
select * from public.matches where game_id = '1952894';

update public.matches
   set is_live_scope = false
 where game_id = '1952894'
   and is_live_scope = true
   and (select coalesce(max(expanded_minute), 0)
          from public.events where game_id = '1952894') < 80;

create or replace function public.record_rescrape_result_canonical(
  p_game_id text,
  p_canonical_game_id text,
  p_ok boolean,
  p_error text
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_att integer;
  v_events integer;
  v_last_minute integer;
begin
  select count(*), coalesce(max(expanded_minute), 0)
    into v_events, v_last_minute
    from public.events
   where game_id = p_canonical_game_id;

  if p_ok and v_events > 0 and v_last_minute >= 80 then
    update public.rescrape_queue
       set status = 'done', last_error = null
     where game_id = p_game_id
     returning attempts into v_att;
    if v_att is null then
      raise exception 'rescrape queue row % is missing', p_game_id;
    end if;
    update public.matches set is_live_scope = true
     where game_id = p_canonical_game_id;
    return 'done';
  end if;

  update public.rescrape_queue
     set last_error = coalesce(p_error, 'scrape returned no complete canonical events'),
         status = case when attempts >= 3 then 'exhausted' else 'queued' end
   where game_id = p_game_id
   returning attempts into v_att;
  if v_att is null then
    raise exception 'rescrape queue row % is missing', p_game_id;
  end if;
  if p_canonical_game_id = p_game_id and v_last_minute < 80 then
    update public.matches set is_live_scope = false
     where game_id = p_canonical_game_id;
  end if;
  if v_att >= 3 then
    perform public.raise_alert(
      'error', 'rescrape_exhausted', p_game_id,
      jsonb_build_object('attempts', v_att,
                         'error', coalesce(p_error, 'no complete canonical events returned'))
    );
    return 'exhausted';
  end if;
  return 'requeued';
end
$function$;
