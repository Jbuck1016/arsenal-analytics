
-- Directness-by-game-state compares winning against losing possessions. A side that has
-- rarely trailed has no losing sample, so the "swing" was being computed from a handful of
-- possessions. Require a real denominator on BOTH sides of the comparison.
create or replace function public.build_reactivity_insights()
returns text language plpgsql security definer set search_path = public as $fn$
declare n int;
begin
  delete from public.insights where detector = 'game_state_reactivity';
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  select 'tactical','identity','team', d.team, d.team, d.team, 'game_state_reactivity',
    case when d.swing_l_minus_w >= 0.03 then format('%s change shape with the scoreline', d.team)
         else format('%s play the same way whatever the score', d.team) end,
    case when d.swing_l_minus_w >= 0.03 then
      format('Their possessions run %s directness when losing against %s when winning, measured across %s losing and %s winning possessions. A reactive side rather than a settled one.',
        d.dir_losing, d.dir_winning, ts.seqs_losing, ts.seqs_winning)
    else
      format('Directness barely moves between winning (%s) and losing (%s), across %s winning and %s losing possessions. A settled identity that does not chase the game.',
        d.dir_winning, d.dir_losing, ts.seqs_winning, ts.seqs_losing) end,
    jsonb_build_object('dir_winning',d.dir_winning,'dir_drawing',d.dir_drawing,
      'dir_losing',d.dir_losing,'swing',d.swing_l_minus_w,
      'seqs_winning',ts.seqs_winning,'seqs_losing',ts.seqs_losing),
    jsonb_build_object('team',d.team), abs(d.swing_l_minus_w)*100, 'medium',
    'Game-state behaviour needs both states to be well sampled. A side that has rarely trailed cannot be judged on how it reacts to trailing.'
  from public.mv_team_directness_state d
  join public.v_team_sample ts on ts.team = d.team
  where ts.meets_min_matches
    and ts.seqs_winning >= 80 and ts.seqs_losing >= 80
    and d.dir_winning is not null and d.dir_losing is not null
    and (abs(d.swing_l_minus_w) >= 0.03 or d.swing_rank <= 3);
  get diagnostics n = row_count;
  return format('reactivity: %s', n);
end $fn$;
revoke execute on function public.build_reactivity_insights() from public, anon, authenticated;
grant execute on function public.build_reactivity_insights() to service_role;

-- Press vulnerability compares containment by build-up type. Sixty opponent possessions
-- per type is the floor below which containment rates are noise.
create or replace function public.build_press_insights()
returns text language plpgsql security definer set search_path = public as $fn$
declare n int;
begin
  delete from public.insights where detector = 'press_vulnerability';
  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence,note)
  with vol as (
    select defending_team team,
      min(n) filter (where buildup_type in ('short_build','direct')) min_n,
      max(n) filter (where buildup_type='short_build') n_short,
      max(n) filter (where buildup_type='direct') n_direct
    from public.mv_press_vs_buildup group by defending_team
  )
  select 'tactical','defending','team', p.team, p.team, p.team, 'press_vulnerability',
    case when p.z_vs_direct <= -1.0 then format('%s struggle against direct play', p.team)
         else format('%s struggle against short build-up', p.team) end,
    case when p.z_vs_direct <= -1.0 then
      format('They contain long, direct possessions %s standard deviations worse than the league, while handling short build-up at %s. Measured across %s direct and %s short-build possessions faced.',
        round(abs(p.z_vs_direct),1), round(p.z_vs_short_build,1), v.n_direct, v.n_short)
    else
      format('They contain patient build-up %s standard deviations worse than the league, while coping with direct play at %s. Measured across %s short-build and %s direct possessions faced.',
        round(abs(p.z_vs_short_build),1), round(p.z_vs_direct,1), v.n_short, v.n_direct) end,
    jsonb_build_object('z_vs_direct',p.z_vs_direct,'z_vs_short_build',p.z_vs_short_build,
      'n_direct',v.n_direct,'n_short',v.n_short),
    jsonb_build_object('team',p.team),
    greatest(abs(p.z_vs_direct), abs(p.z_vs_short_build)), 'medium',
    'The practical use is opposition planning: attack the weakness rather than the strength, and check whether your own personnel can execute that route.'
  from public.v_press_profile p
  join public.v_team_sample ts on ts.team = p.team
  join vol v on v.team = p.team
  where ts.meets_min_matches and coalesce(v.min_n,0) >= 60
    and (p.z_vs_direct <= -1.0 or p.z_vs_short_build <= -1.0);
  get diagnostics n = row_count;
  return format('press: %s', n);
end $fn$;
revoke execute on function public.build_press_insights() from public, anon, authenticated;
grant execute on function public.build_press_insights() to service_role;

-- Universal sweep: any team-scoped insight for a club below the match threshold is removed,
-- regardless of which detector produced it. Belt and braces behind the per-detector gates.
create or replace function public.suppress_low_sample_insights()
returns text language plpgsql security definer set search_path = public as $fn$
declare n int;
begin
  delete from public.insights i
  using public.v_team_sample ts
  where ts.team = i.team and not ts.meets_min_matches;
  get diagnostics n = row_count;
  return format('%s insights suppressed below the 6-match threshold', n);
end $fn$;
revoke execute on function public.suppress_low_sample_insights() from public, anon, authenticated;
grant execute on function public.suppress_low_sample_insights() to service_role;
