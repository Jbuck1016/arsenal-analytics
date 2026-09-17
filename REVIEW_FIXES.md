# Review fixes — round 1

Branch `restyle/global-theme`. Eleven commits, one per item, none squashed.

| | |
|---|---|
| `a90f22e` | test: re-baseline the parity gates on the Phase 3 head |
| `10a1eeb` | fix: thin marks on the pitch are held to 4.5:1, not 3:1 — item 1 |
| `4cafe97` | fix: the pool is the selection — item 3 |
| `1972d46` | fix: the Go to menu lists every live top-level page — item 8 |
| `68e7ce4` | fix: search applies the league it was given — item 10 |
| `67e0b9f` | fix: the ATTACKING label had run outside the pitch viewBox — item 4 |
| `b414ac6` | feat: one export mechanism, and every panel carries it — item 7 |
| `a846e4c` | feat: scatter fits one screen, and five scouting presets — item 6 |
| `1787fe9` | feat: the pizza reads as slices, not as a pie — item 5 |
| `c4a3f1e` | feat: Zone 14, final third and box passes get their own toggles — item 2 |
| `74eac5e` | feat: squad table carries market value and contract expiry — item 9 |

All gates green, contrast at **0 failures under the new stricter threshold**,
separability at 0, resolver and canvas bridge agree, and all 15 pages load in
both themes with no JavaScript errors.

---

## What each item turned out to be

### 0. A gate that had been red since the restyle

Not in the brief, but the brief requires `check.py` to pass and it could not:
`assert_page_parity` and `assert_rule_parity` compared against `c855423`, the
last commit before the restyle, and asserted "nothing renders differently".
Phase 3 lifted that on purpose, so from `ad95b63` onwards the comparison could
only fail.

Rebaselined on the Phase 3 head, and given an **intent ledger**: a change that
alters what a page paints is declared by token, with a reason; anything
undeclared still fails. A parity gate over a design that is deliberately
changing has two bad options — fail permanently, which trains everyone to
ignore it, or move its baseline on every change, which is comparing a commit
with itself. Declaring intent is the third.

### 1. Thin marks on the pitch

**The audit was right and the threshold was wrong**, exactly as the brief
suspected. WCAG 1.4.11's 3:1 is written for graphical objects at a reasonable
size. The pitch plots draw in a 0–100 viewBox, so `stroke-width="0.32"` and
`r="0.4"` are a hairline and a speck once laid out; `--layer-through` is a
dashed 0.4 line.

`PITCH_MARK_PREFIX` is a named category in `palette_audit.py` held to 4.5:1
against `--pitch-fill` in both themes. **48 tokens**: the pass-arrow palettes,
the nine evidence layers, match.html's actions, position lines and shot
outcomes, the single markers, and the keylines.

It covers **data marks only**. A zone edge or a node ring is thin too but pairs
with a fill that identifies the thing, which is why those stayed decoration in
Phase 3 — same test.

**Every pitch mark is now per theme, and has to be.** No single value can clear
4.5:1 on both pitches: clearing it on `#f0ead6` needs relative luminance ≤
0.1438, clearing it on `#111722` needs ≥ 0.2131, and the windows do not
overlap. Phase 3 kept one value per mark because at 3:1 they did overlap, and
one value is the stronger property. At 4.5:1 that option does not exist.

**Nothing needed a thicker stroke.** All 48 reached 4.5:1 with hue and
saturation held and only lightness moved. One exception: `--series-neutral`
moved hue too, from slate blue to warm grey, because darkening it for the cream
pitch brought it within 8.1 CIEDE2000 of `--series-prog`.

One bug found on the way: `--layer-*` was being measured against the page
grounds, a surface it never touches. It is painted on the pitch and measured
there now.

### 3. Rank ordering across a mixed pool

**The Phase 4 check came back half good.** `repoolPct()` did recompute from raw
values, so the multi-league claim was honest — but it **grouped by `r.pool`
first**, so it recomputed *within role*. A striker was never compared with a
centre-back even when the table showed them in the same list. That is the Cunha
/ van Dijk result exactly: 100th among strikers, 97th among centre-backs, sorted
against each other.

And it ran **only when more than one league was selected**. With a single league
it did not run at all and the stored per-`(pool, league)` percentile was used —
same problem, and not even scoped to the current filters.

One function, `pctOverPopulation()`, used by Rank and Scatter, always, over the
filtered rows. `teams.html`'s `repoolTeamPct()` was already the ungrouped shape
and only needed to stop being conditional.

