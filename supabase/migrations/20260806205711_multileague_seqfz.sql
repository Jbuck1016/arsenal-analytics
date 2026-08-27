
drop materialized view if exists public.seq_fz cascade;
create materialized view public.seq_fz as
  with f as (
    select seq_uid, team, game_id, league, xt_sum, n_pass, ended_shot, end_third, ended_in_box,
      start_x::numeric as sx, start_y::numeric as sy, end_x::numeric as ex, end_y::numeric as ey,
      cx, cy, maxx-minx as vs, maxy-miny as ls, end_x-start_x as ndx, end_y-start_y as ndy,
      coalesce(mean_pass_len,0::numeric)*n_pass::numeric as pl, att_share as az
    from public.sequences where is_open_play
  )
  select seq_uid, team, game_id, xt_sum, n_pass, ended_shot, end_third, ended_in_box,
    (sx-avg(sx) over w)/nullif(stddev_samp(sx) over w,0::numeric) as z_sx,
    (sy-avg(sy) over w)/nullif(stddev_samp(sy) over w,0::numeric) as z_sy,
    (ex-avg(ex) over w)/nullif(stddev_samp(ex) over w,0::numeric) as z_ex,
    (ey-avg(ey) over w)/nullif(stddev_samp(ey) over w,0::numeric) as z_ey,
    (cx-avg(cx) over w)/nullif(stddev_samp(cx) over w,0::numeric) as z_cx,
    (cy-avg(cy) over w)/nullif(stddev_samp(cy) over w,0::numeric) as z_cy,
    (vs-avg(vs) over w)/nullif(stddev_samp(vs) over w,0::numeric) as z_vs,
    (ls-avg(ls) over w)/nullif(stddev_samp(ls) over w,0::numeric) as z_ls,
    (ndx-avg(ndx) over w)/nullif(stddev_samp(ndx) over w,0::double precision) as z_ndx,
    (ndy-avg(ndy) over w)/nullif(stddev_samp(ndy) over w,0::double precision) as z_ndy,
    (pl-avg(pl) over w)/nullif(stddev_samp(pl) over w,0::numeric) as z_pl,
    (n_pass::numeric-avg(n_pass) over w)/nullif(stddev_samp(n_pass) over w,0::numeric) as z_np,
    (xt_sum-avg(xt_sum) over w)/nullif(stddev_samp(xt_sum) over w,0::numeric) as z_xt,
    (az-avg(az) over w)/nullif(stddev_samp(az) over w,0::numeric) as z_as,
    league
  from f
  window w as (partition by league);
create unique index seq_fz_pk on public.seq_fz (seq_uid);
create index seq_fz_team on public.seq_fz (team);
grant select on public.seq_fz to anon, authenticated;
