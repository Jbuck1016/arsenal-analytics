# Navigation, flow and aesthetics audit

**Commit audited: `76b0789e4c814c27d16b3fc664f493e3a4d3b17f`**
Date: 2026-09-13. Viewports 1440x900 and 390x780, both themes, headless Chromium 145.

## Method, and how the gate was bypassed

`dashboard/gate.js` line 28 short-circuits before any prompt:

```js
if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') return;
```

So serving locally bypasses the gate outright, with no password. Otherwise it persists
an unlocked state as `siteAccess = 'granted-v1'` in **both** `sessionStorage` and
`localStorage` (either satisfies it). I set that key as well, so the audit is
hostname independent. No password was needed or used.

`python3` is not on PATH on this machine (`python` is), so the static server was a
15-line Node file server over `dashboard/`, functionally identical to
`python -m http.server`. Nothing was installed.

---

## Part 1: the five tasks

Every task started cold on `index.html` with a fresh browser profile.

| # | Task | Clicks to page | Clicks to config | Total | Completed | Legible at a glance |
|---|---|---|---|---|---|---|
| A | Saka receive and release | 1 | 6+ | 7+ | **Partial** | **No** |
| B | Arsenal defensive shape, got at down the left | 1 | 2 | 3 | **Yes** | Yes for shape, no for the left side |
| C | Arsenal last match progression, who carried | 1 | 3 | 4 | **Partial** | Yes for progression, carriers absent |
| D | Rice vs Caicedo | 1 | 6 | 7 | **Partial** | Yes once reached |
| E | Which PL teams press highest | 1 | 2 | 3 | **Yes** | **Yes** |

### A. Saka receive and release: 7+ clicks, not completed as asked

One click to Players. Then the wall: **the player directory cold-starts with a hidden
team filter set to "Los Angeles FC"** (`players.html:572`,
`ts.value = (teams.indexOf('Los Angeles FC') >= 0) ? 'Los Angeles FC' : teams[0]`).
The sidebar lists 23 LAFC players out of 2021, and typing "Saka" in the search box
returns **"No players"**. Nothing on screen explains why. I assumed the search was
broken before I found the dropdown.

Once the filter is cleared: search, click Saka, and the Player tab is a **percentile
table, not plots**. Pitch plots live behind per-metric drill-downs: 32 of 108 metric
rows are clickable, marked only by a small `◱` glyph, a pointer cursor and a `title`
tooltip ("Click to see these actions on the pitch"). No background, no border, no
section header saying plots exist. You have to already know.

There is no "where he receives and releases" view. The data is loaded
(`v_player_receipts` with `start_x, start_y, ttr, release_type`) but is only reachable
by guessing which of 32 drill-downs contains it.

And for Saka specifically every metric reads **n/a** with an empty bar, because he sits
below the 6-nineties percentile gate. That is the known nineties data gap, but the
*design* response to it is the problem: the page renders the full 108-row empty
scaffold rather than saying "not enough minutes yet, here is the raw volume".

### B. Arsenal defensive shape: 3 clicks, completed

The best flow on the site. One click to Teams, type or click Arsenal in the searchable
sidebar, and the profile lands **already configured**: PPDA 7.90, line height 42.3,
possession and field tilt, each with a league percentile beside it. A `PRESSING` block
is on the default view with no further selection.

"Where they are being got at down the left" needs the Maps tab, which offers "Defensive
actions" and "Shots conceded". That is one more click and the right map choice, and the
plot is not split left/right, so you read the side off the scatter yourself.

### C. Match progression and carriers: 4 clicks, half the question unanswerable

`match.html` also cold-starts on Los Angeles FC, with 25 LAFC fixtures in the picker, so
the team must be switched in the header first. After that it lands well: the default
active plots are `["progressive", "passes"]`, so progression is on screen without
configuring anything. Credit where due.

**"Who carried it" cannot be answered.** All 16 plot buttons are pass, shot, shape or
defensive: Pass Map, Progressive, Final Third, Zone 14, Into Box, Key Passes, Network,
Pass Combos, Shots, Heatmap, xT Map, Defensive, Def. Density, Team Shape, Formation,
Dominance. There is no carry plot at match level. Carrying exists only per player on
`players.html`, so answering it means leaving the match, going to Players, and checking
players one at a time with no idea which to check.

### D. Rice vs Caicedo: 7 clicks, blocked by scope before it works

Compare is a tab on `players.html`, so it inherits the LAFC filter problem. Worse, the
**Player A and Player B dropdowns contain 81 names, not 2021**: they are scoped to one
role pool inside the current league scope. With the cold-start scope you cannot select
Rice or Caicedo at all, and nothing says so. You must change the league picker to
Premier League first, then pick the role pool, then A, then B.

