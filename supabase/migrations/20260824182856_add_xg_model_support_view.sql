create or replace view v_xg_model_support as
select
  (select sum(n) from mv_xg_bins)::int                                as training_shots,
  (select count(*) from mv_xg_bins)::int                              as lookup_bins,
  (select count(distinct xg) from mv_shot_xg
     where not is_pen and xg is not null)::int                        as distinct_values,
  (select min(xg) from mv_shot_xg where not is_pen and xg is not null) as xg_min,
  (select max(xg) from mv_shot_xg where not is_pen and xg is not null) as xg_max,
  20::int                                                             as sparse_threshold,
  (select count(*) from mv_xg_bins where n < 20)::int                 as sparse_bins,
  (select round(100.0 * sum(n) filter (where n < 20) / nullif(sum(n), 0), 2)
     from mv_xg_bins)::numeric                                        as sparse_shot_share_pct,
  false                                                               as holdout_run,
  false                                                               as out_of_sample_tested;

grant select on v_xg_model_support to anon, authenticated, service_role;

select * from v_xg_model_support;
