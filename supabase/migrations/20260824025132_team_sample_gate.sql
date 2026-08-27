
-- One source of truth for how much evidence exists behind a team-level claim.
-- Detectors were written for a 30-team, 250-match league and are now running against
-- four-match samples, which produced confident tactical reads from almost no data.
create or replace view public.v_team_sample as
select s.team, min(s.league) as league,
  count(distinct s.game_id) as matches,
  count(*) filter (where s.is_open_play) as open_play_seqs,
  count(*) filter (where s.is_open_play and s.start_x < 33.3) as deep_start_seqs,
  count(*) filter (where s.is_open_play and st.state='winning') as seqs_winning,
  count(*) filter (where s.is_open_play and st.state='losing')  as seqs_losing,
  (count(distinct s.game_id) >= 6) as meets_min_matches
from public.sequences s
left join public.mv_seq_state st on st.seq_uid = s.seq_uid
group by s.team;
grant select on public.v_team_sample to anon, authenticated;

-- Declared denominator requirements, per detector, published rather than buried in code.
create table if not exists public.detector_requirements (
  detector text primary key,
  min_matches int not null default 6,
  requirement text not null,
  rationale text
);
insert into public.detector_requirements (detector, min_matches, requirement, rationale) values
 ('counter_attack', 6, 'counter_pct > 0 and at least 120 deep-start possessions',
  'A rank-based detector fires for the top four even when every team in the league scores zero. Six of them did.'),
 ('low_block', 6, 'at least 6 matches', 'PPDA and line height are unstable below a handful of matches.'),
 ('game_state_reactivity', 6, 'at least 80 possessions both winning and losing',
  'A side that has rarely trailed has no losing sample to compare against.'),
 ('press_vulnerability', 6, 'at least 60 opponent possessions in each build-up type compared',
  'Containment rates on a handful of possessions are noise.'),
 ('sterile_control', 6, 'at least 6 matches', null),
 ('territorial', 6, 'at least 6 matches', null),
 ('central_funnel', 6, 'at least 6 matches', null),
 ('byline_team', 6, 'at least 6 matches', null),
 ('team_profile', 6, 'at least 6 matches', 'Fires for every club, so the sample gate matters most here.'),
 ('team_strength', 6, 'at least 6 matches', null),
 ('team_weakness', 6, 'at least 6 matches', null),
 ('key_man', 6, 'at least 6 matches', null),
 ('squad_gap', 6, 'at least 6 matches', null),
 ('standout_profile', 6, 'player has 150+ involvements', null),
 ('misfit_profile', 6, 'player has 250+ involvements', null),
 ('player_elite', 6, 'player has 8+ full matches', null),
 ('player_weakness', 6, 'player has 10+ full matches', null),
 ('minutes_inflated', 6, 'player has 6+ available matches at the club', null)
on conflict (detector) do update set min_matches=excluded.min_matches,
  requirement=excluded.requirement, rationale=excluded.rationale;
grant select on public.detector_requirements to anon, authenticated;

select count(*) filter (where meets_min_matches) as teams_qualifying,
       count(*) filter (where not meets_min_matches) as teams_suppressed,
       count(*) as total from public.v_team_sample;
