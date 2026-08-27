update public.team_metric_defs set grp='Build-up phase'   where grp='Build-up';
update public.team_metric_defs set grp='Attacking phase', grp_order=4 where grp='Attack';
update public.team_metric_defs set grp='Output',          grp_order=5 where grp='Attacking';
update public.team_metric_defs set grp='Possession shape',grp_order=6 where grp='Possession';
update public.team_metric_defs set grp_order=7 where grp='Defending';
update public.team_metric_defs set grp_order=8 where grp='Channels';
select grp, grp_order, count(*) from public.team_metric_defs group by grp, grp_order order by grp_order;
