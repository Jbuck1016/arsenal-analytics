
-- The three population counts were mislabelled, and investigating why exposed a real defect.
--
-- 564 players sit in mv_player_season with no events at all. Every one of their 991 lineup
-- rows carries position 'Sub', and mv_player_season credits 90 minutes per row regardless,
-- so an unused backup keeper reads as 630 minutes across 7 appearances.
--
-- Two consequences: 'season-record players' was counting matchday-squad membership rather
-- than participation, and the site's stated limitation that unused substitutes are invisible
-- was false. They are present, with fabricated minutes.
drop materialized view if exists public.mv_site_summary cascade;
create materialized view public.mv_site_summary as
select
  (select max(m.date) from public.matches m
     where m.home_score is not null
       and exists (select 1 from public.events e where e.game_id = m.game_id)) as as_of_match_date,
  (select count(distinct game_id) from public.events)  as matches_analysed,
  (select count(*) from public.events)                 as events,
  (select count(*) from public.sequences)              as sequences,
  (select count(*) from public.leagues where is_active) as leagues_active,
  (select count(distinct league) from public.events)   as leagues_with_data,
  (select count(distinct team) from public.events)     as clubs,

  -- 1. touched the ball in a scraped match
  (select count(distinct player_id) from public.events where player_id is not null)
     as players_touched_ball,
  -- 2. named in a matchday squad, INCLUDING unused substitutes
  (select count(distinct player_id) from public.mv_player_season)
     as players_in_matchday_squads,
  -- 3. named but never involved: unused substitutes
  (select count(*) from (
      select player_id from public.mv_player_season
      except select player_id from public.events where player_id is not null) z)
     as players_named_never_involved,
  -- 4. clear the involvement and minutes thresholds, so eligible for percentiles and search
  (select count(*) from public.player_search) as players_profiled_outfield,

  (select count(*) from public.insights)                as insights,
  (select count(distinct team) from public.insights)    as clubs_with_insights,
  (select count(*) from public.metric_defs)             as metrics_player,
  (select count(*) from public.team_metric_defs)        as metrics_team,
  (select count(*) from public.mv_shot_xg where is_pen = false)          as shots_non_pen,
  (select round(sum(xg),1) from public.mv_shot_xg where is_pen = false)  as xg_predicted,
  (select count(*) from public.mv_shot_xg where is_pen = false and is_goal) as goals_actual,
  (select count(*) from public.invariants where enabled and severity='error') as checks_error,
  (select count(*) from public.invariants where enabled and severity='warn')  as checks_warn,
  now() as refreshed_at;
grant select on public.mv_site_summary to anon, authenticated;

-- flag the fabricated minutes so it cannot be forgotten
insert into public.invariants (name, description, check_sql, severity) values
('unused_subs_carry_minutes',
 'Players with no events are credited minutes in mv_player_season. Every lineup row is treated as 90 minutes regardless of whether the player was used, so unused substitutes accrue appearances and minutes they did not play. Any metric derived from mv_player_season.minutes for these players is wrong. Tracked as a known defect pending a fix to the minutes derivation.',
 $q$select count(*) from public.mv_player_season s
    where s.minutes > 0
      and not exists (select 1 from public.events e where e.player_id = s.player_id)$q$,
 'warn')
on conflict (name) do update set description=excluded.description,
  check_sql=excluded.check_sql, severity=excluded.severity;

select players_touched_ball, players_in_matchday_squads, players_named_never_involved,
       players_profiled_outfield, checks_error, checks_warn
from public.mv_site_summary;
