# Overnight run — Phases 2, 5, 4, 6 and the scraper heartbeat

Branch `restyle/global-theme`. Everything below is committed and pushed.
Phase 3 was not started.

## Where the tree was on resume

This report covers two sessions. The first was interrupted by a machine
restart; the second resumed against the repo rather than the brief and found
**all four restyle phases already committed**:

```
0315a02 docs: overnight run report
d082fa1 test: contrast, separability, contact sheet, colour lint   Phase 6
3078fa1 feat: league multi-select, position filter, exports        Phase 4
4b9dfdd fix: total stable sort order on rank                       Phase 5
3da72f0 feat: one global theme switch across every surface         Phase 2
```

`python restyle/check.py` passed all four gates at `0315a02` before anything
was touched, so nothing had been left half-applied by the restart. The
restyle phases were therefore skipped, not redone. The only outstanding item
in the brief was the scraper heartbeat, which had not been started: nothing in
the tree or the report mentioned it.

The second session added exactly one commit, `706834d`, plus this section and
item 5 in `DECISIONS_NEEDED.md`.

Four static gates, three browser verifiers and a fifteen-page smoke test all
pass at the final commit.

```
python restyle/check.py                  # 4 gates, no browser, belongs in CI
python restyle/verify_resolver.py        # 8,580 resolutions vs Chrome
python restyle/verify_canvas_bridge.py   # match.html's runtime palette
python restyle/run_bridge_probe.py       # the canvas bridge mechanism
```

---

## What landed

### Phase 2 — one global theme switch · `3da72f0`

Sixteen pages each shipped their own control in two dialects that disagreed
about what the absence of a stored preference meant. Nine removed `.dark` if
`'light'` was stored and relied on the markup carrying the class; six added
`.dark` unless `'light'` was stored. Both defaulted to dark, none read
`prefers-color-scheme`, and each page repainted its own glyph with its own
copy of the same three lines.

`dashboard/theme.js` is now the only thing that decides, in this order: a URL
`?theme=` that does **not** persist (model-lab already relied on it, and the
contact sheet now does too); then an explicit stored choice, which wins
forever, including over a later change to the system setting; then
`prefers-color-scheme`, which decides the first visit only and is followed
live until the reader picks something.

It is a classic `<script src>` placed ahead of each page's own stylesheets,
because a plain script in the head blocks rendering and that is the whole
pre-paint mechanism. The markup keeps `class="dark"` on `<html>` so a failure
to load leaves the previous default rather than an unstyled page.

The module owns no markup. Each page keeps its own button and glyph and
registers a painter with `FutTheme.onChange()`, which fires once immediately —
so the pages also lose their separate init calls. Changing those glyphs is a
visual decision and this was not that phase.

**`match.html`** re-reads the canvas bridge on every change, and it is worth
being precise about why, because the brief's premise was slightly different
from what the code does. The cache holds **both** palettes and `CT()` picks
between them from the root class, so a switch was already correct without it.
`readPalette()` is called anyway: two style recalcs on a deliberate gesture
costs nothing, and the day a token changes value at runtime this is the line
that would have been missing. Verified by clearing the cache mid-session and
switching — it repopulates.

**`market-values.html`** bakes its chart colours into SVG attributes rather
than reading `var()`, so it rebuilds on change, registered as a listener
rather than called from the toggle so a change from any source rebuilds it.

**`gate.js`** gained a note and nothing else. Its `--gate-*` tokens stay on
`:root`: the gate paints before the page behind it exists, so it has no
surface to match. It is inside the system and chooses not to vary.

Verified across all fifteen pages: every `body` changes between themes, every
choice survives a reload, a first visit follows the system setting in both
directions, and an explicit choice beats the system setting across a
navigation.

### Phase 5 — total stable sort on Rank · `4b9dfdd`

The player comparator sorted on the active key and then, for ties, compared
`a.pct` with `b.pct` — the same two numbers the line above had just found
equal. It always returned 0, so tied rows kept whatever order PostgREST
returned, which is not stable between requests.

