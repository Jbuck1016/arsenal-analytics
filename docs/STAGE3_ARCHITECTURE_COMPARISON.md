# Stage 3 cup isolation: two architectures compared

Prepared 2026-08-24. Updated 2026-08-24 after Plan B was approved and the non-destructive
portion was executed. See section 7 for corrected facts and current state.

---

## 0. Two findings that change the comparison

**The MLS fallback is in six objects, not five.** `mv_player_percentiles` also carries
`coalesce(..., 'USA-MLS')`. It sits in the player percentile stack, which was outside the
blast radius two reviews ago. Full list: `mv_player_percentiles`, `mv_team_breakdown`,
`mv_team_directness_state`, `mv_team_percentiles`, `mv_team_stat_ranks`, `v_team_directory`.

**`mv_team_lanes` feeds `mv_team_all` and is not in the 35-object tree.** It is upstream, not
downstream, so it never appears as a dependent, but it aggregates from raw events with no
competition predicate and its values flow into `mv_team_all`. Any plan that filters only the
dependency tree misses it. This is the specific reason a dependency-tree-driven fix is not
sufficient on its own: contamination enters from sources the tree does not enumerate.

---

## 1. The actual contamination surface

Eleven objects read `events`, `matches` or `sequences` directly with no competition predicate:

| Object | events | matches | sequences |
|---|---|---|---|
| `mv_game_goals` | Y | | |
| `mv_team_match` | Y | | |
| `mv_team_league` | Y | | |
| `mv_team_zones` | Y | | |
| `mv_team_attackphase` | Y | | |
| `mv_team_buildphase` | Y | | |
| `mv_team_lanes` | Y | | |
| `mv_state_segments` | Y | | |
| `v_season_stats` | Y | Y | |
| `mv_squad_role` | Y | Y | |
| `mv_league_summary` | Y | | Y |
| `mv_league_availability` | Y | | |

Everything else inherits contamination through these. That is the useful number: **twelve entry
points**, not thirty-five.

Aggregation chain for team metrics:

```
events ─┬─ mv_team_match ── mv_team_season ─┐
        ├─ mv_team_attackphase ─────────────┤
        ├─ mv_team_buildphase ──────────────┼── mv_team_all ─┬─ mv_team_percentiles
        ├─ mv_team_buildup ─────────────────┤                └─ v_team_directory
        ├─ mv_team_lanes ───────────────────┘
        └─ v_season_stats (+ matches) ─── mv_team_stat_ranks
```

---

## 2. Plan A: relocate cup rows to the legacy `*_cup` tables

### 2.1 Destination for the 5,076 sequences

**`sequences_cup` does not exist.** It would have to be created with all 50 columns of
`sequences`, plus its indexes and the `seq_uid` generation logic. `build_sequences()` writes to
`sequences` only, so a parallel builder or a parameterised rewrite is also required.

### 2.2 Schema work required on every cup table

| Table | Current shape | Work needed |
|---|---|---|
| `matches_cup` | `game_id, season, competition, date, home_team, away_team, home_score, away_score, matchday, venue, stage` | Uses `competition` and `stage`, not `league`. Either add `league` and dual-maintain, or migrate the 4 existing rows to `league` and drop `competition`. |
| `events_cup` | 24 columns, no `league` | Add `league`, backfill, index. Predates the multi-league retrofit. |
| `lineups_cup` | 7 columns, no `league` | Add `league`, backfill. |
| `team_names_cup` | has `league` | Needs the same `(league, event_name)` key fix already applied to `team_names`. |
| `sequences_cup` | does not exist | Create: 50 columns, indexes, builder function. |

Grants, owners and constraints would need establishing on all of them, since none currently
carry the corrected privilege model.

### 2.3 Coexistence with the 4 existing Leagues Cup rows

`matches_cup` holds 4 rows, all `competition = 'USA-Leagues Cup'`. `events_cup`, `lineups_cup`
and `team_names_cup` are **empty**. WhoScored publishes no event data for Leagues Cup, confirmed
twice, so these tables have never held events and have never been exercised end to end.

They therefore use a different vocabulary (`competition`) from a fixture set that never produced
events, and would now receive 30,436 events keyed on `league`. Reconciling those two naming
schemes is a prerequisite, not a detail.

### 2.4 Conservation and integrity checks

Per table, by primary key and by total:

