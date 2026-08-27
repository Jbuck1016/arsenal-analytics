
-- One endpoint the frontend can call for ANY metric: give me the events behind this number.
-- Returns a uniform plottable shape so a single map component handles every stat.
create or replace function public.player_metric_events(p_id text, p_metric text, p_limit int default 800)
returns table(kind text, x double precision, y double precision,
              end_x double precision, end_y double precision,
              value numeric, outcome text, game_id text)
language plpgsql stable set search_path = public as $fn$
begin
  -- xT family: arrows weighted by threat added
  if p_metric in ('xt_90','xt_pass_90','xt_carry_90','player_xt','xt_positive') then
    return query
      select a.kind, a.x, a.y, a.end_x, a.end_y, a.xt,
             case when a.xt > 0 then 'positive' else 'negative' end, a.game_id
      from public.v_player_xt_actions a
      where a.player_id = p_id
        and (p_metric <> 'xt_pass_90'  or a.kind = 'pass')
        and (p_metric <> 'xt_carry_90' or a.kind = 'carry')
        and (p_metric <> 'xt_positive' or a.xt > 0)
      order by abs(a.xt) desc limit p_limit;

  -- carrying family
  elsif p_metric in ('carries_90','prog_carries_90','carry_box_90','carry_pen_90','mean_carry_m') then
    return query
      select 'carry'::text, c.start_x, c.start_y, c.end_x, c.end_y,
             round(c.carry_m::numeric,1),
             case when c.into_box then 'into box' when c.is_progressive then 'progressive' else 'carry' end,
             c.game_id
      from public.v_player_carries c
      where c.player_id = p_id
        and (p_metric <> 'prog_carries_90' or c.is_progressive)
        and (p_metric not in ('carry_box_90','carry_pen_90') or c.into_box)
      order by c.carry_m desc limit p_limit;

  -- shooting family
  elsif p_metric in ('shots_90','sot_90','goals_90','xg_90','xg_per_shot','bigchance_90','conversion','finishing','shot_acc','shot_dist') then
    return query
      select 'shot'::text, a.x, a.y, a.end_x, a.end_y,
             round(coalesce(a.xg,0)::numeric,3),
             case when a.is_goal then 'goal' else coalesce(a.shot_outcome,'shot') end,
             a.game_id
      from public.v_player_actions a
      where a.player_id = p_id and a.is_shot
        and (p_metric <> 'goals_90' or a.is_goal)
        and (p_metric <> 'bigchance_90' or a.bigchance)
        and (p_metric <> 'sot_90' or a.is_goal or a.shot_outcome ilike '%target%' or a.shot_outcome ilike '%saved%')
      order by coalesce(a.xg,0) desc limit p_limit;

  -- defensive family
  elsif p_metric in ('tackle_90','int_90','recov_90','clear_90','block_90','aerial_90','def_action_90',
                     'padj_tackle_90','padj_int_90','padj_recov_90','padj_def_90',
                     'box_def_90','channel_def_90','flank_def_90','counterpress_90') then
    return query
      select lower(a.type), a.x, a.y, a.end_x, a.end_y, 1::numeric,
             case when a.ok then 'won' else 'lost' end, a.game_id
      from public.v_player_actions a
      where a.player_id = p_id
        and ((p_metric in ('tackle_90','padj_tackle_90') and a.type='Tackle')
          or (p_metric in ('int_90','padj_int_90')       and a.type='Interception')
          or (p_metric in ('recov_90','padj_recov_90')   and a.type='BallRecovery')
          or (p_metric = 'clear_90'  and a.type='Clearance')
          or (p_metric = 'block_90'  and a.type in ('BlockedPass','Block'))
          or (p_metric = 'aerial_90' and a.type='Aerial')
          or (p_metric in ('def_action_90','padj_def_90','counterpress_90','box_def_90','channel_def_90','flank_def_90')
              and a.type in ('Tackle','Interception','BallRecovery','Clearance','BlockedPass','Challenge','Aerial')))
      order by a.x desc limit p_limit;

  -- take-ons
  elsif p_metric in ('takeon_90','takeon_pct','disp_90') then
    return query
      select 'takeon'::text, a.x, a.y, a.end_x, a.end_y, 1::numeric,
             case when a.ok then 'beaten' else 'stopped' end, a.game_id
      from public.v_player_actions a
      where a.player_id = p_id and a.type in ('TakeOn','Dispossessed')
      order by a.x desc limit p_limit;

  -- passing family (default)
  else
    return query
      select 'pass'::text, a.x, a.y, a.end_x, a.end_y,
             round(coalesce(a.xg,0)::numeric,3),
             case when a.assist then 'assist' when a.keypass then 'key pass'
                  when a.ok then 'completed' else 'incomplete' end,
             a.game_id
      from public.v_player_actions a
      where a.player_id = p_id and a.type='Pass'
        and (p_metric <> 'pass_cmp_90'     or a.ok)
        and (p_metric not in ('prog_cmp_90','prog_pct','hs_prog_90') or (a.prog and a.ok))
        and (p_metric <> 'into_box_90'     or a.into_box)
        and (p_metric <> 'through_90'      or a.through)
        and (p_metric not in ('cross_90','cross_pct') or a.cross_)
        and (p_metric not in ('key_pass_90','hs_key_90') or a.keypass)
        and (p_metric <> 'assist_90'       or a.assist)
        and (p_metric <> 'final_third_90'  or (a.end_x >= 66.7 and a.ok))
      order by (case when a.assist then 3 when a.keypass then 2 else 1 end) desc, a.end_x desc
      limit p_limit;
  end if;
end $fn$;
grant execute on function public.player_metric_events(text,text,int) to anon, authenticated;
