
drop function if exists public.build_insights_misfit_patch();

create or replace function public.build_insights()
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare v_ct int;
begin
  truncate table public.insights;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with pctr as (
    select p.player_id, p.player, p.pool, p.role, p.raw, p.pct,
      row_number() over (partition by p.pool, p.role order by p.raw desc) rrk,
      p.raw - lead(p.raw) over (partition by p.pool, p.role order by p.raw desc) gap2
    from public.player_chain_pct p
  ),
  firsts as (select * from pctr where rrk=1 and pct>=99),
  tops as (select distinct on (player_id) * from firsts order by player_id, gap2 desc nulls last)
  select 'sd','role_profile','player', t.player_id, t.player, pcr.team, 'standout_profile',
    format('%s tops the %s pool for %s', t.player, t.pool, lbl.friendly),
    format('The league''s most %s profile among %ss, across %s involvements, clear of the next by %s. A shortlist anchor.',
      lbl.friendly, t.pool, pcr.inv, round(t.gap2::numeric,1)),
    jsonb_build_object('pool',t.pool,'role',lbl.friendly,'percentile',t.pct,'inv',pcr.inv,'gap_to_2nd',round(t.gap2::numeric,1)),
    jsonb_build_object('player_id',t.player_id), round(coalesce(t.gap2,0)::numeric,2),
    case when pcr.inv>=300 then 'high' else 'medium' end
  from tops t
  join public.player_chain_roles pcr on pcr.player_id=t.player_id
  join lateral (values
    ('progressor','ball-progression'),('initiator','build-up initiation'),('creator','chance-creation'),
    ('box_threat','box threat'),('carrier','ball-carrying'),('vertical','vertical passing'),
    ('support_angle','diagonal support'),('bridge','third-man bridging'),('finisher','finishing'),
    ('individual','1v1 dribbling'),('controller','tempo control')) lbl(key,friendly) on lbl.key=t.role
  where pcr.inv>=150;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with pr as (
    select team, player_id, player, r.label role, (inv * r.pctval/100.0) rinv
    from public.player_chain_roles
    cross join lateral (values ('ball progression', progressor),('chance creation', creator),
      ('build-up initiation', initiator),('third-man bridging', bridge)) r(label,pctval)
  ),
  tot as (select team, role, sum(rinv) team_rinv from pr group by team, role),
  sh as (select pr.team, pr.player_id, pr.player, pr.role, pr.rinv/nullif(t.team_rinv,0) share,
      row_number() over (partition by pr.team, pr.role order by pr.rinv desc) rk
    from pr join tot t using (team, role)),
  rolep as (select role, percentile_cont(0.9) within group (order by share) p90 from sh where rk=1 group by role),
  top2 as (select team, role, max(share) filter (where rk=1) s1, max(player) filter (where rk=1) p1,
      max(player_id) filter (where rk=1) pid1, max(share) filter (where rk=2) s2
    from sh where rk<=2 group by team, role)
  select 'sd','key_man_risk','team', t.team, t.team, t.team, 'key_man',
    format('%s carries %s''s %s', t.p1, t.team, t.role),
    format('%s handles %s%% of %s''s %s work with a %s-point drop to the next man. No close deputy.',
      t.p1, round(100*t.s1), t.team, t.role, round(100*(t.s1-t.s2))),
    jsonb_build_object('role',t.role,'share_pct',round(100*t.s1,1),'gap_to_2nd_pct',round(100*(t.s1-t.s2),1),'player',t.p1),
    jsonb_build_object('player_id',t.pid1,'team',t.team), round(100*(t.s1-t.s2),1), 'medium'
  from top2 t join rolep rp using(role)
  where t.s1 >= rp.p90 and (t.s1 - t.s2) >= 0.07;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with targets(pool, role, friendly, why) as (values
    ('CB','progressor','ball-playing centre-back','building out from the back'),
    ('FB','carrier','attacking full-back','carrying the ball forward from wide'),
    ('CM','creator','creative midfielder','manufacturing chances from midfield'),
    ('CM','progressor','progressive midfielder','moving the ball forward through the middle'),
    ('AM','creator','creative number ten','unlocking a low block'),
    ('W','individual','one-v-one winger','beating a full-back in isolation'),
    ('ST','box_threat','penalty-box striker','occupying the six-yard area')
  ),
  best as (
    select pcr.team, t.pool, t.role, t.friendly, t.why,
      max(p.pct) as best_pct, (array_agg(p.player order by p.pct desc))[1] as best_player, count(*) as options
    from targets t
    join public.player_chain_pct p on p.pool = t.pool and p.role = t.role
    join public.player_chain_roles pcr on pcr.player_id = p.player_id
    group by pcr.team, t.pool, t.role, t.friendly, t.why
  )
  select 'sd','squad_gap','team', b.team, b.team, b.team, 'squad_gap',
    format('%s have no high-end %s', b.team, b.friendly),
    format('Their best option ranks in the %sth percentile of the %s pool (%s). A clear recruitment lane for %s.',
      b.best_pct, b.pool, b.best_player, b.why),
    jsonb_build_object('pool',b.pool,'role',b.role,'best_pct',b.best_pct,'best_player',b.best_player,'options',b.options),
    jsonb_build_object('team',b.team), (50 - b.best_pct), 'medium'
  from best b where b.best_pct <= 35;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'sd','usage','player', r.player_id, r.player, r.team, 'minutes_inflated',
    format('%s''s minutes come in decided games', r.player),
    format('Plays %s%% of available minutes for %s, but only %s%% of his time on the pitch is with the game within one goal, bottom quartile in the league. Per-90 numbers should be read with that in mind.',
      r.selection_pct, r.team, r.leverage_pct),
    jsonb_build_object('selection_pct',r.selection_pct,'leverage_pct',r.leverage_pct,'squad_role',r.squad_role),
    jsonb_build_object('player_id',r.player_id,'team',r.team), (100 - r.leverage_pct), 'medium'
  from public.v_squad_role r where r.minutes_inflated;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with freq as (
    select pool, primary_label, count(*) n,
      round(100.0*count(*)/sum(count(*)) over (partition by pool), 1) pct_of_pool
    from public.mv_player_archetype group by pool, primary_label
  )
  select 'sd','role_profile','player', a.player_id, a.player, pcr.team, 'misfit_profile',
    format('%s is an unusual %s', a.player, a.pool),
    format('Listed as a %s but behaves like a %s, a profile only %s%% of the %s pool shares. Either a tactical quirk worth exploiting or a player in the wrong role.',
      a.pool, a.primary_label, f.pct_of_pool, a.pool),
    jsonb_build_object('pool',a.pool,'archetype',a.archetype,'primary',a.primary_label,
      'primary_pct',a.primary_pct,'share_of_pool',f.pct_of_pool),
    jsonb_build_object('player_id',a.player_id), (100 - f.pct_of_pool), 'medium'
  from public.mv_player_archetype a
  join freq f on f.pool = a.pool and f.primary_label = a.primary_label
  join public.player_chain_roles pcr on pcr.player_id = a.player_id
  where f.pct_of_pool <= 5 and a.primary_pct >= 85 and pcr.inv >= 250;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with extremes as (
    select team, metric, z, abs(z) az, row_number() over (partition by team order by abs(z) desc) rk
    from public.team_sequence_style where z is not null
  ),
  top as (select * from extremes where rk = 1),
  sig as (select * from public.v_team_signature)
  select 'tactical','identity','team', t.team, t.team, t.team, 'team_profile',
    case when t.az >= 1.5 then format('%s are defined by their %s', t.team, replace(t.metric,'_',' '))
         when t.az >= 0.8 then format('%s lean towards %s', t.team, replace(t.metric,'_',' '))
         else format('%s have no pronounced identity', t.team) end,
    case when t.az >= 0.8 then
      format('Their most distinctive trait is %s (%s standard deviations from the league mean). They break teams down mostly %s, which is %s by league standards.',
        replace(t.metric,'_',' '), round(t.z,1), lower(s.signature_route), s.signature_verdict)
    else
      format('Nothing in their possession profile sits far from the league average, the most distinctive trait being %s at %s standard deviations. They lean %s, %s by league standards. A side without a strong stylistic fingerprint.',
        replace(t.metric,'_',' '), round(t.z,1), lower(s.signature_route), s.signature_verdict) end,
    jsonb_build_object('top_metric',t.metric,'z',round(t.z,2),
      'signature_route',s.signature_route,'route_share',s.share_pct,'route_verdict',s.signature_verdict),
    jsonb_build_object('team',t.team), t.az, 'medium'
  from top t left join sig s on s.team = t.team;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'tactical','defending','team', p.team, p.team, p.team, 'press_vulnerability',
    case when p.z_vs_direct <= -1.0 then format('%s struggle against direct play', p.team)
         else format('%s struggle against short build-up', p.team) end,
    case when p.z_vs_direct <= -1.0 then
      format('They contain long, direct possessions %s standard deviations worse than the league, while handling short build-up at %s. Opponents who go over them find joy.',
        round(abs(p.z_vs_direct),1), round(p.z_vs_short_build,1))
    else
      format('They contain patient build-up %s standard deviations worse than the league, while coping with direct play at %s. Sides that play through them find joy.',
        round(abs(p.z_vs_short_build),1), round(p.z_vs_direct,1)) end,
    jsonb_build_object('z_vs_direct',p.z_vs_direct,'z_vs_short_build',p.z_vs_short_build,
      'raw_vs_direct',p.raw_vs_direct,'raw_vs_short_build',p.raw_vs_short_build),
    jsonb_build_object('team',p.team), greatest(abs(p.z_vs_direct), abs(p.z_vs_short_build)), 'medium'
  from public.v_press_profile p
  where p.z_vs_direct <= -1.0 or p.z_vs_short_build <= -1.0;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'tactical','identity','team', d.team, d.team, d.team, 'game_state_reactivity',
    case when d.swing_l_minus_w >= 0.03 then format('%s change shape with the scoreline', d.team)
         else format('%s play the same way whatever the score', d.team) end,
    case when d.swing_l_minus_w >= 0.03 then
      format('Their possessions run %s directness when losing against %s when winning, one of the sharper swings in the league. A reactive side rather than a settled one.',
        d.dir_losing, d.dir_winning)
    else
      format('Directness barely moves between winning (%s) and losing (%s). A settled identity that does not chase the game.',
        d.dir_winning, d.dir_losing) end,
    jsonb_build_object('dir_winning',d.dir_winning,'dir_drawing',d.dir_drawing,
      'dir_losing',d.dir_losing,'swing',d.swing_l_minus_w),
    jsonb_build_object('team',d.team), abs(d.swing_l_minus_w)*100, 'medium'
  from public.mv_team_directness_state d
  where abs(d.swing_l_minus_w) >= 0.03 or d.swing_rank <= 3;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by passes_seq desc) pass_rk,
      rank() over (order by xt_seq desc) xt_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','identity','team', team, team, team, 'sterile_control',
    format('%s dominate the ball without threat', team),
    format('%s passes per sequence (%s of %s) but only %s xT per possession (%s of %s). Control without penetration.',
      passes_seq, pass_rk, nteams, xt_seq, xt_rk, nteams),
    jsonb_build_object('passes_seq',passes_seq,'passes_rank',pass_rk,'xt_seq',xt_seq,'xt_rank',xt_rk),
    jsonb_build_object('team',team), (xt_rk - pass_rk), 'medium'
  from r where pass_rk <= 8 and xt_rk >= (nteams-9);

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by finds_central_pct desc) c_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','style','team', team, team, team, 'central_funnel',
    format('%s funnel everything through the middle', team),
    format('%s%% of progression runs central (%s of %s), the heaviest reliance on interior play in the league.',
      finds_central_pct, c_rk, nteams),
    jsonb_build_object('finds_central_pct',finds_central_pct,'central_rank',c_rk),
    jsonb_build_object('team',team), (nteams-c_rk), 'medium'
  from r where c_rk<=4;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by finds_wide_pct desc) w_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','style','team', team, team, team, 'byline_team',
    format('%s attack down the outside', team),
    format('%s%% of progression goes wide (%s of %s). Built to reach the byline rather than play through the lines.',
      finds_wide_pct, w_rk, nteams),
    jsonb_build_object('finds_wide_pct',finds_wide_pct,'wide_rank',w_rk),
    jsonb_build_object('team',team), (nteams-w_rk), 'medium'
  from r where w_rk<=4;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by ends_opp_half_pct desc) opp_rk,
      rank() over (order by end_att_third_pct desc) att_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','identity','team', team, team, team, 'territorial',
    format('%s pin opponents in', team),
    format('%s%% of sequences end in the opposition half and %s%% in the final third (%s and %s of %s). A front-foot territorial identity.',
      ends_opp_half_pct, end_att_third_pct, opp_rk, att_rk, nteams),
    jsonb_build_object('ends_opp_half_pct',ends_opp_half_pct,'end_att_third_pct',end_att_third_pct),
    jsonb_build_object('team',team), (nteams-opp_rk)+(nteams-att_rk), 'medium'
  from r where opp_rk<=6 and att_rk<=6;

  select count(*) into v_ct from public.insights;
  return format('built %s insights at %s', v_ct, now()::timestamptz(0));
end $fn$;
revoke execute on function public.build_insights() from public, anon, authenticated;
grant execute on function public.build_insights() to service_role;
