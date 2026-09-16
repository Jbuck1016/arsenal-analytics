# RESTYLE_AUDIT.md

Phase 0 of the global theming brief. Audit only: no rendering code was changed to produce this.
Colour figures come from a scan of `dashboard/`; behaviour comes from reading the render code and
one read-only query against the live database.

---

## 0.1 Surface inventory

`vercel.json` is `{"outputDirectory": "dashboard"}` with no routes, so **every file in `dashboard/`
is served at its own URL**. Surfaces are split below into those reachable from the live nav and files
that are still deployed but unreferenced.

### Tabbed applications

| Surface | Tab / subtab | Rendered by |
| --- | --- | --- |
| players.html | Player | `pick() -> player profile` |
| players.html | Chain roles | `renderChainRoles()` |
| players.html | Rank | `renderRank() + rankCtrls()` |
| players.html | Scatter | `renderScatter() + scatterSvg()` |
| players.html | Scout | `renderScout()` |
| players.html | Compare | `renderCompare()` |
| players.html | Plot studio | `renderPlotStudio()` |
| players.html | Glossary (reachable via `setTab('Glossary')`, absent from `TABS`) | `renderGlossary()` |
| teams.html | Profile | `renderProfile()` |
| teams.html | Sequences | `renderSequences()` |
| teams.html | Maps | `renderMaps()` |
| teams.html | Rankings | `renderRankings()` |
| teams.html | League Map | `renderLeagueMap()` |
| teams.html | Matches | `renderMatches()` |
| teams.html | Squad | `draw() squad branch` |
| match.html | Match Analysis | `.htab[data-tab]` handler |
| match.html | Season Stats | `.htab[data-tab]` handler |
| match.html | Momentum | `.htab[data-tab]` handler |
| sequences.html | single view | `render()`; its `.tab` strip is cross-page links, not subtabs |

**Counts: players 7 tabs plus 1 unlisted (Glossary), teams 7, match 3, sequences 1.**

### Behind the "Go to" control

`players.html` and `teams.html` build `.navmenu-panel` from a `NAV` array of **9 destinations** in two
groups, explore and learn: Home, Insights, Search, Match, Players/Teams, Sequences, Guide, Method,
Reference. `sequences.html` carries the same 9 as a flat `NAV` rendered into its tab strip.

### Standalone pages linked from index.html (12 cards)

match, players, teams, glossary, insights, sequences, search, guide, model-review, model-lab,
market-values, writing-lab.

### Deployed but unreferenced, still publicly reachable

**CORRECTED AFTER PHASE 0.** This section originally listed six files. The real
set is **nine**, and all nine were deleted in `bad515c` before any conversion
work, with per-file evidence of zero inbound references recorded in that commit.

Scanned, with their literal counts:

| File | Colour literals |
| --- | ---: |
| `index_v1.html` | 209 |
| `players (1).html` | 50 |
| `live_dashboard.html` | 35 |
| `thread-board.html` | 23 |
| `line-mockups.html` | 20 |
| `glossary_current.html` | 15 |
| **total** | **352** |

Never scanned, and therefore absent from every count in this document:
`index_current.html`, `players_current.html`, `teams_current.html`.

Those three begin with the bytes `ff fe`, a UTF-16 LE byte order mark. Git
classifies them as binary (`-` in `git diff --numstat`, `Bin ... -> 0 bytes` in
the deletion commit) and the colour scanner, which reads UTF-8 with
`errors="replace"`, saw NUL-interleaved text that matched no pattern. So they
contributed zero to the 352 and to the 1,332 total.

The same check was run against every live file: all fifteen pages start `3c 21`
(`<!`) and the three stylesheets and `gate.js` start `2f 2a` (`/*`), all plain
UTF-8, and git reports line counts for every one. So the live inventory of 980
literals is not undercounting for this reason.

---

## 0.2 Colour literal inventory

**1332 occurrences total: 980 in live surfaces, 352 in unreferenced files.** The scan covers hex, `rgb/rgba/hsl/hsla/color/oklch`,
CSS named colours, d3 `scheme*` and `interpolate*`, Tailwind colour classes, Plotly colorway and template
keys, and the SVG and canvas paint properties. `model-lab-data.js` (4.7 MB) and `model-review-data.js`
were skipped as data files.

No d3 scheme, no Tailwind colour class, no Plotly colorway and no `oklch()` was found: the app paints
entirely with hand-written hex, `rgba()` and CSS named colours.

| Live file | Occurrences |
| --- | ---: |
| `dashboard/index.html` | 38 |
| `dashboard/players.html` | 86 |
| `dashboard/teams.html` | 68 |
| `dashboard/match.html` | 365 |
| `dashboard/sequences.html` | 63 |
| `dashboard/search.html` | 27 |
| `dashboard/insights.html` | 27 |
| `dashboard/glossary.html` | 27 |
| `dashboard/guide.html` | 32 |
| `dashboard/methodology.html` | 32 |
| `dashboard/validation.html` | 34 |
| `dashboard/market-values.html` | 27 |
| `dashboard/model-lab.html` | 38 |
| `dashboard/model-review.html` | 28 |
| `dashboard/writing-lab.html` | 37 |
| `dashboard/theme.css` | 20 |
| `dashboard/shell.css` | 14 |
| `dashboard/gate.js` | 17 |

<details><summary>Every live-surface occurrence: file, line, property, value, role</summary>

