
-- Batch 3. The complaint that motivated this: a club could open its insights page and see
-- almost nothing, because every detector so far only fired on extremes. These add
-- player-level reads and guarantee every side gets a strength and a weakness, so the page
-- is useful for an average team rather than only for outliers.
create or replace function public.build_insights_extra()
returns text language plpgsql security definer set search_path = public
set statement_timeout = '180s' as $fn$
declare v_ct int;
begin
  delete from public.insights where detector in
    ('counter_attack','low_block','team_strength','team_weakness','player_elite','player_weakness');

  -- 1) counter-attacking identity: break fast from deep, without the ball, pressing passively
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with c as (
    select s.team, s.league,
      round(100.0*avg((s.start_x < 33.3 and s.ended_shot and s.dur_s <= 15)::int), 2) counter_pct,
      round(avg(s.dur_s),1) secs
    from public.sequences s where s.is_open_play group by s.team, s.league
  ),
  r as (
    select c.*, m.possession_pct, m.ppda, m.directness, m.field_tilt,
      rank() over (partition by c.league order by c.counter_pct desc) ck,
      count(*) over (partition by c.league) n
    from c join public.mv_team_all m on m.team = c.team
  )
  select 'tactical','identity','team', team, team, team, 'counter_attack',
    format('%s break at speed from deep', team),
    format('%s%% of their possessions start in their own third and reach a shot inside 15 seconds, ranked %s of %s. They do it with only %s%% of the ball and a passive press (PPDA %s), which is the shape of a side that invites pressure and punishes the turnover.',
      counter_pct, ck, n, possession_pct, ppda),
    jsonb_build_object('counter_pct',counter_pct,'counter_rank',ck,'possession_pct',possession_pct,
      'ppda',ppda,'directness',directness,'secs_per_seq',secs),
    jsonb_build_object('team',team), (n-ck)+10, 'medium',
    'A counter-attacking profile is a choice, not a shortfall, but it does make a side dependent on the opponent committing bodies forward. Against a team that also sits deep, the same numbers tend to collapse. Worth checking their record against the sides below them in the table.'
  from r where ck <= 4 and possession_pct < 50 and ppda > 11;

  -- 2) low block
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select m.team, m.ppda, m.def_height, m.possession_pct, m.field_tilt,
      rank() over (order by m.ppda desc) pk, count(*) over () n
    from public.mv_team_all m
  )
  select 'tactical','defending','team', team, team, team, 'low_block',
    format('%s defend deep and let you have it', team),
    format('PPDA of %s (%s of %s, higher means less pressing) with a defensive line at %s and only %s%% of the ball. They concede territory deliberately rather than contesting it.',
      ppda, pk, n, def_height, possession_pct),
    jsonb_build_object('ppda',ppda,'ppda_rank',pk,'def_height',def_height,'possession_pct',possession_pct),
    jsonb_build_object('team',team), (n-pk)+5, 'medium',
    'Read this with the counter-attack number. A deep block that breaks well is a plan; a deep block that does not is a side under pressure.'
  from r where pk <= 5 and def_height < 45;

  -- 3) every club gets a strength and a weakness, so no page is ever empty
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.team, p.metric, p.value, p.pct, d.label, d.higher_is_better, p.league,
      row_number() over (partition by p.team order by p.pct desc) best,
      rank() over (partition by p.league, p.metric order by p.pct desc) lr,
      count(*) over (partition by p.league, p.metric) n
    from public.mv_team_percentiles p
    join public.team_metric_defs d on d.key = p.metric
    where p.pct is not null
  )
  select 'tactical','identity','team', team, team, team, 'team_strength',
    format('%s: best in the squad at %s', team, lower(label)),
    format('%s, which puts them %s of %s in the league and in the %sth percentile. It is the single thing they do best relative to everyone else.',
      value, lr, n, pct),
    jsonb_build_object('metric',metric,'label',label,'value',value,'pct',pct,'rank',lr),
    jsonb_build_object('team',team), pct, 'medium',
    'A team''s strongest percentile is not necessarily a strength in absolute terms, only relative to the league. If the whole division is poor at something, being best at it means less than it reads.'
  from r where best = 1;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.team, p.metric, p.value, p.pct, d.label, p.league,
      row_number() over (partition by p.team order by p.pct asc) worst,
      rank() over (partition by p.league, p.metric order by p.pct asc) lr,
      count(*) over (partition by p.league, p.metric) n
    from public.mv_team_percentiles p
    join public.team_metric_defs d on d.key = p.metric
    where p.pct is not null
  )
  select 'tactical','identity','team', team, team, team, 'team_weakness',
    format('%s: weakest at %s', team, lower(label)),
    format('%s, which is %s of %s in the league and the %sth percentile. Their clearest soft spot relative to the division.',
      value, lr, n, pct),
    jsonb_build_object('metric',metric,'label',label,'value',value,'pct',pct,'rank',lr),
    jsonb_build_object('team',team), (100-pct), 'medium',
    'Before treating this as a problem, ask whether it is a by-product of how they choose to play. A counter-attacking side will always look poor for possession, and that is deliberate.'
  from r where worst = 1;

  -- 4) players who lead the league for something
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.player_id, p.player, p.pool, p.metric, p.raw, p.pct_pool, d.label, d.unit, d.grp,
      ps.team, ps.nineties,
      rank() over (partition by p.pool, p.metric order by p.pct_pool desc, ps.nineties desc) rk,
      count(*) over (partition by p.pool, p.metric) n
    from public.mv_player_pct p
    join public.player_search ps on ps.player_id = p.player_id
    join public.metric_catalog d on d.metric = p.metric
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

  -- 5) a regular with a clear hole in his game
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.player_id, p.player, p.pool, p.metric, p.raw, p.pct_pool, d.label, d.unit,
      ps.team, ps.nineties,
      row_number() over (partition by p.player_id order by p.pct_pool asc) w,
      max(p.pct_pool) over (partition by p.player_id) best_pct
    from public.mv_player_pct p
    join public.player_search ps on ps.player_id = p.player_id
    join public.metric_catalog d on d.metric = p.metric
    where ps.nineties >= 10
  )
  select 'sd','player_rank','player', player_id, player, team, 'player_weakness',
    format('%s struggles with %s', player, lower(label)),
    format('%s%s puts him in the %sth percentile of %ss, his clearest weakness. He reaches the %sth percentile at his best, so this is a gap in an otherwise capable profile.',
      raw, case when unit is null then '' else ' '||unit end, pct_pool, pool, best_pct),
    jsonb_build_object('metric',metric,'label',label,'value',raw,'pct',pct_pool,'pool',pool,'best_pct',best_pct),
    jsonb_build_object('player_id',player_id), (best_pct - pct_pool), 'medium',
    'A low percentile is not automatically a flaw. It may simply be something his role never asks of him, and the honest test is whether the team loses anything because of it. Check whether teammates cover the same ground.'
  from r where w = 1 and pct_pool <= 8 and best_pct >= 70;

  select count(*) into v_ct from public.insights;
  return format('total insights now %s', v_ct);
end $fn$;
revoke execute on function public.build_insights_extra() from public, anon, authenticated;
grant execute on function public.build_insights_extra() to service_role;
