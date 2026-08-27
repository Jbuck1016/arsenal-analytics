drop materialized view if exists mv_player_pool cascade;
drop materialized view if exists mv_player_season cascade;
drop materialized view if exists mv_player_minutes cascade;

-- Minutes are scaled so a full match = 90, matching FBref/Opta convention.
-- Raw clock (incl. stoppage) is kept for reference.
create materialized view mv_player_minutes as
with subs as (
  select game_id, player_id,
         min(expanded_minute) filter (where type = 'SubstitutionOn')  as on_min,
         max(expanded_minute) filter (where type = 'SubstitutionOff') as off_min
  from public.events
  where type in ('SubstitutionOn','SubstitutionOff')
  group by game_id, player_id
),
raw as (
  select
    l.game_id, l.player_id, l.team, l.position, l.is_starter,
    ml.length_min,
    greatest(0,
      coalesce(s.off_min, ml.length_min) - case when l.is_starter then 0 else s.on_min end
    )::numeric as raw_minutes
  from public.lineups l
  join mv_match_length ml on ml.game_id = l.game_id
  left join subs s on s.game_id = l.game_id and s.player_id = l.player_id
  where l.is_starter or s.on_min is not null
)
select
  game_id, player_id, team, position, is_starter,
  raw_minutes,
  round(raw_minutes * 90.0 / nullif(length_min,0), 2) as minutes
from raw;
create index on mv_player_minutes (player_id);
create index on mv_player_minutes (game_id);

create materialized view mv_player_season as
select
  m.player_id,
  p.player_name,
  mode() within group (order by m.team) as team,
  count(*) as apps,
  count(*) filter (where m.is_starter) as starts,
  round(sum(m.minutes),0) as minutes,
  round(sum(m.minutes) / 90.0, 2) as nineties
from mv_player_minutes m
join public.players p on p.player_id = m.player_id
group by m.player_id, p.player_name;
create unique index on mv_player_season (player_id);

create materialized view mv_player_pool as
with mins_by_pos as (
  select player_id, position, sum(minutes) as mins
  from mv_player_minutes
  where is_starter and position <> 'Sub'
  group by player_id, position
),
modal as (
  select distinct on (player_id) player_id, position as modal_position, mins
  from mins_by_pos
  order by player_id, mins desc, position
)
select
  d.player_id, d.modal_position,
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
  case
    when d.modal_position in ('DL','ML','AML','FWL','DML') then 'L'
    when d.modal_position in ('DR','MR','AMR','FWR','DMR') then 'R'
    else 'C'
  end as nominal_side
from modal d;
create unique index on mv_player_pool (player_id);

grant select on mv_player_minutes, mv_player_season, mv_player_pool to anon, authenticated;
