"""Phase 1 gate: assert every tokenised colour resolves to the value it replaced.

WHY THIS EXISTS, AND WHAT IT REPLACED
The original brief asked for "pixel-identical to main". That is not achievable
here: the pages fetch live data, a database rebuild was refreshing matviews
during the work, and Rank sorts on percentile with no tie-break, so row order
legitimately varies run to run. A screenshot harness was built, and its own
control surface proved the instrument wrong: glossary--dark compared IDENTICAL
PIXELS while its PNG bytes differed, so sha256 equality was never a valid test.
Pixel comparison then showed 32 of 52 surfaces differing on an UNCHANGED tree,
all of them data-driven, none of them static markup.

So the gate is static instead. A token refactor is correct when every token
resolves to exactly the value it replaced. That is assertable from the source
alone: exhaustive rather than sampled, no browser, immune to data variance.

WHAT IT CHECKS
For each row of restyle/token-map.csv:
  - the token exists in tokens.css
  - it resolves, following var() aliases, in the family scope that file belongs to
  - the resolved value is byte-equal to the original literal, normalising only
    case and equivalent hex forms (#fff == #ffffff, #ffff == #ffffffff)

Exit code is non-zero on any failure, so it runs in CI.

Usage:
    python restyle/assert_tokens.py            # assert the ledger
"""
from __future__ import annotations

import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / "dashboard" / "tokens.css"
LEDGER = ROOT / "restyle" / "token-map.csv"
# Values a page deliberately keeps for itself because the family scope it now
# carries would otherwise swallow them. token-map.csv asserts "this literal
# became this token"; this asserts the opposite and equally load-bearing claim,
# "this token must NOT have become the family's value here". Without it,
# deleting one of those pins is a silent recolour that every other check passes.
PINS = ROOT / "restyle" / "pinned.csv"

# Which family scope each live file renders under. tokens.css keys values by a
# class on <html>; this is the mapping from file to that scope chain.
FAMILY = {
    "dashboard/theme.css": "app",
    "dashboard/shell.css": "app",
    "dashboard/tokens.css": "app",
    "dashboard/players.html": "app",
    "dashboard/teams.html": "app",
    "dashboard/match.html": "app",
    "dashboard/gate.js": "gate",
    "dashboard/index.html": "doc",
    "dashboard/search.html": "doc",
    "dashboard/glossary.html": "doc",
    "dashboard/sequences.html": "doc",
    "dashboard/insights.html": "doc",
    "dashboard/guide.html": "doc-aa",
    "dashboard/methodology.html": "doc-aa",
    "dashboard/validation.html": "doc-aa",
    "dashboard/market-values.html": "doc",
    "dashboard/model-lab.html": "lab",
    "dashboard/model-review.html": "lab",
    "dashboard/writing-lab.html": "lab",
}

# (family, theme) -> the classes actually on <html> in that state.
#
# WHY A CLASS SET AND NOT A LIST OF SELECTORS
# This used to be a whitelist of the selector strings tokens.css writes. A
# selector a page invented for itself was therefore invisible: insights.html
# scopes its dark palette to `html.dark:root, html.dark`, which appears in no
# chain, so the resolver read straight past a block the browser applies. A
# whitelist can only certify the rules it was told about, which is the same
# defect as a screenshot hash that cannot see the pixels.
#
# The class set is what the DOM actually carries, so any selector in any source
# can be tested against it, and precedence is then decided by real specificity
# and source order rather than by list position.
#
# Light is the ABSENCE of .dark, which is why tokens.css writes html:not(.dark)
# and not :root: a page declares its light values on :root (0,1,0) and
# tokens.css is linked first, so a bare :root there would lose to the page on
# equal specificity and later source order while still reading correctly in
# isolation -- an inert file the assertion would happily certify.
STATE = {
    ("app", "light"): set(),
    ("app", "dark"): {"dark"},
    ("doc", "light"): {"fam-doc"},
    ("doc", "dark"): {"dark", "fam-doc"},
    ("doc-aa", "light"): {"fam-doc", "fam-doc-aa"},
    ("doc-aa", "dark"): {"dark", "fam-doc", "fam-doc-aa"},
    ("lab", "light"): {"fam-lab"},
    ("lab", "dark"): {"dark", "fam-lab"},
    ("gate", "light"): set(),
    ("gate", "dark"): {"dark"},
}

