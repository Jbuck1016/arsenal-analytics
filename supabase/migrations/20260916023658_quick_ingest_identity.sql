begin;

alter table public.writing_lab_projects
  add column if not exists canonical_game_id text;

create index if not exists writing_lab_projects_canonical_game_idx
  on public.writing_lab_projects (canonical_game_id)
  where canonical_game_id is not null;

comment on column public.writing_lab_projects.game_id is
  'WhoScored source match id parsed from the submitted URL.';
comment on column public.writing_lab_projects.canonical_game_id is
  'Published match id. Modeled leagues reconcile to the scheduled provider fixture id; isolated competitions retain the source id.';

commit;
