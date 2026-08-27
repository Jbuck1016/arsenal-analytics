
create or replace function public.similar_teams(p_team text, p_n int default 5)
returns table(rank int, team text, dist numeric)
language sql stable as $$
  with q as (select metric, z from public.team_sequence_style where team = p_team)
  select row_number() over (order by x.d)::int, x.t, round(x.d::numeric,2)
  from (
    select s.team as t, sqrt(sum(power(coalesce(s.z,0)-coalesce(q.z,0),2))) as d
    from public.team_sequence_style s join q using(metric)
    where s.team <> p_team
    group by s.team
  ) x order by x.d limit p_n;
$$;

create or replace function public.top_sequences_by_type(p_tag text, p_n int default 10)
returns setof public.sequences
language plpgsql stable as $$
begin
  if p_tag not in ('low_build','high_build','structured','has_switch','wide_triangles','hold_up',
       'very_short','long_ball','ends_opp_half','end_around_box','finds_central','finds_wide',
       'ended_shot','ended_goal','ended_in_box') then
    raise exception 'invalid tag: %', p_tag;
  end if;
  return query execute format(
    'select * from public.sequences where is_open_play and %I order by xt_sum desc limit %s',
    p_tag, p_n);
end; $$;