BLOCK = re.compile(r"(?P<sel>[^{}]+)\{(?P<body>[^{}]*)\}", re.S)
DECL = re.compile(r"(--[\w-]+)\s*:\s*([^;]+);")
VAR = re.compile(r"var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*))?\)")


def _blocks_from(css: str) -> list[tuple[str, dict[str, str]]]:
    """[(selector, {token: raw})] in source order. Only custom properties.

    A SELECTOR LIST IS SPLIT INTO ITS ARMS. insights.html declares its dark
    palette on `html.dark:root, html.dark`, and keeping that as one key meant it
    matched no entry in any scope chain, so the resolver could not see the block
    at all and reported nine dark tokens as changing value under fam-doc when
    the page had declared every one of them itself. The block was invisible to
    the instrument, not absent from the browser.

    Splitting on commas is safe for the nine selector forms that carry custom
    properties in this repo (enumerated: :root, html.dark, html:not(.dark),
    html.dark:root, and the five family scopes). It would be wrong for a
    functional pseudo-class with a comma inside it, :is(a,b) or :where(a,b);
    none exists here, and one appearing later would need this to parse nesting.
    """
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out = []
    for m in BLOCK.finditer(css):
        # The final declaration in a block is legal without a trailing
        # semicolon, and DECL requires one, so it was being dropped -- silently,
        # everywhere. teams.html ends both its palette blocks with --shadow, so
        # --shadow was invisible to this gate in both themes while the ledger
        # row naming --elevation-1 passed by reading tokens.css instead.
        body = m.group("body").strip()
        if body and not body.endswith(";"):
            body += ";"
        decls = {n: v.strip() for n, v in DECL.findall(body)}
        if not decls:
            continue
        for arm in m.group("sel").split(","):
            arm = " ".join(arm.split())
            if arm:
                out.append((arm, decls))
    return out


# CSS specificity as (ids, classes, elements), where "classes" also counts
# attribute selectors and pseudo-classes, per the spec. :not() contributes the
# specificity of its argument but nothing for itself.
#
# WHY THIS IS NOT A DOT COUNT ANY MORE
# The previous version returned sel.count("."), which scored html.dark:root as 1
# and html.dark.fam-doc as 2. Those are both (0,2,1) and the page's is later in
# source, so the browser gives the page the win and the resolver gave it to the
# family. That is the difference between certifying what is painted and
# certifying what is not.
_NOT = re.compile(r":not\(([^()]*)\)")
_PSEUDO = re.compile(r":(?!not\b)[\w-]+")
_ELEM = re.compile(r"(?:^|[\s>+~])([a-z][\w-]*)")


def _spec(sel: str) -> tuple[int, int, int]:
    s = " ".join(sel.split())
    args = _NOT.findall(s)
    outside = _NOT.sub(" ", s)
    ids = outside.count("#")
    classes = outside.count(".") + outside.count("[") + len(_PSEUDO.findall(outside))
    elements = len(_ELEM.findall(outside))
    for a in args:
        ids += a.count("#")
        classes += a.count(".") + a.count("[") + len(re.findall(r":[\w-]+", a))
        elements += len(_ELEM.findall(a))
    return (ids, classes, elements)


