\set ON_ERROR_STOP on

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
end
$roles$;

create table source_data (id int primary key, value numeric);
insert into source_data values (1, 1.5);
grant select on source_data to anon, authenticated;

create function xt_at(px double precision, py double precision)
returns numeric language sql immutable as 'select (px + py)::numeric';
grant execute on function xt_at(double precision,double precision) to anon, authenticated;

create view pcr_z                 as select * from source_data;
create view player_chain_pct      as select * from source_data;
create view team_sequence_agg     as select * from source_data;
create view team_sequence_style   as select * from source_data;
create view v_goal_fix            as select * from source_data;
create view v_league_availability as select * from source_data;
create view v_league_summary      as select * from source_data;
create view v_loaded_games        as select * from source_data;
create view v_player_actions      as select * from source_data;
create view v_player_carries      as select * from source_data;
create view v_player_metrics_ext  as select * from source_data;
create view v_player_pct_all      as select * from source_data;
create view v_player_receipts     as select * from source_data;
create view v_player_sot_fix      as select * from source_data;
create view v_player_xt_actions   as select id, xt_at(value::double precision, value::double precision) value from source_data;
create view v_press_profile       as select * from source_data;
create view v_season_stats        as select * from source_data;
create view v_seq_directness      as select * from source_data;
create view v_squad_role          as select * from source_data;
create view v_team_actions        as select * from source_data;
create view v_team_carries        as select * from source_data;
create view v_team_directory      as select * from source_data;
create view v_team_sample         as select * from source_data;
create view v_team_shots          as select * from source_data;
create view v_team_signature      as select * from source_data;
create view v_xg_model_support    as select * from source_data;

do $grants$
declare r record;
begin
  for r in select table_name from information_schema.views where table_schema='public' loop
    execute format('grant select on public.%I to anon, authenticated', r.table_name);
  end loop;
end
$grants$;

comment on view v_goal_fix is 'metadata preservation sentinel';
alter view v_goal_fix set (security_barrier = true);
