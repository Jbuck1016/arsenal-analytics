# Phase 1: what is here and what each thing proves

Phase 1 is a pure refactor. Every colour on every live surface moves into
`dashboard/tokens.css` under a role name, and nothing renders differently.
This directory is the evidence for the second half of that sentence.

## Run everything

```
python restyle/check.py                    # the three static gates, no browser
python restyle/verify_resolver.py          # the gates' model vs Chrome
python restyle/verify_canvas_bridge.py     # match.html's runtime palette
python restyle/run_bridge_probe.py         # the canvas bridge mechanism
```

The first is fast and belongs in CI. The other three need Playwright.

## The gates, and what each one can see

| gate | question | blind to |
|---|---|---|
| `assert_tokens.py` | does each literal I recorded replacing resolve back to itself, and does each page-local pin still beat the family scope that would swallow it | anything not written down |
| `assert_page_parity.py` | does every custom property every page *reads* resolve to what it resolved at the branch point | ordinary declarations |
| `assert_rule_parity.py` | does every ordinary CSS declaration, in the page and in the stylesheets it links, expand to what it expanded to at the branch point | which rule *wins* for an element |
| `verify_resolver.py` | does the resolver all three share agree with Chrome | nothing static can see |
| `verify_canvas_bridge.py` | does match.html's JavaScript produce the pre-conversion colours, and does a canvas accept them | renderers that build a colour some other way |

None of them subsumes another, and each was added because something got past
the ones before it:

- the ledger passed while `shell.css` painted three pages' select borders a
  different colour, because nothing was watching a token it did not name;
- page parity passed while 95 rule-level literals in `match.html` were
  unverified, because a new `var()` site only had to resolve, not to resolve
  *correctly*;
- rule parity passed on a model that had been wrong twice about specificity,
  until it was checked against a browser.

## The ledgers

- **`token-map.csv`** — one row per recorded conversion: file, line, the
  literal, the token that replaced it, the themes it applies in. 371 rows.
  It does **not** cover `match.html`'s rule-level or JavaScript conversions:
  those are asserted against git by `assert_rule_parity.py` and against a
  browser by `verify_canvas_bridge.py`, which are stronger checks than a row
  saying a value equals itself.
- **`pinned.csv`** — the opposite claim: a token that must **not** have taken
  its family's value on this page. 15 rows. Deleting a pin from a page makes
  this fail, which is the whole point; that was verified by deleting one.
- **`deliberate-skips.csv`** — every literal still in code, with the reason.
  Four categories: club colours (reference data, not design tokens), gradient
  end-stops that name the absence of a colour, one deliberate fallback on the
  privacy overlay, and 47 values in the fallback position of a `var()` whose
  token always resolves.

## The probes

- **`bridge-probe.html`** + **`run_bridge_probe.py`** — establishes the
  mechanism: `getComputedStyle` returns a custom property exactly as authored,
  and a descendant cannot escape an ancestor's `html.dark`, which is why both
  palettes are captured up front.
- **`family_diff.py`** — a *pre*-conversion tool. Given a page and a family,
  it reports what changes when the family class lands. It refuses to run on a
  page that already carries one, because the answer would be meaningless.

## Known limits

`gate-limitations.md` has the detail. In short: values written at runtime with
`setProperty` are invisible to every static gate, and a canvas silently
discards anything it cannot parse. The first is real and confined to
`match.html`'s `applyTheme()`. The second is closed for everything that goes
through the token bridge, and `verify_canvas_bridge.py` is the only check
anywhere that tests it rather than reasoning about it.