def _matches(sel: str, classes: set[str]) -> bool:
    """Does this selector match <html> carrying exactly `classes`?

    Only the shape that scopes custom properties in this repo is understood: an
    optional `html` type, `:root`, and any number of `.cls` and `:not(.cls)`.
    A selector with a descendant combinator, an id, an attribute or any other
    pseudo-class is not a root-element theme scope and is skipped, because
    guessing at it would be worse than admitting the resolver cannot model it.
    """
    s = " ".join(sel.split())
    required = set(re.findall(r"(?<!\()\.([\w-]+)", _NOT.sub(" ", s)))
    forbidden: set[str] = set()
    for arg in _NOT.findall(s):
        forbidden |= set(re.findall(r"\.([\w-]+)", arg))
    # Whatever is left once html, :root, the classes and the :not()s are struck
    # out must be empty, or this is a selector shape we do not model.
    residue = _NOT.sub("", s)
    residue = re.sub(r"\.[\w-]+|:root|^html", "", residue).strip()
    if residue:
        return False
    return required <= classes and not (forbidden & classes)


def parse_cascade(page_file: str | None = None) -> list[tuple[str, dict[str, str]]]:
    """tokens.css, then theme.css, then the page's inline <style>, in order.

    WHY THIS IS NOT tokens.css ALONE
    A token can resolve perfectly inside tokens.css and still never reach the
    browser, because theme.css declares light values at html:not(.dark) (0,2,1)
    and every page declares its own :root and html.dark blocks in an inline
    <style> that loads AFTER both stylesheets. Reading tokens.css by itself
    would certify a value that a later, equally specific or more specific rule
    overrides. That is the same class of error as trusting a screenshot hash:
    an instrument that cannot see the thing it is certifying.

    A LIST, NOT A DICT KEYED BY SELECTOR. Merging by selector threw away the
    source order BETWEEN different selectors, which is exactly what breaks ties
    at equal specificity -- the case that decides whether a page's own
    html.dark:root beats tokens.css's html.dark.fam-doc.
    """
    sources = [TOKENS.read_text(encoding="utf-8")]
    theme = ROOT / "dashboard" / "theme.css"
    if theme.exists():
        sources.append(theme.read_text(encoding="utf-8"))
    if page_file:
        p = ROOT / page_file
        if p.exists() and p.suffix == ".html":
            sources += re.findall(r"<style>(.*?)</style>",
                                  p.read_text(encoding="utf-8"), re.S)

    out: list[tuple[str, dict[str, str]]] = []
    for css in sources:
        out += _blocks_from(css)
    return out


def resolve(token: str, classes: set[str],
            blocks: list[tuple[str, dict[str, str]]], depth: int = 0) -> str | None:
    """Resolve a token for <html> carrying `classes`, following var() aliases.

    The winner is the declaration with the highest specificity, ties broken by
    latest source order -- the cascade, as the browser applies it. Ordering by
    position in a hand-written chain instead modelled overrides the browser
    does not apply and missed ones it does.
    """
    if depth > 12:
        return None
    raw = None
    best = ((-1, -1, -1), -1)
    for i, (sel, decls) in enumerate(blocks):
        if token not in decls or not _matches(sel, classes):
            continue
        rank = (_spec(sel), i)
        if rank >= best:
            best, raw = rank, decls[token]
    if raw is None:
        return None
    m = VAR.search(raw)
    while m:
        inner = resolve(m.group(1), classes, blocks, depth + 1)
        if inner is None:
            inner = (m.group(2) or "").strip()
            if not inner:
                return None
        raw = raw[:m.start()] + inner + raw[m.end():]
        m = VAR.search(raw)
    return raw.strip()