- `matches` + `matches_cup` = 425 rows, no `game_id` in both, no `game_id` in neither.
- `events` + `events_cup` = 620,306, keyed on `(game_id, ws_id)`.
- `lineups` + `lineups_cup` = 16,366.
- `sequences` + `sequences_cup` = 103,129, keyed on `seq_uid`.
- `team_names` + `team_names_cup` = 103 mappings.
- No event whose `game_id` is absent from the matching fixture table (orphan check, both sides).
- No `game_id` present in both `matches` and `matches_cup` (duplicate check).

### 2.5 Rollback and recovery

Single transaction: insert into destination, delete from source, assert conservation, commit.
Rollback is automatic on assertion failure. Recovery after a *successful* but wrong migration is
the harder case and needs a reverse migration written and tested in advance, because the source
rows are gone.

### 2.6 Scraper routing and deployment order

**Routing must land and be verified before any cleanup.** Otherwise the next scheduled scrape at
Saturday 23:30 re-inserts all 22 fixtures into the main tables and the cleanup silently undoes
itself.

Order: (1) add `league` to cup tables, create `sequences_cup`; (2) change the scraper to route by
`competition_type` and deploy; (3) run one scrape and confirm zero cup rows land in main tables;
(4) only then relocate the existing 22 fixtures.

I do not have the pipeline files, so I cannot specify the routing change.

### 2.7 Repeated-scrape test

Run the scraper twice against a fixture list containing a known cup match. Assert after each run
that `select count(*) from events e join leagues l on l.league = e.league where
l.competition_type <> 'league'` is zero, and that the cup tables grew by the expected amount.

### 2.8 Cup and Champions League analytics later

This is where Plan A is weakest. Every metric object would need a cup-side twin reading the
`*_cup` tables: a second `mv_team_match`, a second sequence builder, a second percentile stack.
That is a duplicated pipeline, and the two copies would drift.

---

## 3. Plan B: unified raw tables, competition-scoped marts

### 3.1 Shape

Raw tables keep every competition. Introduce three filtered views as the only permitted entry
point for league-scoped analytics:

```sql
create view v_league_events    as select e.* from events e
  join leagues l on l.league = e.league and l.competition_type = 'league';
create view v_league_matches   as ...
create view v_league_sequences as ...
```

Repoint the twelve raw-reading objects at these. Their edits are one-line `FROM` swaps.
Everything downstream is recreated byte-identical.

### 3.2 Does filtering the smallest common roots reduce semantic edits?

Yes, substantially, and this directly answers the question asked.

- Filtering at the twelve entry points means **twelve semantic edits**, each a `FROM` swap.
- The six `coalesce(..., 'USA-MLS')` removals are separate and still required, because a silent
  fallback is a defect regardless of whether it is currently reachable.
- `mv_team_league` still needs its `min(league)` replaced, because alphabetical resolution is
  wrong on its own terms even when only leagues are present.
- `mv_game_goals` still needs `period is distinct from 5`, because shootout goals are not goals
  in the cup mart either.

So roughly **twenty semantic edits** rather than thirty-five, and the remaining objects are pure
recreations carrying no review burden beyond confirming they are unchanged.

It does **not** reduce the recreation count. Every downstream matview still has to be dropped and
rebuilt, because PostgreSQL has no `create or replace materialized view`. Operationally the two
plans have the same rebuild cost; Plan B has less semantic surface to get wrong.

### 3.3 Transaction, locking, rollback

One transaction, `statement_timeout` raised, `AccessExclusiveLock` on each object as it is
dropped and recreated. The site is read-only from the browser and has no concurrent writers, so
the practical exposure is a read outage for the duration. Rollback is automatic on any assertion
failure; nothing is left half-applied.

Estimated duration is dominated by `mv_seq_state` over 103,129 sequences and `build_insights()`.
I would measure it on a branch before running it on production rather than guess here.

### 3.4 Permanent invariants

Two, and the first is the important one because it is structural rather than value-based:

**`league_mart_reads_filtered_sources`**, error level. Uses `pg_depend` to assert that no object
in the league mart depends directly on `events`, `matches` or `sequences`. This makes the
architecture self-enforcing: a future object that reads raw tables fails the rebuild rather than
silently pooling competitions. It would also have caught `mv_team_lanes`.

**`no_cross_competition_inputs`**, error level. Asserts that no contributing match in any
league-scoped object comes from a competition other than the club's resolved league, by checking
that every `(team, game_id)` pair reachable in the mart belongs to a fixture whose league matches
`mv_team_league`.

Plus `team_league_resolves`, already drafted, covering unresolved and misresolved clubs.

