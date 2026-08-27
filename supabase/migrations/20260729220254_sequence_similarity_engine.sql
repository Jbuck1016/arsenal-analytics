
drop materialized view if exists public.seq_fz;
create materialized view public.seq_fz as
with f as (
  select seq_uid, team, game_id, xt_sum, n_pass, ended_shot, end_third, ended_in_box,
    start_x::numeric sx, start_y::numeric sy, end_x::numeric ex, end_y::numeric ey,
    cx, cy, (maxx-minx) vs, (maxy-miny) ls,
    (end_x-start_x) ndx, (end_y-start_y) ndy,
    (coalesce(mean_pass_len,0)*n_pass) pl, att_share az
  from public.sequences where is_open_play
)
select seq_uid, team, game_id, xt_sum, n_pass, ended_shot, end_third, ended_in_box,
  (sx -avg(sx ) over())/nullif(stddev_samp(sx ) over(),0) as z_sx,
  (sy -avg(sy ) over())/nullif(stddev_samp(sy ) over(),0) as z_sy,
  (ex -avg(ex ) over())/nullif(stddev_samp(ex ) over(),0) as z_ex,
  (ey -avg(ey ) over())/nullif(stddev_samp(ey ) over(),0) as z_ey,
  (cx -avg(cx ) over())/nullif(stddev_samp(cx ) over(),0) as z_cx,
  (cy -avg(cy ) over())/nullif(stddev_samp(cy ) over(),0) as z_cy,
  (vs -avg(vs ) over())/nullif(stddev_samp(vs ) over(),0) as z_vs,
  (ls -avg(ls ) over())/nullif(stddev_samp(ls ) over(),0) as z_ls,
  (ndx-avg(ndx) over())/nullif(stddev_samp(ndx) over(),0) as z_ndx,
  (ndy-avg(ndy) over())/nullif(stddev_samp(ndy) over(),0) as z_ndy,
  (pl -avg(pl ) over())/nullif(stddev_samp(pl ) over(),0) as z_pl,
  (n_pass-avg(n_pass) over())/nullif(stddev_samp(n_pass) over(),0) as z_np,
  (xt_sum-avg(xt_sum) over())/nullif(stddev_samp(xt_sum) over(),0) as z_xt,
  (az -avg(az ) over())/nullif(stddev_samp(az ) over(),0) as z_as
from f;

create unique index seq_fz_uid on public.seq_fz (seq_uid);

create or replace function public.similar_sequences(p_seq text, p_n int default 10)
returns table(rank int, seq_uid text, team text, game_id text, n_pass integer,
              xt_sum numeric, ended_shot boolean, dist numeric)
language sql stable as $$
  with q as (select * from public.seq_fz where seq_uid = p_seq)
  select row_number() over (order by d.dist)::int, d.seq_uid, d.team, d.game_id,
         d.n_pass, d.xt_sum, d.ended_shot, round(d.dist::numeric,3)
  from (
    select z.seq_uid, z.team, z.game_id, z.n_pass, z.xt_sum, z.ended_shot,
      sqrt(
        power(z.z_sx-q.z_sx,2)+power(z.z_sy-q.z_sy,2)+power(z.z_ex-q.z_ex,2)+power(z.z_ey-q.z_ey,2)
       +power(z.z_cx-q.z_cx,2)+power(z.z_cy-q.z_cy,2)+power(z.z_vs-q.z_vs,2)+power(z.z_ls-q.z_ls,2)
       +power(z.z_ndx-q.z_ndx,2)+power(z.z_ndy-q.z_ndy,2)+power(z.z_pl-q.z_pl,2)+power(z.z_np-q.z_np,2)
       +power(z.z_xt-q.z_xt,2)+power(z.z_as-q.z_as,2)
      ) as dist
    from public.seq_fz z, q
    where z.seq_uid <> q.seq_uid and z.game_id <> q.game_id
  ) d
  order by d.dist limit p_n;
$$;
