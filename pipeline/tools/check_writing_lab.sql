select
  to_regclass('public.writing_lab_projects') is not null as table_exists,
  (select relrowsecurity from pg_class where oid = 'public.writing_lab_projects'::regclass) as rls_enabled,
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'writing_lab_projects') as policy_count,
  has_table_privilege('anon', 'public.writing_lab_projects', 'select') as anon_select,
  has_table_privilege('anon', 'public.writing_lab_projects', 'insert') as anon_insert,
  has_table_privilege('anon', 'public.writing_lab_projects', 'update') as anon_update,
  has_table_privilege('anon', 'public.writing_lab_projects', 'delete') as anon_delete;
