begin;

-- Current-season invariant definitions. Raw archive rows remain queryable, but
-- production checks must use the same season boundary as the analytical mart.
update public.invariants
set description = 'Current-season played matches that have no event data.',
    check_sql = $sql$
      select count(*)
      from public.v_league_matches m
      where m.home_score is not null
        and not exists (
          select 1 from public.v_league_events e where e.game_id = m.game_id
        )
    $sql$
where name = 'played_without_events';

update public.invariants
set description = 'Current-season non-own-goal shots missing from the xG model. Own goals are intentionally excluded from model training and scoring.',
    check_sql = $sql$
      select count(*)
      from public.v_league_events e
      where e.is_shot
        and not coalesce(e.qualifiers @> '[{"type":{"displayName":"OwnGoal"}}]'::jsonb, false)
        and not exists (
          select 1
          from public.mv_shot_xg x
          where x.game_id = e.game_id and x.ws_id = e.ws_id
        )
    $sql$
where name = 'shots_in_xg_model';

-- An active competition that has not ingested its first match is a valid
-- availability state, not a failed whitelist. Once data exists, the guard is
-- required to close before the league can pass verification.
update public.invariants
set description = 'Active leagues with current-season match data but no team whitelist.',
    check_sql = $sql$
      select count(*)
      from public.leagues l
      where l.is_active
        and exists (
          select 1 from public.v_league_matches m where m.league = l.league
        )
        and not exists (
          select 1 from public.team_names t where t.league = l.league
        )
    $sql$
where name = 'leagues_without_whitelist';

-- A real temporal holdout. The final 20 percent of current-season matches is
-- never used to estimate the rates scored below. Sparse cells fall back to a
-- shot-shape estimate, itself shrunk toward the training base rate.
create or replace view public.v_xg_temporal_holdout as
with ordered_matches as (
  select m.game_id, m.date,
         row_number() over (order by m.date, m.game_id) as match_no,
         count(*) over () as match_count
  from public.v_league_matches m
  where exists (select 1 from public.mv_shot_features f where f.game_id = m.game_id)
), shots as (
  select f.*,
         om.date,
         om.match_no <= greatest(1, floor(om.match_count * 0.8)) as is_training,
         case when f.dist_m < 6 then 1 when f.dist_m < 11 then 2
              when f.dist_m < 16 then 3 when f.dist_m < 22 then 4
              when f.dist_m < 30 then 5 else 6 end as d_bin,
         case when f.angle_deg < 12 then 1 when f.angle_deg < 25 then 2 else 3 end as a_bin
  from public.mv_shot_features f
  join ordered_matches om on om.game_id = f.game_id
  where not f.is_pen
), training_base as (
  select avg(is_goal::int)::numeric as rate from shots where is_training
), shape_rates as (
  select s.is_header, s.is_bigchance, count(*) as n, sum(s.is_goal::int) as goals,
         (sum(s.is_goal::int) + 50 * b.rate) / (count(*) + 50) as rate
  from shots s cross join training_base b
  where s.is_training
  group by s.is_header, s.is_bigchance, b.rate
), cell_rates as (
  select s.d_bin, s.a_bin, s.is_header, s.is_bigchance,
         count(*) as n, sum(s.is_goal::int) as goals,
         (sum(s.is_goal::int) + 20 * sr.rate) / (count(*) + 20) as rate
  from shots s
  join shape_rates sr using (is_header, is_bigchance)
  where s.is_training
  group by s.d_bin, s.a_bin, s.is_header, s.is_bigchance, sr.rate
), scored as (
  select s.*,
         least(0.999, greatest(0.001,
           coalesce(cr.rate, sr.rate, b.rate)
         ))::numeric as predicted_xg
  from shots s
  cross join training_base b
  left join shape_rates sr using (is_header, is_bigchance)
  left join cell_rates cr using (d_bin, a_bin, is_header, is_bigchance)
  where not s.is_training
)
select
  (select count(*) from shots where is_training)::integer as training_shots,
  count(*)::integer as validation_shots,
  min(date) as validation_from,
  max(date) as validation_through,
  round(avg(power(predicted_xg - is_goal::int, 2)), 5) as brier_score,
  round(avg(-(is_goal::int * ln(predicted_xg) + (1-is_goal::int) * ln(1-predicted_xg))), 5) as log_loss,
  round(sum(predicted_xg), 2) as predicted_goals,
  sum(is_goal::int)::integer as actual_goals,
  round(100 * (sum(predicted_xg) - sum(is_goal::int)) / nullif(sum(is_goal::int), 0), 1) as goal_error_pct,
  round(max(predicted_xg), 4) as maximum_prediction,
  true as temporal_holdout,
  true as out_of_sample_tested
