# Cup-isolation generator and executable test package

Nothing in this directory is a numbered migration. The generator reads a
PostgreSQL catalog and emits forward/reverse SQL; it does not alter the source
database. Do not run either generated migration on production until its exact
production output has separately passed review.

The numbered files in `pipeline/migrations` are deltas from the established
Stage 2 production schema. They are not a complete Supabase project baseline.
On 2026-08-27, a fresh data-less Supabase preview branch lacked
`run_invariants()`, `leagues`, `detector_requirements`, `mv_team_league`, and
`v_team_sample`; migration 00 therefore rolled back at its first dependency on
`run_invariants()`. Adopt a canonical `supabase/migrations` baseline and prove
`supabase db reset` before using preview branches for this package.

## What is enforced

- Topology uses every path across the complete closure, including edges where
  both objects are seeds. Paths are deduplicated only after recursion.
- Reverse preflight expects PostgreSQL-normalized forward definitions while
  retaining original definitions as restoration targets.
- The exact original `mv_game_goals` registry row, four original invariant
  severities, and all `run_invariants()` results are embedded in reverse.
- Reverse never calls `verify_rebuild()`; an intentionally failing baseline is
  restored and compared exactly.
- Owners, normalized ACL entries (including grant option), indexes, comments,
  and reloptions are asserted at runtime after both directions.
- A raw-table CTE name collision aborts generation because regex cannot safely
  resolve CTE scope.

## Production generation

Generate reverse and forward from the same untouched source catalog. `-X -qAt`
is required so psql status lines cannot enter the files.

```text
psql -X -qAt -v direction=reverse -v expect_objects=36 -v expect_matviews=28 -v expect_views=8 -f pipeline/tools/generate_cup_isolation.sql > reverse.sql
psql -X -qAt -v direction=forward -v expect_objects=36 -v expect_matviews=28 -v expect_views=8 -f pipeline/tools/generate_cup_isolation.sql > forward.sql
python pipeline/tools/validate_generated_migration.py forward.sql reverse.sql --objects 36 --matviews 28 --views 8
python pipeline/tools/negative_tests.py forward.sql reverse.sql --objects 36 --matviews 28 --views 8
```

When direct `psql` credentials are unavailable, render the same generator as a
single-result SQL query for the Supabase SQL connector:

```text
python pipeline/tools/render_generator_query.py --direction reverse > reverse-query.sql
python pipeline/tools/render_generator_query.py --direction forward > forward-query.sql
```

The end-to-end harness executes both connector queries against the fixture and
requires their generated migration text to match the native psql generator
byte-for-byte. Generate reverse first from the untouched catalog, then forward.
The reviewed production pair is stored in `pipeline/generated`; never regenerate
reverse after forward has been applied.

`capture_dependency_manifest.sql` provides a human-readable capture using the
same topology algorithm. It is tooling, not a migration.

## End-to-end fixture test

The harness needs PostgreSQL binaries containing `initdb`, `pg_ctl`, `createdb`
and `psql`. It creates three disposable databases, executes generated forward
and reverse SQL, checks exact restoration, tests the CTE refusal path, runs 16
negative validator mutations, and proves example regeneration with
`git diff --exit-code`.

```text
python pipeline/tools/run_fixture_tests.py --pg-bin C:\path\to\pgsql\bin
```

All phase output and exit statuses are written to
`pipeline/tools/fixture/END_TO_END_TEST_RESULTS.txt`.

To intentionally replace stale examples once:

```text
python pipeline/tools/run_fixture_tests.py --pg-bin C:\path\to\pgsql\bin --update-examples
```

The normal run does not update examples. `regenerate_examples.py --check`
deletes both examples, regenerates them from the exact fixture and generator,
then fails if Git reports a difference.

## Dashboard data contracts

The lightweight frontend guard checks the five active dashboard pages for the
silent MLS fallback, verifies the Player directory is built from all
appearances rather than starters, and confirms every Player pitch primitive
shares the inverted WhoScored y-axis transform:

```text
python pipeline/tools/check_dashboard_data_contracts.py
```

## Supabase migration snapshot

The exact production migration history is stored under `supabase/migrations`
and frozen by `supabase/LIVE_HISTORY_MANIFEST.sha256`. Check that none of the
192 captured historical migrations changed, that version numbers remain
unique, and that later repository-authored migrations are canonically named:

```text
python pipeline/tools/check_supabase_migration_snapshot.py
```

This proves repository fidelity to the history recorded by production. It does
not prove that the captured history can recreate the current schema. That
requires `supabase db reset` or an empty preview-branch replay; neither should
be claimed until it has completed successfully.

## Public-view caller-rights hardening

`run_security_invoker_tests.py` executes the public-view hardening migration
against disposable local PostgreSQL clusters. The fixture covers the success
path, exact owner/ACL/comment/reloptions preservation, anonymous reads after
conversion, a missing-dependency-privilege failure, and exact rollback:

```text
python pipeline/tools/run_security_invoker_tests.py --pg-bin C:\path\to\pgsql\bin
```

The harness does not contact Supabase and does not apply the migration to
production.
