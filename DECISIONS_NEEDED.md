# Decisions needed

Items an overnight run reached and deliberately did not guess at. Each says
what the options are and what picking one would change, so the decision can be
made quickly and the work finished.

Written during the Phase 2 / 5 / 4 / 6 run on `restyle/global-theme`.

---

## 1. The team profile scatter (Phase 4.5) — not started

**Why it stopped.** The brief put this out of scope tonight, and the reason
holds: the scatter needs a pair of team-level metrics on its axes, and which
pair is a judgement about what the chart is *for*, not a mechanical choice.
The player scatter defaults to progressive carries against key passes, which
is a claim that those two together describe a wide forward. There is no
equivalent claim on the team side that can be read off the code.

**What is needed to build it.**

1. **What is the default pair, and what does it say?** `teams.html` already
   has a League Map defaulting to PPDA against field tilt, and it names the
   quadrants for that pairing only, with a comment saying the names describe
   style rather than quality. Is the profile scatter the same chart scoped to
   one team's league, or a different question?
2. **What is a point?** One team per point, as the League Map does, or one
   match per point for the selected team? Those are different charts. The
   second is the only one that is really a *profile* scatter, and nothing in
   the current code plots a team's matches against each other.
3. **Which metrics may be offered on the axes?** `team_metric_defs` drives the
   League Map's dropdowns. Same list, or a curated subset — and if curated,
   which, and on what grounds?
4. **Does it need a comparison population?** If a point is a match, the
   interesting overlay is usually the league's distribution behind it. That
   is a second data source and a second set of percentile questions.

**Cost once decided:** small. The League Map is a working scatter with axis
selection, highlighting, quadrant labelling and tooltips; a profile variant is
mostly a scope change and a new default pair.

---

## 2. How `pct` is computed in the percentile views

**The situation.** Phase 4.2 makes league selection multi-select and pools the
selection into one population, which means the stored per-league percentile is
the wrong number to show: it says where a player sits among his own countrymen
while the table claims to rank him against everyone on screen. So when more
than one league is selected the percentile is recomputed in the browser.

**What could not be checked.** The definition `mv_player_percentiles` and
`mv_team_percentiles` use. The database was explicitly out of scope for this
run, so the view definitions were not read.

**What was implemented.** The share of the pooled population at or below this
row, times 100, rounded, computed within the role pool for players and across
the whole selection for teams, and inverted for a lower-is-better metric so
the best is always 100. In SQL terms that is `round(100 * cume_dist())`.

**Why it is probably safe as it stands.** It is only ever applied to a pooled
selection. A single league still displays the stored number untouched, so the
two definitions never appear in the same table, and switching from one league
to two is already a change of population that the subtitle announces.

**The decision.** If the views use something else — `percent_rank`, which
gives the *lowest* row 0 rather than the lowest row `1/n`, or `ntile(100)`,
which is a different shape again — then the pooled and single-league views
differ slightly in definition as well as in population.

- **Option A, match the view.** Read the view definition and change
  `repoolPct` in `players.html` and `repoolTeamPct` in `teams.html` to agree.
  One function each, a few lines. This is the obvious answer if the two are
  meant to be the same measure.
- **Option B, always recompute.** Drop the stored `pct` from the display
  entirely and compute it in the browser for every selection, single league
  included. One definition everywhere, at the cost of doing work the database
  has already done, and of the single-league numbers changing.
- **Option C, leave it.** Accept two definitions on the grounds that they
  describe two different populations anyway. Cheapest, and the subtitle
  already tells the reader which population is in play — but it does not tell
  them the *definition* changed too.

Nothing needs to happen for the page to work; this is about whether the two
numbers mean exactly the same thing.

---

## 3. Whether "All leagues" should pool

**What changed.** Before tonight, "All leagues" showed every player with the
percentile computed *within his own league*, so a table could put a 99th
percentile Ligue 1 player above a 95th percentile Premier League player
without ever saying they had been measured against different populations.

