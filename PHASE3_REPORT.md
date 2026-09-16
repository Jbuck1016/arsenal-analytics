# Phase 3 — the visual overhaul

Branch `restyle/global-theme`. Six commits, one per section, none squashed.

| | |
|---|---|
| `7f11460` | refactor: six families collapse into app and editorial |
| `bffa51a` | feat: one palette, and the brand red is the accent |
| `36dfe5d` | fix: every contrast and separability failure Phase 6 measured |
| `f54fc57` | feat: two type systems, and the boundary between them |
| `20c4130` | feat: the Rank table gets a hierarchy |
| `1723df3` | feat: the export sheet gets a voice of its own |

**Contrast failures: 324 of 800 → 0 of 508. Separability flags: 21 → 0, of
which 18 severe → 0.** Both are measured, not asserted; `restyle/contrast.md`
and `restyle/separability.md` are regenerated at the head of this branch.

---

## What the palette is, and why

### Light is canonical

Every value was chosen against the light ground first and dark derived from it.
That is not a stylistic preference — it is what fixes the single largest class
of failure in the audit. Thirty-odd marks measured under 3:1 on cream because
they were bright, saturated colours chosen against `#0e1219` and then used on
both grounds unchanged.

### Grounds and surfaces

| role | light | dark |
|---|---|---|
| `--ground` | `#faf8f3` | `#0e1219` |
| `--surface-raised` | `#fffdf8` | `#161b24` |
| `--surface-recessed` | `#f0ebdf` | `#1e242e` |

The raised surface is now **lighter** than the ground. It was `#f4f1e9` on
`#faf8f3` — darker than the thing it sat on — so a card read as a dent rather
than as a sheet. Recessed is the darker one, which is what the name says.

The dark ground is the document family's `#0e1219`, the brief's one named
exception to "the app value wins". `match.html` and all eight document pages
already painted it; `players` and `teams` were the outlier.

### Ink

Warm near-black on a warm grey scale, not the blue-grey the app family carried.
`#17140f · #4a4436 · #655e4d · #726a58` in light. Every rung clears 4.5:1 on all
three light surfaces including the recessed one, where the old `--ink-tertiary`
failed at 4.28.

### The accent is three tokens

The brief says the accent is `#EF0107` and that "the new accent clears AA
everywhere by construction". The second half is arithmetically false, and this
is the one place the phase departs from the brief as written. `#EF0107`
measures 4.23:1 on cream and 4.18:1 on `#0e1219` as text, and **white on it
measures 4.49:1 — white being the maximum, so no ink clears it.**

One value cannot do three jobs:

| token | value | job | threshold |
|---|---|---|---|
| `--accent-base` | `#EF0107` both themes | the brand, and a MARK: rules, bars, focus rings, panel edges | 3:1 ✓ |
| `--accent-solid` | `#EC0107` both themes | a fill that CARRIES TEXT | white on it 4.59:1 ✓ |
| `--accent-ink` | `#C10005` / `#FF4A42` | accent-coloured TEXT on a page surface | 4.5:1 ✓ |

`--accent-solid` is three units of red darker, **0.65 CIEDE2000 from the brand**
— below the threshold of noticing a difference at all — so it is the brand red
wherever a label sits on it.

This is not `fam-doc-aa` under a new name, and the difference is the whole
point. That was a second *scope*: one role, `--accent-base`, meaning a
different colour on three pages, so what the accent *was* depended on which
page you were on. This is three *roles* in one family; every page carries all
three and no page disagrees with any other. **Splitting by role is what let the
scope die.**

`match.html`'s runtime `setProperty` writes stay: a team's colour is data.
`applyTheme()` now writes `--accent-solid` alongside `--accent`, or every
filled button would sit on brand red while the rules around it followed the
selected team.

The warm gold survives only as `--accent-muted`, `#8a5e1a` in light — which is
the value the deleted AA scope had darkened it to. The darkening outlived the
scope that produced it.

---

## Which families collapsed into what

Eight scopes became two.

