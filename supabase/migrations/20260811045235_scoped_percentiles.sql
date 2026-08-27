
-- Percentiles against a CHOSEN set of leagues, computed on demand.
-- Default (p_leagues null) = the player's own league, which stays the platform default.
-- Pass an array to pool several: e.g. Saka vs {ENG-Premier League, ESP-La Liga, USA-MLS}.
create or replace function public.player_pct_scoped(
  p_id text,
  p_leagues text[] default null,
  p_metrics text[] default null
)
returns table(
  metric text, label text, grp text, unit text,
  raw numeric, pct int, higher_better boolean,
  pool text, n_in_scope int, scope text
)
language sql stable set search_path = public as $fn$
  with tgt as (
    select pool, league from public.mv_player_pct where player_id = p_id limit 1
  ),
  scope as (
    select case
      when p_leagues is null or array_length(p_leagues,1) is null
        then array[(select league from tgt)]
      else p_leagues end as ls
  ),
  pop as (
    select p.player_id, p.metric, p.raw, p.higher_better, p.pool
    from public.mv_player_pct p, tgt, scope
    where p.pool = tgt.pool
      and p.league = any(scope.ls)
      and (p_metrics is null or p.metric = any(p_metrics))
  ),
  ranked as (
    select player_id, metric, raw, higher_better, pool,
      percent_rank() over (partition by metric order by raw) pr,
      count(*) over (partition by metric) n
    from pop
  )
  select r.metric, d.label, d.grp, d.unit, r.raw,
    round(100*(case when r.higher_better then r.pr else 1-r.pr end))::int as pct,
    r.higher_better, r.pool, r.n::int,
    array_to_string((select ls from scope), ' + ')
  from ranked r
  join public.metric_catalog d on d.metric = r.metric
  where r.player_id = p_id
  order by pct desc;
$fn$;
grant execute on function public.player_pct_scoped(text,text[],text[]) to anon, authenticated;

-- What comparison scopes are available, and how big each pool is.
create or replace function public.comparison_scopes()
returns table(league text, display_name text, players int)
language sql stable set search_path = public as $fn$
  select l.league, l.display_name, count(distinct ps.player_id)::int
  from public.leagues l
  left join public.player_search ps on ps.league = l.league
  where l.is_active
  group by l.league, l.display_name
  order by l.display_name;
$fn$;
grant execute on function public.comparison_scopes() to anon, authenticated;

-- Card variant that accepts a comparison scope, so the UI can offer a league selector
-- without needing a second endpoint for everything else on the card.
create or replace function public.player_card_scoped(p_id text, p_leagues text[] default null)
returns jsonb language sql stable set search_path = public as $fn$
  with ps as (select * from public.player_search where player_id = p_id),
  pct as (
    select s.metric, s.label, s.grp, s.unit, s.raw, s.pct, s.n_in_scope, s.scope,
      case when s.pct >= 90 then 'Elite' when s.pct >= 75 then 'Strong'
           when s.pct >= 40 then 'Average' when s.pct >= 20 then 'Below Par'
           else 'Limited' end as band
    from public.player_pct_scoped(p_id, p_leagues) s
  )
  select jsonb_build_object(
    'player', to_jsonb((select row_to_json(x) from (
        select ps.player_id, ps.player, ps.team, ps.pos, ps.side, ps.pool, ps.league,
               ps.age_seen, ps.height_cm, ps.foot, ps.nineties, ps.archetype
        from ps) x)),
    'scope', (select scope from pct limit 1),
    'compared_against', (select n_in_scope from pct limit 1),
    'traits', (select jsonb_agg(jsonb_build_object(
        'metric',metric,'label',label,'group',grp,'unit',unit,
        'value',raw,'pct',pct,'band',band) order by pct desc) from pct),
    'strengths', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct,'value',raw)
        order by pct desc) from (select * from pct where pct >= 80 order by pct desc limit 6) s),
    'weaknesses', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct,'value',raw)
        order by pct asc) from (select * from pct where pct <= 25 order by pct asc limit 4) w)
  );
$fn$;
grant execute on function public.player_card_scoped(text,text[]) to anon, authenticated;
