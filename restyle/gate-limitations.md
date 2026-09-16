# What the Phase 1 assertion cannot see

`assert_tokens.py` proves one thing: that a token, resolved through the
stylesheet cascade, is byte-equal to the literal it replaced. That is worth
having, and it has caught real defects — aliases declared in one theme only,
light scopes written on a bare `:root` that would have lost to every page.

It is not a proof that the page renders correctly. Three holes are known.
Two of them were found by accident while converting `match.html`, not by
designing a test to look for them, which is itself worth recording.

## 1. Values written at runtime are invisible to it

The assertion models `tokens.css` + `theme.css` + the page's inline `<style>`.
It has no model of JavaScript.

`match.html:3104` writes three custom properties onto the root element:

```js
function applyTheme(){ ... const s=document.documentElement.style;
  s.setProperty('--accent',t.color);
  s.setProperty('--accent-dim',t.colorDim);
  s.setProperty('--accent-glow',t.colorGlow); ... }
```

An inline style outranks every selector in every stylesheet. So `--accent` on
that page resolves to the *selected team's* colour, defaulting to `#8b95b5`
(the `__ALL__` pseudo-team), and **not** to the `#EF0107` declared at line 20.

Consequence: for any property a page sets from JS, the assertion can pass
while the browser paints something else entirely. It was caught here only
because a browser check happened to read `--accent` and got a blue-grey.

Scope of the exposure, measured rather than assumed: a grep for
`setProperty(['"]--` across all of `dashboard/` finds runtime custom-property
writes in exactly one file, `match.html`, at two sites (3104 and 1394).
`players.html` and `teams.html` have none, so the conversions already
committed for those files do not sit under a runtime override.

## 2. Canvas silently discards `var()`

`players.html` and `teams.html` are SVG-based, and `var()` resolves inside SVG
`fill` and `stroke` attributes in generated markup. That was verified before
relying on it.

`match.html` is canvas-based: 118 `fillStyle` / `strokeStyle` / `shadowColor`
assignments, and the file says so itself at line 863 — *"Canvas can't read CSS
variables, so the palette is mirrored here and swapped whenever the theme
changes."*

`ctx.fillStyle = 'var(--pitch-fill)'` is **not** an error. It is ignored, and
the previous fill stays in place. So the technique used on the first two files
would produce a file that passes the assertion and renders wrong.

Worse, a large set of call sites cannot hold a `var()` string even in
principle, because they do arithmetic on the hex:

- `hexAlpha(hex,a)` — `parseInt(hex.slice(1,3),16)` and friends — 17 call sites
- `drawComet(...)` — same slicing — 2 call sites
- `hexToRgba(c,a)` — 3 call sites; already carries an `hsl` escape hatch at
  line 799, evidence that someone hit this before and patched the symptom
- three bare `.slice(1,3)` sites on `t.color` (1233, 1245, 2160)

The mechanism for this file is therefore a bridge, not substitution: read the
tokens once via `getComputedStyle` and hand canvas concrete strings.

### The bridge is verified

`restyle/bridge-probe.html`, run under Playwright, establishes:

- the root element returns the **light** palette with `.dark` absent and the
  **dark** palette with `.dark` present;
- custom properties come back **exactly as authored** — `getComputedStyle`
  does not normalise `rgba` spacing — so a value read through the bridge is
  byte-identical to `tokens.css` and still satisfies the assertion;
- a descendant element **cannot** escape an ancestor `html.dark`, which rules
  out hanging a light-scoped element inside a dark document (this is the
  probe's test 3, and every line of it failing is the expected result);
- an iframe with its own document element does resolve light while the parent
  is dark, as a fallback that is not needed.

So `CT()` can be populated by toggling `.dark` once at startup, reading both
palettes, and caching them. The `EXP_LIGHT` export path then reads the cached
light object and works while the page is dark — which matters, because exports
are what actually leave the building.

### And the bridge as built is verified too, separately

Proving the mechanism works in a probe page is not the same as proving the
page uses it correctly. `restyle/verify_canvas_bridge.py` loads the real
`match.html` in a browser and checks three things:

- `CT()` returns, in each theme, exactly the ten values the hand-mirrored
  palette returned before the bridge replaced it. Those ten pairs are written
  out in the verifier rather than read from `tokens.css`; reading them from
  the file the bridge reads would make the check a tautology.
- with `EXP_LIGHT` set while the document is dark, `CT()` returns the light
  palette — the case that motivated caching both.
- every value the bridge produces is **assigned to a real `ctx.fillStyle` and
  read back**, after setting a marker fill first. A canvas normalises what it
  accepts and ignores what it does not, so a value that comes back as the
  marker was silently discarded. This is the only check anywhere that tests
  the failure mode this section is about, instead of reasoning about it.

That closes hole 2 for everything that goes through `CT()`. It does not close
it for a call site that builds a colour some other way, so any new canvas
paint needs to come through the bridge or be added to the verifier.

## 3. It counts what a regex thinks is a colour

The scanner matches `#[0-9a-fA-F]{3,8}` and so also matches HTML numeric
entities. In `match.html` alone, 18 matches are not colours: `&#11015;`,
`&#10005;`, `&#8212;`, `&#9997;`, `&#9917;`, `&#9728;`, `&#8962;`, `&#65039;`,
`&#128100;`, `&#127769;`, `&#127942;` — arrows, an em-dash, a variation
selector and emoji. `players.html` and `teams.html` carry 2 each.

It also cannot distinguish a declaration from prose. Four matches in
`teams.html` sit inside a comment whose entire purpose is to explain why two
literals survive.

The Phase 6 lint rule must therefore strip comments and exclude `&#NNNNN;`
before scanning, or it fails permanently on text that is doing its job.

## What this means for the numbers

The audit's conversion surface has been corrected twice — 980, then 838 — and
both corrections were downward for this kind of reason. Any future count
should be produced by an entity-aware, comment-stripping, dead-code-aware
pass, not by a bare grep.

For `match.html`, that pass gives: 319 raw matches, minus 18 entities, minus
13 occurrences inside a provably dead `html.dark` block, leaving **288** real
conversions — 116 live CSS, 52 in JS palette objects, 120 JS inline paints.
