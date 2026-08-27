
-- Prose layer: a short scouting note per insight, assembled from the pinned facts.
-- Deterministic on purpose — no API dependency, no per-view cost, and it physically
-- cannot reference a number the detector did not surface.
alter table public.insights add column if not exists note text;

create or replace function public.write_insight_notes()
returns text language plpgsql security definer set search_path = public as $fn$
declare n int := 0;
begin
  -- standout profile: what the profile means and what to check next
  update public.insights i set note = format(
    'Reads as a specialist rather than an all-rounder: he tops the %s pool for %s. Before shortlisting, check whether the volume is a product of his side having the ball, and look at the pitch map to see whether the actions come in useful areas or safe ones.',
    i.metrics->>'pool', i.metrics->>'role')
  where i.detector='standout_profile' and i.note is null;

  -- key man: the risk framed as a squad-planning question
  update public.insights i set note = format(
    'The planning question is what happens without him. With %s%% of the %s load and no close deputy, an injury or sale forces either a like-for-like replacement or a change of approach. Worth checking whether the next man is young enough to grow into it.',
    round((i.metrics->>'share_pct')::numeric), i.metrics->>'role')
  where i.detector='key_man' and i.note is null;

  -- squad gap: the recruitment brief
  update public.insights i set note = format(
    'This is a recruitment lane rather than a crisis: the squad functions without one, but the ceiling is capped. If the side already struggles to progress, filling it changes more than one metric. If they progress fine by other routes, it may be a deliberate stylistic choice.')
  where i.detector='squad_gap' and i.note is null;

  -- minutes inflated: how to read his numbers
  update public.insights i set note = format(
    'Read his per-90 output with that in mind. It does not mean he is a poor player — it means a meaningful share of his production arrived when the game was already settled, and the same numbers in tighter matches would be worth more. Compare his output split by game state before valuing him.')
  where i.detector='minutes_inflated' and i.note is null;

  -- misfit: quirk or misuse
  update public.insights i set note = format(
    'Two readings. Either the coach is using him deliberately against type, which is worth understanding tactically, or he is playing a role that does not suit him. The data flags the anomaly; only watching the games separates intent from accident.')
  where i.detector='misfit_profile' and i.note is null;

  -- team profile
  update public.insights i set note = case
    when abs((i.metrics->>'z')::numeric) < 0.8 then
      'A side without a strong stylistic fingerprint is not necessarily a poor one, but it is harder to plan against and harder to recruit for. Ask whether that is deliberate flexibility or an absence of identity.'
    else format(
      'Style is not quality. This tells you how they try to play, not how well it works — the route verdict does that. A side leaning this heavily on one trait is also predictable, which is exploitable if you can take that trait away.')
    end
  where i.detector='team_profile' and i.note is null;

  -- press vulnerability
  update public.insights i set note =
    'The practical use is opposition planning: attack the weakness rather than the strength, and check whether your own personnel can execute that route before committing to it.'
  where i.detector='press_vulnerability' and i.note is null;

  -- game state reactivity
  update public.insights i set note =
    'Useful for in-game planning. A reactive side changes character once you score, so the game you prepare for is not the game you get after the first goal. A settled side gives you the same problem for ninety minutes.'
  where i.detector='game_state_reactivity' and i.note is null;

  -- sterile control
  update public.insights i set note =
    'Control without penetration is usually a final-third problem rather than a build-up one. Check the route breakdown to see where possessions die, then check whether the squad has anyone above pool average for chance creation.'
  where i.detector='sterile_control' and i.note is null;

  -- route extremes
  update public.insights i set note =
    'A pronounced route preference is both an identity and a vulnerability. Cross-reference against opponents who defend that route well to find the fixtures where they struggle.'
  where i.detector in ('central_funnel','byline_team') and i.note is null;

  update public.insights i set note =
    'Territorial dominance says where the game is played, not whether chances follow. Pair it with the share of possessions ending in a shot before treating it as a strength.'
  where i.detector='territorial' and i.note is null;

  select count(*) into n from public.insights where note is not null;
  return format('%s insight notes written', n);
end $fn$;
revoke execute on function public.write_insight_notes() from public, anon, authenticated;
grant execute on function public.write_insight_notes() to service_role;

create or replace function public.polish_insights()
returns text language plpgsql security definer set search_path = public as $fn$
declare a text; b text;
begin
  a := public.build_team_profile_insights();
  b := public.write_insight_notes();
  return a || ' · ' || b;
end $fn$;
revoke execute on function public.polish_insights() from public, anon, authenticated;
grant execute on function public.polish_insights() to service_role;