Now: active key in the direction the Order control asks for, then the *other*
number (raw value when percentile is primary, percentile when a role pool has
switched the primary to raw value), then `player_id`.

The team Rankings table had no tie-break at all. It now falls to the raw value
and then the team name, with the raw value compared in the direction that
means "better" for that metric so a tie on PPDA does not put the worst team on
top.

Both tables now name their sort key in the header, in the accent with a
direction arrow. Neither has clickable headers, and on the player one the key
switches silently from percentile to raw value when a role pool is chosen, so
which column was ordering the rows was previously not discoverable at all.

The shipped comparator was extracted and run against a tie-heavy fixture:
stable across eight arrival orders in all four control combinations, total,
antisymmetric, both directions honoured.

### Phase 4 — league multi-select, position, exports · `3078fa1`

**4.1** The league selector left `.hdr-id`, which is what squeezed both page
titles. It now sits with the other filters — in the control bar of every view
that has one, and in the side panel on the views that use that instead. Both
titles measure 15px tall in a browser: one line.

**4.2** League scope is a set. Empty means all, so deselecting everything
shows everything rather than nothing, and it persists comma-joined under the
key the single-select version used — which `players.html` and `teams.html`
share, so a scope chosen on one page still carries to the other.

Percentiles recompute across the combined selection, because the stored `pct`
is computed *within one league*: pooling two of them leaves a number that says
where a player sits among his own countrymen while the table claims to rank
him against everyone on screen. Recomputed within the role pool for players,
across the whole selection for teams, inverted for lower-is-better, and done
**before** the sort, since the pooled percentile is the sort key.

The subtitle names the population on every render, not only when several
leagues are picked.

**4.3** Listed position joins role pool as a filter on Rank and Scatter. They
are different things: pool is the group a player is judged in, assigned from
where he actually plays; `modal_position` is what the team sheet lists him as.
A full-back reassigned to a wide-forward pool is one of the more interesting
things this data says. Teams have no position dimension, so this is
player-side only.

**4.4** Exports are always light and carry panel content only. Every `.sect`
goes in — title, subtitle, legend, chart — and the control bar does not,
because it says what was asked for rather than what the answer is. An as-of
caption is appended. `match.html`'s `EXP_LIGHT` is a flag its canvas renderers
consult; the CSS analogue is the root class, so that is removed for the
capture and restored after. Verified in a browser: light during the capture,
theme restored, no leftover DOM.

### Phase 6 — measurement · `d082fa1`

**`restyle/contrast.md`** — 800 measurements, 324 failures.
**`restyle/separability.md`** — 490 pairs, 21 flagged, 18 severe.
**`restyle/contact-sheet.html`** — 54 live frames, 27 views, both themes.
**`restyle/lint_colors.py`** — now the fourth gate in `check.py`.

---

### Scraper heartbeat — the real event count · `706834d`

Not part of the restyle. Repo code, no database access.

**What the bug actually was: a discarded return value.** Of the four causes
the brief offered, it is that one, and the code says so without ambiguity.

`process_match()` in `scrape_and_load.py:396` has always returned
`(game_id, n)`, where `n` is what `upsert_events()` actually upserted —
`len(rows)` after deduplicating on `(game_id, ws_id)`, so it is the number
that landed rather than the number the feed offered. `scrape_one_league()`
called it as:

```python
game_id, _ = process_match(...)
```

and dropped the count on the floor. Nothing above that line had one to pass
on. `scrape_one_league` and `scrape_targets` both returned
`(ok, failed, remaining)`, with no fourth element, so `main()` called:

```python
hb.record(matches_attempted=..., matches_written=total_ok,
          matches_failed=..., matches_remaining=...)
```

**without `events_written` at all.** `record()`'s default for it is `0`, the
accumulator stayed at `0`, and `_settle()` wrote that `0` to the row on every
run that ever ran.

It is worth being precise about what it was *not*, because three plausible
stories are wrong here:

