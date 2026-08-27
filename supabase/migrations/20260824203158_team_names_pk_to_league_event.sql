alter table team_names drop constraint team_names_pkey;
alter table team_names add constraint team_names_pkey primary key (league, event_name);

select conname, pg_get_constraintdef(oid) as def
from pg_constraint where conrelid = 'public.team_names'::regclass and contype = 'p';