| File | Line | Property | Value | Role |
| --- | ---: | --- | --- | --- |
| gate.js | 61 | `background` | `#080a0e` | ground/surface |
| gate.js | 64 | `background` | `#0e1116` | ground/surface |
| gate.js | 64 | `border` | `#1c222c` | border |
| gate.js | 65 | `box-shadow` | `rgba(` | overlay/glow |
| gate.js | 67 | `color` | `#e2b877` | ink-or-marker-fill |
| gate.js | 68 | `color` | `#e8eef6` | ink-or-marker-fill |
| gate.js | 69 | `color` | `#8794a6` | ink-or-marker-fill |
| gate.js | 70 | `background` | `#141821` | ground/surface |
| gate.js | 70 | `color` | `#e8eef6` | ink-or-marker-fill |
| gate.js | 71 | `border` | `#2b333f` | border |
| gate.js | 72 | `border-color` | `rgba(` | border |
| gate.js | 74 | `color` | `#8794a6` | ink-or-marker-fill |
| gate.js | 75 | `color` | `#e2b877` | ink-or-marker-fill |
| gate.js | 75 | `background` | `rgba(` | ground/surface |
| gate.js | 76 | `border` | `rgba(` | border |
| gate.js | 79 | `background` | `rgba(` | ground/surface |
| gate.js | 80 | `color` | `#ff5f56` | ink-or-marker-fill |
| glossary.html | 12 | `?` | `blue` | unclassified |
| glossary.html | 14 | `--amber` | `#9c6b1e` | token-definition |
| glossary.html | 14 | `--amber-dim` | `rgba(` | token-definition |
| glossary.html | 14 | `--amber-dim` | `rgba(` | token-definition |
| glossary.html | 15 | `--blue` | `#2f6aa8` | token-definition |
| glossary.html | 18 | `--bg` | `#0e1219` | token-definition |
| glossary.html | 18 | `--panel` | `#161b24` | token-definition |
| glossary.html | 18 | `--panel` | `#1e242e` | token-definition |
| glossary.html | 19 | `--line` | `#272e3a` | token-definition |
| glossary.html | 19 | `--line` | `#3a4351` | token-definition |
| glossary.html | 20 | `--text` | `#f2f5fa` | token-definition |
| glossary.html | 20 | `--dim` | `#b6c2d4` | token-definition |
| glossary.html | 20 | `--dim` | `#8b98ab` | token-definition |
| glossary.html | 21 | `--amber` | `#e2b877` | token-definition |
| glossary.html | 21 | `--amber-dim` | `rgba(` | token-definition |
| glossary.html | 21 | `--amber-dim` | `rgba(` | token-definition |
| glossary.html | 22 | `--green` | `#3ddc97` | token-definition |
| glossary.html | 22 | `--red` | `#ff5f56` | token-definition |
| glossary.html | 22 | `--blue` | `#5aa9ff` | token-definition |
| glossary.html | 111 | `selects` | `white` | unclassified |
| glossary.html | 112 | `?` | `white` | unclassified |
| glossary.html | 112 | `?` | `white` | unclassified |
| glossary.html | 114 | `background-color` | `#1a1d24` | ground/surface |
| glossary.html | 114 | `color` | `#f4f6fb` | ink-or-marker-fill |
| glossary.html | 115 | `background-color` | `#1a1d24` | ground/surface |
| glossary.html | 115 | `color` | `#f4f6fb` | ink-or-marker-fill |
| glossary.html | 152 | `?` | `Red` | unclassified |
| guide.html | 13 | `?` | `green` | unclassified |
| guide.html | 13 | `?` | `red` | unclassified |
| guide.html | 15 | `?` | `blue` | unclassified |
| guide.html | 19 | `?` | `#9c6b1e` | unclassified |
| guide.html | 21 | `?` | `#8a5e1a` | unclassified |
| guide.html | 22 | `?` | `red` | unclassified |
| guide.html | 25 | `--amber` | `#8a5e1a` | token-definition |
| guide.html | 25 | `--amber-dim` | `rgba(` | token-definition |
| guide.html | 25 | `--amber-dim` | `rgba(` | token-definition |
| guide.html | 26 | `--blue` | `#2f6aa8` | token-definition |
| guide.html | 29 | `--bg` | `#0e1219` | token-definition |
| guide.html | 29 | `--panel` | `#161b24` | token-definition |
| guide.html | 29 | `--panel` | `#1e242e` | token-definition |
| guide.html | 30 | `--line` | `#272e3a` | token-definition |
| guide.html | 30 | `--line` | `#3a4351` | token-definition |
| guide.html | 31 | `--text` | `#f2f5fa` | token-definition |
| guide.html | 31 | `--dim` | `#b6c2d4` | token-definition |
| guide.html | 31 | `--dim` | `#8b98ab` | token-definition |
| guide.html | 32 | `--amber` | `#e2b877` | token-definition |
| guide.html | 32 | `--amber-dim` | `rgba(` | token-definition |
| guide.html | 32 | `--amber-dim` | `rgba(` | token-definition |
| guide.html | 33 | `--green` | `#3ddc97` | token-definition |
| guide.html | 33 | `--red` | `#ff5f56` | token-definition |
| guide.html | 33 | `--blue` | `#5aa9ff` | token-definition |
| guide.html | 117 | `background` | `transparent` | ground/surface |
| guide.html | 118 | `background` | `transparent` | ground/surface |
| guide.html | 151 | `background` | `#fff` | ground/surface |
| guide.html | 151 | `color` | `#000` | ink-or-marker-fill |
| guide.html | 152 | `border-top` | `#ccc` | border |
| guide.html | 154 | `border` | `#ccc` | border |
| guide.html | 156 | `color` | `#000` | ink-or-marker-fill |
| guide.html | 158 | `color` | `#ff5f56` | ink-or-marker-fill |
| index.html | 12 | `?` | `green` | unclassified |
| index.html | 12 | `?` | `red` | unclassified |
| index.html | 16 | `--amber` | `#9a6f2a` | token-definition |
| index.html | 16 | `--amber-dim` | `rgba(` | token-definition |
| index.html | 16 | `--amber-dim` | `rgba(` | token-definition |
| index.html | 17 | `--blue` | `#2f6fd0` | token-definition |
| index.html | 20 | `--bg` | `#0e1219` | token-definition |
| index.html | 20 | `--panel` | `#161b24` | token-definition |
| index.html | 20 | `--panel` | `#1e242e` | token-definition |
| index.html | 21 | `--line` | `#272e3a` | token-definition |
| index.html | 21 | `--line` | `#3a4351` | token-definition |
| index.html | 22 | `--text` | `#f2f5fa` | token-definition |
| index.html | 22 | `--dim` | `#b6c2d4` | token-definition |
| index.html | 22 | `--dim` | `#8b98ab` | token-definition |
| index.html | 23 | `--amber` | `#e2b877` | token-definition |
| index.html | 23 | `--amber-dim` | `rgba(` | token-definition |
| index.html | 23 | `--amber-dim` | `rgba(` | token-definition |
| index.html | 24 | `--green` | `#3ddc97` | token-definition |
| index.html | 24 | `--red` | `#ff5f56` | token-definition |
| index.html | 24 | `--blue` | `#5aa9ff` | token-definition |
| index.html | 29 | `background-image` | `rgba(` | ramp |
| index.html | 29 | `background-image` | `transparent` | ramp |
| index.html | 43 | `box-shadow` | `rgba(` | overlay/glow |
| index.html | 58 | `box-shadow` | `rgba(` | overlay/glow |
| index.html | 130 | `color` | `#b6c2d4` | ink-or-marker-fill |
| index.html | 131 | `border` | `#2b333f` | border |
| index.html | 132 | `color` | `#e8eef6` | ink-or-marker-fill |
| index.html | 134 | `color` | `#e8eef6` | ink-or-marker-fill |
| index.html | 134 | `border-color` | `rgba(` | border |
| index.html | 135 | `background` | `rgba(` | ground/surface |
| index.html | 135 | `background` | `rgba(` | ground/surface |
| index.html | 136 | `color` | `#e2b877` | ink-or-marker-fill |
| index.html | 153 | `cursor` | `#9728` | unclassified |
| index.html | 281 | `?` | `Red` | unclassified |
| index.html | 604 | `innerhtml` | `#9728` | unclassified |
| index.html | 604 | `innerhtml` | `#9789` | unclassified |
| index.html | 605 | `innerhtml` | `#9728` | unclassified |
| index.html | 605 | `innerhtml` | `#9789` | unclassified |
| insights.html | 15 | `?` | `blue` | unclassified |
| insights.html | 17 | `--amber` | `#9c6b1e` | token-definition |
| insights.html | 17 | `--amber-dim` | `rgba(` | token-definition |
| insights.html | 17 | `--amber-dim` | `rgba(` | token-definition |
| insights.html | 18 | `--blue` | `#2f6aa8` | token-definition |
| insights.html | 21 | `--bg` | `#0e1219` | token-definition |
| insights.html | 21 | `--panel` | `#161b24` | token-definition |
| insights.html | 21 | `--panel` | `#1e242e` | token-definition |
| insights.html | 22 | `--line` | `#272e3a` | token-definition |
| insights.html | 22 | `--line` | `#3a4351` | token-definition |
| insights.html | 23 | `--text` | `#f2f5fa` | token-definition |
| insights.html | 23 | `--dim` | `#b6c2d4` | token-definition |
| insights.html | 23 | `--dim` | `#8b98ab` | token-definition |
| insights.html | 24 | `--amber` | `#e2b877` | token-definition |
| insights.html | 24 | `--amber-dim` | `rgba(` | token-definition |
| insights.html | 24 | `--amber-dim` | `rgba(` | token-definition |
| insights.html | 25 | `--green` | `#3ddc97` | token-definition |
| insights.html | 25 | `--red` | `#ff5f56` | token-definition |
| insights.html | 25 | `--blue` | `#5aa9ff` | token-definition |
| insights.html | 89 | `border` | `transparent` | border |
| insights.html | 101 | `selects` | `white` | unclassified |
| insights.html | 102 | `?` | `white` | unclassified |
| insights.html | 102 | `?` | `white` | unclassified |
| insights.html | 104 | `background-color` | `#1a1d24` | ground/surface |
| insights.html | 104 | `color` | `#f4f6fb` | ink-or-marker-fill |
| insights.html | 105 | `background-color` | `#1a1d24` | ground/surface |
| insights.html | 105 | `color` | `#f4f6fb` | ink-or-marker-fill |
| market-values.html | 14 | `--ink` | `#17202c` | token-definition |
| market-values.html | 14 | `--paper` | `#f2eee4` | token-definition |
| market-values.html | 14 | `--panel` | `#faf7ef` | token-definition |
| market-values.html | 14 | `--line` | `#c9c1b1` | token-definition |
| market-values.html | 14 | `--muted` | `#657080` | token-definition |
| market-values.html | 14 | `--signal` | `#a66a12` | token-definition |
| market-values.html | 14 | `--signal` | `#0f7777` | token-definition |
| market-values.html | 14 | `--soft` | `rgba(` | token-definition |
| market-values.html | 14 | `--soft` | `rgba(` | token-definition |
| market-values.html | 15 | `--ink` | `#edf2f8` | token-definition |
| market-values.html | 15 | `--paper` | `#0e1219` | token-definition |
| market-values.html | 15 | `--panel` | `#161b24` | token-definition |
| market-values.html | 15 | `--line` | `#323b49` | token-definition |
| market-values.html | 15 | `--muted` | `#98a6ba` | token-definition |
| market-values.html | 15 | `--signal` | `#efbd6f` | token-definition |
| market-values.html | 15 | `--signal` | `#4cc8c4` | token-definition |
| market-values.html | 15 | `--soft` | `rgba(` | token-definition |
| market-values.html | 15 | `--soft` | `rgba(` | token-definition |
| market-values.html | 16 | `background-image` | `rgba(` | ramp |
| market-values.html | 16 | `background-image` | `rgba(` | ramp |
| market-values.html | 16 | `background-image` | `transparent` | ramp |
| market-values.html | 16 | `background-image` | `transparent` | ramp |
| market-values.html | 18 | `background` | `transparent` | ground/surface |
| market-values.html | 22 | `color` | `#d16f52` | ramp |
| market-values.html | 22 | `border-bottom` | `transparent` | ramp |
| market-values.html | 22 | `border-bottom` | `transparent` | ramp |
| market-values.html | 25 | `border-bottom` | `transparent` | border |
| match.html | 19 | `--accent` | `#EF0107` | token-definition |
| match.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| match.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| match.html | 20 | `--pitch` | `#f0ead6` | token-definition |
| match.html | 23 | `--bg` | `#101319` | token-definition |
| match.html | 23 | `--bg` | `#1a1d24` | token-definition |
| match.html | 23 | `--bg` | `#22252e` | token-definition |
| match.html | 24 | `--surface` | `rgba(` | token-definition |
| match.html | 24 | `--surface` | `rgba(` | token-definition |
| match.html | 25 | `--border` | `#2a2d35` | token-definition |
| match.html | 25 | `--border` | `#3a3d45` | token-definition |
| match.html | 26 | `--text` | `#f4f6fb` | token-definition |
| match.html | 26 | `--text` | `#c3cde2` | token-definition |
| match.html | 26 | `--text` | `#9aa7c2` | token-definition |
| match.html | 27 | `--pitch` | `#11141b` | token-definition |
| match.html | 28 | `--shadow` | `rgba(` | token-definition |
| match.html | 28 | `--shadow` | `rgba(` | token-definition |
| match.html | 35 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 41 | `?` | `white` | unclassified |
| match.html | 41 | `?` | `white` | unclassified |
| match.html | 41 | `?` | `white` | unclassified |
| match.html | 47 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 61 | `background` | `rgba(` | ground/surface |
| match.html | 63 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 64 | `background` | `transparent` | ramp |
| match.html | 75 | `background` | `rgba(` | ground/surface |
| match.html | 77 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 79 | `background` | `transparent` | ramp |
| match.html | 92 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 96 | `color` | `#c0392b` | ink-or-marker-fill |
| match.html | 96 | `background` | `rgba(` | ground/surface |
| match.html | 96 | `background` | `rgba(` | ground/surface |
| match.html | 118 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 129 | `border-color` | `rgba(` | border |
| match.html | 129 | `border-color` | `rgba(` | border |
| match.html | 137 | `color` | `#8a6500` | ink-or-marker-fill |
| match.html | 137 | `background` | `rgba(` | ground/surface |
| match.html | 137 | `background` | `rgba(` | ground/surface |
| match.html | 138 | `color` | `#b91c1c` | ink-or-marker-fill |
| match.html | 138 | `background` | `rgba(` | ground/surface |
| match.html | 138 | `background` | `rgba(` | ground/surface |
| match.html | 143 | `border` | `transparent` | border |
| match.html | 150 | `background` | `rgba(` | ground/surface |
| match.html | 151 | `background` | `rgba(` | ground/surface |
| match.html | 153 | `color` | `#9a9894` | ink-or-marker-fill |
| match.html | 167 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 168 | `background` | `#2563eb` | ground/surface |
| match.html | 171 | `background` | `#2563eb` | ramp |
| match.html | 171 | `background` | `#2563eb` | ramp |
| match.html | 171 | `color` | `#fff` | ramp |
| match.html | 171 | `border-color` | `transparent` | ramp |
| match.html | 181 | `font-variant-numeric` | `gold` | unclassified |
| match.html | 181 | `color` | `red` | ink-or-marker-fill |
| match.html | 285 | `background` | `transparent` | ground/surface |
| match.html | 286 | `background` | `rgba(` | ground/surface |
| match.html | 290 | `background` | `transparent` | ground/surface |
| match.html | 290 | `background` | `transparent` | ground/surface |
| match.html | 323 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 324 | `accent-color` | `#fff` | unclassified |
| match.html | 329 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 330 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 337 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 346 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 356 | `background` | `transparent` | ramp |
| match.html | 365 | `background` | `#fafafa` | ground/surface |
| match.html | 366 | `background` | `rgba(` | ground/surface |
| match.html | 373 | `color` | `#16a34a` | ink-or-marker-fill |
| match.html | 373 | `background` | `#f0fdf4` | ground/surface |
| match.html | 374 | `color` | `#ca8a04` | ink-or-marker-fill |
| match.html | 374 | `background` | `#fefce8` | ground/surface |
| match.html | 375 | `color` | `#dc2626` | ink-or-marker-fill |
| match.html | 375 | `background` | `#fef2f2` | ground/surface |
| match.html | 376 | `background` | `rgba(` | ground/surface |
| match.html | 377 | `background` | `rgba(` | ground/surface |
| match.html | 378 | `background` | `rgba(` | ground/surface |
| match.html | 388 | `border` | `transparent` | border |
| match.html | 397 | `color` | `#b8860b` | ink-or-marker-fill |
| match.html | 397 | `background` | `rgba(` | ground/surface |
| match.html | 398 | `color` | `#2563eb` | ink-or-marker-fill |
| match.html | 398 | `background` | `rgba(` | ground/surface |
| match.html | 399 | `color` | `#16a34a` | ink-or-marker-fill |
| match.html | 399 | `background` | `rgba(` | ground/surface |
| match.html | 400 | `color` | `#ef4444` | ink-or-marker-fill |
| match.html | 400 | `background` | `rgba(` | ground/surface |
| match.html | 441 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 447 | `color` | `#fff` | ink-or-marker-fill |
| match.html | 477 | `background` | `rgba(` | ground/surface |
| match.html | 478 | `background` | `rgba(` | ground/surface |
| match.html | 480 | `color` | `#16a34a` | ink-or-marker-fill |
| match.html | 481 | `color` | `#dc2626` | ink-or-marker-fill |
| match.html | 488 | `background` | `rgba(` | ground/surface |
| match.html | 490 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 498 | `background` | `rgba(` | ground/surface |
| match.html | 504 | `background` | `rgba(` | ground/surface |
| match.html | 504 | `background` | `rgba(` | ground/surface |
| match.html | 522 | `color` | `#8b95b5` | ink-or-marker-fill |
| match.html | 527 | `--gold` | `#9a6f2a` | token-definition |
| match.html | 527 | `--blue` | `#2f6fd0` | token-definition |
| match.html | 528 | `--shadow` | `rgba(` | token-definition |
| match.html | 528 | `--shadow` | `rgba(` | token-definition |
| match.html | 531 | `--bg` | `#0e1219` | token-definition |
| match.html | 531 | `--bg` | `#161b24` | token-definition |
| match.html | 531 | `--bg` | `#1e242e` | token-definition |
| match.html | 532 | `--surface` | `#1e242e` | token-definition |
| match.html | 532 | `--surface` | `rgba(` | token-definition |
| match.html | 533 | `--border` | `#272e3a` | token-definition |
| match.html | 533 | `--border` | `#3a4351` | token-definition |
| match.html | 534 | `--text` | `#f2f5fa` | token-definition |
| match.html | 534 | `--text` | `#b6c2d4` | token-definition |
| match.html | 534 | `--text` | `#8b98ab` | token-definition |
| match.html | 535 | `--gold` | `#e2b877` | token-definition |
| match.html | 535 | `--green` | `#3ddc97` | token-definition |
| match.html | 535 | `--blue` | `#5aa9ff` | token-definition |
| match.html | 535 | `--red-bright` | `#ff5f56` | token-definition |
| match.html | 536 | `--pitch` | `#111722` | token-definition |
| match.html | 537 | `--shadow` | `rgba(` | token-definition |
| match.html | 537 | `--shadow` | `rgba(` | token-definition |
| match.html | 543 | `?` | `rgba(` | ramp |
| match.html | 543 | `?` | `transparent` | ramp |
| match.html | 544 | `?` | `rgba(` | ramp |
| match.html | 544 | `?` | `transparent` | ramp |
| match.html | 545 | `?` | `rgba(` | ramp |
| match.html | 545 | `?` | `transparent` | ramp |
| match.html | 548 | `background` | `rgba(` | ground/surface |
| match.html | 549 | `background` | `transparent` | ground/surface |
| match.html | 550 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 550 | `box-shadow` | `rgba(` | overlay/glow |
| match.html | 557 | `background` | `rgba(` | ground/surface |
| match.html | 557 | `background` | `rgba(` | ground/surface |
| match.html | 558 | `background` | `transparent` | ground/surface |
| match.html | 559 | `background` | `rgba(` | ground/surface |
| match.html | 560 | `background` | `transparent` | ground/surface |
| match.html | 566 | `background` | `rgba(` | ground/surface |
| match.html | 566 | `background` | `rgba(` | ground/surface |
| match.html | 568 | `background` | `rgba(` | ground/surface |
| match.html | 568 | `background` | `rgba(` | ground/surface |
| match.html | 569 | `background` | `rgba(` | ground/surface |
| match.html | 570 | `background` | `transparent` | ground/surface |
| match.html | 573 | `background` | `rgba(` | ground/surface |
| match.html | 573 | `background` | `rgba(` | ground/surface |
| match.html | 574 | `background` | `rgba(` | ground/surface |
| match.html | 574 | `background` | `rgba(` | ground/surface |
| match.html | 576 | `background` | `rgba(` | ground/surface |
| match.html | 576 | `background` | `rgba(` | ground/surface |
| match.html | 577 | `background` | `rgba(` | ground/surface |
| match.html | 577 | `background` | `transparent` | ground/surface |
| match.html | 578 | `background` | `rgba(` | ground/surface |
| match.html | 578 | `background` | `transparent` | ground/surface |
| match.html | 579 | `background` | `transparent` | ground/surface |
| match.html | 583 | `background` | `rgba(` | ground/surface |
| match.html | 584 | `background` | `transparent` | ground/surface |
| match.html | 596 | `background` | `rgba(` | ground/surface |
| match.html | 597 | `background` | `transparent` | ground/surface |
| match.html | 599 | `background` | `rgba(` | ground/surface |
| match.html | 599 | `background` | `transparent` | ground/surface |
| match.html | 600 | `background` | `rgba(` | ground/surface |
| match.html | 600 | `background` | `transparent` | ground/surface |
| match.html | 601 | `background` | `transparent` | ground/surface |
| match.html | 624 | `class` | `#9917` | unclassified |
| match.html | 635 | `href` | `#8962` | unclassified |
| match.html | 636 | `href` | `#128100` | unclassified |
| match.html | 637 | `href` | `#127942` | unclassified |
| match.html | 639 | `class` | `#9997` | unclassified |
| match.html | 641 | `title` | `#127769` | unclassified |
| match.html | 647 | `value` | `#8212` | unclassified |
| match.html | 647 | `value` | `#8212` | unclassified |
| match.html | 787 | `colors` | `#C39E6D` | unclassified |
| match.html | 787 | `colors` | `#00245D` | unclassified |
| match.html | 787 | `colors` | `#F7B5CD` | unclassified |
| match.html | 788 | `?` | `#5D9732` | unclassified |
| match.html | 788 | `?` | `#00482B` | unclassified |
| match.html | 788 | `?` | `#80000A` | unclassified |
| match.html | 789 | `?` | `#6CACE4` | unclassified |
| match.html | 789 | `?` | `#FEDD00` | unclassified |
| match.html | 789 | `?` | `#F05323` | unclassified |
| match.html | 790 | `?` | `#071B2C` | unclassified |
| match.html | 790 | `?` | `#ECE83A` | unclassified |
| match.html | 790 | `?` | `#00B140` | unclassified |
| match.html | 791 | `?` | `#00B7BD` | unclassified |
| match.html | 791 | `?` | `#00245E` | unclassified |
| match.html | 791 | `?` | `#B30838` | unclassified |
| match.html | 795 | `?` | `hsl(` | unclassified |
| match.html | 798 | `?` | `hsl(` | unclassified |
| match.html | 798 | `?` | `hsla(` | unclassified |
| match.html | 800 | `?` | `rgba(` | unclassified |
| match.html | 835 | `color` | `#8b95b5` | ink-or-marker-fill |
| match.html | 836 | `colorbright` | `#8b95b5` | unclassified |
| match.html | 836 | `colordim` | `rgba(` | unclassified |
| match.html | 836 | `colordim` | `rgba(` | unclassified |
| match.html | 858 | `tackle` | `#ef4444` | unclassified |
| match.html | 858 | `interception` | `#2563eb` | unclassified |
| match.html | 858 | `clearance` | `#7c3aed` | unclassified |
| match.html | 858 | `ballrecovery` | `#16a34a` | unclassified |
| match.html | 858 | `blockedpass` | `#d4a017` | unclassified |
| match.html | 858 | `aerial` | `#0891b2` | unclassified |
| match.html | 858 | `challenge` | `#db2777` | unclassified |
| match.html | 861 | `?` | `#1a6b3a` | unclassified |
| match.html | 861 | `fail` | `#c0392b` | unclassified |
| match.html | 871 | `pitch` | `#111722` | unclassified |
| match.html | 871 | `line` | `rgba(` | unclassified |
| match.html | 871 | `line` | `rgba(` | unclassified |
| match.html | 872 | `band` | `rgba(` | unclassified |
| match.html | 872 | `band` | `rgba(` | unclassified |
| match.html | 872 | `band` | `rgba(` | unclassified |
| match.html | 873 | `chiptext` | `#f2f5fa` | unclassified |
| match.html | 873 | `passok` | `#3ddc97` | unclassified |
| match.html | 873 | `passfail` | `#ff6b63` | unclassified |
| match.html | 873 | `chipbg` | `rgba(` | unclassified |
| match.html | 874 | `pitch` | `#f0ead6` | unclassified |
| match.html | 874 | `line` | `#888` | unclassified |
| match.html | 874 | `linestrong` | `#666` | unclassified |
| match.html | 875 | `text` | `#333` | unclassified |
| match.html | 875 | `band` | `rgba(` | unclassified |
| match.html | 875 | `band` | `rgba(` | unclassified |
| match.html | 876 | `chiptext` | `#fff` | unclassified |
| match.html | 876 | `passok` | `#12855a` | unclassified |
| match.html | 876 | `passfail` | `#cc4038` | unclassified |
| match.html | 876 | `chipbg` | `rgba(` | unclassified |
| match.html | 1008 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1031 | `grad` | `rgba(` | unclassified |
| match.html | 1031 | `grad` | `rgba(` | unclassified |
| match.html | 1031 | `grad` | `rgba(` | unclassified |
| match.html | 1034 | `?` | `rgba(` | unclassified |
| match.html | 1036 | `col` | `#555` | unclassified |
| match.html | 1036 | `col` | `#555` | unclassified |
| match.html | 1036 | `col` | `#444` | unclassified |
| match.html | 1036 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1036 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1069 | `strokestyle` | `#e2b877` | canvas-stroke |
| match.html | 1070 | `color` | `#1f5b6f` | ink-or-marker-fill |
| match.html | 1070 | `color` | `#e2b877` | ink-or-marker-fill |
| match.html | 1072 | `rgb` | `rgba(` | unclassified |
| match.html | 1097 | `?` | `#22e39a` | unclassified |
| match.html | 1097 | `?` | `#0f7a52` | unclassified |
| match.html | 1097 | `fail` | `#ff5a5a` | unclassified |
| match.html | 1097 | `fail` | `#bf3535` | unclassified |
| match.html | 1098 | `goal` | `#f0a5ff` | unclassified |
| match.html | 1098 | `goal` | `#a1279b` | unclassified |
| match.html | 1098 | `blocked` | `#a78bfa` | unclassified |
| match.html | 1098 | `blocked` | `#6641cf` | unclassified |
| match.html | 1099 | `post` | `#ffc93c` | unclassified |
| match.html | 1099 | `post` | `#9a6b00` | unclassified |
| match.html | 1178 | `netcolor` | `#2563eb` | unclassified |
| match.html | 1178 | `poscolors` | `#d4a017` | unclassified |
| match.html | 1178 | `netcolor` | `#2563eb` | unclassified |
| match.html | 1178 | `netcolor` | `#2563eb` | unclassified |
| match.html | 1178 | `netcolor` | `#2563eb` | unclassified |
| match.html | 1178 | `dmc` | `#0d9488` | unclassified |
| match.html | 1178 | `dmc` | `#16a34a` | unclassified |
| match.html | 1178 | `dmc` | `#16a34a` | unclassified |
| match.html | 1178 | `dmc` | `#16a34a` | unclassified |
| match.html | 1178 | `amc` | `#84cc16` | unclassified |
| match.html | 1178 | `amc` | `#84cc16` | unclassified |
| match.html | 1178 | `amc` | `#84cc16` | unclassified |
| match.html | 1178 | `amr` | `#ef4444` | unclassified |
| match.html | 1178 | `amr` | `#ef4444` | unclassified |
| match.html | 1178 | `amr` | `#ef4444` | unclassified |
| match.html | 1178 | `sub` | `#9ca3af` | unclassified |
| match.html | 1178 | `sub` | `#9ca3af` | unclassified |
| match.html | 1178 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1189 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1189 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1191 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1191 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1193 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1200 | `col` | `#9ca3af` | unclassified |
| match.html | 1210 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1212 | `fillstyle` | `#c00` | canvas-fill |
| match.html | 1212 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1214 | `?` | `rgba(` | unclassified |
| match.html | 1222 | `poscolors` | `#d4a017` | unclassified |
| match.html | 1222 | `poscolors` | `#2563eb` | unclassified |
| match.html | 1222 | `poscolors` | `#2563eb` | unclassified |
| match.html | 1222 | `poscolors` | `#2563eb` | unclassified |
| match.html | 1222 | `dmc` | `#0d9488` | unclassified |
| match.html | 1222 | `dmc` | `#16a34a` | unclassified |
| match.html | 1222 | `dmc` | `#16a34a` | unclassified |
| match.html | 1222 | `dmc` | `#16a34a` | unclassified |
| match.html | 1222 | `amc` | `#84cc16` | unclassified |
| match.html | 1222 | `amc` | `#84cc16` | unclassified |
| match.html | 1222 | `amc` | `#84cc16` | unclassified |
| match.html | 1222 | `amr` | `#ef4444` | unclassified |
| match.html | 1222 | `amr` | `#ef4444` | unclassified |
| match.html | 1222 | `amr` | `#ef4444` | unclassified |
| match.html | 1222 | `poscolors` | `#d4a017` | unclassified |
| match.html | 1222 | `poscolors` | `#2563eb` | unclassified |
| match.html | 1222 | `dmc` | `#16a34a` | unclassified |
| match.html | 1222 | `amr` | `#ef4444` | unclassified |
| match.html | 1223 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1225 | `fillstyle` | `#333` | canvas-fill |
| match.html | 1225 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1225 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1232 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1232 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1232 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1233 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1235 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1248 | `scale` | `grey` | unclassified |
| match.html | 1250 | `col` | `rgb(` | unclassified |
| match.html | 1262 | `innerhtml` | `#2563eb` | unclassified |
| match.html | 1262 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1262 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1262 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1275 | `?` | `rgba(` | unclassified |
| match.html | 1275 | `?` | `rgba(` | unclassified |
| match.html | 1275 | `?` | `rgba(` | unclassified |
| match.html | 1275 | `?` | `rgba(` | unclassified |
| match.html | 1277 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1277 | `strokestyle` | `rgba(` | canvas-stroke |
| match.html | 1278 | `strokestyle` | `#5aa9ff` | canvas-stroke |
| match.html | 1279 | `fillstyle` | `#e2b877` | canvas-fill |
| match.html | 1281 | `color` | `#e2b877` | ink-or-marker-fill |
| match.html | 1281 | `color` | `#5aa9ff` | ink-or-marker-fill |
| match.html | 1281 | `color` | `#e2b877` | ink-or-marker-fill |
| match.html | 1281 | `color` | `#5aa9ff` | ink-or-marker-fill |
| match.html | 1299 | `strokestyle` | `#2563eb` | canvas-stroke |
| match.html | 1299 | `strokestyle` | `#2563eb` | canvas-stroke |
| match.html | 1311 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1311 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1313 | `strokestyle` | `#e2b877` | canvas-stroke |
| match.html | 1313 | `strokestyle` | `#5aa9ff` | canvas-stroke |
| match.html | 1313 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 1320 | `innerhtml` | `#dca014` | unclassified |
| match.html | 1320 | `innerhtml` | `#e03000` | unclassified |
| match.html | 1350 | `dominance` | `red` | unclassified |
| match.html | 1393 | `color` | `#5aa9ff` | ink-or-marker-fill |
| match.html | 1502 | `fill` | `rgba(` | ink-or-marker-fill |
| match.html | 1502 | `fill` | `rgba(` | ink-or-marker-fill |
| match.html | 1504 | `team` | `#2563eb` | unclassified |
| match.html | 1507 | `?` | `Transparent` | unclassified |
| match.html | 1508 | `fill` | `transparent` | ink-or-marker-fill |
| match.html | 1569 | `stroke` | `#6b7280` | marker-stroke/axis |
| match.html | 1571 | `col` | `#6b7280` | unclassified |
| match.html | 1573 | `fill` | `transparent` | ink-or-marker-fill |
| match.html | 1581 | `teams` | `grey` | unclassified |
| match.html | 1582 | `background` | `#6b7280` | ground/surface |
| match.html | 1800 | `rescolors` | `#16a34a` | unclassified |
| match.html | 1800 | `rescolors` | `#ca8a04` | unclassified |
| match.html | 1800 | `rescolors` | `#dc2626` | unclassified |
| match.html | 1801 | `stroke` | `#fff` | marker-stroke/axis |
| match.html | 1815 | `color` | `#16a34a` | ink-or-marker-fill |
| match.html | 1815 | `color` | `#ca8a04` | ink-or-marker-fill |
| match.html | 1815 | `color` | `#dc2626` | ink-or-marker-fill |
| match.html | 2313 | `?` | `#faf8f3` | unclassified |
| match.html | 2314 | `panel` | `#f4f1e9` | unclassified |
| match.html | 2315 | `text` | `#16191f` | unclassified |
| match.html | 2316 | `muted` | `#4a5262` | unclassified |
| match.html | 2317 | `label` | `#6b7280` | unclassified |
| match.html | 2318 | `border` | `rgba(` | border |
| match.html | 2319 | `rule` | `rgba(` | unclassified |
| match.html | 2320 | `dim` | `#4a5262` | unclassified |
| match.html | 2683 | `?` | `red` | unclassified |
| match.html | 2684 | `?` | `red` | unclassified |
| match.html | 2874 | `fillstyle` | `rgba(` | canvas-fill |
| match.html | 3104 | `innerhtml` | `#9728` | unclassified |
| match.html | 3104 | `innerhtml` | `#127769` | unclassified |
| match.html | 3203 | `?` | `#4ade80` | unclassified |
| match.html | 3204 | `?` | `#f97316` | unclassified |
| match.html | 3208 | `?` | `red` | unclassified |
| match.html | 3208 | `?` | `green` | unclassified |
| match.html | 3215 | `background` | `rgba(` | ground/surface |
| match.html | 3216 | `color` | `rgb(` | ink-or-marker-fill |
| match.html | 3218 | `background` | `rgba(` | ground/surface |
| match.html | 3218 | `background` | `rgba(` | ground/surface |
| match.html | 3218 | `background` | `rgba(` | ground/surface |
| methodology.html | 15 | `?` | `green` | unclassified |
| methodology.html | 15 | `?` | `red` | unclassified |
| methodology.html | 17 | `?` | `blue` | unclassified |
| methodology.html | 20 | `?` | `#9c6b1e` | unclassified |
| methodology.html | 20 | `?` | `#8a5e1a` | unclassified |
| methodology.html | 22 | `--amber` | `#8a5e1a` | token-definition |
| methodology.html | 22 | `--amber-dim` | `rgba(` | token-definition |
| methodology.html | 22 | `--amber-dim` | `rgba(` | token-definition |
| methodology.html | 23 | `--blue` | `#2f6aa8` | token-definition |
| methodology.html | 26 | `--bg` | `#0e1219` | token-definition |
| methodology.html | 26 | `--panel` | `#161b24` | token-definition |
| methodology.html | 26 | `--panel` | `#1e242e` | token-definition |
| methodology.html | 27 | `--line` | `#272e3a` | token-definition |
| methodology.html | 27 | `--line` | `#3a4351` | token-definition |
| methodology.html | 28 | `--text` | `#f2f5fa` | token-definition |
| methodology.html | 28 | `--dim` | `#b6c2d4` | token-definition |
| methodology.html | 28 | `--dim` | `#8b98ab` | token-definition |
| methodology.html | 29 | `--amber` | `#e2b877` | token-definition |
| methodology.html | 29 | `--amber-dim` | `rgba(` | token-definition |
| methodology.html | 29 | `--amber-dim` | `rgba(` | token-definition |
| methodology.html | 30 | `--green` | `#3ddc97` | token-definition |
| methodology.html | 30 | `--red` | `#ff5f56` | token-definition |
| methodology.html | 30 | `--blue` | `#5aa9ff` | token-definition |
| methodology.html | 87 | `border` | `transparent` | border |
| methodology.html | 88 | `border` | `transparent` | border |
| methodology.html | 90 | `border` | `transparent` | border |
| methodology.html | 98 | `background` | `#fff` | ground/surface |
| methodology.html | 98 | `color` | `#000` | ink-or-marker-fill |
| methodology.html | 100 | `color` | `#ff5f56` | ink-or-marker-fill |
| methodology.html | 115 | `class` | `#9790` | unclassified |
| methodology.html | 191 | `?` | `transparent` | unclassified |
| methodology.html | 297 | `?` | `transparent` | unclassified |
| model-lab.html | 14 | `--bg` | `#e9e5dc` | token-definition |
| model-lab.html | 14 | `--paper` | `#fffdf6` | token-definition |
| model-lab.html | 14 | `--ink` | `#101820` | token-definition |
| model-lab.html | 14 | `--muted` | `#45535e` | token-definition |
| model-lab.html | 14 | `--line` | `#aaa394` | token-definition |
| model-lab.html | 14 | `--acid` | `#c9431d` | token-definition |
| model-lab.html | 14 | `--cyan` | `#006f79` | token-definition |
| model-lab.html | 14 | `--green` | `#086843` | token-definition |
| model-lab.html | 14 | `--amber` | `#8b5500` | token-definition |
| model-lab.html | 14 | `--red` | `#a82424` | token-definition |
| model-lab.html | 15 | `--bg` | `#081017` | token-definition |
| model-lab.html | 15 | `--paper` | `#111d26` | token-definition |
| model-lab.html | 15 | `--ink` | `#f7f7f1` | token-definition |
| model-lab.html | 15 | `--muted` | `#bac4cb` | token-definition |
| model-lab.html | 15 | `--line` | `#52616d` | token-definition |
| model-lab.html | 15 | `--acid` | `#ff754a` | token-definition |
| model-lab.html | 15 | `--cyan` | `#64d7df` | token-definition |
| model-lab.html | 15 | `--green` | `#5add9f` | token-definition |
| model-lab.html | 15 | `--amber` | `#ffc566` | token-definition |
| model-lab.html | 15 | `--red` | `#ff7972` | token-definition |
| model-lab.html | 16 | `background-image` | `transparent` | ramp |
| model-lab.html | 16 | `background-image` | `transparent` | ramp |
| model-lab.html | 16 | `background-image` | `transparent` | ramp |
| model-lab.html | 16 | `background-image` | `transparent` | ramp |
| model-lab.html | 17 | `outline` | `transparent` | border |
| model-lab.html | 19 | `color` | `#fff` | ink-or-marker-fill |
| model-lab.html | 19 | `background` | `transparent` | ground/surface |
| model-lab.html | 22 | `background` | `transparent` | ground/surface |
| model-lab.html | 23 | `background` | `transparent` | ramp |
| model-lab.html | 23 | `background` | `transparent` | ramp |
| model-lab.html | 23 | `background` | `transparent` | ramp |
| model-lab.html | 23 | `background` | `transparent` | ramp |
| model-lab.html | 25 | `background` | `transparent` | ground/surface |
| model-lab.html | 25 | `background` | `transparent` | ground/surface |
| model-lab.html | 25 | `background` | `transparent` | ground/surface |
| model-lab.html | 25 | `background` | `transparent` | ground/surface |
| model-lab.html | 64 | `class` | `Teal` | unclassified |
| model-lab.html | 64 | `teal` | `Orange` | unclassified |
| model-review.html | 14 | `--bg` | `#f1efe8` | token-definition |
| model-review.html | 14 | `--paper` | `#fbfaf6` | token-definition |
| model-review.html | 14 | `--ink` | `#171b22` | token-definition |
| model-review.html | 14 | `--muted` | `#667080` | token-definition |
| model-review.html | 14 | `--faint` | `#929aa6` | token-definition |
| model-review.html | 14 | `--line` | `#d8d3c8` | token-definition |
| model-review.html | 14 | `--gold` | `#96681c` | token-definition |
| model-review.html | 14 | `--gold` | `#d9ac62` | token-definition |
| model-review.html | 14 | `--green` | `#087854` | token-definition |
| model-review.html | 14 | `--red` | `#ba3f38` | token-definition |
| model-review.html | 14 | `--blue` | `#2766b0` | token-definition |
| model-review.html | 15 | `--bg` | `#0b1017` | token-definition |
| model-review.html | 15 | `--paper` | `#141a23` | token-definition |
| model-review.html | 15 | `--ink` | `#f3f5f8` | token-definition |
| model-review.html | 15 | `--muted` | `#aeb9c8` | token-definition |
| model-review.html | 15 | `--faint` | `#778395` | token-definition |
| model-review.html | 15 | `--line` | `#2a323e` | token-definition |
| model-review.html | 15 | `--gold` | `#edbd70` | token-definition |
| model-review.html | 15 | `--gold` | `#8e6326` | token-definition |
| model-review.html | 15 | `--green` | `#42d89c` | token-definition |
| model-review.html | 15 | `--red` | `#ff746b` | token-definition |
| model-review.html | 15 | `--blue` | `#70b4ff` | token-definition |
| model-review.html | 16 | `background-image` | `transparent` | ramp |
| model-review.html | 16 | `background-image` | `transparent` | ramp |
| model-review.html | 16 | `background-image` | `transparent` | ramp |
| model-review.html | 16 | `background-image` | `transparent` | ramp |
| model-review.html | 16 | `background-image` | `transparent` | ramp |
| model-review.html | 23 | `background` | `transparent` | ground/surface |
| players.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| players.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| players.html | 20 | `--elite` | `#16a34a` | token-definition |
| players.html | 20 | `--above` | `#4ade80` | token-definition |
| players.html | 20 | `--avg` | `#d4a017` | token-definition |
| players.html | 20 | `--below` | `#f97316` | token-definition |
| players.html | 20 | `--poor` | `#dc2626` | token-definition |
| players.html | 21 | `--shadow` | `rgba(` | token-definition |
| players.html | 24 | `--accent` | `#D8B384` | token-definition |
| players.html | 24 | `--accent-dim` | `rgba(` | token-definition |
| players.html | 24 | `--accent-dim` | `rgba(` | token-definition |
| players.html | 25 | `--bg` | `#101319` | token-definition |
| players.html | 25 | `--bg` | `#191d25` | token-definition |
| players.html | 25 | `--bg` | `#222732` | token-definition |
| players.html | 26 | `--surface` | `rgba(` | token-definition |
| players.html | 26 | `--surface` | `rgba(` | token-definition |
| players.html | 27 | `--border` | `#272b35` | token-definition |
| players.html | 27 | `--border` | `#3a3f4b` | token-definition |
| players.html | 28 | `--text` | `#f4f6fb` | token-definition |
| players.html | 28 | `--text` | `#c3cde2` | token-definition |
| players.html | 28 | `--text` | `#9aa7c2` | token-definition |
| players.html | 29 | `--elite` | `#34d399` | token-definition |
| players.html | 29 | `--above` | `#6ee7a8` | token-definition |
| players.html | 29 | `--avg` | `#fbbf24` | token-definition |
| players.html | 29 | `--below` | `#fb923c` | token-definition |
| players.html | 29 | `--poor` | `#f87171` | token-definition |
| players.html | 30 | `--shadow` | `rgba(` | token-definition |
| players.html | 37 | `color` | `#12141a` | ink-or-marker-fill |
| players.html | 72 | `background` | `rgba(` | ground/surface |
| players.html | 116 | `color` | `#12141a` | ink-or-marker-fill |
| players.html | 228 | `background` | `rgba(` | ground/surface |
| players.html | 229 | `box-shadow` | `rgba(` | overlay/glow |
| players.html | 232 | `box-shadow` | `rgba(` | overlay/glow |
| players.html | 236 | `selects` | `white` | unclassified |
| players.html | 237 | `?` | `white` | unclassified |
| players.html | 237 | `?` | `white` | unclassified |
| players.html | 239 | `background-color` | `#1a1d24` | ground/surface |
| players.html | 239 | `color` | `#f4f6fb` | ink-or-marker-fill |
| players.html | 240 | `background-color` | `#1a1d24` | ground/surface |
| players.html | 240 | `color` | `#f4f6fb` | ink-or-marker-fill |
| players.html | 245 | `color` | `#d4a017` | ink-or-marker-fill |
| players.html | 259 | `border` | `transparent` | border |
| players.html | 376 | `?` | `Red` | unclassified |
| players.html | 381 | `pal` | `#22e39a` | unclassified |
| players.html | 381 | `fail` | `#ff5a5a` | unclassified |
| players.html | 381 | `pal` | `#22e39a` | unclassified |
| players.html | 381 | `prog` | `#4d9fff` | unclassified |
| players.html | 381 | `carry` | `#ffc93c` | unclassified |
| players.html | 381 | `box` | `#f0a5ff` | unclassified |
| players.html | 850 | `passing` | `#2f80ed` | unclassified |
| players.html | 850 | `creation` | `#00a896` | unclassified |
| players.html | 850 | `shooting` | `#e63956` | unclassified |
| players.html | 850 | `carrying` | `#f2b134` | unclassified |
| players.html | 850 | `defending` | `#7656d6` | unclassified |
| players.html | 850 | `aerial` | `#9b5de5` | unclassified |
| players.html | 850 | `discipline` | `#ef8354` | unclassified |
| players.html | 850 | `tempo` | `#00b4d8` | unclassified |
| players.html | 850 | `tempo` | `#36b37e` | unclassified |
| players.html | 850 | `tempo` | `#d97706` | unclassified |
| players.html | 850 | `tempo` | `#b94d8c` | unclassified |
| players.html | 850 | `goalkeeping` | `#3a86ff` | unclassified |
| players.html | 851 | `?` | `#2f80ed` | unclassified |
| players.html | 851 | `?` | `#00a896` | unclassified |
| players.html | 851 | `?` | `#e63956` | unclassified |
| players.html | 851 | `?` | `#f2b134` | unclassified |
| players.html | 851 | `?` | `#7656d6` | unclassified |
| players.html | 864 | `fill` | `#fff` | ink-or-marker-fill |
| players.html | 864 | `stroke` | `rgba(` | marker-stroke/axis |
| players.html | 946 | `?` | `#cbd5e1` | unclassified |
| players.html | 957 | `?` | `#a78bfa` | unclassified |
| players.html | 957 | `?` | `#a78bfa` | unclassified |
| players.html | 961 | `?` | `#22d3ee` | unclassified |
| players.html | 961 | `?` | `#22d3ee` | unclassified |
| players.html | 962 | `?` | `#f472b6` | unclassified |
| players.html | 962 | `?` | `#f472b6` | unclassified |
| players.html | 1615 | `fill` | `transparent` | ink-or-marker-fill |
| players.html | 1627 | `?` | `#a78bfa` | unclassified |
| players.html | 1627 | `?` | `#a78bfa` | unclassified |
| players.html | 1659 | `?` | `#34d399` | unclassified |
| players.html | 1659 | `?` | `#34d399` | unclassified |
| players.html | 1672 | `clearance` | `#a78bfa` | unclassified |
| players.html | 1673 | `challenge` | `#f472b6` | unclassified |
| players.html | 1673 | `save` | `#22d3ee` | unclassified |
| players.html | 1806 | `background` | `transparent` | ground/surface |
| players.html | 1989 | `?` | `#a78bfa` | unclassified |
| players.html | 1992 | `leg` | `#a78bfa` | unclassified |
| search.html | 14 | `?` | `blue` | unclassified |
| search.html | 16 | `--amber` | `#9c6b1e` | token-definition |
| search.html | 16 | `--amber-dim` | `rgba(` | token-definition |
| search.html | 16 | `--amber-dim` | `rgba(` | token-definition |
| search.html | 17 | `--blue` | `#2f6aa8` | token-definition |
| search.html | 20 | `--bg` | `#0e1219` | token-definition |
| search.html | 20 | `--panel` | `#161b24` | token-definition |
| search.html | 20 | `--panel` | `#1e242e` | token-definition |
| search.html | 21 | `--line` | `#272e3a` | token-definition |
| search.html | 21 | `--line` | `#3a4351` | token-definition |
| search.html | 22 | `--text` | `#f2f5fa` | token-definition |
| search.html | 22 | `--dim` | `#b6c2d4` | token-definition |
| search.html | 22 | `--dim` | `#8b98ab` | token-definition |
| search.html | 23 | `--amber` | `#e2b877` | token-definition |
| search.html | 23 | `--amber-dim` | `rgba(` | token-definition |
| search.html | 23 | `--amber-dim` | `rgba(` | token-definition |
| search.html | 24 | `--green` | `#3ddc97` | token-definition |
| search.html | 24 | `--red` | `#ff5f56` | token-definition |
| search.html | 24 | `--blue` | `#5aa9ff` | token-definition |
| search.html | 128 | `background` | `transparent` | ground/surface |
| search.html | 156 | `selects` | `white` | unclassified |
| search.html | 157 | `?` | `white` | unclassified |
| search.html | 157 | `?` | `white` | unclassified |
| search.html | 159 | `background-color` | `#1a1d24` | ground/surface |
| search.html | 159 | `color` | `#f4f6fb` | ink-or-marker-fill |
| search.html | 160 | `background-color` | `#1a1d24` | ground/surface |
| search.html | 160 | `color` | `#f4f6fb` | ink-or-marker-fill |
| sequences.html | 17 | `--amber` | `#9c6b1e` | token-definition |
| sequences.html | 17 | `--amber-dim` | `rgba(` | token-definition |
| sequences.html | 17 | `--amber-dim` | `rgba(` | token-definition |
| sequences.html | 18 | `--blue` | `#2f6aa8` | token-definition |
| sequences.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| sequences.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| sequences.html | 20 | `--nb` | `#2f6aa8` | token-definition |
| sequences.html | 20 | `--shadow` | `rgba(` | token-definition |
| sequences.html | 24 | `?` | `red` | unclassified |
| sequences.html | 27 | `--accent` | `#9c6b1e` | token-definition |
| sequences.html | 29 | `--bg` | `#0e1219` | token-definition |
| sequences.html | 29 | `--panel` | `#161b24` | token-definition |
| sequences.html | 29 | `--panel` | `#1e242e` | token-definition |
| sequences.html | 30 | `--line` | `#272e3a` | token-definition |
| sequences.html | 30 | `--line` | `#3a4351` | token-definition |
| sequences.html | 31 | `--text` | `#f2f5fa` | token-definition |
| sequences.html | 31 | `--dim` | `#b6c2d4` | token-definition |
| sequences.html | 31 | `--dim` | `#8b98ab` | token-definition |
| sequences.html | 32 | `--amber` | `#e2b877` | token-definition |
| sequences.html | 32 | `--amber-dim` | `rgba(` | token-definition |
| sequences.html | 32 | `--amber-dim` | `rgba(` | token-definition |
| sequences.html | 33 | `--green` | `#3ddc97` | token-definition |
| sequences.html | 33 | `--red` | `#ff5f56` | token-definition |
| sequences.html | 33 | `--blue` | `#5aa9ff` | token-definition |
| sequences.html | 35 | `--accent` | `#D8B384` | token-definition |
| sequences.html | 35 | `--accent-dim` | `rgba(` | token-definition |
| sequences.html | 35 | `--accent-dim` | `rgba(` | token-definition |
| sequences.html | 36 | `--bg` | `#101319` | token-definition |
| sequences.html | 36 | `--bg` | `#191d25` | token-definition |
| sequences.html | 36 | `--bg` | `#222732` | token-definition |
| sequences.html | 36 | `--surface` | `rgba(` | token-definition |
| sequences.html | 36 | `--surface` | `rgba(` | token-definition |
| sequences.html | 37 | `--border` | `#2c313d` | token-definition |
| sequences.html | 37 | `--border` | `#414957` | token-definition |
| sequences.html | 37 | `--text` | `#f4f6fb` | token-definition |
| sequences.html | 37 | `--text` | `#c3cde2` | token-definition |
| sequences.html | 37 | `--text` | `#9aa7c2` | token-definition |
| sequences.html | 38 | `--elite` | `#34d399` | token-definition |
| sequences.html | 38 | `--above` | `#6ee7a8` | token-definition |
| sequences.html | 38 | `--avg` | `#fbbf24` | token-definition |
| sequences.html | 38 | `--below` | `#fb923c` | token-definition |
| sequences.html | 38 | `--poor` | `#f87171` | token-definition |
| sequences.html | 38 | `--nb` | `#5aa0ff` | token-definition |
| sequences.html | 38 | `--shadow` | `rgba(` | token-definition |
| sequences.html | 43 | `color` | `#12141a` | ink-or-marker-fill |
| sequences.html | 49 | `background-image` | `transparent` | ramp |
| sequences.html | 49 | `background-image` | `transparent` | ramp |
| sequences.html | 87 | `background` | `rgba(` | ground/surface |
| sequences.html | 102 | `selects` | `white` | unclassified |
| sequences.html | 103 | `?` | `white` | unclassified |
| sequences.html | 103 | `?` | `white` | unclassified |
| sequences.html | 105 | `background-color` | `#1a1d24` | ground/surface |
| sequences.html | 105 | `color` | `#f4f6fb` | ink-or-marker-fill |
| sequences.html | 106 | `background-color` | `#1a1d24` | ground/surface |
| sequences.html | 106 | `color` | `#f4f6fb` | ink-or-marker-fill |
| sequences.html | 110 | `color` | `#e2b877` | ink-or-marker-fill |
| sequences.html | 115 | `color` | `#b9c3db` | ink-or-marker-fill |
| sequences.html | 117 | `color` | `#e2b877` | ink-or-marker-fill |
| sequences.html | 119 | `color` | `#b9c3db` | ink-or-marker-fill |
| sequences.html | 120 | `color` | `#e8eef6` | ink-or-marker-fill |
| sequences.html | 121 | `color` | `#9aa7c2` | ink-or-marker-fill |
| sequences.html | 193 | `?` | `Red` | unclassified |
| sequences.html | 471 | `class` | `blue` | unclassified |
| shell.css | 61 | `background` | `transparent` | ground/surface |
| shell.css | 61 | `background` | `transparent` | ground/surface |
| shell.css | 73 | `background` | `transparent` | ground/surface |
| shell.css | 114 | `background-image` | `rgba(` | ramp |
| shell.css | 114 | `background-image` | `transparent` | ramp |
| shell.css | 116 | `background-image` | `rgba(` | ramp |
| shell.css | 116 | `background-image` | `transparent` | ramp |
| shell.css | 119 | `?` | `rgba(` | ramp |
| shell.css | 119 | `?` | `transparent` | ramp |
| shell.css | 120 | `?` | `rgba(` | ramp |
| shell.css | 120 | `?` | `transparent` | ramp |
| shell.css | 148 | `border` | `transparent` | border |
| shell.css | 148 | `border-top-color` | `currentColor` | border |
| shell.css | 154 | `box-shadow` | `rgba(` | overlay/glow |
| teams.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| teams.html | 19 | `--accent-dim` | `rgba(` | token-definition |
| teams.html | 20 | `--elite` | `#16a34a` | token-definition |
| teams.html | 20 | `--above` | `#4ade80` | token-definition |
| teams.html | 20 | `--avg` | `#d4a017` | token-definition |
| teams.html | 20 | `--below` | `#f97316` | token-definition |
| teams.html | 20 | `--poor` | `#dc2626` | token-definition |
| teams.html | 21 | `--style-hi` | `#2563eb` | token-definition |
| teams.html | 21 | `--style-low` | `#d97706` | token-definition |
| teams.html | 21 | `--shadow` | `rgba(` | token-definition |
| teams.html | 22 | `--accent` | `#D8B384` | token-definition |
| teams.html | 22 | `--accent-dim` | `rgba(` | token-definition |
| teams.html | 22 | `--accent-dim` | `rgba(` | token-definition |
| teams.html | 23 | `--bg` | `#101319` | token-definition |
| teams.html | 23 | `--bg` | `#191d25` | token-definition |
| teams.html | 23 | `--bg` | `#222732` | token-definition |
| teams.html | 23 | `--surface` | `rgba(` | token-definition |
| teams.html | 23 | `--surface` | `rgba(` | token-definition |
| teams.html | 24 | `--border` | `#2c313d` | token-definition |
| teams.html | 24 | `--border` | `#414957` | token-definition |
| teams.html | 24 | `--text` | `#f4f6fb` | token-definition |
| teams.html | 24 | `--text` | `#c3cde2` | token-definition |
| teams.html | 24 | `--text` | `#9aa7c2` | token-definition |
| teams.html | 25 | `--elite` | `#34d399` | token-definition |
| teams.html | 25 | `--above` | `#6ee7a8` | token-definition |
| teams.html | 25 | `--avg` | `#fbbf24` | token-definition |
| teams.html | 25 | `--below` | `#fb923c` | token-definition |
| teams.html | 25 | `--poor` | `#f87171` | token-definition |
| teams.html | 26 | `--style-hi` | `#60a5fa` | token-definition |
| teams.html | 26 | `--style-low` | `#fbbf24` | token-definition |
| teams.html | 26 | `--shadow` | `rgba(` | token-definition |
| teams.html | 31 | `color` | `#12141a` | ink-or-marker-fill |
| teams.html | 37 | `background-image` | `transparent` | ramp |
| teams.html | 37 | `background-image` | `transparent` | ramp |
| teams.html | 133 | `box-shadow` | `rgba(` | overlay/glow |
| teams.html | 165 | `color` | `#0d0f14` | ink-or-marker-fill |
| teams.html | 169 | `selects` | `white` | unclassified |
| teams.html | 170 | `?` | `white` | unclassified |
| teams.html | 170 | `?` | `white` | unclassified |
| teams.html | 172 | `background-color` | `#1a1d24` | ground/surface |
| teams.html | 172 | `color` | `#f4f6fb` | ink-or-marker-fill |
| teams.html | 173 | `background-color` | `#1a1d24` | ground/surface |
| teams.html | 173 | `color` | `#f4f6fb` | ink-or-marker-fill |
| teams.html | 205 | `color` | `#d4a017` | ink-or-marker-fill |
| teams.html | 242 | `?` | `Red` | unclassified |
| teams.html | 247 | `tpal` | `#22e39a` | unclassified |
| teams.html | 247 | `fail` | `#ff5a5a` | unclassified |
| teams.html | 247 | `tpal` | `#22e39a` | unclassified |
| teams.html | 247 | `prog` | `#4d9fff` | unclassified |
| teams.html | 247 | `carry` | `#ffc93c` | unclassified |
| teams.html | 247 | `box` | `#f0a5ff` | unclassified |
| teams.html | 674 | `?` | `green` | unclassified |
| teams.html | 674 | `?` | `red` | unclassified |
| teams.html | 726 | `blocked` | `#a78bfa` | unclassified |
| teams.html | 813 | `view` | `green` | unclassified |
| teams.html | 813 | `view` | `red` | unclassified |
| teams.html | 813 | `view` | `green` | unclassified |
| teams.html | 814 | `?` | `blue` | unclassified |
| teams.html | 814 | `?` | `yellow` | unclassified |
| teams.html | 865 | `background` | `#f5a623` | ramp |
| teams.html | 865 | `background` | `rgba(` | ramp |
| teams.html | 895 | `clearance` | `#a78bfa` | unclassified |
| teams.html | 895 | `challenge` | `#f472b6` | unclassified |
| teams.html | 919 | `box` | `#a78bfa` | unclassified |
| teams.html | 922 | `fill` | `transparent` | ink-or-marker-fill |
| teams.html | 954 | `fill` | `rgb(` | ink-or-marker-fill |
| teams.html | 995 | `background` | `transparent` | ground/surface |
| teams.html | 1126 | `?` | `Blue` | unclassified |
| theme.css | 6 | `--bg` | `#f5f4f1` | token-definition |
| theme.css | 6 | `?` | `white` | unclassified |
| theme.css | 7 | `?` | `#f4f2ea` | unclassified |
| theme.css | 7 | `?` | `#f4f2ec` | unclassified |
| theme.css | 8 | `?` | `#f4f2ec` | unclassified |
| theme.css | 45 | `--bg` | `#faf8f3` | token-definition |
| theme.css | 46 | `?` | `#f4f1e9` | token-definition |
| theme.css | 47 | `?` | `#eceadf` | token-definition |
| theme.css | 48 | `--surface` | `rgba(` | token-definition |
| theme.css | 49 | `?` | `#e8e4d8` | token-definition |
| theme.css | 50 | `--border` | `#ded9cd` | token-definition |
| theme.css | 51 | `?` | `#b9b2a1` | token-definition |
| theme.css | 52 | `--text` | `#16191f` | token-definition |
| theme.css | 53 | `?` | `#4a5262` | token-definition |
| theme.css | 54 | `?` | `#6b7280` | token-definition |
| theme.css | 55 | `?` | `#9aa0aa` | token-definition |
| theme.css | 56 | `--green` | `#0f7a52` | token-definition |
| theme.css | 57 | `--red-bright` | `#c23b34` | token-definition |
| theme.css | 58 | `--accent` | `#EF0107` | token-definition |
| theme.css | 68 | `?` | `red` | unclassified |
| validation.html | 12 | `?` | `green` | unclassified |
| validation.html | 12 | `?` | `red` | unclassified |
| validation.html | 14 | `?` | `blue` | unclassified |
| validation.html | 17 | `?` | `#9a6f2a` | unclassified |
| validation.html | 18 | `?` | `#8a5e1a` | unclassified |
| validation.html | 19 | `--amber` | `#8a5e1a` | token-definition |
| validation.html | 19 | `--amber-dim` | `rgba(` | token-definition |
| validation.html | 19 | `--amber-dim` | `rgba(` | token-definition |
| validation.html | 20 | `--blue` | `#2f6fd0` | token-definition |
| validation.html | 23 | `--bg` | `#0e1219` | token-definition |
| validation.html | 23 | `--panel` | `#161b24` | token-definition |
| validation.html | 23 | `--panel` | `#1e242e` | token-definition |
| validation.html | 23 | `--line` | `#272e3a` | token-definition |
| validation.html | 23 | `--line` | `#3a4351` | token-definition |
| validation.html | 24 | `--text` | `#f2f5fa` | token-definition |
| validation.html | 24 | `--dim` | `#b6c2d4` | token-definition |
| validation.html | 24 | `--dim` | `#8b98ab` | token-definition |
| validation.html | 25 | `--amber` | `#e2b877` | token-definition |
| validation.html | 25 | `--green` | `#3ddc97` | token-definition |
| validation.html | 25 | `--red` | `#ff5f56` | token-definition |
| validation.html | 25 | `--blue` | `#5aa9ff` | token-definition |
| validation.html | 25 | `--amber-dim` | `rgba(` | token-definition |
| validation.html | 25 | `--amber-dim` | `rgba(` | token-definition |
| validation.html | 65 | `color` | `#5aa9ff` | ink-or-marker-fill |
| validation.html | 65 | `border` | `rgba(` | border |
| validation.html | 66 | `color` | `#ff5f56` | ink-or-marker-fill |
| validation.html | 66 | `border` | `rgba(` | border |
| validation.html | 71 | `color` | `#ff5f56` | ink-or-marker-fill |
| validation.html | 83 | `innerhtml` | `#9728` | unclassified |
| validation.html | 83 | `innerhtml` | `#9789` | unclassified |
| validation.html | 83 | `innerhtml` | `#9728` | unclassified |
| validation.html | 219 | `?` | `White` | unclassified |
| validation.html | 220 | `?` | `White` | unclassified |
| validation.html | 272 | `?` | `transparent` | unclassified |
| writing-lab.html | 11 | `--ink` | `#121820` | token-definition |
| writing-lab.html | 11 | `--muted` | `#68717c` | token-definition |
| writing-lab.html | 11 | `--paper` | `#f2efe6` | token-definition |
| writing-lab.html | 11 | `--sheet` | `#fffdf7` | token-definition |
| writing-lab.html | 11 | `--line` | `#d8d1c2` | token-definition |
| writing-lab.html | 11 | `--red` | `#e14b2d` | token-definition |
| writing-lab.html | 11 | `--gold` | `#c79843` | token-definition |
| writing-lab.html | 11 | `--green` | `#176b51` | token-definition |
| writing-lab.html | 11 | `--blue` | `#315f78` | token-definition |
| writing-lab.html | 11 | `--shadow` | `rgba(` | token-definition |
| writing-lab.html | 12 | `--ink` | `#edf0e9` | token-definition |
| writing-lab.html | 12 | `--muted` | `#9da8ac` | token-definition |
| writing-lab.html | 12 | `--paper` | `#10151b` | token-definition |
| writing-lab.html | 12 | `--sheet` | `#171d24` | token-definition |
| writing-lab.html | 12 | `--line` | `#303944` | token-definition |
| writing-lab.html | 12 | `--red` | `#ff6848` | token-definition |
| writing-lab.html | 12 | `--gold` | `#e2b877` | token-definition |
| writing-lab.html | 12 | `--green` | `#4cc39b` | token-definition |
| writing-lab.html | 12 | `--blue` | `#72abc2` | token-definition |
| writing-lab.html | 12 | `--shadow` | `rgba(` | token-definition |
| writing-lab.html | 13 | `background-image` | `rgba(` | ramp |
| writing-lab.html | 13 | `background-image` | `rgba(` | ramp |
| writing-lab.html | 13 | `background-image` | `transparent` | ramp |
| writing-lab.html | 13 | `background-image` | `transparent` | ramp |
| writing-lab.html | 15 | `color` | `white` | ink-or-marker-fill |
| writing-lab.html | 16 | `background-color` | `#171d24` | ground/surface |
| writing-lab.html | 16 | `color` | `#edf0e9` | ink-or-marker-fill |
| writing-lab.html | 16 | `background-color` | `#171d24` | ground/surface |
| writing-lab.html | 16 | `color` | `#edf0e9` | ink-or-marker-fill |
| writing-lab.html | 16 | `background` | `transparent` | ground/surface |
| writing-lab.html | 16 | `background` | `transparent` | ground/surface |
| writing-lab.html | 17 | `background` | `transparent` | ground/surface |
| writing-lab.html | 21 | `background` | `transparent` | ground/surface |
| writing-lab.html | 22 | `background` | `transparent` | ramp |
| writing-lab.html | 22 | `background` | `transparent` | ramp |
| writing-lab.html | 78 | `fill` | `transparent` | ink-or-marker-fill |
| writing-lab.html | 78 | `stroke` | `currentColor` | marker-stroke/axis |

