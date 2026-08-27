
-- Reconciliation against ground truth we did not produce. These are the checks that
-- actually answer "how do you know the data is right", so they run every rebuild rather
-- than being something someone once ran by hand.
insert into public.invariants (name, description, check_sql, severity) values

('goals_reconcile',
 'Goals parsed from the event feed must equal the published scoreline for every match. This is the strongest single check in the system: it validates event parsing, own-goal attribution and team-name reconciliation simultaneously, against a number we did not generate.',
 $q$with ev as (
      select g.game_id,
        count(*) filter (where g.scoring_team = x.home_ev) h,
        count(*) filter (where g.scoring_team = x.away_ev) a
      from public.mv_game_goals g
      join (select m.game_id,
              coalesce(th.event_name,m.home_team) home_ev,
              coalesce(ta.event_name,m.away_team) away_ev
            from public.matches m
            left join public.team_names th on th.match_name=m.home_team and th.league=m.league
            left join public.team_names ta on ta.match_name=m.away_team and ta.league=m.league) x
        on x.game_id=g.game_id
      group by g.game_id)
    select count(*) from public.matches m
    left join ev on ev.game_id=m.game_id
    where m.home_score is not null
      and exists (select 1 from public.events e where e.game_id=m.game_id)
      and (m.home_score <> coalesce(ev.h,0) or m.away_score <> coalesce(ev.a,0))$q$, 'error'),

('possession_sums',
 'Each match must have both sides'' possession shares summing to 100. A drift here means the touch attribution is wrong.',
 $q$select count(*) from (
    select game_id, sum(possession_pct) t from public.mv_team_match group by game_id) z
    where t not between 99.0 and 101.0$q$, 'error'),

('xg_calibration',
 'Across the season, total non-penalty xG should land within 10 percent of goals actually scored. Wider than that means the shot model has drifted away from reality.',
 $q$select case when abs(
      (select sum(xg) from public.mv_shot_xg where is_pen=false)
      - (select count(*) from public.mv_shot_xg where is_pen=false and is_goal)
    ) / nullif((select count(*) from public.mv_shot_xg where is_pen=false and is_goal),0)
    > 0.10 then 1 else 0 end$q$, 'error'),

('shots_in_xg_model',
 'Shots present in the event feed but missing from the shot model, usually because they carry no coordinates.',
 $q$select greatest(0,
     (select count(*) from public.events where is_shot)
   - (select count(*) from public.mv_shot_xg))$q$, 'warn')

on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity;

select name, severity, violations from public.run_invariants()
where name in ('goals_reconcile','possession_sums','xg_calibration','shots_in_xg_model');