| was | is | what happened |
|---|---|---|
| `fam-doc` | **app** | its palette WAS the app palette but for an amber accent and two tints; those went with the accent. Seven names survive that the app family had no token for at all. |
| `fam-doc-aa` | **deleted** | existed only because `#9c6b1e` failed AA on the shared surfaces. The amber is not the accent, so the darkened variant had nothing to do. |
| `fam-match` | **app** | Phase 1 gave it a family because it matched nothing — document surfaces, brand-red accent. Phase 3 made every other page agree with it. Folding it in changed three of its values in light and eight in dark; its other 134 names are app tokens. |
| `fam-market` | **app** | see below. |
| `fam-lab` | **editorial** | its values won where the three disagreed. |
| `fam-review` | **editorial** | lost its `--ink-tertiary`, which measured 2.47:1 on its own ground. |
| `fam-writing` | **editorial** | lost its select control, which was pinned to a dark sheet in **both** themes, so a light page painted a dark dropdown. |

`editorial` shares the app family's ink logic, accent and states. Only the
surfaces and the five numbered series differ — it is not a second design
system, it is one family with a warm paper ground and a serif reading face,
because those pages are read rather than worked.

**The brief names `market-values.html` in both families** — the app list
includes it, the editorial merge bullet claims it. Implemented as an app page;
the reasoning is item 1 of `PHASE3_NOTES.md`, and reversing it costs one class
on one page.

### Three colours were being decided by source order

Concatenating two families into one scope exposed them. `--series-link`
resolved to match's `#2f6fd0` over the document family's `#2f6aa8` purely
because the match block came later in the file. **Decided on measurement**:
`#2f6aa8` clears 4.5:1 on all three light surfaces, `#2f6fd0` reaches 4.14:1 on
the recessed one. `--grid-line` was warm at `.055` on two pages and cool at
`.018` on a third, for the same graph-paper rule.

---

## Every skip row resolved, and every one that survives

**28 of 64 resolved and deleted with the literal each described.** All of them
gave the same reason — two families disagreed on a role and Phase 1 was not
allowed to choose:

- `teams.html` ×2 — the dark border divergence, `#2c313d` / `#414957` against
  `#272b35` / `#3a3f4b`. The app scale wins.
- `index.html` ×3 — its own light amber `#9a6f2a` / `.09` / `.34` against the
  family's `#9c6b1e` / `.10` / `.32`. Six values for one role, differing in the
  third decimal of an alpha. The accent change retires the question.
- `insights.html` ×1, `sequences.html` ×2 — amber tints at `.30` and `.28`.
- `sequences.html` ×11 — a whole second dark block pasting the app palette over
  the document one.
- `validation.html` ×3 — the three places it differed from `guide` and
  `methodology`. Its blue was decided on measurement, as above.
- `market-values.html` ×2 — a light panel and hairline it declared and that
  have never been painted.
- `match.html` ×1 — `--dim:#8b95b5`, a private grey where the family has an ink
  scale.
- `teams.html` ×1 — the comment prose row, no longer needed: the lint strips
  comments, and the rewritten comment carries the hexes safely.
- `teams.html` ×1 — the heat overlay's `rgb()` arithmetic. The one row flagged
  forward to "ramps rebuilt per theme, not inverted", now resolved by making it
  read the ramp tokens.

**36 survive, and none of them was ever about disagreement:**

| count | category |
|---|---|
| 22 | `var()` fallback defaults, including the gate's deliberate `#080a0e` |
| 5 | semantic keywords (`transparent`, `currentColor`) |
| 4 | gradient end-stops (`rgba(0,0,0,0)`) |
| 4 | HTML entities (`&#11015;`) read as hex by the scanner |
| 1 | `TEAM_COLORS` — fifteen club colours, which are facts about clubs |

**All 15 page-local pins are gone.** A pin asserted that a page overrode the
family on a role and had not been swallowed by it. With one family there is
nothing left to override, and a pin that agrees with the family asserts nothing.

---

## Every contrast and separability failure fixed

### The dark pitch — the clearest failure on the site

`--plot-share-label` at **1.10:1** and `--plot-label` at **1.42:1**: near-black
ink at low alpha painted onto a `#111722` pitch. Not "hard to read" —
invisible. Every plot token was tuned for the light pitch and carried to dark
unchanged; all of them have real dark values now.

`--plot-shadow` deliberately does **not** lighten with the rest. A shadow on a
dark ground is still a shadow, and lightening it makes a glow. It deepens to
`rgba(0,0,0,0.55)` and no longer shares a value with `--plot-guide`, which it
never should have.

### The percentile ramp

Two ramps, built per ground rather than one inverted.

