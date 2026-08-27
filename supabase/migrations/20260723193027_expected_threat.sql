-- Expected Threat grid (12 x 8), matching the grid already used in the dashboard
-- front end so server-side and client-side xT agree.
create table if not exists public.xt_grid (
  x_bin int not null, y_bin int not null, v numeric not null,
  primary key (x_bin, y_bin)
);
truncate public.xt_grid;
insert into public.xt_grid (x_bin,y_bin,v) values
(0,0,.000),(0,1,.000),(0,2,.000),(0,3,.000),(0,4,.000),(0,5,.000),(0,6,.000),(0,7,.000),
(1,0,.001),(1,1,.001),(1,2,.001),(1,3,.002),(1,4,.002),(1,5,.001),(1,6,.001),(1,7,.001),
(2,0,.002),(2,1,.003),(2,2,.004),(2,3,.005),(2,4,.005),(2,5,.004),(2,6,.003),(2,7,.002),
(3,0,.004),(3,1,.006),(3,2,.008),(3,3,.011),(3,4,.011),(3,5,.008),(3,6,.006),(3,7,.004),
(4,0,.006),(4,1,.009),(4,2,.014),(4,3,.019),(4,4,.019),(4,5,.014),(4,6,.009),(4,7,.006),
(5,0,.010),(5,1,.015),(5,2,.022),(5,3,.030),(5,4,.030),(5,5,.022),(5,6,.015),(5,7,.010),
(6,0,.016),(6,1,.024),(6,2,.035),(6,3,.048),(6,4,.048),(6,5,.035),(6,6,.024),(6,7,.016),
(7,0,.025),(7,1,.037),(7,2,.054),(7,3,.075),(7,4,.075),(7,5,.054),(7,6,.037),(7,7,.025),
(8,0,.038),(8,1,.056),(8,2,.082),(8,3,.115),(8,4,.115),(8,5,.082),(8,6,.056),(8,7,.038),
(9,0,.055),(9,1,.082),(9,2,.122),(9,3,.170),(9,4,.170),(9,5,.122),(9,6,.082),(9,7,.055),
(10,0,.082),(10,1,.120),(10,2,.178),(10,3,.250),(10,4,.250),(10,5,.178),(10,6,.120),(10,7,.082),
(11,0,.120),(11,1,.180),(11,2,.270),(11,3,.390),(11,4,.390),(11,5,.270),(11,6,.180),(11,7,.120);

create or replace function xt_at(px double precision, py double precision)
returns numeric language sql immutable as $$
  select v from public.xt_grid
  where x_bin = least(11, greatest(0, floor(px/100*12)::int))
    and y_bin = least(7,  greatest(0, floor(py/100*8)::int));
$$;

-- xT added by successful passes and by carries
create materialized view mv_player_xt as
with pass_xt as (
  select player_id,
    sum(xt_at(end_x,end_y) - xt_at(x,y)) as xt_pass,
    sum(greatest(xt_at(end_x,end_y) - xt_at(x,y),0)) as xt_pass_pos
  from public.events
  where type='Pass' and outcome_type='Successful' and is_open_play
    and x is not null and y is not null and end_x is not null and end_y is not null
  group by player_id
),
carry_xt as (
  select player_id,
    sum(xt_at(end_x,end_y) - xt_at(start_x,start_y)) as xt_carry,
    sum(greatest(xt_at(end_x,end_y) - xt_at(start_x,start_y),0)) as xt_carry_pos
  from mv_receipt_events
  where is_carry
  group by player_id
)
select
  coalesce(p.player_id, c.player_id) as player_id,
  coalesce(p.xt_pass,0)      as xt_pass,
  coalesce(c.xt_carry,0)     as xt_carry,
  coalesce(p.xt_pass,0) + coalesce(c.xt_carry,0) as xt_total,
  coalesce(p.xt_pass_pos,0) + coalesce(c.xt_carry_pos,0) as xt_positive
from pass_xt p
full outer join carry_xt c on c.player_id = p.player_id;
create unique index on mv_player_xt (player_id);

grant select on public.xt_grid, mv_player_xt to anon, authenticated;