Once configured it works and reads well. Both are central midfielders in the same
league, which is the only case it supports: **you cannot compare across role pools or
across leagues**, which is exactly what a recruitment comparison usually needs.

### E. Which PL teams press highest: 3 clicks, completed cleanly

Teams, Rankings tab, set the league picker to Premier League. The metric dropdown
**already defaults to PPDA**, so the ranking is on screen immediately. This is the one
task where the site anticipates the question. The only wrinkle is a second dropdown
also defaulted to Los Angeles FC as the highlighted team.

### Ideal path versus reality, ranked by gap

| Rank | Task | Ideal | Actual | Gap |
|---|---|---|---|---|
| 1 | **A. Saka receive and release** | 2 (home search, Saka, plots visible) | 7+, and the view does not exist | **+5 and incomplete** |
| 2 | **D. Rice vs Caicedo** | 3 (search Rice, Compare, pick Caicedo) | 7, blocked until scope is changed | **+4** |
| 3 | **C. Match carriers** | 2 (fixture, Carries plot) | 4, and carriers unanswerable | **+2 and incomplete** |
| 4 | **B. Arsenal defensive shape** | 2 | 3 | +1 |
| 5 | **E. PL pressing** | 2 | 3 | +1 |

The pattern: the two team-shaped tasks are nearly ideal. The three player-shaped tasks
all fail, and all three fail for the same two reasons: **a stale default scope** and
**plots buried below the metric tables**.

---

## Part 2: navigation specifics

### Steps from home to a player's plots
Discoverable path: 1 click to Players, then 2 to clear the filter, then search, then
click, then find and click a drill row. **Six or more, and the last step is not
discoverable.** There is no link, button or tab labelled anything like "plots", "maps"
or "on the pitch" on the player page.

Undocumented fast path: **the home page search bar works and is excellent.** Typing
"Saka" on `index.html` surfaces him directly. That is 2 clicks to the player and it
sidesteps the broken sidebar filter entirely. It is the strongest navigational asset on
the site and it is visually treated as a decorative terminal prompt.

### Steps from home to a team's plots
1 click to Teams, 1 to pick the team, 1 to Maps. **Three, fully discoverable.** The team
side of the product is in much better shape than the player side.

### Moving between related things

Measured by grepping which pages construct which deep links:

| From | To | Exists? |
|---|---|---|
| `insights.html` | player, team | **Yes** |
| `search.html` | player | **Yes** |
| `teams.html` | match | **Yes** |
| `teams.html` | stat to its league ranking | **Yes** (commit `f1bc551`) |
| `players.html` | anything | **No. Zero outbound links.** |
| `match.html` | anything | **No. Zero outbound links.** |
| `sequences.html` | anything | **No.** |

So: **the player card and the match page are both terminal.** From Saka you cannot reach
Arsenal, cannot reach the match he played in, cannot reach a team-mate outside the stale
sidebar filter. From a match you cannot click a player into their fingerprint. Every one
of those is a trip back through the top nav.

The `f1bc551` stat-to-ranking pattern on `teams.html` is the right idea and **should
extend to exactly two places**: the player card's metric rows (click a metric, see that
metric's league ranking within the role pool, which `Rank` already renders), and the
match page's player list (click a player, open their fingerprint).

### Is the plot selector understandable?
On `match.html`, mostly yes. Sixteen buttons grouped under Passing / Attacking /
Defending with a 1/2/3/4 plot-count control. The grouping is legible and the `TEAM` badge
on team-level plots is a nice touch. Two problems: nothing explains what the 1/2/3/4
count does until you click it, and "Dominance", "Zone 14" and "xT Map" assume vocabulary
that the Guide has but the control does not surface on hover.

On `players.html` there is effectively **no plot selector at all**, which is the deeper
problem.

### Can you tell what is being filtered?
Partly, and this is where the LAFC default does real damage. On `players.html` the
header caption reads "All leagues · 2021 players", which is **actively contradicted** by
the sidebar dropdown silently set to Los Angeles FC. The two disagree, and the header is
the one you read. On the Saka screenshot the sidebar lists LAFC players while the main
pane shows an Arsenal player, with nothing tying the two together.

`match.html` is the best here: the collapsible window panel states the scope in effect
("Full match" or "Window 62-89 min") and keeps it visible when collapsed.

### Back button and shareable state
Only three pages read a URL parameter: `players.html?player=`, `teams.html?team=`,
`match.html?game=`. Verified: `players.html?player=367185` does restore Saka.