### 3.5 Future cross-competition analysis

Preserved by construction. The raw tables hold every competition together, so a cup mart, a
continental mart, or a cross-competition comparison is a new set of views over the same source
rather than a second pipeline. This is the standard warehouse shape: conform the raw layer, scope
the marts.

---

## 4. Champions League is not a domestic cup

The current `competition_type` of `league` or `cup` is too coarse, and this matters analytically.

**Domestic cups** (FA Cup, League Cup) draw from the same national pyramid. Arsenal's opponents
across those 10 fixtures include Mansfield, Port Vale and Wigan. Pooling those into Premier
League metrics inflates Arsenal against lower-tier opposition. The right treatment is exclusion
from league metrics, with optional separate cup analysis.

**The Champions League** is different in kind. Its 11 fixtures involve Bayern, Inter, Leverkusen,
Atletico, Olympiacos, Sporting, Club Brugge, Slavia Prague, Athletic Club and Kairat Almaty:
clubs from other domestic leagues, none of which appear in the league population. Pooling it into
Premier League metrics is equally wrong, but discarding it throws away something the platform
does not otherwise have.

The parked league-strength bridge in the backlog needs multi-season transfers precisely because
there is no common-opponent data across leagues. Continental competition **is** common-opponent
data. Twelve fixtures is far too few to bridge anything today, but it is the seed of the only
non-transfer route to cross-league calibration, and it accumulates every season.

Recommendation: `competition_type in ('league', 'domestic_cup', 'continental')`. League-scoped
analytics filters on `'league'` exactly as before, so nothing in either plan changes. The
distinction costs one migration now and preserves an option that is expensive to reconstruct
later.

---

## 5. Recommendation

**Plan B.** I argued for relocation last round on risk grounds and that was the wrong basis.

The `*_cup` tables are evidence of an earlier single-competition design, not a validated
architecture. They have never held an event row, they predate the `league` column, they have no
sequence equivalent, and using them commits the project to maintaining two parallel pipelines
that will drift. Relocation also leaves `min(league)`, the six MLS fallbacks and the shootout
rule dormant rather than fixed, so the classification defects survive and resurface the first
time a club appears in two league competitions.

The thirty-five object rebuild is an operational cost paid once. The duplicated pipeline is a
cost paid continuously.

Two caveats I hold to. The rebuild should be timed on a branch before it runs on production, not
estimated. And `mv_team_lanes` proves the dependency tree is not a complete enumeration of
contamination sources, so the structural invariant in 3.4 is not optional polish; it is the thing
that makes this fix hold.

---

## 6. In scope regardless of route

The privilege corrections are independent of the architecture and should land in migrations 01
and 02 either way:

- `revoke all on <object> from public, anon, authenticated`
- `grant select on <object> to anon, authenticated`
- administrative privileges to `service_role` only
- `revoke execute on function refresh_site_summaries() from public, anon, authenticated`,
  then `grant execute` to `service_role`
- a test proving anonymous reads succeed while anonymous writes and RPC refresh calls fail

Migrations 01 and 02 also need `begin`/`commit`, raising assertions instead of printed results,
and a definition check that aborts when an existing prerequisite object differs from expectation
rather than accepting it via `if not exists`.


---

## 7. Corrected facts and current state (added after execution)

### 7.1 Numbers corrected

| Fact | Earlier statement | Correct |
|---|---|---|
| Audited league-mart entry objects | "twelve" | **20 registered, 18 initially reading raw sources** |
| Schema objects reading raw tables | not measured | **51** |
| Destructive closure | 35 | **42** |
| Silent MLS fallbacks | five | **six** (`mv_player_percentiles` included) |

### 7.2 What was executed, non-destructively

Migrations 00 through 06. No materialized view was dropped. No raw row was written.

- Privilege lockdown: browser-writable objects **122 to 0**, readable held at 126.
- Three-way classification: `league`, `domestic_cup`, `continental`.
- Canonical scoped sources: `v_league_events`, `v_league_matches`, `v_league_sequences`,
  `v_league_lineups`.
- `v_team_sample` and `v_seq_directness` rescoped in place via `create or replace view`, which
  needs no drop. Arsenal now resolves to `ENG-Premier League` and cup-only clubs left the
  evidence base.
- Insight eligibility made rebuild-safe inside `suppress_low_sample_insights()`.

### 7.3 Contamination still measured (warn level)

