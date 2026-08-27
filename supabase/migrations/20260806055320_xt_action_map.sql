
-- Event-level xT, using EXACTLY the same sources and grid as mv_player_xt, so a plotted
-- map sums to the number shown in the rankings rather than quietly disagreeing with it.
create or replace view public.v_player_xt_actions as
  select e.player_id, e.game_id, 'pass'::text as kind,
    e.x, e.y, e.end_x, e.end_y,
    round((public.xt_at(e.end_x,e.end_y) - public.xt_at(e.x,e.y))::numeric, 4) as xt,
    e.expanded_minute as minute
  from public.events e
  where e.type='Pass' and e.outcome_type='Successful' and e.is_open_play
    and e.x is not null and e.y is not null and e.end_x is not null and e.end_y is not null
    and e.player_id is not null
  union all
  select r.player_id, r.game_id, 'carry'::text,
    r.start_x, r.start_y, r.end_x, r.end_y,
    round((public.xt_at(r.end_x,r.end_y) - public.xt_at(r.start_x,r.start_y))::numeric, 4),
    null::int
  from public.mv_receipt_events r
  where r.is_carry and r.player_id is not null
    and r.start_x is not null and r.end_x is not null;
grant select on public.v_player_xt_actions to anon, authenticated;

-- Plot feed: every xT-adding action for one player, biggest contributions first.
-- p_kind: 'all' | 'pass' | 'carry'.  p_positive_only trims the noise of negative actions.
create or replace function public.player_xt_map(
  p_id text, p_kind text default 'all', p_positive_only boolean default false, p_limit int default 500)
returns table(kind text, x double precision, y double precision,
              end_x double precision, end_y double precision, xt numeric, game_id text, minute int)
language sql stable set search_path = public as $fn$
  select a.kind, a.x, a.y, a.end_x, a.end_y, a.xt, a.game_id, a.minute
  from public.v_player_xt_actions a
  where a.player_id = p_id
    and (p_kind = 'all' or a.kind = p_kind)
    and (not p_positive_only or a.xt > 0)
  order by a.xt desc
  limit p_limit;
$fn$;
grant execute on function public.player_xt_map(text,text,boolean,int) to anon, authenticated;
