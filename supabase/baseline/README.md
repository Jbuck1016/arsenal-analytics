# Canonical schema baseline

The 192 frozen production-history migrations are evidence, not a reset path.
Their empty replay fails because historical `CASCADE` operations remove objects
that later files still reference. Do not edit that history.

The canonical baseline is generated from the current production catalogs:

1. Run `pipeline/tools/capture_canonical_baseline.sql` with an administrative
   database connection. It creates a service-role-only export buffer.
2. Run `python pipeline/tools/download_canonical_baseline.py` to write
   `20260831_public_schema.sql` and its SHA-256 file.
3. Immediately drop `public._schema_baseline_export`.
4. Replay the baseline on an empty disposable PostgreSQL database:

   `python pipeline/tools/test_schema_reset.py --pg-bin <postgres-bin> --python-lib <psycopg-target> --baseline supabase/baseline/20260831_public_schema.sql`

The capture includes public schema definitions, dependency-ordered views,
materialized views, functions, indexes, triggers, RLS, policies, grants,
reloptions, and non-sensitive configuration seeds. It explicitly excludes raw
events, matches, lineups, players, insights, biographies, LAFC tracker content,
and rebuild-run history.