from scored;

alter view public.v_xg_temporal_holdout set (security_invoker = true);
revoke all on public.v_xg_temporal_holdout from public, anon, authenticated;
grant select on public.v_xg_temporal_holdout to anon, authenticated;
grant all on public.v_xg_temporal_holdout to service_role;

-- Match-only event feed with the fitted per-shot value. Non-shot rows and
-- intentionally excluded own goals retain NULL xG.
create or replace view public.v_match_events as
select e.*, x.xg, x.dist_m as shot_dist_m, x.angle_deg as shot_angle_deg
from public.v_league_events e
left join public.mv_shot_xg x on x.game_id = e.game_id and x.ws_id = e.ws_id;

alter view public.v_match_events set (security_invoker = true);
revoke all on public.v_match_events from public, anon, authenticated;
grant select on public.v_match_events to anon, authenticated;
grant all on public.v_match_events to service_role;

-- xT provenance and internal directional sanity are deliberately separate
-- from validation. These fields must never be presented as external proof.
create or replace view public.v_xt_model_status as
select
  (select count(*) from public.xt_grid)::integer as grid_cells,
  (select min(v) from public.xt_grid) as grid_min,
  (select max(v) from public.xt_grid) as grid_max,
  true as borrowed_grid,
  false as fitted_on_platform_competitions,
  false as externally_validated,
  round(avg(s.xt_sum) filter (where s.ended_shot), 4) as shot_ending_mean_xt,
  round(avg(s.xt_sum) filter (where not s.ended_shot), 4) as other_mean_xt,
  round(
    avg(s.xt_sum) filter (where s.ended_shot)
    / nullif(avg(s.xt_sum) filter (where not s.ended_shot), 0), 2
  ) as internal_directional_ratio
from public.v_league_sequences s;

alter view public.v_xt_model_status set (security_invoker = true);
revoke all on public.v_xt_model_status from public, anon, authenticated;
grant select on public.v_xt_model_status to anon, authenticated;
grant all on public.v_xt_model_status to service_role;

-- Pin every application function currently reported by the Supabase advisor.
-- Extension-owned trigram/unaccent functions are intentionally not altered.
alter function public.xt_at(double precision,double precision) set search_path = public, pg_temp;
alter function public.xt_val(double precision,double precision) set search_path = public, pg_temp;
alter function public.build_sequences() set search_path = public, pg_temp;
alter function public.build_player_chain_roles() set search_path = public, pg_temp;
alter function public.similar_sequences(text,integer) set search_path = public, pg_temp;
alter function public.similar_teams(text,integer) set search_path = public, pg_temp;
alter function public.top_sequences_by_type(text,integer) set search_path = public, pg_temp;
alter function public.similar_players_chain(text,integer) set search_path = public, pg_temp;
alter function public.state_weight(numeric) set search_path = public, pg_temp;
alter function public.pretty_metric(text) set search_path = public, pg_temp;
alter function public.lafc_projects_touch() set search_path = public, pg_temp;

do $assert$
declare v bigint;
begin
  execute (select check_sql from public.invariants where name='shots_in_xg_model') into v;
  if v <> 0 then raise exception 'shots_in_xg_model expected 0 unexplained omissions, got %', v; end if;
  execute (select check_sql from public.invariants where name='played_without_events') into v;
  if v <> 0 then raise exception 'played_without_events expected 0 current-season gaps, got %', v; end if;
  execute (select check_sql from public.invariants where name='leagues_without_whitelist') into v;
  if v <> 0 then raise exception 'leagues_without_whitelist expected 0 data-bearing gaps, got %', v; end if;
  if (select count(*) from public.v_xg_temporal_holdout) <> 1 then
    raise exception 'xG temporal holdout did not return exactly one row';
  end if;
  if (select validation_shots from public.v_xg_temporal_holdout) = 0 then
    raise exception 'xG temporal holdout is empty';
  end if;
  if (select count(*) from public.v_xt_model_status) <> 1 then
    raise exception 'xT model status did not return exactly one row';
  end if;
end $assert$;

commit;
