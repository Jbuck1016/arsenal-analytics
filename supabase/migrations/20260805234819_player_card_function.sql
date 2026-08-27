
-- One call returns everything the scouting card needs: bio, archetype, banded trait
-- pills, strengths, weaknesses, and stylistic comps.
create or replace function public.player_card(p_id text)
returns jsonb language sql stable set search_path = public as $fn$
  with ps as (select * from public.player_search where player_id = p_id),
  pct as (
    select p.metric, d.label, d.grp, d.unit, p.raw, p.pct_pool, p.pct_archetype,
      case when p.pct_pool >= 90 then 'Elite'
           when p.pct_pool >= 75 then 'Strong'
           when p.pct_pool >= 40 then 'Average'
           when p.pct_pool >= 20 then 'Below Par'
           else 'Limited' end as band
    from public.mv_player_pct p
    join public.metric_defs d on d.metric = p.metric
    where p.player_id = p_id
  ),
  roles as (
    select role, raw, pct from public.player_chain_pct where player_id = p_id order by pct desc
  ),
  comps as (
    select * from public.similar_players_chain(p_id, 5)
  )
  select jsonb_build_object(
    'player', to_jsonb((select row_to_json(x) from (
        select ps.player_id, ps.player, ps.team, ps.pos, ps.side, ps.pool,
               ps.age_seen, ps.height_cm, ps.weight_kg, ps.foot, ps.foot_confidence,
               ps.nineties, ps.inv, ps.archetype, ps.archetype_primary, ps.archetype_secondary
        from ps) x)),
    'traits', (select jsonb_agg(jsonb_build_object(
        'metric',metric,'label',label,'group',grp,'unit',unit,
        'value',raw,'pct',pct_pool,'pct_archetype',pct_archetype,'band',band)
        order by pct_pool desc) from pct),
    'strengths', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct_pool,'value',raw)
        order by pct_pool desc) from (select * from pct where pct_pool >= 80 order by pct_pool desc limit 6) s),
    'weaknesses', (select jsonb_agg(jsonb_build_object('label',label,'pct',pct_pool,'value',raw)
        order by pct_pool asc) from (select * from pct where pct_pool <= 25 order by pct_pool asc limit 4) w),
    'roles', (select jsonb_agg(jsonb_build_object('role',role,'value',raw,'pct',pct) order by pct desc) from roles),
    'similar', (select jsonb_agg(to_jsonb(c) order by c.rank) from comps c)
  );
$fn$;
grant execute on function public.player_card(text) to anon, authenticated;