</details>

---

## 0.3 Role classification

Classified by the CSS property or SVG/canvas attribute each literal sits in, not by how it looks.

| Role | Live occurrences |
| --- | ---: |
| token-definition | 360 |
| unclassified | 275 |
| ground/surface | 117 |
| ink-or-marker-fill | 92 |
| ramp | 55 |
| border | 24 |
| canvas-fill | 24 |
| overlay/glow | 16 |
| canvas-stroke | 13 |
| marker-stroke/axis | 4 |

What matters for Phase 1:

- **`token-definition`** occurrences are the only literals that should survive. Everything else is a raw
  literal in a rule or a script string and has to become a token.
- The percentile ramp is already semantic in two files: `players.html` and `teams.html` both define
  `--elite / --above / --avg / --below / --poor` and resolve them through `tier(pct)`. That is a
  **diverging ramp keyed to percentile**, and it is the most reused data colour in the app.
- `match.html` carries a second, independent vocabulary (`--gold`, `--blue`) plus canvas paints that never
  touch a token.
- `gate.js` paints a hardcoded near-black shell and reads no token at all.

---

## 0.4 Dark-dependent tricks

**68 literal occurrences** in live surfaces only work because the ground is dark.

| File | Line | Property | Value | Why it breaks on cream |
| --- | ---: | --- | --- | --- |
| gate.js | 65 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| glossary.html | 111 | `selects` | `white` | white or near-white ink, invisible on cream |
| glossary.html | 112 | `?` | `white` | white or near-white ink, invisible on cream |
| glossary.html | 112 | `?` | `white` | white or near-white ink, invisible on cream |
| guide.html | 151 | `background` | `#fff` | white or near-white ink, invisible on cream |
| index.html | 43 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| index.html | 58 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| insights.html | 101 | `selects` | `white` | white or near-white ink, invisible on cream |
| insights.html | 102 | `?` | `white` | white or near-white ink, invisible on cream |
| insights.html | 102 | `?` | `white` | white or near-white ink, invisible on cream |
| match.html | 35 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 41 | `?` | `white` | white or near-white ink, invisible on cream |
| match.html | 41 | `?` | `white` | white or near-white ink, invisible on cream |
| match.html | 41 | `?` | `white` | white or near-white ink, invisible on cream |
| match.html | 47 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 61 | `background` | `rgba(` | blend or opacity depth trick |
| match.html | 63 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 75 | `background` | `rgba(` | blend or opacity depth trick |
| match.html | 77 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 92 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 118 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 167 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 171 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 290 | `background` | `transparent` | blend or opacity depth trick |
| match.html | 290 | `background` | `transparent` | blend or opacity depth trick |
| match.html | 323 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 324 | `accent-color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 329 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 330 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 337 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 346 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 441 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 447 | `color` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 488 | `background` | `rgba(` | blend or opacity depth trick |
| match.html | 490 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 522 | `color` | `#8b95b5` | blend or opacity depth trick |
| match.html | 548 | `background` | `rgba(` | blend or opacity depth trick |
| match.html | 550 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 550 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| match.html | 559 | `background` | `rgba(` | blend or opacity depth trick |
| match.html | 569 | `background` | `rgba(` | blend or opacity depth trick |
| match.html | 876 | `chiptext` | `#fff` | white or near-white ink, invisible on cream |
| match.html | 1801 | `stroke` | `#fff` | white or near-white ink, invisible on cream |
| methodology.html | 98 | `background` | `#fff` | white or near-white ink, invisible on cream |
| model-lab.html | 19 | `color` | `#fff` | white or near-white ink, invisible on cream |
| model-lab.html | 19 | `background` | `transparent` | blend or opacity depth trick |
| players.html | 228 | `background` | `rgba(` | blend or opacity depth trick |
| players.html | 229 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| players.html | 232 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |
| players.html | 236 | `selects` | `white` | white or near-white ink, invisible on cream |
| players.html | 237 | `?` | `white` | white or near-white ink, invisible on cream |
| players.html | 237 | `?` | `white` | white or near-white ink, invisible on cream |
| players.html | 864 | `fill` | `#fff` | white or near-white ink, invisible on cream |
| search.html | 156 | `selects` | `white` | white or near-white ink, invisible on cream |
| search.html | 157 | `?` | `white` | white or near-white ink, invisible on cream |
| search.html | 157 | `?` | `white` | white or near-white ink, invisible on cream |
| sequences.html | 102 | `selects` | `white` | white or near-white ink, invisible on cream |
| sequences.html | 103 | `?` | `white` | white or near-white ink, invisible on cream |
| sequences.html | 103 | `?` | `white` | white or near-white ink, invisible on cream |
| shell.css | 154 | `box-shadow` | `rgba(` | glow/shadow tuned to a dark ground |

...and 8 more, listed in `colour_roles.json`.

Three structural tricks found by reading the render code rather than the literals:

1. `players.html` `scatterSvg()` draws the highlighted player as `fill="var(--accent)"` with
   `stroke="var(--bg)"`, a **halo ring in the page background colour** for figure/ground separation. It is
   token-based so it follows the theme, but it assumes the marker sits directly on `--bg`; over any other
   surface it draws a ring that reads as a defect.
2. Quadrant labels use `opacity=".72"` over `--text3`, and scatter dots `fill-opacity="0.65"`. Both were
   tuned against a dark ground and will read heavier on cream.
3. `teams.html` `renderLeagueMap()` uses `stroke-opacity` 0.55 for gridlines and 0.8 for median guides.
   The same alphas over cream read considerably stronger than intended.

---

## 0.5 Existing theme mechanism

**It is not a stub, and it is already global in the only sense that matters: it toggles a class on the
root element and stores the choice under one shared key.** What it is not is consistent, and it has no
`prefers-color-scheme` support anywhere in the repo.

- **What it sets:** `document.documentElement.classList.toggle('dark')`. Dark is the default; every page
  ships `<html class="dark">`.
- **Where the value is stored:** `localStorage['theme']`, values `'dark'` / `'light'`, one key shared by
  every page.
- **Scope:** the document root, so it covers whatever that page renders. Cross-page persistence comes
  only from every page re-reading that key on load.
- **Applied by:** an inline pre-paint script in `<head>`, in **two dialects**. Ten pages *remove* `.dark`
  when the stored value is `light`: players, teams, match, index, validation, market-values, model-lab,
  model-review, writing-lab and the archived copies. Six pages *add* `.dark` unless the value is `light`:
  methodology, insights, glossary, search, guide, sequences, with a `catch` that also adds it. Same end
  state, two code paths.
- **Which surfaces respect it:** every page linking `theme.css`, which supplies the light palette under
  `html:not(.dark)`: index, players, teams, match, sequences, search, insights, glossary, guide,
  methodology, validation, market-values. **`gate.js` does not** and paints a hardcoded near-black shell.
- **The control is duplicated per page and inconsistent:** `players.html` has `toggleDark()`; `teams.html`
  an inline `onclick` on a `.lnk` labelled "Theme"; `validation.html` an inline handler that also swaps a
  sun/moon glyph; `index.html` a `#themeBtn` calling `toggleTheme(b)`; `market-values.html` and
  `writing-lab.html` their own `toggleTheme()`; `model-lab.html` additionally accepts `?theme=light`.
- **Where the values live:** dark values on each page's `:root`, light values in `theme.css` under
  `html:not(.dark)`. That file's own comment explains the specificity: `html:not(.dark)` (0,2,0) outranks
  a page's `:root` (0,1,0) in light and cannot match in dark, so dark is left untouched.

**Consequence for Phase 2:** the mechanism is sound and should be extended, not replaced. The work is
consolidating nine hand-written controls into one, adding first-visit `prefers-color-scheme`, and bringing
`gate.js` into the system.

---

## 0.6 Rank ordering logic

`players.html` lines 1355-1359, inside `renderRank()`:

```js
.sort(function(a,b){
  const av=RK.pool?a.value:a.pct, bv=RK.pool?b.value:b.pct;
  if(av!==bv)return (av-bv)*RK.dir;
  return (a.pct-b.pct)*RK.dir;
})
```

- **Sort key:** `RK.pool ? value : pct`. With a role pool selected it is the raw metric value; with
  *All roles* it is the league-and-role percentile. This matches what `rankCtrls()` tells the user.
- **Comparator:** numeric difference times `RK.dir` (`-1` highest first, `+1` lowest first).
- **Tie-break: there is none.** With *All roles*, `av` and `bv` *are* `a.pct` and `b.pct`, so the second
  line compares the two values just found equal and returns 0 for every tie.
- **Precision:** display precision equals storage precision. `pct` renders raw (`+r.pct`, line 1391), and
  in the database **0 of 92,068 rows in `mv_player_percentiles` carry a fractional `pct`**. The tied
  values are genuinely equal integers, not distinct values collapsed by rounding.

**Therefore:** the ties are real and their order is whatever `Array.prototype.sort` leaves behind. V8's
sort is stable, so the visible order is the order PostgREST returned rows in, which is unspecified
because the query sends no `order` parameter. The reported Valverde / Bellingham / Alonso case is this,
not a rounding bug. Fix in Phase 5.

The team-side equivalent, `teams.html` `renderRankings()` line 1005, has the same shape:
`rows.sort((a,b)=>(b.pct==null?-1:b.pct)-(a.pct==null?-1:a.pct))`: percentile only, no tie-break, and no
direction control at all.

