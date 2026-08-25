# Publication gating: verifying before data becomes visible

Written 2026-08-24. Design note only. No migration attached.

## The problem

`verify_rebuild()` raises on any error-level invariant, so the blocking path works. It just runs
in the wrong place. `rebuild_step('insights')` calls `refresh_site_summaries()`, which refreshes
the summaries and commits. `verify` is a separate step in a separate transaction afterwards. By
the time it raises, the figures are already live and nothing rolls back.

That is why the Methodology page now states plainly that verification does not gate publication.

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