- **Not a counter that is never incremented.** `_Heartbeat.record()` and
  `_settle()` in `scraper_heartbeat.py` are correct and always were. They were
  being handed nothing.
- **Not a local going out of scope.** The accumulator lives on the heartbeat
  object for the whole `with` block.
- **Not a row written before the flush.** `_settle()` runs on context-manager
  exit, long after every `upsert_events()` call has returned.

**The fix.** `scrape_one_league` and `scrape_targets` return a fourth element
and `main()` passes it to `hb.record()`. The count accumulates only for
fixtures that ingested, so a run that fetched nothing still settles a genuine
zero — which is the case the heartbeat exists to make visible, and it would be
self-defeating to paper over. The per-league and run summaries print the total
too, so the log and the row can be compared without a query.

**`matches_written`, checked against the same standard: it is right.**
`succeeded` increments only after `process_match` returns a truthy `game_id`
with no exception raised. A whitelist rejection returns `("", 0)`, and the
caller turns that falsy `game_id` into `RuntimeError("match was rejected
before ingestion")`, so a refused match counts as failed and never as written.
`matches_attempted` is `total_ok + total_failed`, which correctly excludes
fixtures the time-budget `break` never reached. One edge case behaves
correctly and is worth knowing: a match that ingests from an empty feed counts
`matches_written` 1 and `events_written` 0, which is exactly what it should
say.

**This fix is unverified against a live run.** The database was out of scope
and nothing here reached it. Three things were done instead:

1. Read the whole call chain, `process_match` → `scrape_one_league` →
   `scrape_targets` → `main` → `hb.record` → `_settle`, and confirmed every
   caller of the two changed functions was updated. There are three:
   `scrape_history.py`, `tools/check_historical_scraper.py`, and `main()`.
   The other `process_match` callers — `scrape_and_load.py:488`, `:496`,
   `scrape_new.py:142` — ignore the return value entirely and write no
   heartbeat row, so they are unaffected.
2. Ran the existing dry-run harness, `pipeline/tools/check_historical_scraper.py`.
   Its `scrape_targets` fixture now asserts the event count, and that a league
   which aborts contributes none. All 23 checks pass.
3. Drove `heartbeat()` against a fake Supabase client with the shape of the
   16 September run — 5 matches, 6,072 events — and asserted the settled
   payload. It reports `events_written: 6072` where it previously reported
   `0`.

The first real run will confirm it. The thing to look at is whether the
`events` line in the run summary matches `scraper_runs.events_written` for
that run, and whether both match the row count actually added to `events`.

**A second, worse bug found on the way, deliberately not fixed.**
`drain_rescrape_queue()` calls `process_match()` with a signature that does
not exist, so every re-scrape has always failed instantly with `TypeError` and
been recorded as a fixture failure. Three of those marks a fixture exhausted
and permanently excluded. It is item 5 in `DECISIONS_NEEDED.md`, with what
the database would need to be asked to confirm it. It is left alone because
fixing it restructures the drain and may require a data repair, and because
the truncated-fixture tables sit near the parallel `mv_*` rebuild.

One consequence is load-bearing for the fix above: because the drain writes
no events today, leaving its total out of `events_written` costs nothing right
now. A comment at the `hb.record()` call marks the gap so it is not missed if
the drain is ever repaired.

---

## Deferred to `DECISIONS_NEEDED.md`

Items 1–4 are from the first session; item 5 from the second.

1. **The team profile scatter (4.5).** Out of scope per the brief, and the
   reason holds: the axes need a pair of team metrics, and which pair is a
   claim about what the chart is for. Four questions written up — default
   pair, whether a point is a team or a match, which metrics may be offered,
   and whether it needs a comparison population. Cheap once decided.
2. **How `pct` is computed in the percentile views.** The pooled recomputation
   uses `round(100 × cume_dist())`. Whether the materialised views agree could
   not be checked: the database was out of scope. Only ever applied to a
   pooled selection, so the two definitions never share a table, but if they
   differ then pooled and single-league percentiles differ in definition as
   well as in population. Three options written up.
