
-- Two problems with batch 3 as first written.
-- (a) A centre-back was flagged for "struggles with goals". A low percentile is only a
--     weakness if the role actually asks for it, so weaknesses are now restricted to
--     metric groups relevant to the position.
-- (b) Weakness scores ran to 90+ while a league-leading counter-attack scored 39, so the
--     least interesting reads sorted to the top. Detectors now carry a priority band.
create table if not exists public.pool_metric_relevance (
  pool text, grp text, primary key (pool, grp)
);
insert into public.pool_metric_relevance (pool, grp) values
 ('CB','Passing'),('CB','Progression'),('CB','Defending'),('CB','Chain value'),
 ('FB','Passing'),('FB','Progression'),('FB','Carrying'),('FB','Creation'),('FB','Defending'),
 ('CM','Passing'),('CM','Progression'),('CM','Creation'),('CM','Carrying'),('CM','Defending'),
 ('CM','Chain value'),('CM','Threat'),
 ('AM','Creation'),('AM','Progression'),('AM','Carrying'),('AM','Shooting'),('AM','Threat'),
 ('W','Carrying'),('W','Creation'),('W','Shooting'),('W','Threat'),('W','Progression'),
 ('ST','Shooting'),('ST','Creation'),('ST','Carrying'),('ST','Threat')
on conflict do nothing;
grant select on public.pool_metric_relevance to anon, authenticated;

create table if not exists public.detector_priority (
  detector text primary key, band int not null, note text
);
insert into public.detector_priority (detector, band, note) values
 ('key_man', 9, 'squad fragility, highest planning value'),
 ('counter_attack', 9, 'a whole tactical identity in one read'),
 ('sterile_control', 9, 'diagnosis plus implied recruitment need'),
 ('squad_gap', 8, 'direct recruitment lane'),
 ('low_block', 8, null),
 ('press_vulnerability', 8, 'opposition planning'),
 ('standout_profile', 7, 'shortlist anchor'),
 ('territorial', 7, null),
 ('central_funnel', 7, null),
 ('byline_team', 7, null),
 ('game_state_reactivity', 6, null),
 ('team_profile', 6, 'always fires, so should not lead'),
 ('misfit_profile', 6, null),
 ('minutes_inflated', 5, 'a caveat rather than a finding'),
 ('team_strength', 4, 'always fires'),
 ('team_weakness', 4, 'always fires'),
 ('player_elite', 3, 'plentiful, so ranks below team reads'),
 ('player_weakness', 2, 'least actionable on its own')
on conflict (detector) do update set band=excluded.band, note=excluded.note;
grant select on public.detector_priority to anon, authenticated;

-- rebuild the two player detectors with relevance applied
create or replace function public.build_insights_players()
returns text language plpgsql security definer set search_path = public
set statement_timeout = '180s' as $fn$
declare v_ct int;
begin
  delete from public.insights where detector in ('player_elite','player_weakness');

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.player_id, p.player, p.pool, p.metric, p.raw, p.pct_pool, d.label, d.unit, d.grp,
      ps.team, ps.nineties,
      rank() over (partition by p.pool, p.metric order by p.pct_pool desc, ps.nineties desc) rk,
      count(*) over (partition by p.pool, p.metric) n
    from public.mv_player_pct p
    join public.player_search ps on ps.player_id = p.player_id
    join public.metric_catalog d on d.metric = p.metric
    join public.pool_metric_relevance rel on rel.pool = p.pool and rel.grp = d.grp
    where ps.nineties >= 8
  ),
  best as (select distinct on (player_id) * from r where rk <= 5 order by player_id, rk, n desc)
  select 'sd','player_rank','player', player_id, player, team, 'player_elite',
    format('%s is %s in the league for %s among %ss', player,
      case rk when 1 then 'first' when 2 then 'second' when 3 then 'third'
              when 4 then 'fourth' else 'fifth' end, lower(label), pool),
    format('%s%s across %s full matches, ranked %s of %s %ss. A defining part of what he offers.',
      raw, case when unit is null then '' else ' '||unit end, round(nineties,1), rk, n, pool),
    jsonb_build_object('metric',metric,'label',label,'value',raw,'pct',pct_pool,'rank',rk,'pool',pool,'group',grp),
    jsonb_build_object('player_id',player_id), (100 - rk*3), 'medium',
    'A league-leading rate is worth checking against volume and game state. A player at a dominant side accumulates more of most things, and output banked in decided games is worth less than the same output in tight ones.'
  from best;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.player_id, p.player, p.pool, p.metric, p.raw, p.pct_pool, d.label, d.unit,
      ps.team, ps.nineties,
      row_number() over (partition by p.player_id order by p.pct_pool asc) w,
      max(p.pct_pool) over (partition by p.player_id) best_pct
    from public.mv_player_pct p
    join public.player_search ps on ps.player_id = p.player_id
    join public.metric_catalog d on d.metric = p.metric
    join public.pool_metric_relevance rel on rel.pool = p.pool and rel.grp = d.grp
    where ps.nineties >= 10
  )
  select 'sd','player_rank','player', player_id, player, team, 'player_weakness',
    format('%s struggles with %s', player, lower(label)),
    format('%s%s puts him in the %sth percentile of %ss, his clearest weakness in an area the role asks for. He reaches the %sth percentile at his best.',
      raw, case when unit is null then '' else ' '||unit end, pct_pool, pool, best_pct),
    jsonb_build_object('metric',metric,'label',label,'value',raw,'pct',pct_pool,'pool',pool,'best_pct',best_pct),
    jsonb_build_object('player_id',player_id), (best_pct - pct_pool), 'medium',
    'A low percentile is not automatically a flaw. It may be something his side never asks of him, and the honest test is whether the team loses anything because of it. Check whether teammates cover the same ground.'
  from r where w = 1 and pct_pool <= 8 and best_pct >= 70;

  -- rebalance every score into its detector's band so ordering reflects usefulness,
  -- keeping the within-detector ordering intact
  update public.insights i set score =
    coalesce(dp.band, 5) * 1000
    + least(999, greatest(0, round(coalesce(i.score, 0))))
  from public.detector_priority dp where dp.detector = i.detector;

  update public.insights set score = 5000 + least(999, greatest(0, round(coalesce(score,0))))
  where detector not in (select detector from public.detector_priority);

  select count(*) into v_ct from public.insights;
  return format('%s insights, re-ranked by detector priority', v_ct);
end $fn$;
revoke execute on function public.build_insights_players() from public, anon, authenticated;
grant execute on function public.build_insights_players() to service_role;
