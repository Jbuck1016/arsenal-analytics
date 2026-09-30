-- Queue IDs may be WhoScored source IDs while events belong to an fd-* fixture.
-- Keep the legacy three-argument RPC for in-flight workers; new workers pass
-- the canonical ID explicitly and can only mark success when it has events.
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
begin
  select count(*) into v_events
  from public.events
  where game_id = p_canonical_game_id;

  if p_ok and v_events > 0 then
    update public.rescrape_queue
       set status = 'done', last_error = null
     where game_id = p_game_id
     returning attempts into v_att;
    if v_att is null then
      raise exception 'rescrape queue row % is missing', p_game_id;
    end if;
    return 'done';
  end if;

  update public.rescrape_queue
     set last_error = coalesce(p_error, 'scrape returned no canonical events'),
         status = case when attempts >= 3 then 'exhausted' else 'queued' end
   where game_id = p_game_id
   returning attempts into v_att;
  if v_att is null then
    raise exception 'rescrape queue row % is missing', p_game_id;
  end if;
  if v_att >= 3 then
    perform public.raise_alert(
      'error', 'rescrape_exhausted', p_game_id,
      jsonb_build_object('attempts', v_att,
                         'error', coalesce(p_error, 'no canonical events returned'))
    );
    return 'exhausted';
  end if;
  return 'requeued';
end
$function$;

revoke all on function public.record_rescrape_result_canonical(text,text,boolean,text)
  from public, anon, authenticated;
grant execute on function public.record_rescrape_result_canonical(text,text,boolean,text)
  to service_role;
