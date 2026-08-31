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

The exact history is intentionally preserved even though an empty replay now
reproduces its historical cascade defect. Do not edit those 192 files to make
the replay green. The canonical replacement is generated from the production
catalog into `baseline/20260831_public_schema.sql`; that generated file is tested independently
on an empty disposable PostgreSQL database.

Run `pipeline/tools/check_supabase_migration_snapshot.py` for the frozen-history
hashes and the exact current count of later repository-authored migrations;
the checker, not a prose count in this README, is canonical.