The subtitle now names what the percentile is measured against on every render:
*"percentiles across every player in the selection, not within role"* or
*"percentiles within Centre-back, across the selected leagues"*.

The Rank footnote said the opposite of what the code now does — "with all roles
selected, rank uses each player's role percentile" was a description of the bug
— and is rewritten.

### 4. The clipped orientation label

The SVG pitches drew it at baseline `y=71.2` in a viewBox running −3 to 71, so
it was **outside the box**: descenders clipped by the SVG edge. The box gains
2.5 units at the foot.

The arrow sat level with the text *baseline*, which is a whole unit low — an
arrow aligns with the middle of the cap height, about 0.95 above the baseline
at this size.

match.html's two are canvas, where the arrow is inside the text run and aligned
by construction; those lacked clearance (8px → 13 with a floor of 15) and an
explicit `textBaseline`.

Weight drops 700 → 600 across all six: at 2.7 units it read as a heading.

### 8. Go to menu — **15 pages found**

Fifteen `.html` files in `dashboard/`, all of them pages in their own right
(own `<html>`, own `<head>`, own theme class; none is a fragment or include).

It listed **nine**. Worse, the array was copied into three pages and each copy
omitted whichever page it sat on, so **no two pages offered the same menu**. Six
were missing from all three: Market values, Validation, Model lab, Model review,
Writing lab, and whichever of Players / Teams / Sequences you were not on.
`sequences.html`'s copy had two fields per entry where the renderer reads three,
so it could not have grouped even if that page mounted the menu.

Current page listed and marked rather than hidden. A third group, **Lab**, for
the three editorial pages. Subtabs excluded, as instructed.

### 10a. What Search was actually dropping

**Nothing was being dropped — the league was never parsed.** Both the parse and
the query happened inside the `nl_query` database function, and the only filters
it hands back are `pool`, `side`, `foot`, `max_age`, `min_nineties` — no league
in either direction. There was no point between parse and query for it to be
lost at.

The same hole was in the other half of the page: `STATE` had no league and
`apply()` never filtered on one, so a reader could not reproduce the query by
hand either.

The database is out of scope this round, so the fix is to **stop asking it to
parse**. `player_search` is already loaded whole into the browser; the one
missing piece was `team → league`, one more view the page was not reading. A
ranking is parsed and answered client-side now, where the league can be applied.
`nl_query` still answers similarity, which needs a model this page lacks.

**The other constraints, checked as instructed — two more were silently doing
nothing:**

- **`foot`.** In the example queries and in `nl_query`'s filter list, and
  `player_search` has no footedness column. Now named as unapplied.
- **The sample threshold and age** were applied by the RPC but never shown, so a
  reader could not tell which population a number came from.

Every applied constraint is a chip, including the population count. Anything
recognised but not applicable appears under **"Not applied"**.

Parser verified against all six example queries in the page, including the one
in the report:

```
top 5 centre backs at progressive passing in the premier league
  -> league=ENG-Premier League  pool=CB  metric=prog_cmp_90  limit=5
```

### 10b. Then useful

A local answer states what it ranked on, how many players it ranked against, and
that the percentile is computed across exactly that population — the same rule
as item 3. Every answer links into Rank with the same filters applied, for which
Rank now accepts `metric`, `pool`, `pos`, `n` and `league` from the URL, each
validated against what exists. The facet UI gets league chips, offering only
leagues present in the loaded index.

No reasoning is invented: the answer is the ranked list, and it says what it was
ranked on.

### 7 → 6a. One export mechanism

There were **two** in players.html and a third in teams.html, and none did the
whole job. `snap()` captured every `.sect` as one sheet, so you could not take a
single table. `exportViz()` took one pitch panel but built its own stage inline,
so it did **not** force light, did not use the Phase 3 export styling, and
carried a caption hard-coded to the player view.

`exportPanel(el, meta, fmt)` is the whole of it. Every panel is decorated
**after render** rather than having a button written into each renderer — a
panel qualifies if it holds a table, SVG, canvas or bar, so a control strip or
empty state is skipped. Rank, Scatter, Scout and its bar, Compare, Rankings, the
squad table, the pitch views and the pizza all export individually without any
of them knowing about it.

6a needed no separate work, which was the test of whether the mechanism was
general enough.

Two things bit: the buttons inject *into* `.sect-h`, so reading every span back
gave a subtitle of `"PNGPDF"` until decoration was excluded from metadata; and
decoration must be idempotent, because async renderers resolve after `setTab`
returns.

### 6b/6c. Scatter

Height was `auto` at a 2.34 aspect, so the bottom axis fell below the fold and
scrolling to it scrolled the control bar away. Now `clamp(300px, 100vh − 335px,
640px)` with the control bar sticky.

