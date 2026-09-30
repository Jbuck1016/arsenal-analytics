-- Keep immutable frozen prediction references (two runs share one match ID),
-- but remove their phantom
-- fixtures from live scope. Archive and delete only unreferenced provider
-- placeholders that duplicate a numeric WhoScored fixture.
create table if not exists public.audit_duplicate_future_matches_before_20260930 as
select fd.*
from public.matches fd
join public.matches ws
  on ws.league = fd.league
 and ws.season = fd.season
 and ws.date = fd.date
 and ws.home_team = fd.home_team
 and ws.away_team = fd.away_team
 and ws.game_id ~ '^[0-9]+$'
where fd.season = '2627'
  and fd.game_id like 'fd-%'
  and fd.home_score is null
  and fd.away_score is null;

revoke all on public.audit_duplicate_future_matches_before_20260930
  from public, anon, authenticated;

do $migration$
declare
  archived integer;
  protected integer;
  remaining integer;
  live_remaining integer;
begin
  select count(*) into archived
  from public.audit_duplicate_future_matches_before_20260930;
  select count(*) into protected
  from public.ml_match_predictions p
  join public.audit_duplicate_future_matches_before_20260930 a
    on a.game_id = p.game_id;
  if archived <> 62 or protected <> 2 then
    raise exception 'duplicate fixture audit changed: % archived, % frozen references',
      archived, protected;
  end if;
  if exists (
    select 1 from public.audit_duplicate_future_matches_before_20260930
    where is_live_scope is distinct from true or date <= current_date
  ) then
    raise exception 'duplicate fixture candidates are no longer future live placeholders';
  end if;

  update public.matches m
  set is_live_scope = false
  from public.audit_duplicate_future_matches_before_20260930 a
  where m.game_id = a.game_id;

  delete from public.matches m
  using public.audit_duplicate_future_matches_before_20260930 a
  where m.game_id = a.game_id
    and not exists (
      select 1 from public.ml_match_predictions p where p.game_id = m.game_id
    );

  select count(*), count(*) filter (where m.is_live_scope)
    into remaining, live_remaining
  from public.matches m
  join public.audit_duplicate_future_matches_before_20260930 a
    on a.game_id = m.game_id;
  if remaining <> 1 or live_remaining <> 0 then
    raise exception 'expected one archived fixture referenced by two frozen runs and zero live duplicates; got %, %',
      remaining, live_remaining;
  end if;
end;
$migration$;
