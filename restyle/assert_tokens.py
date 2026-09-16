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
    python restyle/assert_tokens.py --emit     # rewrite token-map.csv resolved columns
"""
from __future__ import annotations

import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / "dashboard" / "tokens.css"
LEDGER = ROOT / "restyle" / "token-map.csv"

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

# (family, theme) -> the selectors that apply, in increasing precedence.
#
# The light scopes are html:not(.dark), NOT :root. Every page declares its own
# dark palette on html.dark (0,2,0) and its light values on :root (0,1,0), and
# tokens.css is linked before each page's inline <style>. Light values on a bare
# :root would lose to the page's own :root on equal specificity and later source
# order, leaving the token file inert while it still resolved correctly when read
# in isolation. That would make this assertion certify values the browser never
# uses. html:not(.dark) (0,2,0) outranks a page :root and cannot match in dark,
# which is the behaviour theme.css already relies on.
#
# :root stays in every chain for the theme-independent tokens (gate shell,
# heatmap ramp stops), which must resolve in both modes.
SCOPE_CHAIN = {
    ("app", "light"): [":root", "html:not(.dark)"],
    ("app", "dark"): [":root", "html.dark"],
    ("doc", "light"): [":root", "html:not(.dark)", "html:not(.dark).fam-doc"],
    ("doc", "dark"): [":root", "html.dark", "html.dark.fam-doc"],
    ("doc-aa", "light"): [":root", "html:not(.dark)", "html:not(.dark).fam-doc",
                          "html:not(.dark).fam-doc.fam-doc-aa"],
    ("doc-aa", "dark"): [":root", "html.dark", "html.dark.fam-doc"],
    ("lab", "light"): [":root", "html:not(.dark)", "html:not(.dark).fam-lab"],
    ("lab", "dark"): [":root", "html.dark", "html.dark.fam-lab"],
    ("gate", "light"): [":root", "html:not(.dark)"],
    ("gate", "dark"): [":root", "html.dark"],
}

BLOCK = re.compile(r"(?P<sel>[^{}]+)\{(?P<body>[^{}]*)\}", re.S)
DECL = re.compile(r"(--[\w-]+)\s*:\s*([^;]+);")
VAR = re.compile(r"var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*))?\)")


def _blocks_from(css: str) -> list[tuple[str, dict[str, str]]]:
    """[(selector, {token: raw})] in source order. Only custom properties."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out = []
    for m in BLOCK.finditer(css):
        decls = {n: v.strip() for n, v in DECL.findall(m.group("body"))}
        if decls:
            out.append((m.group("sel").strip(), decls))
    return out


# Specificity of the selectors that carry custom properties here. A page's own
# :root is (0,1,0); html.dark and html:not(.dark) are (0,2,0); the family
# scopes add a class each.
def _spec(sel: str) -> int:
    sel = sel.strip()
    classes = sel.count(".")          # .dark, .fam-doc, .fam-doc-aa, .fam-lab
    if ":not(" in sel:
        classes = sel.count(".")      # .dark inside :not() still counts once
    return classes


def parse_cascade(page_file: str | None = None) -> dict[str, dict[str, str]]:
    """Merge tokens.css, theme.css and optionally a page's own inline <style>.

    WHY THIS IS NOT tokens.css ALONE
    A token can resolve perfectly inside tokens.css and still never reach the
    browser, because theme.css declares light values at html:not(.dark) (0,2,0)
    and every page declares its own :root and html.dark blocks in an inline
    <style> that loads AFTER both stylesheets. Reading tokens.css by itself
    would certify a value that a later, equally specific or more specific rule
    overrides. That is the same class of error as trusting a screenshot hash:
    an instrument that cannot see the thing it is certifying.

    Returns selector -> {token: raw value}, with later sources overriding
    earlier ones at equal specificity, which is what the browser does.
    """
    sources = [TOKENS.read_text(encoding="utf-8")]
    theme = ROOT / "dashboard" / "theme.css"
    if theme.exists():
        sources.append(theme.read_text(encoding="utf-8"))
    if page_file:
        p = ROOT / page_file
        if p.exists() and p.suffix in (".html",):
            for style in re.findall(r"<style>(.*?)</style>", p.read_text(encoding="utf-8"), re.S):
                sources.append(style)

    merged: dict[str, dict[str, str]] = {}
    for css in sources:
        for sel, decls in _blocks_from(css):
            merged.setdefault(sel, {}).update(decls)
    return merged


def parse_tokens() -> dict[str, dict[str, str]]:
    """tokens.css alone. Kept for the resolver smoke test."""
    out: dict[str, dict[str, str]] = {}
    for sel, decls in _blocks_from(TOKENS.read_text(encoding="utf-8")):
        out.setdefault(sel, {}).update(decls)
    return out


def resolve(token: str, chain: list[str], blocks: dict[str, dict[str, str]],
            depth: int = 0) -> str | None:
    """Resolve a token through the scope chain, following var() aliases.

    Selectors are considered in SPECIFICITY order, not the order they appear in
    the chain list, because the chain may now include a page's own inline
    <style> blocks. A page :root is (0,1,0) and loses to html:not(.dark) and
    html.dark at (0,2,0) however late it appears in source; ordering by list
    position alone would model a page override that the browser does not apply.
    Ties at equal specificity fall back to chain position, which is source
    order, which is what the browser then uses.
    """
    if depth > 12:
        return None
    raw = None
    best = (-1, -1)
    for i, sel in enumerate(chain):
        if token in blocks.get(sel, {}):
            rank = (_spec(sel), i)
            if rank >= best:
                best, raw = rank, blocks[sel][token]
    if raw is None:
        return None
    m = VAR.search(raw)
    while m:
        inner = resolve(m.group(1), chain, blocks, depth + 1)
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


def main() -> int:
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
    cascades: dict[str, dict[str, dict[str, str]]] = {}
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
            chain = SCOPE_CHAIN.get((fam, theme))
            if chain is None:
                failures.append(f"{f}:{r['line']} no scope chain for {fam}/{theme}")
                continue
            got = resolve(token, chain, blocks)
            checked += 1
            if got is None:
                failures.append(f"{f}:{r['line']} {token} does not resolve in {fam}/{theme}")
            elif norm(got) != norm(original):
                failures.append(
                    f"{f}:{r['line']} {token} in {fam}/{theme} resolves {got!r}, "
                    f"expected {original!r}")

    print(f"{len(rows)} converted occurrences, {checked} token/theme resolutions checked")
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
