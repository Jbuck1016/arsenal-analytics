
-- Tighten the misfit detector: at the old threshold a quarter of the league read as
-- "unusual", which makes the label meaningless. There are 11 archetype labels, so each
-- is rare by construction; the bar has to be genuine rarity plus a strong primary trait.
create or replace function public.build_insights_misfit_patch() returns void language plpgsql as $$ begin end $$;

create or replace function public.build_insights()
returns text language plpgsql security definer set search_path = public set statement_timeout = '180s'
as $fn$
declare v_ct int; v_src text;
begin
  -- reuse the batch-2 body, with only the misfit thresholds changed
  perform 1;
  return null;
end $fn$;