def norm(value: str) -> str:
    """Normalise case, equivalent hex forms, and bare-decimal numbers. Nothing else."""
    v = " ".join(value.split()).strip().lower().rstrip(";")
    hexm = re.fullmatch(r"#([0-9a-f]{3,8})", v)
    if hexm:
        h = hexm.group(1)
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        elif len(h) == 4:
            h = "".join(c * 2 for c in h)
        if len(h) == 8 and h[6:] == "ff":
            h = h[:6]
        return "#" + h
    # A leading zero on a decimal IS normalised: .12 and 0.12 are the same CSS
    # number, and a comparator that calls them different is wrong about
    # equivalence rather than strict about colour. teams.html spells its alphas
    # bare (rgba(216,179,132,.12)) where players.html spells them with the zero
    # (rgba(216,179,132,0.12)), so without this the assertion fails on pairs
    # that parse identically.
    #
    # This canonicalises the FORM of a number, never its VALUE. .12 becomes
    # 0.12; .2 does not become 0.20, and 0.12 never becomes 0.13. A changed
    # alpha is still a changed colour and still fails. rgb/rgba SPACING is
    # likewise still not normalised.
    v = re.sub(r"(?<![\w.])\.(\d)", r"0.\1", v)
    return v


# Regression cases for the cascade model. Every one of these was either a real
# defect this instrument had, or a case the fix for one could plausibly have
# broken. They run on every invocation, because a gate whose own correctness is
# checked only when someone remembers is a gate that drifts.
#
# The NEGATIVE cases matter most: widening _spec and _matches until the answer
# came out right would be indistinguishable from fixing them, so each widening
# is pinned by a case that fails if it went one step too far.
_SPEC_CASES = [
    (":root", (0, 1, 0)),
    ("html", (0, 0, 1)),
    ("html.dark", (0, 1, 1)),
    ("html:not(.dark)", (0, 1, 1)),
    # The pair the dot count got wrong: equal, so source order decides.
    ("html.dark:root", (0, 2, 1)),
    ("html.dark.fam-doc", (0, 2, 1)),
    ("html:not(.dark).fam-doc", (0, 2, 1)),
    ("html:not(.dark).fam-doc.fam-doc-aa", (0, 3, 1)),
    ("html.dark.fam-lab", (0, 2, 1)),
]
_MATCH_CASES = [
    # selector, classes on <html>, expected
    (":root", set(), True),
    (":root", {"dark"}, True),
    ("html.dark", {"dark"}, True),
    ("html.dark", set(), False),
    ("html:not(.dark)", set(), True),
    ("html:not(.dark)", {"dark"}, False),
    ("html:not(.dark)", {"fam-doc"}, True),
    ("html.dark:root", {"dark", "fam-doc"}, True),
    ("html.dark.fam-doc", {"dark"}, False),
    ("html.dark.fam-doc", {"dark", "fam-doc"}, True),
    ("html:not(.dark).fam-doc", {"fam-doc"}, True),
    ("html:not(.dark).fam-doc", {"dark", "fam-doc"}, False),
    ("html:not(.dark).fam-doc.fam-doc-aa", {"fam-doc"}, False),
    ("html:not(.dark).fam-doc.fam-doc-aa", {"fam-doc", "fam-doc-aa"}, True),
    ("html:not(.dark).fam-lab", {"fam-doc"}, False),
    # NOT a root-element theme scope. These must be refused rather than
    # accidentally matched by a matcher that only looks for required classes:
    # a rule on body, or on a descendant, does not set the root's tokens.
    ("body", set(), False),
    ("html body", set(), False),
    (".card", {"dark"}, False),
    ("html.dark .panel", {"dark"}, False),
    ("html.dark:hover", {"dark"}, False),
    ("#app", set(), False),
]


