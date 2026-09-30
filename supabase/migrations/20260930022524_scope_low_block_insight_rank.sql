-- The low-block detector used a global PPDA rank but is displayed under a
-- league filter. Make both the rank and denominator league-specific.
do $migration$
declare
  existing_definition text;
  old_rank text := 'rank() over (order by m.ppda desc) pk, count(*) over () n';
  new_rank text := 'rank() over (partition by ts.league order by m.ppda desc) pk, count(*) over (partition by ts.league) n';
  old_label text := 'PPDA of %s (%s of %s, higher means less pressing)';
  new_label text := 'PPDA of %s (ranked %s of %s eligible clubs in their league; higher means less pressing)';
begin
  select pg_get_functiondef(p.oid) into existing_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'build_insights_extra'
    and p.pronargs = 0;
  if existing_definition is null
    or position(old_rank in existing_definition) = 0
    or position(old_label in existing_definition) = 0 then
    raise exception 'build_insights_extra changed; inspect before scoping ranks';
  end if;
  existing_definition := replace(existing_definition, old_rank, new_rank);
  existing_definition := replace(existing_definition, old_label, new_label);
  execute existing_definition;
end;
$migration$;
