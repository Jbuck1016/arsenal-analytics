# Publication gating: verifying before data becomes visible

Written 2026-08-24. Summary gating implemented 2026-08-27. The full atomic
path was made non-blocking and production-verified on 2026-08-31.

## Original summary gate

Migration `20260827203000_gate_summary_publication.sql` removes the summary
refresh from the `insights` step. The existing final `verify` step now runs
`verify_rebuild()` first and refreshes the four browser-facing summary
materialized views only after it passes, in the same transaction. A failure
therefore leaves the previously published summaries untouched. This was the
first publication guarantee. The full atomic path below now supersedes it and
keeps every analytical materialized view inside the same verified transaction.

## Full atomic path: rollback-safe and production-verified

`rebuild_all_verified()` wraps every analytical refresh, insights, final
verification and summary publication in one rollback-safe transaction. A
service-role-only deliberate failure after preflight rolled back its probe
write and recorded a failed run, proving the rollback boundary. A real queued
blocking run executed for 12m49s and correctly rolled back when verification
found a stale current-season invariant. A second blocking run was canceled
after Player and Match returned HTTP 500s while ordinary refreshes held read
locks.

Migration `20260831233000_enable_nonblocking_atomic_refresh.sql` adds 22
natural-key unique indexes, making all 68 materialized views eligible for
`REFRESH MATERIALIZED VIEW CONCURRENTLY`, and rewrites the three refresh
functions to use it. Its disposable replay passed before activation. The first
production run, `7218a44b-f06a-4b68-ac68-473b351af435`, committed all 19 steps
through `verify` in 15m31.8s. Validation, Methodology, Player, Team, Match,
Insights and Sequences all returned HTTP 200 and reached ready state in repeated
probes during the transaction and again after commit. Every error-level
invariant was zero; the only non-zero result was the documented
`xg_bins_sparse = 18` warning. The once-per-minute worker is active and remains
service-role-only.

## Historical problem

`verify_rebuild()` raises on any error-level invariant, so the blocking path works. It just runs
in the wrong place. `rebuild_step('insights')` calls `refresh_site_summaries()`, which refreshes
the summaries and commits. `verify` is a separate step in a separate transaction afterwards. By
the time it raises, the figures are already live and nothing rolls back.

This ordering was corrected for browser-facing summaries on 2026-08-27 and for
the full analytical rebuild on 2026-08-31.

## Why the first atomic implementation was rejected

Wrapping the whole rebuild in one transaction with ordinary refreshes did roll
back correctly, but held read-blocking locks across the rebuild. Concurrent
refreshes preserve the same transactional rollback boundary without making the
existing materialized view unavailable to readers.

Rebuilding into shadow objects and swapping names does not work either: materialized views bind
to sources by OID, so a renamed object is still read by its dependents. That is the same
constraint that forces the destructive migration.

## Earlier alternative: gate the read, not the write

The following wrapper design was proposed before the concurrent atomic path was
proven. It is retained as design history, not as open release work.

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

## Historical sequencing note

The read-wrapper option was intentionally deferred until after cup isolation.
The concurrent atomic implementation made those wrappers unnecessary.


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