**No page calls `pushState` or `replaceState` anywhere.** Consequences:
- Tab, plot selection, league scope, role pool, time window and comparison state are
  never in the URL. You cannot share "Arsenal, Maps tab, defensive actions".
- The back button never undoes an in-page action. It leaves the page entirely.
- `sequences.html`, `insights.html`, `search.html` and `index.html` support no deep link
  at all and lose everything on reload.

### Mobile at 390px
No horizontal overflow on any of the three main pages, which is better than expected.
The sidebar collapses to a 317-378px scrolling block above the content, so every task is
still *possible*. What breaks first is **the sidebar-plus-detail model**: on
`players.html` you scroll past ~330px of player list before reaching the player you just
selected, with no scroll-into-view. The match plot grid also drops to one column, which
is correct but makes a four-plot comparison a long scroll rather than a glance.

---

## Part 3: aesthetics, page by page

The house style is strong and consistent: JetBrains Mono for numerics, Archivo for
display, a restrained amber/gold accent, generous use of small-caps section labels. It
does read as an instrument rather than a generic dashboard. The failures are hierarchy
and density, not taste.

### `index.html`, the best-designed page
Numbered cards `01 · MATCH` through `08 · GUIDE` with a count under each ("450 fixtures",
"2021 players", "101,016 chains"), league filter chips, and two live leaderboards
below. The numbering implies a reading order and the counts prove the system is live.
This is genuinely the private-intelligence feel the brief asks for.

Two faults. The title is **"MLS 2026 · Analytics"** on a product now covering five
leagues including the Premier League, which undersells it on the first thing you read.
And the search bar, the most useful control on the site, is styled as a low-contrast
terminal prompt with a `/` hint and reads as decoration.

### `teams.html`, the strongest working page
Six KPI tiles across the top, each with a value, unit and **league percentile beneath
it**, then grouped tables (Control, Pressing, Build-up phase, Attacking phase, Output,
Possession shape) with a value, a bar and a percentile number. The bar colour carries
percentile, the number repeats it, so it is not colour-alone. Metric labels are
underlined to signal the ranking link. Your eye lands on the numbers first. This is what
the rest of the site should look like.

Density is high but earns it. Nothing here is wasted space.

### `players.html`, the weakest working page
The hierarchy is inverted. The first thing above the player's name is a **legend strip**
(Elite 80+ / Above 60+ / Average 40+ / Below 20+ / Poor), that is, chrome above content.
Then the name, well set at 27px. Then a 108-row grid of metric rows in four columns.

When percentiles exist this is dense in a good way. When they do not, as with Saka, it
is **108 rows of "n/a" and empty grey bars**, four columns wide, and the page still
renders the entire scaffold. That is the single ugliest screen on the site.

The type ramp is also doing the least work here: metric label, value and bar are all
roughly the same weight and size, so nothing pulls the eye to the outliers, which is the
only reason to look at a percentile table.

### `match.html`
Good. The plot cards have real titles, an orientation caption
("ORIENTATION · ATTACK BOTTOM → TOP · TEAM RIGHT = SCREEN RIGHT") and a per-panel
selection summary. The collapsible window panel is a good pattern. The 16-button plot
rail is dense but grouped.

### `sequences.html` and `insights.html`
These feel like a different product. `sequences.html` opens with a long prose
`<details>` explaining what a sequence is, which is well written but means the page
leads with an essay rather than data. Neither page constructs a single outbound link, so
they are reading destinations rather than parts of a workflow.

### On-screen plots versus the exported PNG
The export cards restyled in `d6bb683` are **better than the on-screen plots**, and it is
not close. The export has a title block, team and opponent, the time window as a chip,
a stats strip and a footer. The on-screen equivalent has a title and a small caption.
The export is a considered analytical object; the on-screen plot is the raw canvas with
chrome around it. The obvious move is the reverse of what usually happens: bring the
export's header and stats strip **into** the on-screen panel.

### Both themes
Light mode works. The warm paper palette from `784b6e9` and `9dbf641` is a real light
design, not an inverted dark one: the pitch is a warm `#f0ead6`, the page is off-white
rather than pure white, the amber accent holds up, and the metric bars keep their
contrast. Dark remains the stronger of the two and is clearly the primary, but light is
no longer embarrassing. The only place it thins out is the plot cards, where the pitch
fill and the card background are close enough that the pitch edge nearly disappears.

---

## The three worst friction points, ranked

### 1. The hardcoded Los Angeles FC default scope
`players.html:572` sets the team filter to Los Angeles FC on every cold start. The same
default appears on `teams.html` (profile), `match.html` (fixture picker) and the Rankings
highlight. It is a leftover from when this was an LAFC dashboard.

