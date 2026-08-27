create index if not exists idx_events_qualifiers_gin on public.events using gin (qualifiers jsonb_path_ops);