def _selftest() -> list[str]:
    bad = []
    for sel, want in _SPEC_CASES:
        got = _spec(sel)
        if got != want:
            bad.append(f"_spec({sel!r}) == {got}, expected {want}")
    for sel, classes, want in _MATCH_CASES:
        got = _matches(sel, classes)
        if got != want:
            bad.append(f"_matches({sel!r}, {sorted(classes)}) == {got}, "
                       f"expected {want}")
    # A selector list must become one entry per arm, each carrying the
    # declarations. insights.html's dark block was invisible without this.
    arms = _blocks_from("html.dark:root, html.dark{--x:1;}")
    if [s for s, _ in arms] != ["html.dark:root", "html.dark"]:
        bad.append(f"selector list not split into arms: {[s for s, _ in arms]}")
    elif any(d.get("--x") != "1" for _, d in arms):
        bad.append("selector list arms lost their declarations")
    # The last declaration in a block needs no trailing semicolon. Both forms
    # must parse, and the value must not swallow the closing brace.
    last = dict(_blocks_from(":root{--a:1;--shadow:0 1px 3px rgba(0,0,0,.07)}"))
    if last.get(":root", {}).get("--shadow") != "0 1px 3px rgba(0,0,0,.07)":
        bad.append(f"unterminated last declaration mis-parsed: {last}")
    return bad


def main() -> int:
    broken = _selftest()
    if broken:
        print(f"{len(broken)} SELF-TEST FAILURES -- the gate is wrong, not the CSS:")
        for x in broken:
            print("  " + x)
        return 1

    if not LEDGER.exists():
        print(f"no ledger at {LEDGER}; nothing converted yet")
        return 0
    rows = list(csv.DictReader(LEDGER.open(encoding="utf-8")))
    if not rows:
        print("ledger is empty; nothing to assert")
        return 0

    # The cascade is built PER FILE: tokens.css + theme.css + that page's own
    # inline <style>. A token that resolves inside tokens.css can still be
    # overridden by the consuming page, and reading tokens.css alone would
    # certify a value the browser never uses.
    cascades: dict[str, list[tuple[str, dict[str, str]]]] = {}
    failures, checked = [], 0
    for r in rows:
        f, token, original = r["file"], r["token"], r["original"]
        if f not in cascades:
            cascades[f] = parse_cascade(f)
        blocks = cascades[f]
        fam = FAMILY.get(f)
        if fam is None:
            failures.append(f"{f}:{r['line']} unknown family for file")
            continue
        themes = r.get("themes", "light,dark").split(",")
        for theme in [t.strip() for t in themes if t.strip()]:
            classes = STATE.get((fam, theme))
            if classes is None:
                failures.append(f"{f}:{r['line']} no scope state for {fam}/{theme}")
                continue
            got = resolve(token, classes, blocks)
            checked += 1
            if got is None:
                failures.append(f"{f}:{r['line']} {token} does not resolve in {fam}/{theme}")
            elif norm(got) != norm(original):
                failures.append(
                    f"{f}:{r['line']} {token} in {fam}/{theme} resolves {got!r}, "
                    f"expected {original!r}")

    pins = 0
    if PINS.exists():
        for r in csv.DictReader(PINS.open(encoding="utf-8")):
            f, token, value = r["file"], r["token"], r["value"]
            if f not in cascades:
                cascades[f] = parse_cascade(f)
            fam = FAMILY.get(f)
            if fam is None:
                failures.append(f"{f} pin {token}: unknown family for file")
                continue
            for theme in [t.strip() for t in r["themes"].split(",") if t.strip()]:
                classes = STATE.get((fam, theme))
                if classes is None:
                    failures.append(f"{f} pin {token}: no scope state for {fam}/{theme}")
                    continue
                got = resolve(token, classes, cascades[f])
                pins += 1
                if got is None:
                    failures.append(f"{f} pin {token} does not resolve in {fam}/{theme}")
                elif norm(got) != norm(value):
                    failures.append(
                        f"{f} pin {token} in {fam}/{theme} resolves {got!r}, "
                        f"pinned {value!r} -- the family scope has swallowed it")

    print(f"{len(rows)} converted occurrences, {checked} token/theme resolutions checked")
    if pins:
        print(f"{pins} page-local pins checked against the family they override")
    if failures:
        print(f"\n{len(failures)} FAILURES:")
        for x in failures[:60]:
            print("  " + x)
        if len(failures) > 60:
            print(f"  ...and {len(failures)-60} more")
        return 1
    print("all tokens resolve byte-equal to the literal they replaced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
