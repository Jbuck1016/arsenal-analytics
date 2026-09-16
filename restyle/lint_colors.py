"""Ban raw colour literals outside tokens.css.

Phase 1 moved every colour on every live surface into dashboard/tokens.css.
This is what stops them coming back. It fails the build on a literal in a
page, a stylesheet or a script.

WHAT IT MUST NOT FLAG, or it fails forever on things that are correct. Each
of these is a real category found while writing the phase it polices, and all
of them are recorded in restyle/deliberate-skips.csv -- which this reads,
rather than rediscovering them:

  * HTML numeric entities. `&#11015;` is a download arrow, not a colour, and
    a bare hex scan finds eighteen of them in match.html alone.
  * Comment prose. The comments that explain why a literal survives name the
    literal; a scanner that cannot tell code from prose flags the explanation.
  * The fallback position of a var(). `var(--dim,#8b95b5)` is a default for a
    token that does resolve. It is not a component choosing a colour.
  * `white` inside `white-space`, and every other colour word that is part of
    an identifier: --gold, --red-bright, .res-w, blueprint.
  * TEAM_COLORS in match.html. Fifteen club colours, which are facts about
    the clubs rather than design tokens, and whose home is the database.

    python restyle/lint_colors.py
"""
from __future__ import annotations

import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIPS = ROOT / "restyle" / "deliberate-skips.csv"

# tokens.css is where colours are allowed to be. The two generated data files
# are machine output, not authored style.
EXEMPT_FILES = {"tokens.css", "model-lab-data.js", "model-review-data.js"}

HEX = re.compile(r"(?<![\w&])#[0-9a-fA-F]{3,8}(?![\w])")
FUNC = re.compile(r"(?<![\w-])(?:rgba?|hsla?)\(\s*[\d.]")
# Colour words, only where they cannot be part of an identifier. That single
# pair of lookarounds is what keeps `white-space`, `--red-bright` and
# `var(--gold)` out of the results.
NAMED = re.compile(
    r"(?<![\w-])(white|black|red|green|blue|yellow|orange|purple|pink|brown|"
    r"grey|gray|silver|gold|cyan|magenta|teal|navy|olive|maroon|lime|aqua|"
    r"fuchsia|indigo|violet|beige|ivory|khaki|coral|salmon|crimson|tomato)"
    r"(?![\w-])")


def strip_comments(src: str, kind: str) -> str:
    """Blank out comments, preserving offsets so line numbers stay true."""
    def blank(m):
        return re.sub(r"\S", " ", m.group(0))
    src = re.sub(r"/\*.*?\*/", blank, src, flags=re.S)
    if kind == "js":
        # Line comments, but not the // inside a URL or a regex-ish string.
        src = re.sub(r"(?m)(^|[^:\w\\])//[^\n]*", lambda m: m.group(1) + blank(
            type("o", (), {"group": lambda s, i=0: m.group(0)[len(m.group(1)):]})()), src)
    return src


def blank_entities(src: str) -> str:
    return re.sub(r"&#\d+;", lambda m: " " * len(m.group(0)), src)


def var_fallback_spans(src: str):
    """Character ranges that sit in the fallback position of a var()."""
    spans, i = [], 0
    while True:
        i = src.find("var(", i)
        if i < 0:
            return spans
        depth, j, comma = 0, i + 3, -1
        while j < len(src):
            c = src[j]
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    break
            elif c == "," and depth == 1 and comma < 0:
                comma = j
            j += 1
        if j >= len(src):
            return spans
        if comma >= 0:
            spans.append((comma, j))
        i = i + 4


def team_colors_span(src: str):
    """The one object literal that is reference data rather than design."""
    i = src.find("const TEAM_COLORS=")
    if i < 0:
        return []
    j = src.find("};", i)
    return [(i, j)] if j > i else []


def allowed_from_ledger():
    """file -> the ledger text that file is allowed to keep.

    Containment, not equality. A skip row often records the whole declaration
    it justifies -- "0 1px 3px rgba(42,37,28,.12)" -- while the scanner finds
    the colour inside it. Matching the part against the whole is what makes
    one row cover one literal rather than needing a row per fragment.
    """
    allow = {}
    if not SKIPS.exists():
        return allow
    for r in csv.DictReader(SKIPS.open(encoding="utf-8")):
        f, lit = r.get("file", ""), (r.get("literal") or "").strip()
        if f and lit:
            allow.setdefault(pathlib.Path(f).name, []).append(lit.lower())
    return allow


