
create or replace function public.build_insights()
returns text language plpgsql security definer set search_path = public set statement_timeout = '120s'
as $fn$
declare v_ct int;
begin
  truncate table public.insights;

  -- 1) standout profile (percentile-based)
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
    format('The league''s most %s profile among %ss (top of the pool across %s involvements), clear of the next by %s. A recruitment-shortlist anchor.',
      lbl.friendly, t.pool, pcr.inv, round(t.gap2::numeric,1)),
    jsonb_build_object('pool',t.pool,'role',lbl.friendly,'percentile',t.pct,'inv',pcr.inv,'player_xt',pcr.player_xt,'gap_to_2nd',round(t.gap2::numeric,1)),
    jsonb_build_object('player_id',t.player_id),
    round(coalesce(t.gap2,0)::numeric,2),
    case when pcr.inv>=300 then 'high' else 'medium' end
  from tops t
  join public.player_chain_roles pcr on pcr.player_id=t.player_id
  join lateral (values
    ('progressor','ball-progression'),('initiator','build-up initiation'),('creator','chance-creation'),
    ('box_threat','box threat'),('carrier','ball-carrying'),('vertical','vertical passing'),
    ('support_angle','diagonal support'),('bridge','third-man bridging'),('finisher','finishing'),
    ('individual','1v1 dribbling'),('controller','tempo control')) lbl(key,friendly) on lbl.key=t.role
  where pcr.inv>=150;

  -- 2) key-man risk (relative concentration + no deputy)
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with pr as (
    select team, player_id, player, r.label role, (inv * r.pctval/100.0) rinv
    from public.player_chain_roles
    cross join lateral (values
      ('ball progression', progressor),('chance creation', creator),
      ('build-up initiation', initiator),('third-man bridging', bridge)) r(label,pctval)
  ),
  tot as (select team, role, sum(rinv) team_rinv from pr group by team, role),
  sh as (
    select pr.team, pr.player_id, pr.player, pr.role,
      pr.rinv/nullif(t.team_rinv,0) share,
      row_number() over (partition by pr.team, pr.role order by pr.rinv desc) rk
    from pr join tot t using (team, role)
  ),
  rolep as (select role, percentile_cont(0.9) within group (order by share) p90 from sh where rk=1 group by role),
  top2 as (
    select team, role,
      max(share) filter (where rk=1) s1, max(player) filter (where rk=1) p1,
      max(player_id) filter (where rk=1) pid1, max(share) filter (where rk=2) s2
    from sh where rk<=2 group by team, role
  )
  select 'sd','key_man_risk','team', t.team, t.team, t.team, 'key_man',
    format('%s carry %s''s %s', t.p1, t.team, t.role),
    format('%s handles %s%% of %s''s %s work with a %s-point drop to the next man. Unusually concentrated for the role, with no close deputy.',
      t.p1, round(100*t.s1), t.team, t.role, round(100*(t.s1-t.s2))),
    jsonb_build_object('role',t.role,'share_pct',round(100*t.s1,1),'gap_to_2nd_pct',round(100*(t.s1-t.s2),1),'player',t.p1),
    jsonb_build_object('player_id',t.pid1,'team',t.team),
    round(100*(t.s1-t.s2),1), 'medium'
  from top2 t join rolep rp using(role)
  where t.s1 >= rp.p90 and (t.s1 - t.s2) >= 0.07;

  -- 3) sterile control
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

  -- 4) vertical identity
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by long_pct desc) long_rk,
      rank() over (order by passes_seq asc) direct_rk, rank() over (order by xt_seq desc) xt_rk,
      count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','identity','team', team, team, team, 'vertical_identity',
    format('%s are among the league''s most vertical sides', team),
    format('%s%% of sequences go long and they average just %s passes per possession, yet rank %s of %s for xT. Threat through directness, not control.',
      long_pct, passes_seq, xt_rk, nteams),
    jsonb_build_object('long_pct',long_pct,'long_rank',long_rk,'passes_seq',passes_seq,'xt_rank',xt_rk),
    jsonb_build_object('team',team), (nteams-long_rk)+(nteams-direct_rk), 'medium'
  from r where long_rk<=6 and direct_rk<=10;

  -- 5) central funnel
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by finds_central_pct desc) c_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','style','team', team, team, team, 'central_funnel',
    format('%s funnel everything through the middle', team),
    format('%s%% of progression runs central (%s of %s), the heaviest reliance on interior play in the league.',
      finds_central_pct, c_rk, nteams),
    jsonb_build_object('finds_central_pct',finds_central_pct,'central_rank',c_rk),
    jsonb_build_object('team',team), (nteams-c_rk), 'medium'
  from r where c_rk<=4;

  -- 6) byline / wide
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by finds_wide_pct desc) w_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','style','team', team, team, team, 'byline_team',
    format('%s attack down the outside', team),
    format('%s%% of progression goes wide (%s of %s). A side built to reach the byline rather than play through the lines.',
      finds_wide_pct, w_rk, nteams),
    jsonb_build_object('finds_wide_pct',finds_wide_pct,'wide_rank',w_rk),
    jsonb_build_object('team',team), (nteams-w_rk), 'medium'
  from r where w_rk<=4;

  -- 7) territorial
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with r as (select *, rank() over (order by ends_opp_half_pct desc) opp_rk,
      rank() over (order by end_att_third_pct desc) att_rk, count(*) over () nteams from public.team_sequence_agg)
  select 'tactical','identity','team', team, team, team, 'territorial',
    format('%s pin opponents in', team),
    format('%s%% of sequences end in the opposition half and %s%% in the final third (ranked %s and %s of %s). A front-foot territorial identity.',
      ends_opp_half_pct, end_att_third_pct, opp_rk, att_rk, nteams),
    jsonb_build_object('ends_opp_half_pct',ends_opp_half_pct,'opp_rank',opp_rk,'end_att_third_pct',end_att_third_pct,'att_rank',att_rk),
    jsonb_build_object('team',team), (nteams-opp_rk)+(nteams-att_rk), 'medium'
  from r where opp_rk<=6 and att_rk<=6;

  select count(*) into v_ct from public.insights;
  return format('built %s insights at %s', v_ct, now()::timestamptz(0));
end $fn$;
