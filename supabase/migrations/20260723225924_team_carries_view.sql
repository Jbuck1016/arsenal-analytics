create or replace view v_team_carries as
select team, start_x, start_y, end_x, end_y, carry_m, is_progressive, into_box
from mv_receipt_events where is_carry;
grant select on v_team_carries to anon, authenticated;
notify pgrst, 'reload schema';
