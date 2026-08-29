begin;

grant select on public.v_match_season_scope to anon, authenticated;

comment on view public.v_match_season_scope is
  'Current-season match catalogue used by caller-rights public analytics. Contains only already-public match and registry fields.';

do $assert$
begin
  if not has_table_privilege('anon','public.v_match_season_scope','SELECT')
     or not has_table_privilege('authenticated','public.v_match_season_scope','SELECT') then
    raise exception 'SEASON SCOPE GRANT ASSERT: browser roles cannot resolve caller-rights analytics.';
  end if;
end
$assert$;

commit;