3. **Whether "All leagues" should pool.** Implemented as pooled, which is the
   honest reading of a single ranked table and what the brief's wording
   describes. Flagged because it moves numbers on the view most people land
   on; the alternative is to keep All as per-league and pool only on an
   explicit multi-selection.
4. **Tie direction on "Lowest first".** The brief said raw value descending.
   Implemented as following the primary direction, so Lowest first is coherent
   all the way down. One-character change if the literal reading was meant.

---

## Contrast failures — the input to Phase 3

324 of 800, split **57 text · 82 mark · 185 boundary**. That order is the
order they matter in, and the boundary count is soft: WCAG 1.4.11 applies to a
boundary *required* to identify a control, and most of those 185 are
decorative hairlines between rows that position already separates. The 57 text
failures are not soft — that is content nobody can read.

Worst text failures:

| scope | token | on | ratio |
|---|---|---|---|
| `match` dark | `--plot-share-label` | `--pitch-fill` | **1.10** |
| `match` dark | `--plot-label` | `--pitch-fill` | **1.42** |
| `app` / `match` dark | `--label-on-fill` | `--rank-mid` | **1.67** |
| `match` dark | `--legend-muted-ink` | `--pitch-fill` | **1.84** |
| `lab` dark | `--ink-on-accent` | `--accent-base` | **1.96** |
| `writing` dark | `--ink-on-state` | `--state-positive` | **2.19** |
| `app` / `match` light | `--label-on-fill` | `--rank-mid` | **2.38** |
| `match` dark | `--legend-muted` | `--pitch-fill` | **2.41** |
| `review` light | `--ink-tertiary` | `--ground` | **2.47** |
| `match` light | `--list-group-ink` | `--surface-raised` | **2.55** |
| `match` light | `--caution-ink` | `--surface-raised` | **2.60** |

The pattern in the top four is the one `tokens.css` predicted in a comment
when the values were moved: **near-black at low alpha painted over a dark
pitch**. `--plot-share-label` is `rgba(0,0,0,0.55)` on `#111722`. Those were
tuned against a light pitch and have been invisible in dark ever since.

Failures by scope: `match light` 76, `app light` 65, `match dark` 55, then a
long tail. `match.html` accounts for 40% of everything, which is consistent
with it carrying 100 of its own tokens.

## Separability failures

21 of 490 pairs below ΔE00 10, 18 of them below 5. **Eleven are exact
duplicates**, and `tokens.css` predicted every one: the evidence layers were
given three hues between nine names precisely so Phase 3 could diverge them
deliberately rather than inherit a collision.

| set | pair | ΔE00 |
|---|---|---|
| players evidence layers | `--layer-blocked` / `--layer-clearance` / `--layer-through` | **0.0** |
| players evidence layers | `--layer-challenge` / `--layer-shot` | **0.0** |
| players evidence layers | `--layer-receipt` / `--layer-save` | **0.0** |
| pitch layer series | `--series-ok` / `--series-pass` | **0.0** |
| players metric groups | `--group-goalkeeping` / `--group-passing` | **3.1** |
| pitch layer series | `--series-mint` / `--series-ok` / `--series-pass` | **4.3** |
| percentile ramp, dark | `--rank-high` / `--rank-top` | **6.0** |

The two that are *not* predicted, and are the real findings: `--group-passing`
and `--group-goalkeeping` at 3.1 sit next to each other on a twelve-slice
pizza chart where the whole point is telling slices apart by hue; and the
percentile ramp's top two steps collapse to 6.0 in dark while holding 16.0 in
light, so the ramp is materially worse in the theme the site ships in.

Every other categorical set is comfortable: the closest pair in the defensive
actions is 15.1, in the position lines 18.2, in the shot outcomes 15.0.

---

## What the gates could not certify

