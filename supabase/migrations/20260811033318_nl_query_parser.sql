
-- Deterministic parser: intent + entities + filters, no model in the loop.
-- Returns both the parse and the results, so the UI can show WHY it answered that way.
create or replace function public.nl_query(q text, p_limit int default 10)
returns jsonb language plpgsql stable set search_path = public as $fn$
declare
  s text := lower(trim(coalesce(q,'')));
  intent text := 'filter';
  subj_id text; subj_name text; subj_team text; subj_pos text;
  name_part text;
  metrics text[] := '{}';
  metric_label text;
  v_pool text; v_side text; v_foot text; v_age int; v_n int := p_limit;
  m text[]; res jsonb;
begin
  if s = '' then return jsonb_build_object('error','empty query'); end if;

  -- explicit count: "ten players", "top 5"
  m := regexp_match(s, '\m(\d{1,3})\M');
  if m is not null then v_n := least(greatest((m[1])::int,1),50); end if;
  if s ~ '\mten\M' then v_n := 10; elsif s ~ '\mfive\M' then v_n := 5;
  elsif s ~ '\mtwenty\M' then v_n := 20; elsif s ~ '\mthree\M' then v_n := 3; end if;

  -- filters
  if s ~ '\m(centre[- ]?back|center[- ]?back|cb|defender)\M' then v_pool := 'CB';
  elsif s ~ '\m(full[- ]?back|fullback|fb|wing[- ]?back)\M' then v_pool := 'FB';
  elsif s ~ '\m(midfielder|midfield|cm|number (6|8)|holding)\M' then v_pool := 'CM';
  elsif s ~ '\m(attacking midfielder|number 10|playmaker|am)\M' then v_pool := 'AM';
  elsif s ~ '\m(winger|wingers|wide (player|forward)|w)\M' then v_pool := 'W';
  elsif s ~ '\m(striker|forward|centre[- ]?forward|number 9|st)\M' then v_pool := 'ST';
  end if;

  if s ~ '\m(right[- ]?sided|from the right|right wing|right side)\M' then v_side := 'R';
  elsif s ~ '\m(left[- ]?sided|from the left|left wing|left side)\M' then v_side := 'L';
  elsif s ~ '\m(central|centrally|through the middle)\M' then v_side := 'C';
  end if;

  if s ~ '\mleft[- ]?footed\M' then v_foot := 'left';
  elsif s ~ '\mright[- ]?footed\M' then v_foot := 'right';
  elsif s ~ '\m(two[- ]?footed|both feet|either foot)\M' then v_foot := 'either';
  end if;

  m := regexp_match(s, '(?:under|younger than|below|u)\s*(\d{2})');
  if m is not null then v_age := (m[1])::int; end if;

  -- metric phrases, longest match first so "expected threat creation" beats "threat"
  select array_agg(distinct mm) into metrics from (
    select case when ms.metric is not null then ms.metric else mc.metric end as mm
    from public.metric_synonyms ms
    left join public.metric_catalog mc on ms.metric is null and mc.grp = ms.grp
    where s like '%'||ms.phrase||'%'
  ) z where mm is not null;

  select ms.phrase into metric_label from public.metric_synonyms ms
   where s like '%'||ms.phrase||'%' order by length(ms.phrase) desc limit 1;

  -- intent: similarity needs a subject
  if s ~ '\m(similar to|like|comparable to|alternatives to|version of)\M' then
    intent := 'similar';
    name_part := trim(regexp_replace(s,
      '^.*?(?:similar to|comparable to|alternatives to|version of|like)\s+', ''));
    name_part := trim(regexp_replace(name_part,
      '\s+(in|for|at|on|by|with|when)\s+.*$', ''));
    name_part := trim(regexp_replace(name_part, '[^a-z0-9áéíóúñü'' -]', '', 'g'));
    select r.player_id, r.player, r.team, r.pos
      into subj_id, subj_name, subj_team, subj_pos
      from public.resolve_player(name_part) r limit 1;
    if subj_id is null then
      return jsonb_build_object('intent','similar','error',
        format('could not find a player matching "%s"', name_part), 'query', q);
    end if;
  elsif s ~ '\m(best|top|most|highest|leading|strongest)\M' then
    intent := 'rank';
  end if;

  -- execute
  if intent = 'similar' then
    res := (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.rank),'[]'::jsonb) from (
        select * from public.similar_players_full(
          subj_id, v_n,
          case when array_length(metrics,1) is null then null else metrics end)
      ) x
    );
    return jsonb_build_object(
      'intent','similar','query',q,
      'subject', jsonb_build_object('player_id',subj_id,'player',subj_name,
                                    'team',subj_team,'pos',subj_pos),
      'compared_on', case when array_length(metrics,1) is null
                          then 'overall style' else coalesce(metric_label,'selected metrics') end,
      'metrics', to_jsonb(metrics), 'results', res);
  else
    res := (
      select coalesce(jsonb_agg(to_jsonb(y) order by y.rk),'[]'::jsonb) from (
        select row_number() over (order by p.pct_pool desc, ps.nineties desc) rk,
               ps.player, ps.team, ps.pos, ps.pool, ps.age_seen, ps.foot,
               round(ps.nineties,1) nineties, p.metric, p.raw as value, p.pct_pool as pct
        from public.mv_player_pct p
        join public.player_search ps on ps.player_id = p.player_id
        where p.metric = coalesce(metrics[1],'xt_90')
          and (v_pool is null or ps.pool = v_pool)
          and (v_side is null or ps.side = v_side)
          and (v_foot is null or ps.foot = v_foot)
          and (v_age  is null or ps.age_seen <= v_age)
          and coalesce(ps.nineties,0) >= 6
        order by p.pct_pool desc, ps.nineties desc
        limit v_n
      ) y
    );
    return jsonb_build_object(
      'intent', intent, 'query', q,
      'ranked_on', coalesce(metrics[1],'xt_90'),
      'ranked_on_label', coalesce(metric_label,'expected threat'),
      'filters', jsonb_build_object('pool',v_pool,'side',v_side,'foot',v_foot,
                                    'max_age',v_age,'min_nineties',6),
      'results', res);
  end if;
end $fn$;
grant execute on function public.nl_query(text,int) to anon, authenticated;
