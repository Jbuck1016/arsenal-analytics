# Supabase migration history

`migrations/` contains the exact 192 migrations recorded in production's
`supabase_migrations.schema_migrations` table as of 2026-08-27, followed by
new repository-authored migrations.

The production snapshot was fetched read-only and compared against the live
statement body for every version: 192 of 192 filenames and contents matched.
`LIVE_HISTORY_MANIFEST.sha256` freezes that snapshot so historical migrations
cannot be edited silently.

Run the offline integrity check with:

```text
python pipeline/tools/check_supabase_migration_snapshot.py
```

Important limit: this is an exact history capture, not yet proof that the
history recreates the current schema. Docker is unavailable on the capture
host, so `supabase db reset` has not run. The next preview-branch test must
replay this directory against an empty Supabase database before the baseline
is called reproducible.

`20260827180929_harden_existing_public_views.sql` is a new, locally tested
migration. It has not been applied to production.
