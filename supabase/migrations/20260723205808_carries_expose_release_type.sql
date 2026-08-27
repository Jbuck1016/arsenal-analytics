create or replace view v_player_carries as
select player_id, game_id, start_x, start_y, end_x, end_y,
       carry_m, is_progressive, into_box, ttr, release_type
from mv_receipt_events
where is_carry;

-- All receipts (not just carries) so release time can be mapped spatially
create or replace view v_player_receipts as
select player_id, game_id, start_x, start_y, end_x, end_y, ttr, release_type, is_carry
from mv_receipt_events;

grant select on v_player_carries, v_player_receipts to anon, authenticated;
notify pgrst, 'reload schema';