| | worst contrast | adjacent ΔE00 | closest pair |
|---|---|---|---|
| light, before | 1.64 | 21.5 / 22.5 / 37.8 / 16.0 | 16.0 |
| light, after | 3.64 | 22.4 / 22.2 / 19.6 / 15.9 | 15.9 |
| dark, before | 6.24 | 23.5 / 18.9 / 37.7 / **6.0** | 6.0 |
| dark, after | 6.38 | 27.2 / 20.1 / 23.6 / 19.3 | 19.3 |

Three of the five light steps measured under 3:1 on cream. In dark,
`--rank-high` and `--rank-top` sat 6.0 apart — two greens no reader separates
at the size they are drawn. They are a yellow-green and a teal-green now. Tier
4 and tier 5 are told apart without the legend, which was the requirement.

### `rankColor()`'s hybrid

It drew five bands from three unrelated places: two states, the second accent,
and two literals fixed across themes while the other three followed it. **Three
of five moved with the theme and two did not**, so which band a value fell in
changed meaning between light and dark. It is a percentile-to-colour map and
there is a percentile ramp. `--pct-high` and `--pct-low` are deleted.

### The categorical palettes

Each carried **one value used on both grounds, chosen against the dark one**.
They still carry one value each — but chosen so it clears 3:1 on *both*
grounds, which is a stronger property than a per-theme split and keeps a series
identity stable when the reader flips the theme.

| set | closest pair before | after |
|---|---|---|
| evidence layers (9) | **0.0** ×5 | 13.3 |
| metric groups (12) | **3.1** | 11.9 |
| pitch layer series | **0.0** | 11.7 |
| defensive actions (8) | 15.1 | 15.1 |
| position lines (7) | 18.2 | 11.5 |
| shot outcomes (5) | 15.3 | 15.6 |

Six of the nine evidence layers shared three values between them. The metric
groups' two blues were 3.1 apart and its two purples 7.5.

**Two merged rather than separated**, which the brief permits for things that
genuinely encode the same thing: `--series-pass` was byte-identical to
`--series-ok` and its `PAL`/`TPAL` key was never dereferenced; `--series-mint`
was read by nothing.

### The heat ramp

`teams.html` computed its overlay per cell from `r=40+215t, g=90+150t,
b=190-150t` — the one skip row with no literal to tokenise. It was tuned
cool-to-warm for a dark pitch and **read backwards on cream**, the hottest cell
coming out lightest against a light ground. It interpolates `--heat-low/mid/high`
now, the same three stops `match.html`'s `densityRGB()` reads, so the canvas
heatmap, the SVG overlay and the legend swatch can no longer disagree about
what the ramp is. Light ends dark, dark ends light: the hottest cell has to be
furthest from the ground it sits on, and the two grounds are at opposite ends.

### Two judgements `contrast.md` asked Phase 3 to make

The audit said the line between decoration and affordance "is a design
judgement, and Phase 3 is where it gets made". It is made by one rule: **a
boundary is an affordance only when it is the ONLY thing identifying a control
or its state.**

**Held to 3:1 — seven tokens**, and every one was fixed rather than
reclassified: `--border-strong`, `--select-edge`, `--timeline-sel-edge`,
`--pitch-line-strong`, `--gate-field-border`, `--gate-action-edge`,
`--gate-focus-ring`. The gate's field edge measured 1.48:1 and its button edge
2.24:1 — the two places on the site where the boundary *is* the control.

**Decoration, measured and reported but not failed — 36 tokens.** Two families:
the edge half of a veil-and-edge pair, where the fill identifies the chip and
the border only softens its shape; and rules, rings and hairlines drawn behind
other content. Plus one ramp rule: a ramp's **minimum** stop is decoration,
because sitting close to the ground is what "nearly nothing here" means.
Requiring 3:1 of it is requiring the ramp to have no low end. Every ramp's
**high** stop was fixed rather than reclassified.

Drawing `--border-hairline` at 3:1 on cream would mean a near-black hairline
through every table on the site — worse to read, not better.

### One instrument fix, not a colour fix

A translucent ground was composited over **white** before measuring, so
`--pos-gk-fill` at `rgba(212,160,23,0.15)` flattened to a pale gold pill in
*both* themes and the dark badge inks were measured against a surface that only
exists in light. It composites over the family's own ground now. This is the
defect `palette_audit.py`'s own header warns about — measuring against a surface
the token never touches.

---

## What I implemented and disagree with

All in `PHASE3_NOTES.md`, in full. In short:

