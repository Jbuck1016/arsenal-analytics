\set ON_ERROR_STOP on

do $assert$
declare n int;
begin
  select count(*) into n
  from pg_class c join pg_namespace ns on ns.oid=c.relnamespace and ns.nspname='public'
  where c.relkind='v' and coalesce('security_invoker=true'=any(c.reloptions),false);
  if n <> 26 then raise exception 'Expected 26 security-invoker views, found %', n; end if;

  if obj_description('public.v_goal_fix'::regclass,'pg_class')
       is distinct from 'metadata preservation sentinel' then
    raise exception 'View comment was not preserved';
  end if;
  if not exists (select 1 from pg_class where oid='public.v_goal_fix'::regclass
                 and 'security_barrier=true'=any(reloptions)) then
    raise exception 'Existing security_barrier option was not preserved';
  end if;
  if not has_table_privilege('anon','public.v_goal_fix','SELECT')
     or not has_table_privilege('authenticated','public.v_goal_fix','SELECT') then
    raise exception 'View ACL was not preserved';
  end if;
end
$assert$;

set role anon;
select count(*) from pcr_z;
select count(*) from v_player_xt_actions;
select count(*) from v_xg_model_support;
reset role;

select 'SECURITY_INVOKER_ASSERTIONS_OK';
