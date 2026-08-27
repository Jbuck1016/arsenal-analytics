
-- Family phrases need a designated metric for ranking ("best at defending" must pick one).
alter table public.metric_synonyms add column if not exists rank_metric text;
update public.metric_synonyms set rank_metric = case grp
  when 'Threat' then 'xt_90' when 'Progression' then 'prog_cmp_90'
  when 'Carrying' then 'carries_90' when 'Creation' then 'xa_90'
  when 'Shooting' then 'xg_90' when 'Defending' then 'def_action_90'
  when 'Passing' then 'pass_cmp_90' when 'Trajectory' then 'pct_through'
  when 'Chain value' then 'early_shot_inv_90' end
where grp is not null;

create or replace function public.nl_query(q text, p_limit int default 10)
returns jsonb language plpgsql stable set search_path = public as $fn$
declare
  s text := lower(trim(coalesce(q,'')));
  intent text := 'filter';
  subj_id text; subj_name text; subj_team text; subj_pos text;
  name_part text;
  metrics text[] := '{}';
  best_phrase text; best_metric text;
  v_pool text; v_side text; v_foot text; v_age int; v_n int := p_limit;
  m text[]; res jsonb;
begin
  if s = '' then return jsonb_build_object('error','empty query'); end if;

  m := regexp_match(s, '\m(\d{1,3})\M');
  if m is not null then v_n := least(greatest((m[1])::int,1),50); end if;
  if s ~ '\mten\M' then v_n := 10; elsif s ~ '\mfive\M' then v_n := 5;
  elsif s ~ '\mtwenty\M' then v_n := 20; elsif s ~ '\mthree\M' then v_n := 3; end if;

  -- position (plural tolerant)
  if s ~ '(centre[- ]?back|center[- ]?back|\mcbs?\M|\mdefenders?\M)' then v_pool := 'CB';
  elsif s ~ '(full[- ]?backs?|\mfbs?\M|wing[- ]?backs?)' then v_pool := 'FB';
  elsif s ~ '(attacking midfield|number ?10|\mplaymakers?\M|\mams?\M)' then v_pool := 'AM';
  elsif s ~ '(\mmidfielders?\M|\mmidfield\M|\mcms?\M|number ?(6|8)|\mholding\M|\mregista\M)' then v_pool := 'CM';
  elsif s ~ '(\mwingers?\M|wide (players?|forwards?)|\mwide\M)' then v_pool := 'W';
  elsif s ~ '(\mstrikers?\M|\mforwards?\M|centre[- ]?forwards?|number ?9|\msts?\M)' then v_pool := 'ST';
  end if;

  if s ~ '(right[- ]?sided|from the right|right wing|right side|right flank)' then v_side := 'R';
  elsif s ~ '(left[- ]?sided|from the left|left wing|left side|left flank)' then v_side := 'L';
  elsif s ~ '(\mcentral\M|\mcentrally\M|through the middle)' then v_side := 'C';
  end if;

  if s ~ 'left[- ]?footed' then v_foot := 'left';
  elsif s ~ 'right[- ]?footed' then v_foot := 'right';
  elsif s ~ '(two[- ]?footed|both feet|either foot)' then v_foot := 'either';
  end if;

  m := regexp_match(s, '(?:under|younger than|below|aged under|\mu)\s*(\d{2})');
  if m is not null then v_age := (m[1])::int; end if;

  -- all metrics implied by any matching phrase (used for similarity subsetting)
  select array_agg(distinct mm) into metrics from (
    select case when ms.metric is not null then ms.metric else mc.metric end as mm
    from public.metric_synonyms ms
    left join public.metric_catalog mc on ms.metric is null and mc.grp = ms.grp
    where s like '%'||ms.phrase||'%'
  ) z where mm is not null;

  -- the LONGEST matching phrase wins for ranking, so "progressive passing" beats "passing"
  select ms.phrase, coalesce(ms.metric, ms.rank_metric)
    into best_phrase, best_metric
    from public.metric_synonyms ms
   where s like '%'||ms.phrase||'%'
   order by length(ms.phrase) desc limit 1;

  if s ~ '(similar to|comparable to|alternatives to|version of|\mlike\M)' then
    intent := 'similar';
    name_part := trim(regexp_replace(s,
      '^.*?(?:similar to|comparable to|alternatives to|version of|like)\s+', ''));
    name_part := trim(regexp_replace(name_part, '\s+(in|for|at|on|by|with|when)\s+.*$', ''));
    name_part := trim(regexp_replace(name_part, '[^a-z0-9áéíóúñü'' -]', '', 'g'));
    select r.player_id, r.player, r.team, r.pos
      into subj_id, subj_name, subj_team, subj_pos
      from public.resolve_player(name_part) r limit 1;
    if subj_id is null then
      return jsonb_build_object('intent','similar','error',
        format('could not find a player matching "%s"', name_part), 'query', q);
    end if;
  elsif s ~ '(\mbest\M|\mtop\M|\mmost\M|\mhighest\M|\mleading\M|\mstrongest\M|\mworst\M)' then
    intent := 'rank';
  end if;

  if intent = 'similar' then
    res := (select coalesce(jsonb_agg(to_jsonb(x) order by x.rank),'[]'::jsonb) from (
      select * from public.similar_players_full(subj_id, v_n,
        case when array_length(metrics,1) is null then null else metrics end)) x);
    return jsonb_build_object('intent','similar','query',q,
      'subject', jsonb_build_object('player_id',subj_id,'player',subj_name,
                                    'team',subj_team,'pos',subj_pos),
      'compared_on', case when array_length(metrics,1) is null
                          then 'overall style' else coalesce(best_phrase,'selected metrics') end,
      'metrics', to_jsonb(metrics), 'results', res);
  else
    res := (select coalesce(jsonb_agg(to_jsonb(y) order by y.rk),'[]'::jsonb) from (
      select row_number() over (order by p.pct_pool desc, ps.nineties desc) rk,
             ps.player, ps.team, ps.pos, ps.pool, ps.age_seen, ps.foot,
             round(ps.nineties,1) nineties, p.metric, p.raw as value, p.pct_pool as pct
      from public.mv_player_pct p
      join public.player_search ps on ps.player_id = p.player_id
      where p.metric = coalesce(best_metric,'xt_90')
        and (v_pool is null or ps.pool = v_pool)
        and (v_side is null or ps.side = v_side)
        and (v_foot is null or ps.foot = v_foot)
        and (v_age  is null or ps.age_seen <= v_age)
        and coalesce(ps.nineties,0) >= 6
      order by p.pct_pool desc, ps.nineties desc
      limit v_n) y);
    return jsonb_build_object('intent', intent, 'query', q,
      'ranked_on', coalesce(best_metric,'xt_90'),
      'ranked_on_label', coalesce(best_phrase,'expected threat'),
      'filters', jsonb_build_object('pool',v_pool,'side',v_side,'foot',v_foot,
                                    'max_age',v_age,'min_nineties',6),
      'results', res);
  end if;
end $fn$;
grant execute on function public.nl_query(text,int) to anon, authenticated;