| Invariant | Violations |
|---|---|
| `league_mart_reads_scoped_sources` | 16 |
| `no_non_league_fixture_in_metrics` | 42 |
| `no_non_league_row_in_league_outputs` | 198 |
| `goals_reconcile` (error) | 1 |

These are warn rather than error on purpose. The contamination is real and reported honestly, but
raising them before the destructive rebuild lands would abort every scheduled scrape.

### 7.4 Why the destructive rebuild remains deferred

Three reasons, in order of weight.

**The rebuild path is unmeasured.** Timing it needs a disposable branch, which is a billable
action and outside the authorised scope. Running a 42-object destructive transaction on a live
site with no measured duration is the operation that destroyed the metric stack once already.

**The scope premise changed under it.** The work was scoped to twelve entry objects. Recapture
found 20 audited entries, 51 schema objects reading raw tables, and a 42-object closure.

**Most of the value was available without it.** The security exposure, the competition registry,
the scoped sources, the corrected evidence base and rebuild-safe suppression all landed without
dropping anything. What remains is the metric *values*, not the metric *scoping*.

### 7.5 Defects discovered during execution

- **Live security exposure.** 17 base tables including `sequences`, `insights`, `invariants` and
  `team_names` had RLS disabled while granting `anon` INSERT and DELETE. The anon key ships in
  frontend JavaScript. `anon` could also call `refresh_analytics()`. Both closed.
- **`suppress_low_sample_insights()` inner-join bug.** It deleted `using v_team_sample`, so a club
  absent from the evidence base matched nothing and survived. Cup-only clubs kept insights through
  a full rebuild.
- **Season pooling.** `season` exists only on `matches`. `events` and `sequences` have no season
  column, so every object aggregating from them pools 2025/26 with 2026/27. Arsenal's Premier
  League evidence base is 35 matches from 2526 plus 1 from 2627.
- **Goalkeepers absent from `player_search`.** `player_chain_roles` is outfield-only, so David
  Raya (2,098 events, 4,342 minutes) and Kepa are missing from Arsenal's player list.


---

## 8. Live state after the 2026-08-24 batch

### 8.1 Migrations applied live

`00` through `08`. No materialized view dropped. No raw row written.

Raw tables unchanged throughout: 620,306 events, 425 matches, 103,129 sequences, 16,366 lineups.

### 8.2 Insight eligibility is now detector governed

`suppress_low_sample_insights()` compares `ts.matches >= r.min_matches` per detector and no
longer references `meets_min_matches`. Proven from `pg_get_functiondef`. A full production
rebuild through `build_insights()` then `polish_insights()` returns **916 insights across 31
clubs**, with assertions confirming no insight belongs to a club absent from the scoped evidence
base and none comes from an undeclared detector.

### 8.3 Invariants: direct run versus materialized

Every check agrees between `run_invariants()` and `mv_invariant_status`.

| Check | Severity | Violations |
|---|---|---|
| `goals_reconcile` | error | 1 |
| `league_mart_reads_scoped_sources` | warn | 16 |
| `no_non_league_row_in_league_outputs` | warn | 198 |
| `unused_subs_carry_minutes` | warn | 564 |
| `no_non_league_fixture_in_metrics` | warn | 42 |
| `shots_in_xg_model` | warn | 36 |
| `xg_bins_sparse` | warn | 18 |
| `played_without_events` | warn | 3 |
| `leagues_without_whitelist` | warn | 1 |

### 8.4 Security advisor

**New findings introduced by Stage 3, all fixed.** The five scoped views defaulted to
SECURITY DEFINER semantics and now carry `security_invoker = true`.

**Pre-existing, not addressed.** Roughly thirty older views carry the same SECURITY DEFINER
finding. Fifteen base tables have RLS disabled while exposed to PostgREST; browser write
privileges are revoked so the immediate risk is closed, but RLS with explicit read policies is
the belt-and-braces fix. Around eighty materialized views are selectable over the Data API.
`get_starter_names` is anon executable and likely used by the dashboard. The `lafc_*` tracker
functions are anon executable by design and were deliberately left alone.

### 8.5 Destructive migration: recaptured blast radius

The tree has grown at every recapture: 18 dependents, then 23, now **36 distinct objects** across
five levels once `mv_team_all`, `v_season_stats`, `mv_team_match` and `mv_team_lanes` are seeded.

It remains unwritten and unexecuted. Writing 36 literal definitions by hand carries more
transcription risk than the fix removes, and the rebuild path is still untimed. Use
`capture_dependency_manifest.sql` to produce a verified capture first.
