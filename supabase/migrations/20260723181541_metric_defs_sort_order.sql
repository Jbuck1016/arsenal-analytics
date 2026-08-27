alter table public.metric_defs add column if not exists sort_order int;
alter table public.metric_defs add column if not exists grp_order int;

update public.metric_defs set grp_order = case grp
  when 'Passing' then 1 when 'Creation' then 2 when 'Shooting' then 3
  when 'Carrying' then 4 when 'Defending' then 5 when 'Discipline' then 6 else 9 end;

update public.metric_defs set sort_order = v.ord from (values
 ('pass_cmp_90',1),('pass_pct',2),('prog_cmp_90',3),('prog_pct',4),('territory_90',5),
 ('into_box_90',6),('final_third_90',7),('through_90',8),('cross_90',9),('cross_pct',10),
 ('long_90',11),('long_pct',12),
 ('key_pass_90',1),('assist_90',2),('bcc_90',3),
 ('shots_90',1),('sot_90',2),('goals_90',3),('box_share',4),('shot_dist',5),
 ('conversion',6),('shot_acc',7),('bigchance_90',8),('weak_foot_share',9),
 ('takeon_90',1),('takeon_pct',2),('disp_90',3),('badtouch_90',4),
 ('tackle_90',1),('tackle_pct',2),('int_90',3),('clear_90',4),('block_90',5),
 ('recov_90',6),('aerial_90',7),('aerial_pct',8),('def_action_90',9),('def_height',10),
 ('foul_com_90',1),('foul_won_90',2),('error_90',3)
) as v(k,ord) where metric_defs.key = v.k;
