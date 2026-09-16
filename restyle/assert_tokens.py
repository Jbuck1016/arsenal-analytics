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

# Selector -> (family, theme). A scope inherits from the ones before it.
SCOPE_CHAIN = {
    ("app", "light"): [":root"],
    ("app", "dark"): [":root", "html.dark"],
    ("doc", "light"): [":root", "html.fam-doc"],
    ("doc", "dark"): [":root", "html.dark", "html.fam-doc", "html.fam-doc.dark"],
    ("doc-aa", "light"): [":root", "html.fam-doc", "html.fam-doc.fam-doc-aa"],
    ("doc-aa", "dark"): [":root", "html.dark", "html.fam-doc", "html.fam-doc.dark",
                         "html.fam-doc.fam-doc-aa"],
    ("lab", "light"): [":root", "html.fam-lab"],
    ("lab", "dark"): [":root", "html.dark", "html.fam-lab", "html.fam-lab.dark"],
    ("gate", "light"): [":root"],
    ("gate", "dark"): [":root", "html.dark"],
}

BLOCK = re.compile(r"(?P<sel>[^{}]+)\{(?P<body>[^{}]*)\}", re.S)
DECL = re.compile(r"(--[\w-]+)\s*:\s*([^;]+);")
VAR = re.compile(r"var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*))?\)")


def parse_tokens() -> dict[str, dict[str, str]]:
    """selector -> {token: raw value}. Later blocks with the same selector merge."""
    css = TOKENS.read_text(encoding="utf-8")
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out: dict[str, dict[str, str]] = {}
    for m in BLOCK.finditer(css):
        sel = m.group("sel").strip()
        block = out.setdefault(sel, {})
        for name, val in DECL.findall(m.group("body")):
            block[name] = val.strip()
    return out


def resolve(token: str, chain: list[str], blocks: dict[str, dict[str, str]],
            depth: int = 0) -> str | None:
    """Resolve a token through the scope chain, following var() aliases.

    Later selectors in the chain win, matching CSS cascade for these scopes.
    """
    if depth > 12:
        return None
    raw = None
    for sel in chain:
        if token in blocks.get(sel, {}):
            raw = blocks[sel][token]
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
    """Normalise only case and equivalent hex forms. Nothing else."""
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
    # rgb/rgba spacing and trailing-zero alpha differences are NOT normalised:
    # a changed alpha is a changed colour and must fail.
    return v


def main() -> int:
    if not LEDGER.exists():
        print(f"no ledger at {LEDGER}; nothing converted yet")
        return 0
    blocks = parse_tokens()
    rows = list(csv.DictReader(LEDGER.open(encoding="utf-8")))
    if not rows:
        print("ledger is empty; nothing to assert")
        return 0

    failures, checked = [], 0
    for r in rows:
        f, token, original = r["file"], r["token"], r["original"]
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
