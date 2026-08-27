-- ============================================================
-- 1. BUG FIX: is_starter was true on every row, including bench.
--    WhoScored marks bench players with position = 'Sub'.
-- ============================================================
update public.lineups set is_starter = (position <> 'Sub');

-- ============================================================
-- 2. Match length (accounts for stoppage time)
-- ============================================================
create or replace view v_match_length as
select game_id, max(expanded_minute) as length_min
from public.events
group by game_id;

-- ============================================================
-- 3. Real minutes per player per match
--    starter: 0 -> subbed off (or full match)
--    sub:     subbed on -> subbed off (or full match)
--    unused bench: excluded (never appeared)
-- ============================================================
create or replace view v_player_minutes as
with subs as (
  select game_id, player_id,
         min(expanded_minute) filter (where type = 'SubstitutionOn')  as on_min,
         max(expanded_minute) filter (where type = 'SubstitutionOff') as off_min
  from public.events
  where type in ('SubstitutionOn','SubstitutionOff')
  group by game_id, player_id
)
select
  l.game_id,
  l.player_id,
  l.team,
  l.position,
  l.is_starter,
  greatest(
    0,
    coalesce(s.off_min, ml.length_min) - case when l.is_starter then 0 else s.on_min end
  )::numeric as minutes
from public.lineups l
join v_match_length ml on ml.game_id = l.game_id
left join subs s on s.game_id = l.game_id and s.player_id = l.player_id
where l.is_starter or s.on_min is not null;   -- drop unused bench

-- ============================================================
-- 4. Season totals per player
-- ============================================================
create or replace view v_player_season as
select
  m.player_id,
  p.player_name,
  mode() within group (order by m.team) as team,
  count(*)                       as apps,
  count(*) filter (where m.is_starter) as starts,
  sum(m.minutes)                 as minutes,
  round(sum(m.minutes) / 90.0, 2) as nineties
from v_player_minutes m
join public.players p on p.player_id = m.player_id
group by m.player_id, p.player_name;

-- ============================================================
-- 5. Position pool: minutes-weighted modal STARTING position.
--    Pools are deliberately broad for percentile stability;
--    finer distinctions come from derived style tags, not slots.
--      GK | CB | FB | CM (DM+MC merged) | AM | W | ST
-- ============================================================
create or replace view v_player_pool as
with mins_by_pos as (
  select player_id, position, sum(minutes) as mins
  from v_player_minutes
  where is_starter and position <> 'Sub'
  group by player_id, position
),
modal as (
  select distinct on (player_id) player_id, position as modal_position, mins
  from mins_by_pos
  order by player_id, mins desc, position
)
select
  d.player_id,
  d.modal_position,
  case d.modal_position
    when 'GK'  then 'GK'
    when 'DC'  then 'CB'
    when 'DR'  then 'FB'  when 'DL'  then 'FB'
    when 'DMC' then 'CM'  when 'DML' then 'CM' when 'DMR' then 'CM'
    when 'MC'  then 'CM'
    when 'AMC' then 'AM'
    when 'ML'  then 'W'   when 'MR'  then 'W'
    when 'AML' then 'W'   when 'AMR' then 'W'
    when 'FWL' then 'W'   when 'FWR' then 'W'
    when 'FW'  then 'ST'
  end as pool,
  -- nominal side from the team sheet; a data-derived side tag comes later
  case
    when d.modal_position in ('DL','ML','AML','FWL','DML') then 'L'
    when d.modal_position in ('DR','MR','AMR','FWR','DMR') then 'R'
    else 'C'
  end as nominal_side
from modal d;

grant select on v_match_length, v_player_minutes, v_player_season, v_player_pool to anon, authenticated;
