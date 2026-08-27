
create or replace function public.build_insights_extra()
returns text language plpgsql security definer set search_path = public
set statement_timeout = '180s' as $fn$
declare v_ct int;
begin
  delete from public.insights where detector in
    ('counter_attack','low_block','team_strength','team_weakness','player_elite','player_weakness');

  -- 1) counter-attacking identity.
  -- The rank-based version fired for the top four in every league, so in a competition
  -- where every side had zero counter-attacks it announced six teams as breaking at speed
  -- from deep on 0.00%. Now requires a non-zero rate AND a real denominator.
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with c as (
    select s.team, s.league,
      round(100.0*avg((s.start_x < 33.3 and s.ended_shot and s.dur_s <= 15)::int), 2) counter_pct,
      count(*) filter (where s.start_x < 33.3) deep_n,
      round(avg(s.dur_s),1) secs
    from public.sequences s where s.is_open_play group by s.team, s.league
  ),
  r as (
    select c.*, m.possession_pct, m.ppda, m.directness, ts.matches,
      rank() over (partition by c.league order by c.counter_pct desc) ck,
      count(*) over (partition by c.league) n
    from c
    join public.mv_team_all m on m.team = c.team
    join public.v_team_sample ts on ts.team = c.team
    where ts.meets_min_matches and c.counter_pct > 0 and c.deep_n >= 120
  )
  select 'tactical','identity','team', team, team, team, 'counter_attack',
    format('%s break at speed from deep', team),
    format('%s%% of their possessions start in their own third and reach a shot inside 15 seconds, ranked %s of %s, measured across %s deep starts in %s matches. They do it with only %s%% of the ball and a passive press (PPDA %s), which is the shape of a side that invites pressure and punishes the turnover.',
      counter_pct, ck, n, deep_n, matches, possession_pct, ppda),
    jsonb_build_object('counter_pct',counter_pct,'counter_rank',ck,'deep_starts',deep_n,
      'matches',matches,'possession_pct',possession_pct,'ppda',ppda),
    jsonb_build_object('team',team), (n-ck)+10, 'medium',
    'A counter-attacking profile is a choice, not a shortfall, but it does make a side dependent on the opponent committing bodies forward. Against a team that also sits deep, the same numbers tend to collapse.'
  from r where ck <= 4;

  -- 2) low block
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select m.team, m.ppda, m.def_height, m.possession_pct, ts.matches,
      rank() over (order by m.ppda desc) pk, count(*) over () n
    from public.mv_team_all m
    join public.v_team_sample ts on ts.team = m.team
    where ts.meets_min_matches
  )
  select 'tactical','defending','team', team, team, team, 'low_block',
    format('%s defend deep and let you have it', team),
    format('PPDA of %s (%s of %s, higher means less pressing) with a defensive line at %s and only %s%% of the ball, across %s matches. They concede territory deliberately rather than contesting it.',
      ppda, pk, n, def_height, possession_pct, matches),
    jsonb_build_object('ppda',ppda,'ppda_rank',pk,'def_height',def_height,
      'possession_pct',possession_pct,'matches',matches),
    jsonb_build_object('team',team), (n-pk)+5, 'medium',
    'Read this with the counter-attack number. A deep block that breaks well is a plan; a deep block that does not is a side under pressure.'
  from r where pk <= 5 and def_height < 45;

  -- 3) strength and weakness, gated on sample
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.team, p.metric, p.value, p.pct, d.label, p.league, ts.matches,
      row_number() over (partition by p.team order by p.pct desc) best,
      rank() over (partition by p.league, p.metric order by p.pct desc) lr,
      count(*) over (partition by p.league, p.metric) n
    from public.mv_team_percentiles p
    join public.team_metric_defs d on d.key = p.metric
    join public.v_team_sample ts on ts.team = p.team
    where p.pct is not null and ts.meets_min_matches
  )
  select 'tactical','identity','team', team, team, team, 'team_strength',
    format('%s: best in the squad at %s', team, lower(label)),
    format('%s, which puts them %s of %s in the league and in the %sth percentile across %s matches.',
      value, lr, n, pct, matches),
    jsonb_build_object('metric',metric,'label',label,'value',value,'pct',pct,'rank',lr,'matches',matches),
    jsonb_build_object('team',team), pct, 'medium',
    'A team''s strongest percentile is relative to the league, not an absolute strength. If the whole division is poor at something, leading it means less than it reads.'
  from r where best = 1;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with r as (
    select p.team, p.metric, p.value, p.pct, d.label, p.league, ts.matches,
      row_number() over (partition by p.team order by p.pct asc) worst,
      rank() over (partition by p.league, p.metric order by p.pct asc) lr,
      count(*) over (partition by p.league, p.metric) n
    from public.mv_team_percentiles p
    join public.team_metric_defs d on d.key = p.metric
    join public.v_team_sample ts on ts.team = p.team
    where p.pct is not null and ts.meets_min_matches
  )
  select 'tactical','identity','team', team, team, team, 'team_weakness',
    format('%s: weakest at %s', team, lower(label)),
    format('%s, which is %s of %s in the league and the %sth percentile across %s matches.',
      value, lr, n, pct, matches),
    jsonb_build_object('metric',metric,'label',label,'value',value,'pct',pct,'rank',lr,'matches',matches),
    jsonb_build_object('team',team), (100-pct), 'medium',
    'Before treating this as a problem, ask whether it is a by-product of how they choose to play. A counter-attacking side will always look poor for possession, and that is deliberate.'
  from r where worst = 1;

  -- 4/5) player detectors are unchanged here; build_insights_players rebuilds them
  select count(*) into v_ct from public.insights;
  return format('extra detectors rebuilt, %s insights', v_ct);
end $fn$;
revoke execute on function public.build_insights_extra() from public, anon, authenticated;
grant execute on function public.build_insights_extra() to service_role;