Phase 4.2's decided behaviour — percentiles recompute across the combined
selection — makes All a pooled population like any other multi-league
selection. That is consistent, and it is the honest reading of a single
ranked table. It also changes the numbers on the default view.

**The alternative**, if that is not wanted: keep All as it was, per-league,
and pool only when the reader explicitly picks two or more leagues. That
preserves the old default exactly, at the cost of All meaning something
different from every other selection.

Implemented as pooled, because the brief's wording describes pooling as a
property of the selection rather than of a particular control state. Flagged
because it moves numbers on the view most people land on.

---

## 4. Which way ties break when the Rank order is "Lowest first"

Phase 5 needed a total order. The brief specified: active key, then raw metric
value **descending**, then `player_id` ascending.

Descending is unambiguous when the order is Highest first. When the reader has
asked for Lowest first, a secondary key that still sorts descending reads
oddly — the table counts up on the primary and down on the secondary.

**Implemented:** the secondary key follows the same direction as the primary,
so Lowest first is descending on neither. That matches the brief exactly in
the default direction and is internally consistent in the other.

**If the literal reading was intended** — raw value always descending
regardless of the control — it is a one-character change:
`(a[sec]-b[sec])*RK.dir` becomes `(b[sec]-a[sec])`.

---

## 5. `drain_rescrape_queue()` calls `process_match()` with the wrong signature

Found while fixing the heartbeat's event count. It is a real defect in
`pipeline/rescrape_queue.py`, separate from the heartbeat, and it was left
alone because fixing it changes what gets written to the database.

**What is wrong.** `rescrape_queue.py:61` calls:

```python
process_match(game_id, scraper=scraper)
```

`process_match`'s actual signature, in `scrape_and_load.py:396`, is:

```python
def process_match(sb, ws, sched_row, league, season, historical=False) -> tuple[str, int]
```

There is no `scraper` keyword and `game_id` lands in the `sb` slot. Every call
raises `TypeError` immediately, on every fixture, before any fetch is
attempted. The `except Exception` around it catches that, and the run then
reports the fixture as a failure to `record_rescrape_result`.

**Why it matters.** The re-scrape queue holds fixtures whose event feed was
truncated — the ones `mv_match_length` and `mv_player_minutes` mis-scale, and
the reason those per-90s are diluted. Nothing has ever been repaired by this
path. Worse, each run increments `attempts` on up to ten fixtures, and three
failures marks a fixture *exhausted* and raises an alert. `exhausted_game_ids()`
then permanently excludes it from the backfill's to-do list. So the queue has
most likely been converting truncated fixtures into permanently skipped ones
at ten per run, and the alert that fires says the fixture is unfetchable when
in fact it was never fetched.

This is stated from reading the code, not from the database, which was out of
scope. **The database will say whether it actually happened**: the counts in
`rescrape_queue` by status, and whether the recorded errors all read
`TypeError`, settle it in one query.

**The decision.** Three separable questions:

1. **Fix the call?** It needs `sb`, an opened `ws` scraper for that fixture's
   league and season, and the schedule row — none of which the drain currently
   has. It runs before the per-league scrapers are built, so this is a real
   restructure, not a one-line signature fix, and it belongs in its own change
   with its own review.
2. **Unwind the damage?** If fixtures were wrongly marked exhausted, their
   `attempts` and status need resetting or they stay excluded forever. That is
   a data repair, and it touches tables the parallel rebuild may also be on.
3. **Should the drain's events count toward `events_written`?** Once the drain
   actually writes events, it will be writing them inside the heartbeat's
   context and they will not be counted. `scrape_league.py` carries a comment
   at the `hb.record()` call marking this gap. If the answer is yes,
   `drain_rescrape_queue` should return an event total alongside `done`.

**Cost once decided:** 1 is a moderate change to the drain's structure. 2 is a
small, careful data fix that must be sequenced against the parallel `mv_*`
rebuild. 3 is a few lines once 1 lands.