def is_allowed(name, lit, allow):
    low = lit.lower()
    return any(low in entry for entry in allow.get(name, []))


# A COLOUR WORD IS ONLY A COLOUR IN A VALUE POSITION.
# `white` in `white-space` is already excluded by the lookarounds, but `gold`
# in the selector `.stat-v.gold`, and `red` in the sentence "40% = opponent
# dominant (red)", are not. Both are ruled out by asking whether the word sits
# after a property name and a colon, inside the current declaration: scan back
# to the nearest declaration or string boundary and require `prop:` in what is
# left. Prose inside a JS string stops at the quote and has no colon; a
# selector stops at the brace and has no colon; `border:1px solid red` does.
_DECL = re.compile(r"(^|[\s;{(])([-a-zA-Z][-\w]*)\s*:")


_BOUNDARY = ";{}" + chr(39) + chr(34) + chr(10) + chr(96)


def in_value_position(clean, pos):
    start = max((clean.rfind(ch, 0, pos) for ch in _BOUNDARY), default=-1)
    return bool(_DECL.search(clean[start + 1:pos]))


def scan(path: pathlib.Path, allow):
    name = path.name
    raw = path.read_text(encoding="utf-8", errors="replace")
    kind = "css" if path.suffix == ".css" else "js"

    if path.suffix == ".html":
        # Only the parts that can carry a colour: the inline style and the
        # inline scripts. Body text cannot.
        regions = []
        for m in re.finditer(r"<style>(.*?)</style>", raw, re.S):
            regions.append((m.start(1), m.group(1), "css"))
        for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", raw, re.S):
            regions.append((m.start(1), m.group(1), "js"))
        # inline style="" attributes are style too
        for m in re.finditer(r'\sstyle="([^"]*)"', raw):
            regions.append((m.start(1), m.group(1), "css"))
    else:
        regions = [(0, raw, kind)]

    hits = []
    for base, text, k in regions:
        clean = blank_entities(strip_comments(text, k))
        skip = var_fallback_spans(clean) + (team_colors_span(clean) if name == "match.html" else [])

        def inside(pos):
            return any(a <= pos <= b for a, b in skip)

        for rx in (HEX, FUNC, NAMED):
            for m in rx.finditer(clean):
                if inside(m.start()):
                    continue
                lit = m.group(0)
                if rx is FUNC:
                    end = clean.find(")", m.start())
                    lit = clean[m.start():end + 1] if end > 0 else lit
                if rx is NAMED and not in_value_position(clean, m.start()):
                    continue
                if is_allowed(name, lit, allow):
                    continue
                line = raw.count("\n", 0, base + m.start()) + 1
                ctx = clean[max(0, m.start() - 44):m.start() + len(lit) + 26].strip()
                hits.append((line, lit, " ".join(ctx.split())))
    return hits


def main() -> int:
    allow = allowed_from_ledger()
    files = sorted(
        [p for p in (ROOT / "dashboard").glob("*.html")] +
        [p for p in (ROOT / "dashboard").glob("*.css")] +
        [p for p in (ROOT / "dashboard").glob("*.js")],
        key=lambda p: p.name)
    files = [p for p in files if p.name not in EXEMPT_FILES]

    total, offenders = 0, []
    for p in files:
        hits = scan(p, allow)
        if hits:
            offenders.append((p, hits))
            total += len(hits)

    allowed_n = sum(len(v) for v in allow.values())
    print(f"{len(files)} files scanned, {allowed_n} literals allowed by "
          f"restyle/deliberate-skips.csv")
    if not total:
        print("no raw colour literals outside tokens.css")
        return 0
    print(f"\n{total} RAW COLOUR LITERAL(S) OUTSIDE tokens.css:\n")
    for p, hits in offenders:
        print(f"  {p.relative_to(ROOT).as_posix()}")
        for line, lit, ctx in hits[:25]:
            print(f"    :{line:<6} {lit:<26} {ctx[:80]}")
        if len(hits) > 25:
            print(f"    ...and {len(hits)-25} more")
    print("\nA colour belongs in dashboard/tokens.css under a role name. If this one")
    print("genuinely has to stay, add it to restyle/deliberate-skips.csv with the")
    print("reason, and this will accept it.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