**Presets and the metric I used for each.** Each axis is a *list* of candidate
keys resolved against the loaded `metric_defs`, first match wins, because the
database is the authority on which measure exists and I could not query it.
Where it substitutes, the button's tooltip names what it actually plotted.

| Preset | Pool | X | Y |
|---|---|---|---|
| Forward passer who finishes | AM | `prog_cmp_90` | `finishing` |
| Aerial monster with feet | CB | `aerial_win_pct` → falls back to `aerial_90` | `pass_pct` → falls back to `prog_cmp_90` |
| Ball-winner who progresses it | CM | `def_action_90` | `prog_carries_90` |
| Creator: volume vs quality | AM | `key_pass_90` | `bcc_90` |
| Press-resistant carrier | W | `takeon_pct` → falls back to `takeon_90` |`prog_carries_90` |

**Two are known approximations.** "Aerial win %" and "take-on success %" are
*rates*, and the metric set is per-90 *volumes*. If no rate column exists those
axes plot the volume, which answers a related but different question — "wins a
lot of headers" rather than "wins a high share of them". Worth a follow-up if
the rates exist under names I did not guess.

A preset leaves the league selection alone. Any hand-change to an axis or pool
clears the preset chip.

### 5. Pizza

Both tells in the brief were geometry, not taste. **The wedges touched** because
the gap was 0.018rad (~1°) and the track was stroked 2px in the panel colour to
fake a separation the geometry did not have, while the filled wedge carried its
own 1px stroke in its own hue. Gap is 0.055rad, both fake strokes gone.

**The labels fought the rim** because they sat at R+27 on a 600-wide box with
R=182 — 91px for "Progressive passes completed". Box is 780 wide with a smaller
radius; labels over 17 characters wrap at a word boundary. Verified: no text
overflows the viewBox.

The ring at 100 was the last of four identical gridlines; it is now drawn after
the wedges, solid, in the strong rule, and labelled once. The number is 10px/500
rather than 13px/800, pushed out to the track when its wedge is too short to
hold it. The hub said `PERCENTILE` at 14px/800 — the loudest thing in the chart,
saying the least.

### 2. Pass-type toggles

Three layers using the existing toggle mechanism, each with its own count. **The
geometry is match.html's to the unit** rather than re-derived — two pages
disagreeing about where zone 14 is would be the same class of bug as two
disagreeing about a colour token.

They filter `all` rather than `base`, so the Progressive/All switch cannot
silently empty them. They start **off**: all three overlap the two layers already
there, so defaulting them on would change what the view shows on open.

Colours are `--series-alt`, `--series-cool`, `--series-warm` — declared and read
by nothing, already in the pitch-mark set at 4.5:1, closest pair in that palette
11.7.

### 9. Squad columns

A missing value renders as an em dash in muted ink with a title saying *which*
kind of missing. Not a zero, not a blank that reads as nought, and no row hidden
for lacking one. The footnote states the actual coverage **for the squad on
screen** rather than a general disclaimer.

A contract inside a year of expiry is marked in the state palette.

---

## What I could not do without a decision that was not in the brief

1. **`nl_query`'s parser is still league-blind.** The user-visible bug is fixed
   because rankings no longer go through it, but the function itself still
   cannot parse or apply a league — so anything still routed to it (similarity)
   ignores one, which the UI now says out loud. Fixing it properly is a database
   change and out of scope this round.

2. **Two preset axes are volumes standing in for rates**, as above. I could not
   query `metric_defs` to find out whether `aerial_win_pct` or `takeon_pct`
   exist under some other name.

3. **The contract-expiry column name is a guess hedged two ways.** I select both
   `contract_expires` and `contract_expiry` and use whichever is present. If the
   view calls it something else entirely the column will read as uniformly
   not-on-file — which is at least honest, but it is not verified.

4. **Nothing here was seen against live data.** Every page was loaded in both
   themes and checked for JavaScript errors, and every new function was tested
   against synthetic rows — the parser against all six example queries, the pass
   layers against constructed passes in the Opta frame, the export metadata and
   missing-value cells against fixtures. But `file://` cannot reach Supabase, so
   no rendered table or chart was seen with real numbers in it. In particular the
   Cunha / van Dijk ordering is fixed *by reasoning over the code*; confirming
   the two now sort correctly wants one look at the running site.

5. **`build_insights()` producing insights for only two of six leagues** is
   noted and untouched, as instructed.

Regenerated `restyle/contact-sheet.html`: 15 pages, 27 views, 54 frames.
