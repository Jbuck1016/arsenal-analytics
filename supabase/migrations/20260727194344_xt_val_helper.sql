
create or replace function public.xt_val(px double precision, py double precision)
returns numeric language sql immutable as $$
  select v from public.xt_grid
  where x_bin = least(15, greatest(0, floor(px/100.0*16)::int))
    and y_bin = least(5, greatest(0, floor(py/100.0*6)::int));
$$;