1. **`market-values.html` is in both of the brief's family lists.** Implemented
   as an app page — the reading that leaves one statement wrong instead of two,
   and the page is a working surface rather than a reading one.
2. **The accent cannot clear the brief's own contrast rule.** Implemented as
   three roles rather than one value; the brief's claim that `fam-doc-aa` has
   "nothing to do" is true of the *scope* and not of the *job*.
3. **The type consolidation drops four faces.** The brief said consolidate
   rather than add, which I read as licence to remove: Archivo, DM Mono, IBM
   Plex Mono and IBM Plex Sans Condensed are gone. Four pages that had a
   deliberate typographic identity now share one. `model-lab` in particular was
   set in IBM Plex Mono throughout and now reads in JetBrains Mono. I think
   this is right and it is the largest single visual change nobody asked for
   explicitly.

---

## What the gates certify, and what still cannot be certified

**Passing at `HEAD`:**

```
python restyle/assert_tokens.py        375 occurrences, 442 resolutions
python restyle/lint_colors.py          19 files, 36 allowed literals
python restyle/palette_audit.py        508 measurements, 0 failures
                                       452 pairs, 0 flagged
python restyle/verify_resolver.py      8,542 resolutions vs Chrome, agree
python restyle/verify_canvas_bridge.py 225 JS palette values
python restyle/run_bridge_probe.py     0 unexpected failures
```

**Failing by design, as the brief says they must:** `assert_page_parity.py` and
`assert_rule_parity.py` compare against the branch point, and Phase 3 is the
phase that changes what renders. Every entry in their output was checked to be
an intended recolour rather than a resolution that broke.

**`assert_tokens.py`'s ledger was re-pointed**, not abandoned. Its job is
unchanged — every token still has to resolve to exactly one recorded value, so
accidental drift still fails — but the recorded value is now the one Phase 3
chose, with each row's Phase 1 value kept in its note. 117 rows were re-pointed
in the collapse, 72 in the palette, 66 in the measured fixes.

**`verify_canvas_bridge.py`'s expectations were re-transcribed by hand from
`tokens.css`, never from the probe's own output.** What it proves is narrower
than before: that the JavaScript palette a browser actually builds equals the
palette the stylesheet declares, in both themes, through the export path and
after a theme switch. A bridge that cached one palette, read a wrong token name
or failed to re-read on a theme change still fails there. What it no longer
proves is that the values are Phase 1's — that job moved to the two audits,
which measure the values rather than remembering them.

### Cannot be certified without a human looking

1. **Nothing here was seen rendered.** `restyle/contact-sheet.html` is
   regenerated — 15 pages, 27 views, 54 frames — and opening it is the whole of
   what this phase could not do for itself. Every number above is arithmetic
   over declarations; none of it knows whether the result looks like anything.
2. **Whether the two treatments actually read as two.** The chrome/editorial
   split is enforced by which token a rule uses, and a gate can see that. Whether
   a reader *experiences* a bracketed mono tab and a serif panel title as one
   system rather than two unrelated ones is a judgement no measurement makes.
3. **The Rank hierarchy's top-three rule.** It hangs on `:nth-child(-n+3)`, so
   it follows the sort. Whether "the top three" is the right number, and whether
   it still reads correctly when the table is sorted ascending so the leaders
   are the worst players, wants an eye on it.
4. **`match.html`'s runtime accent.** `applyTheme()` writes the selected team's
   colour into `--accent` and `--accent-solid`. The contrast of `--ink-on-accent`
   against an arbitrary club colour is outside the system's control and always
   was; `verify_resolver` excludes both tokens for that reason. A club with a
   pale primary will have a low-contrast button label and no gate will say so.
5. **The export flash**, unchanged from the earlier session: forcing light means
   the page visibly flashes while `html2canvas` works, and the bridge probe's
   test 3 established there is nowhere else to put the light copy.
6. **`--accent-edge` as decoration.** It is the edge half of a veil-and-edge
   pair on chips, which is why it is classified as decoration — but it is also
   what several pages use as a focus ring. If a focus ring anywhere resolves to
   it rather than to `--gate-focus-ring` or an outline, that is an affordance
   sitting in the decoration bucket. I could not establish it either way from
   the stylesheets alone.

---

## Where this stops

Everything in the Phase 3 brief is done. Sections 1, 2, 3, 4, 5 and 6 each have
their own commit and can be reverted alone.

The first thing to do is open `restyle/contact-sheet.html`.
