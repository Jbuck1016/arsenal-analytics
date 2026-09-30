begin;

-- A superseded future provider row cannot be deleted while immutable frozen
-- predictions reference it. It must stay outside live scope so analytics and
-- table simulations see the one canonical fixture, while the frozen call
-- retains its original game_id. Permit only that narrow archival exception.
update public.invariants
set check_sql = $check$
  select count(*)
  from public.matches m
  join public.leagues l on l.league = m.league
  where m.is_live_scope <> (m.season = l.season and l.competition_type = 'league')
    and not (
      m.is_live_scope = false
      and m.season = l.season
      and l.competition_type = 'league'
      and m.home_score is null
      and m.away_score is null
      and exists (
        select 1 from public.matches canonical
        where canonical.game_id <> m.game_id
          and canonical.league = m.league
          and canonical.season = m.season
          and canonical.home_team = m.home_team
          and canonical.away_team = m.away_team
          and canonical.is_live_scope = true
      )
      and exists (
        select 1 from public.ml_match_predictions p where p.game_id = m.game_id
      )
    )
$check$,
description = 'Live scope must match the current league-season registry. The only exception is an unplayed superseded fixture alias retained to preserve an immutable prediction foreign key, with a live canonical pairing for the same clubs.'
where name = 'league_outputs_current_season';

commit;