The damage is out of all proportion to the size of the bug: **it makes the player search
look broken.** Typing "Saka" returns "No players" while the header says "2021 players".
It blocks Task A and Task D outright and slows Task C.

**Change:** default the team filter to "All teams" and let the league picker be the only
scope control. One line.

### 2. Pitch plots are invisible on the player page
32 of 108 metric rows open a plot, marked by a `◱` glyph and a tooltip. There is no
tab, button or heading that says plots exist. An analyst looking for "where does he
receive the ball" has no entry point.

**Change:** add the drill affordance to the section headers, or add one line under the
player name, "Click any metric marked ◱ to see it on the pitch". Cheapest useful version
is a visible hover background on `.row.drill` so the 32 clickable rows look clickable.

### 3. Player card and match page are terminal
Neither constructs a single outbound link. Player to team, player to match, match to
player are all dead ends that cost a trip through the top nav.

**Change:** make the team name in the player card's meta line a link to
`teams.html?team=`, and make the match page's player list link to
`players.html?player=`. Both deep links already exist and are verified working. This is
the `f1bc551` pattern applied twice.

---

## What I could not find at all

- **Any carry or ball-progression-by-carry view at match level.** Task C's second half.
- **Cross-pool or cross-league player comparison.** Compare is locked to one role pool
  inside one league.
- **A left/right split of defensive actions or shots conceded.** Task B's "down their
  left" has to be eyeballed off a scatter.
- **Any way to share a configured view.** No page serialises tab, plot, scope or window
  into the URL.
- **A route from a match back to the players in it.**

---

## What the site does well, do not break this

- **The home page.** Numbered cards with live counts, league chips, two leaderboards. It
  sets the tone correctly and it is the only page that explains the product.
- **The home search.** It works, it is fast, it crosses entity types, and it is the only
  thing that rescues the player flow.
- **`teams.html` end to end.** Percentile beside every value, bars that do not rely on
  colour alone, stat-to-ranking links, a searchable team list. This page already answers
  its job in three clicks.
- **Landing configured.** `match.html` opening on progressive passes, and Rankings
  defaulting to PPDA, are exactly right and rarer than they should be.
- **The scope label on `match.html`.** Always visible, survives collapse, names the
  window in effect.
- **The export cards.** Better than the screen they came from.
- **Typography and palette.** Mono numerics, display headings, one accent. Consistent
  across every page audited.

---

## Does the information architecture match the three jobs?

**Partly. It is organised around data structure, and it shows on two of the three jobs.**

The nav is `Home / Insights / Search / Match / Players / Teams / Sequences / Guide /
Method / Reference`. Seven of those are **tables in the warehouse**: a match is a table,
a player is a table, a sequence is a table. Only Insights and Search are organised around
a question someone actually has.

Mapped against the three stated jobs:

- **Diagnose a team: well served.** `teams.html` is built around the job, not the table.
  Three clicks, lands configured, percentiles everywhere.
- **Review or prepare for a match: half served.** `match.html` lands on the right plots,
  but it is a single-fixture viewer with no route to the players in it and no carry view,
  so "prepare for Arsenal vs Chelsea" stalls at "look at one past Arsenal match".
- **Scout a player: poorly served.** This is the job with the most pages pointed at it
  (Players, Search, Insights) and the worst flow. The entity is reachable; the analysis
  is buried; the comparison is scope-locked; and the default filter actively hides the
  player you want.

The tell is that **`players.html` has zero outbound links**. Scouting is inherently
relational: player to team, to match, to comparable, to shortlist. A scouting tool whose
player page cannot leave itself is organised around the player *row*, not the scouting
*task*.

---

## Smallest changes, and the one that buys the most

In increasing cost:

1. `players.html:572`: default the team filter to "All teams". **One line.**
2. Give `.row.drill` a visible hover background so the 32 plot rows look clickable.
   **One CSS rule.**
3. Link the team name on the player card to `teams.html?team=`. **One string.**
4. Link players on `match.html` to `players.html?player=`. **One string.**
5. When a player is below the percentile gate, render the volume columns and suppress the
   108 empty percentile rows, instead of drawing the full n/a scaffold.
6. Add a `Carries` plot to `match.html`, reusing the players.html carry renderer.
7. Promote the home search: give it the contrast of a primary control, and put the same
   component in the header of `players.html` and `teams.html`.

**The single change that buys the most is number 1.** It is one line, it is a leftover
from a previous product, and it is the difference between "the player search is broken"
and "the player search works". It unblocks Task A and Task D, removes the contradiction
between the header caption and the sidebar, and costs nothing to reverse.

If a second is affordable, take number 3 and 4 together: two strings that turn the two
terminal pages into a connected workflow, using deep links that already exist.
