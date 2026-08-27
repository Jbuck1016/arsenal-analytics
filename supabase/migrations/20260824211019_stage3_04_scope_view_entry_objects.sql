-- v_team_sample: was min(s.league) over ALL competitions, which resolved
-- Arsenal to ENG-FA Cup and gave it a 54-match cross-competition evidence
-- base. Now reads the canonical scoped source, so cup fixtures cannot
-- reach the six-match minimum or the insight generator.
create or replace view v_team_sample as
 select s.team,
    min(s.league) as league,
    count(distinct s.game_id) as matches,
    count(*) filter (where s.is_open_play) as open_play_seqs,
    count(*) filter (where (s.is_open_play and (s.start_x < (33.3)::double precision))) as deep_start_seqs,
    count(*) filter (where (s.is_open_play and (st.state = 'winning'::text))) as seqs_winning,
    count(*) filter (where (s.is_open_play and (st.state = 'losing'::text))) as seqs_losing,
    (count(distinct s.game_id) >= 6) as meets_min_matches
   from (v_league_sequences s
     left join mv_seq_state st on ((st.seq_uid = s.seq_uid)))
  group by s.team;

comment on view v_team_sample is
  'Team evidence base, league competitions only via v_league_sequences. Source of truth for the six-match minimum.';

-- v_seq_directness: same scoping, plus league exposed for downstream use.
create or replace view v_seq_directness as
 select s.seq_uid, s.game_id, s.team, s.n_pass, s.dur_s,
    greatest('-1.0'::numeric, least(1.0, (((s.end_x - s.start_x))::numeric / nullif((s.mean_pass_len * (s.n_pass)::numeric), (0)::numeric)))) as directness,
    st.state, st.margin, st.is_close
   from (v_league_sequences s join mv_seq_state st using (seq_uid))
  where (s.is_open_play and (s.n_pass >= 2) and (coalesce(s.mean_pass_len, (0)::numeric) > (0)::numeric));

do $g$
declare r text;
begin
  foreach r in array array['v_team_sample','v_seq_directness'] loop
    execute format('alter view public.%I owner to postgres', r);
    execute format('revoke all on public.%I from public, anon, authenticated', r);
    execute format('grant select on public.%I to anon, authenticated', r);
    execute format('grant all on public.%I to service_role', r);
  end loop;
end
$g$;

do $assert$
declare v text;
begin
  select league into v from v_team_sample where team = 'Arsenal';
  if v is distinct from 'ENG-Premier League' then
    raise exception 'ASSERT FAILED. v_team_sample resolves Arsenal to %, expected ENG-Premier League.', v;
  end if;
  if exists (select 1 from v_team_sample ts join leagues l on l.league = ts.league
             where l.competition_type <> 'league') then
    raise exception 'ASSERT FAILED. v_team_sample still carries a non-league competition.';
  end if;
end
$assert$;

select team, league, matches, open_play_seqs, meets_min_matches
from v_team_sample where team in ('Arsenal','Chelsea','Manchester City','Man City') order by team;
