# Publication gating: verifying before data becomes visible

Written 2026-08-24. Summary gating implemented 2026-08-27. An in-place atomic
path was rollback-tested on 2026-08-31, then disabled after its live
availability test exposed read-lock timeouts.

## Implemented summary gate

Migration `20260827203000_gate_summary_publication.sql` removes the summary
refresh from the `insights` step. The existing final `verify` step now runs
`verify_rebuild()` first and refreshes the four browser-facing summary
materialized views only after it passes, in the same transaction. A failure
therefore leaves the previously published summaries untouched. This is a
summary-publication guarantee; full last-known-good versioning of every
analytical matview would still require the wrapper design below.

## Full atomic path: rollback-safe but not production-safe

`rebuild_all_verified()` can wrap every analytical refresh, insights, final
verification and summary publication in a PL/pgSQL subtransaction. A
service-role-only deliberate failure after preflight rolled back its probe
write and recorded a failed run, proving the rollback boundary. A real queued
run executed for 12m49s and correctly rolled back when verification found a
stale current-season invariant. However, a second in-flight smoke test showed
Player and Match API HTTP 500s while ordinary refreshes held read-blocking
locks. That run was canceled and rolled back; the Cron schedule is disabled and
the shipped scraper remains stepwise.

The replacement migration is locally validated but requires separate approval:
22 natural-key unique indexes make all 68 materialized views eligible for
`REFRESH MATERIALIZED VIEW CONCURRENTLY`, and the three refresh functions are
rewritten to use it. On a disposable replay, 68/68 views were concurrent-ready
and a concurrent refresh succeeded inside a transaction. Production activation
must still repeat the in-flight browser smoke before it can be called complete.

## The problem

`verify_rebuild()` raises on any error-level invariant, so the blocking path works. It just runs
in the wrong place. `rebuild_step('insights')` calls `refresh_site_summaries()`, which refreshes
the summaries and commits. `verify` is a separate step in a separate transaction afterwards. By
the time it raises, the figures are already live and nothing rolls back.

This ordering was corrected for the browser-facing summaries on 2026-08-27.

## Why the obvious fix is not available

Wrapping the whole rebuild in one transaction so a failed verify rolls back publication would
work, but it means holding `AccessExclusiveLock` across every matview refresh for the duration of
the rebuild. It also does not survive the pipeline calling steps independently.

Rebuilding into shadow objects and swapping names does not work either: materialized views bind
to sources by OID, so a renamed object is still read by its dependents. That is the same
constraint that forces the destructive migration.

## Recommendation: gate the read, not the write

Add a single row table, `publication_state`, holding the currently published rebuild id and the
verification verdict. The rebuild writes a new id, refreshes as it does today, runs the invariant
battery, and only then marks that id published. If verification fails, the id is never published.

The site does not read the matviews directly. It reads through thin views that check
`publication_state`. When the newest rebuild is unverified, those views serve the last verified
figures and expose a staleness timestamp, which the trust pages already have a slot for.

Properties this gives:

- **No destructive migration.** The gating views are new objects. Nothing existing is dropped.
- **Fails safe.** An unverified rebuild is invisible rather than published.
- **Honest.** The pages already show a refresh timestamp; they would additionally show that the
  latest rebuild failed verification, rather than silently serving it.
- **Cheap.** One table, a handful of views, no change to refresh mechanics or locking.

The cost is that every publicly read object gains a gating wrapper, which is a genuine amount of
plumbing, and stale-but-verified data is served during a failure window. That trade is the right
way round for a portfolio piece aimed at a Sporting Director: showing last week's verified numbers
is defensible, showing this week's unverified ones is not.

## Sequencing

This should land **after** the destructive cup-isolation rebuild, not before. Building gating
wrappers over objects that are about to be dropped and recreated doubles the work.


---

## Live state, 2026-08-24

Historical note: summary publication was ungated at this point. It is gated as
described above as of 2026-08-27.

`refresh_site_summaries()` is no longer callable by `anon` or `authenticated`, so an anonymous
visitor can no longer trigger a refresh. That closes the abuse path but does not change the
ordering problem.

## Execution and rollback procedure for the destructive migration

1. Run `capture_dependency_manifest.sql` and save the output. The tree has grown at every
   recapture, so a stale capture is the main risk.
2. Write the migration from that capture, literal definitions only, no CASCADE.
3. Time it on an isolated database carrying representative production-volume data. A standard
   Supabase preview branch is data-less, so it can prove schema compatibility but not rebuild
   timing or production-volume lock behaviour.
4. Execute inside one transaction with an explicit `statement_timeout`, with preflight dependency
   assertions, raw-data conservation assertions against a baseline captured in the same
   transaction, and `verify_rebuild()` before `commit`.
5. Rollback is automatic on any assertion failure. Recovery after a successful but wrong run is
   the harder case: Supabase migration history is the only route, so a reverse migration should
   be written before execution, not after.
6. Raise the four scoping invariants from warn to error only after the rebuilt objects satisfy
   them, inside the same migration.


## Branch test result, 2026-08-27

The temporary branch was created, reached `ACTIVE_HEALTHY`, tested, and deleted immediately after
the failure was captured. Production was not touched.

The test stopped before cup-isolation generation. The branch did not contain the current Stage 2/3
baseline: `run_invariants()`, `leagues`, `detector_requirements`, `mv_team_league`, and
`v_team_sample` were absent. Applying migration 00 rolled back with PostgreSQL error `42883`:
`function run_invariants() does not exist`. This proves the repository migration history is not
currently sufficient to recreate production on a fresh Supabase branch.

The next valid branch test has two prerequisites:

1. Establish a canonical `supabase/migrations` baseline from the current production schema and
   prove it with `supabase db reset` on an empty local database.
2. For timing, load a sanitized dataset with representative event, match, sequence, and lineup
   volumes. A data-less preview branch cannot measure the 36-object rebuild.

After those prerequisites, generate forward and reverse from the same untouched catalog, validate
both, execute forward with timing, assert the promoted invariants, execute reverse, and compare the
exact captured baseline. Delete the branch when complete.

If the forward transaction exceeds roughly ten minutes, split the refresh out of the transaction
and gate publication instead, per the design above, rather than holding locks longer.

## Rollback on production

Rollback during the run is automatic: any assertion raises and the transaction rolls back with
nothing applied. Rollback after a successful but unwanted run is the generated reverse migration,
which restores every object to its captured pre-migration definition. Generate and commit the
reverse file **before** running the forward one, since it is built from the live catalog as it
stands beforehand.
