insert into invariants (name, description, check_sql, severity, enabled)
values (
  'xg_bins_sparse',
  'Shot-model lookup bins holding fewer than 20 shots. Rates in these bins are noise rather than signal, so any xG assigned from them is weakly supported. Reported as a count, not a pass or fail, because no defensible sparse-bin ceiling has been established. Currently 18 of 44 bins, covering under 1 percent of shots.',
  'select count(*) from mv_xg_bins where n < 20',
  'warn',
  true
)
on conflict (name) do update
  set description = excluded.description,
      check_sql  = excluded.check_sql,
      severity   = excluded.severity,
      enabled    = excluded.enabled;

select name, severity, enabled from invariants where name = 'xg_bins_sparse';
