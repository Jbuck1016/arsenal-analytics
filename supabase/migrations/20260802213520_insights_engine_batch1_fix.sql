
create or replace function public.build_insights()
returns text language plpgsql security definer set search_path = public set statement_timeout = '120s'
as $fn$
declare v_ct int;
begin
  truncate table public.insights;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  select 'sd','role_profile','player', z.player_id, z.player, z.team, 'standout_profile',
    format('%s is the league''s most %s profile in the %s pool', z.player, r.label, z.pool),
    format('Sits at the extreme of the %s pool for %s (z %s across %s involvements). A profile to build around or shortlist against.',
      z.pool, r.label, to_char(r.zval,'SG9990.0'), z.inv),
    jsonb_build_object('pool',z.pool,'role',r.label,'z',round(r.zval::numeric,2),'inv',z.inv,'player_xt',z.player_xt),
    jsonb_build_object('player_id',z.player_id),
    round(r.zval::numeric,2),
    case when z.inv>=300 then 'high' else 'medium' end
  from public.pcr_z z
  cross join lateral (values
    ('ball-progression', z.z_prog),('build-up initiation', z.z_init),('chance creation', z.z_creator),
    ('box threat', z.z_box),('ball-carrying', z.z_carry),('vertical passing', z.z_vert),
    ('diagonal support', z.z_supp),('third-man bridging', z.z_bridge),('finishing', z.z_finish),
    ('1v1 dribbling', z.z_indiv)) r(label,zval)
  where r.zval >= 2.0
    and r.zval = greatest(z.z_prog,z.z_init,z.z_creator,z.z_box,z.z_carry,z.z_vert,z.z_supp,z.z_bridge,z.z_finish,z.z_indiv);

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with pr as (
    select team, player_id, player, r.label role, (inv * r.pctval/100.0) rinv
    from public.player_chain_roles
    cross join lateral (values
      ('ball progression', progressor),('chance creation', creator),
      ('build-up initiation', initiator),('third-man bridging', bridge)) r(label,pctval)
  ),
  tot as (select team, role, sum(rinv) team_rinv from pr group by team, role),
  ranked as (
    select pr.*, t.team_rinv, pr.rinv/nullif(t.team_rinv,0) share,
      row_number() over (partition by pr.team, pr.role order by pr.rinv desc) rk
    from pr join tot t using (team, role)
  )
  select 'sd','key_man_risk','team', team, team, team, 'key_man',
    format('%s carry %s''s %s', player, team, role),
    format('%s accounts for %s%% of %s''s %s involvements, well clear of any teammate. A profile the side would badly miss to injury or sale.',
      player, round(100*share), team, role),
    jsonb_build_object('role',role,'share_pct',round(100*share,1),'player',player),
    jsonb_build_object('player_id',player_id,'team',team),
    round(100*share,1), 'medium'
  from ranked where rk=1 and share>=0.40;

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with tm as (
    select team, r.label role, max(r.zval) best_z,
      (array_agg(player order by r.zval desc))[1] best_player
    from public.pcr_z
    cross join lateral (values
      ('ball progression', z_prog),('chance creation', z_creator),
      ('build-up initiation', z_init),('box threat', z_box)) r(label,zval)
    group by team, r.label
  )
  select 'sd','squad_gap','team', team, team, team, 'squad_gap',
    format('%s lack a high-end %s option', team, role),
    format('Their strongest %s profile sits at z %s, below the pool average. A clear recruitment lane.',
      role, to_char(best_z,'SG9990.0')),
    jsonb_build_object('role',role,'best_z',round(best_z::numeric,2),'best_player',best_player),
    jsonb_build_object('team',team),
    round((0-best_z)::numeric,2), 'medium'
  from tm where best_z < -0.25;

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
    format('%s%% of progression goes wide (%s of %s). A side built to reach the byline rather than play through the lines.',
      finds_wide_pct, w_rk, nteams),
    jsonb_build_object('finds_wide_pct',finds_wide_pct,'wide_rank',w_rk),
    jsonb_build_object('team',team), (nteams-w_rk), 'medium'
  from r where w_rk<=4;

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
