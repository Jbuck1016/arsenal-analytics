
-- team_profile lives in its own function so its wording can be iterated without
-- touching the whole detector battery. Direction-aware: a negative z means the team
-- does LESS of that thing, which the previous wording got backwards.
create or replace function public.build_team_profile_insights()
returns text language plpgsql security definer set search_path = public as $fn$
declare n int;
begin
  delete from public.insights where detector = 'team_profile';

  insert into public.insights (lens,category,scope,subject,subject_label,team,detector,headline,detail,metrics,evidence,score,confidence)
  with extremes as (
    select team, metric, z, abs(z) az, row_number() over (partition by team order by abs(z) desc) rk
    from public.team_sequence_style where z is not null
  ),
  top as (select * from extremes where rk = 1),
  sig as (select * from public.v_team_signature)
  select 'tactical','identity','team', t.team, t.team, t.team, 'team_profile',
    case
      when t.az < 0.8 then format('%s have no pronounced identity', t.team)
      when t.z > 0 and t.az >= 1.5 then format('%s are defined by %s', t.team, public.pretty_metric(t.metric))
      when t.z > 0 then format('%s lean towards %s', t.team, public.pretty_metric(t.metric))
      when t.az >= 1.5 then format('%s almost never rely on %s', t.team, public.pretty_metric(t.metric))
      else format('%s do less %s than most', t.team, public.pretty_metric(t.metric))
    end,
    (case
      when t.az < 0.8 then
        format('Nothing in their possession profile sits far from the league average. The closest thing to a signature is %s, and even that is only %s standard deviations out. A side without a strong stylistic fingerprint.',
          public.pretty_metric(t.metric), round(t.z,1))
      when t.z > 0 then
        format('Their most distinctive trait is %s, %s standard deviations above the league mean.',
          public.pretty_metric(t.metric), round(t.z,1))
      else
        format('What separates them is how little they do it: %s sits %s standard deviations below the league mean.',
          public.pretty_metric(t.metric), round(abs(t.z),1))
     end)
    || coalesce(
       format(' They break teams down mostly by %s, %s.', lower(s.signature_route),
         case s.signature_verdict
           when 'effective'    then 'and that route pays off'
           when 'unproductive' then 'though that route rarely pays off'
           else 'at a return no better or worse than the league'
         end), ''),
    jsonb_build_object('top_metric',t.metric,'top_metric_label',public.pretty_metric(t.metric),
      'z',round(t.z,2),'signature_route',s.signature_route,
      'route_share',s.share_pct,'route_verdict',s.signature_verdict),
    jsonb_build_object('team',t.team), t.az, 'medium'
  from top t left join sig s on s.team = t.team;

  get diagnostics n = row_count;
  return format('team profiles built (%s)', n);
end $fn$;
revoke execute on function public.build_team_profile_insights() from public, anon, authenticated;
grant execute on function public.build_team_profile_insights() to service_role;

create or replace function public.polish_insights()
returns text language plpgsql security definer set search_path = public as $fn$
begin
  return public.build_team_profile_insights();
end $fn$;
revoke execute on function public.polish_insights() from public, anon, authenticated;
grant execute on function public.polish_insights() to service_role;