- **Live data.** Nothing here was checked against a populated page. `file://`
  cannot reach Supabase, and the database was out of scope, so the Rank and
  Scatter changes were verified by extracting the shipped comparator and the
  pooled-percentile helper and running them against fixtures, plus a browser
  pass for page errors and control rendering. **The first thing to do in the
  morning is open the contact sheet**, which is exactly this gap closed by a
  human with a session.
- **The pooled percentile's agreement with the views.** See deferred item 2.
- **The export flash.** Forcing light means the page visibly flashes light
  while `html2canvas` works. `html2canvas` reads computed styles off the live
  DOM and a descendant cannot escape an ancestor's `html.dark` — Phase 1's
  bridge probe test 3 established that — so there is nowhere else to put the
  light copy. A brief flash on a deliberate button press seemed the smaller
  cost, but it is a choice, not a fact.
- **Which rule wins for an element.** `assert_rule_parity` compares a
  declaration with itself across revisions; the thirteen theme-rule merges are
  listed in `GONE`/`SURVIVED` rather than proven.
- **`setProperty` at runtime.** Unchanged from Phase 1: `applyTheme()` writes
  `--accent` on the root and no stylesheet gate can see it.
- **Plot studio and Glossary** have no league control. Glossary does not need
  one; Plot studio inherits the scope and operates on an already-selected
  player, and it has no control row to put one in without a layout change that
  was not in scope.

## Two literals Phase 1 missed, found by the new lint

Both now tokens, both real:

- `match.html` painted the opponent's zones with an `rgba()` built from three
  string fragments — `'rgba(100,100,100,'+alpha+')'`. The Phase 1 census
  looked for a complete function call and never saw it. It reads
  `--dominance-them-rgb` through the bridge now, the same shape as `--heat-*`.
- `writing-lab.html` had a bare `color:white`. Phase 1's census scanned for
  hex and `rgb()` and not for colour keywords at all.

Fixing the second made rule parity fail on `white` versus `#fff`, which is one
colour spelled two ways. `norm()` now equates the sixteen basic CSS keywords
with their hex, pinned by regression cases that fail if it went too far: `red`
must not equal `#ff0001`, `white` must not equal `#fffffe`, and a keyword
outside the table must not match anything.

---

## Where I stopped

Everything in the brief is done. Phases 2, 5, 4 and 6 landed in the first
session; the scraper heartbeat landed in the second. Phase 3 was not started
and no colour value, family or component was touched, so Phase 1's guarantee
that nothing renders differently still holds for everything except the
deliberate changes the brief listed.

Two things were deferred rather than guessed: Phase 4.5, as the brief
directed, and the `drain_rescrape_queue()` defect, which is a genuine bug but
outside what "fix the event count" authorises and entangled with a data
repair. Both are in `DECISIONS_NEEDED.md` with what each would need.

One note on the working tree, because it is not obvious from the log: there is
uncommitted parallel work in `pipeline/scrape_history.py` and
`pipeline/tools/check_historical_scraper.py` — `EXPECTED_MATCHES`, the
`--refresh-schedule` flag, and the whole `scrape_targets` test fixture. Commit
`706834d` stages **only** the heartbeat hunks and leaves that work
uncommitted, so it has not been published under a commit message that does not
describe it. The working tree still has it, plus the one assertion added to
that fixture, which will land when that work is committed.

---

## Where to pick up

1. **Open `restyle/contact-sheet.html`** in a browser with a gate session.
   That is the one check tonight could not run, and it covers everything at
   once.
2. **Answer `DECISIONS_NEEDED.md`.** Item 2 is the only one that could be a
   correctness problem; the rest are preferences.
3. **Phase 3**, with `contrast.md` and `separability.md` as input. The three
   things they say most clearly: the near-black-on-dark-pitch labels in
   `match.html` are unreadable today and are not a taste question; the
   percentile ramp is materially worse in dark than in light; and six families
   plus 64 skip rows is the thing to converge, with `match.html` alone
   accounting for 40% of the contrast failures and 100 of its own tokens.
