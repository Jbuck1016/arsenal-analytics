
drop function if exists public.rebuild_step(text);

create or replace function public.rebuild_all()
returns text language plpgsql security definer set search_path = public set statement_timeout = 0
as $fn$
begin
  perform public.rebuild_step('preflight', null);
  perform public.rebuild_step('metrics', null);
  perform public.rebuild_step('sequences', null);
  perform public.rebuild_step('players', null);
  perform public.rebuild_step('seqfz', null);
  perform public.rebuild_step('lookups', null);
  perform public.rebuild_step('state', null);
  perform public.rebuild_step('chains', null);
  perform public.rebuild_step('traj', null);
  perform public.rebuild_step('profiles', null);
  perform public.rebuild_step('usage', null);
  perform public.rebuild_step('teamstyle', null);
  perform public.rebuild_step('search', null);
  perform public.rebuild_step('percentiles', null);
  perform public.rebuild_step('insights', null);
  return public.rebuild_step('verify', null);
end $fn$;
revoke execute on function public.rebuild_all() from public, anon, authenticated;
grant execute on function public.rebuild_all() to service_role;
