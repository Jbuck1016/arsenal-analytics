"""Every CSS declaration paints what it painted at the branch point.

WHY THIS EXISTS ALONGSIDE THE OTHER TWO GATES
assert_tokens.py checks the custom properties I remembered to write down.
assert_page_parity.py checks every custom property a page reads. Neither looks
at an ORDINARY declaration. Replacing `color:#16a34a` with
`color:var(--positive-ink)` is the actual work of this refactor, and until now
nothing verified that the token resolves to the colour it replaced -- the
var() site is new, so page parity only asks whether it resolves at all.

So this parses every rule out of a page's inline <style>, keyed by at-rule
context plus selector plus property, expands var() in the value, and requires
the result to equal what the same declaration computed at the branch point.
It covers the declarations nobody touched as well as the ones I edited, which
is the point: a token whose value moved underneath an untouched rule is
exactly the failure the ledger cannot see.

WHAT IT CANNOT SEE
Which rule WINS for a given element. It compares a declaration with itself
across revisions, so merging two theme-scoped rules into one tokenised rule
looks like a change even when the painted result is identical. Those merges
are listed in GONE and SURVIVED below, each naming the token that now carries
the value -- and that token's value is asserted by the ledger.

    python restyle/assert_rule_parity.py
    python restyle/assert_rule_parity.py dashboard/match.html
"""
from __future__ import annotations

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import assert_tokens as A  # noqa: E402
import assert_page_parity as P  # noqa: E402

# THE MERGES. Where two theme-scoped rules painted one element, tokenising
# leaves one rule whose token carries both values, and the other rule goes.
# That shows up here twice: the removed rule is missing, and the surviving one
# no longer matches in the theme where the removed rule used to win. Both are
# listed, per page, and neither is taken on trust -- the token named in each
# entry has its value asserted for both themes in token-map.csv.
#
# GONE: (selector, property) that no longer exists, and the token that absorbed it.
GONE = {
    "dashboard/match.html": [
        ("html.dark .stbl tbody tr:nth-child(even) td", "background", "--row-stripe"),
        ("html.dark .res-w", "background", "--result-win-fill"),
        ("html.dark .res-d", "background", "--result-draw-fill"),
        ("html.dark .res-l", "background", "--result-loss-fill"),
        ("html:not(.dark) .hdr", "background", "--float-header"),
        ("html:not(.dark) .side", "background", "--float-rail"),
        ("html:not(.dark) .view-team-bar", "background", "--float-bar"),
        ("html:not(.dark) .timeline", "background", "--float-timeline"),
        ("html:not(.dark) .tw-panel", "background", "--float-tools"),
        ("html:not(.dark) .panel", "background", "--float-panel"),
        ("html:not(.dark) .concept-info-bar", "background", "--float-rail"),
        ("html:not(.dark) .ps-side", "background", "--float-rail"),
        ("html:not(.dark) .ps-hl-card", "background", "--float-card"),
        ("html:not(.dark) .sb-group", "background", "--float-card"),
        ("html:not(.dark) .mom-chart-wrap", "background", "--float-card"),
        ("html:not(.dark) .mom-heat-panel", "background", "--float-card"),
        ("html:not(.dark) .mom-moments", "background", "--float-card"),
    ],
}
# SURVIVED: (selector, property, theme) where the rule remains but the removed
# one used to win, so its own declaration was never what painted in that theme.
SURVIVED = {
    "dashboard/match.html": [
        (".stbl tbody tr:nth-child(even) td", "background", "dark"),
        (".res-w", "background", "dark"),
        (".res-d", "background", "dark"),
        (".res-l", "background", "dark"),
        (".hdr", "background", "light"),
        (".side", "background", "light"),
        (".view-team-bar", "background", "light"),
        (".timeline", "background", "light"),
        (".tw-panel", "background", "light"),
        (".panel", "background", "light"),
        (".concept-info-bar", "background", "light"),
        (".ps-side", "background", "light"),
        (".ps-hl-card", "background", "light"),
        (".sb-group", "background", "light"),
        (".mom-chart-wrap", "background", "light"),
        (".mom-heat-panel", "background", "light"),
        (".mom-moments", "background", "light"),
    ],
}

DECL = re.compile(r"([-a-zA-Z][-\w]*)\s*:\s*([^;]+)")


def rules(css: str) -> dict[tuple[str, str, str], str]:
    """{(at-rule context, selector, property): value} for every declaration.

    Brace matching rather than a regex, so an @media wrapper becomes context on
    the rules inside it instead of colliding with the same selector outside.
    """
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out: dict[tuple[str, str, str], str] = {}
    stack: list[str] = []
    buf, i = [], 0
    while i < len(css):
        ch = css[i]
        if ch == "{":
            head = " ".join("".join(buf).split())
            buf = []
            # An at-rule with a block becomes context; anything else is a
            # selector whose body is the declarations that follow.
            if head.startswith("@"):
                stack.append(head)
                i += 1
                continue
            j, depth = i + 1, 1
            while j < len(css) and depth:
                if css[j] == "{":
                    depth += 1
                elif css[j] == "}":
                    depth -= 1
                j += 1
            body = css[i + 1:j - 1]
            ctx = " ".join(stack)
            for sel in [s for s in (" ".join(a.split()) for a in head.split(",")) if s]:
                for prop, val in DECL.findall(body):
                    out[(ctx, sel, prop.lower())] = " ".join(val.split())
            i = j
            continue
        if ch == "}":
            if stack:
                stack.pop()
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    return out


def expand(value: str, classes: set[str], blocks) -> str:
    """Substitute every var() in a declaration value with what it paints."""
    for _ in range(12):
        sites = P.var_sites(value)
        if not sites:
            return value
        for s in sites:
            got = P.paint(s, classes, blocks)
            if got is None:
                return value.replace(s, "⚠UNRESOLVED")
            value = value.replace(s, got)
    return value


def check(page: str) -> list[str]:
    now_src = (A.ROOT / page).read_text(encoding="utf-8")
    was_src = P._at(P.BASE, page)
    if was_src is None:
        return [f"{page}: did not exist at {P.BASE}"]

    # The page's inline <style> AND the stylesheets it links. shell.css is
    # shared by four pages and carries real rules, not just a palette; leaving
    # it out would have meant the one converted file with actual declarations
    # in it was the one file nothing checked.
    def css_of(src, at):
        parts = []
        for name in P.LINKED.findall(src):
            s = P._at(at, f"dashboard/{name}") if at else None
            if at is None:
                f = A.ROOT / "dashboard" / name
                s = f.read_text(encoding="utf-8") if f.exists() else None
            if s:
                parts.append(s)
        parts += re.findall(r"<style>(.*?)</style>", src, re.S)
        return "\n".join(parts)

    was_r, now_r = rules(css_of(was_src, P.BASE)), rules(css_of(now_src, None))
    was_c, now_c = P._cascade(was_src, P.BASE), P._cascade(now_src, None)
    fam_was, fam_now = P._family(was_src), P._family(now_src)
    gone = {(s, p) for s, p, _ in GONE.get(page, [])}
    survived = {(s, p, th) for s, p, th in SURVIVED.get(page, [])}

    bad = []
    for key, was_val in was_r.items():
        ctx, sel, prop = key
        if prop.startswith("--"):
            continue          # custom properties are assert_page_parity's job
        if (sel, prop) in gone:
            continue
        if key not in now_r:
            bad.append(f"{page} {sel} {{{prop}}} was removed and is not in GONE")
            continue
        for theme in ("light", "dark"):
            if (sel, prop, theme) in survived:
                continue
            b = expand(was_val, A.STATE[(fam_was, theme)], was_c)
            a = expand(now_r[key], A.STATE[(fam_now, theme)], now_c)
            if A.norm(b) != A.norm(a):
                bad.append(f"{page} {theme:5} {sel} {{{prop}}} was {b!r}, now {a!r}")
    return bad


def main() -> int:
    pages = sys.argv[1:] or [f"dashboard/{p.name}"
                             for p in sorted((A.ROOT / "dashboard").glob("*.html"))
                             if f"dashboard/{p.name}" in A.FAMILY]
    failures = []
    for page in pages:
        failures += check(page)
    print(f"{len(pages)} page(s) checked for declaration parity with {P.BASE}")
    if failures:
        print(f"\n{len(failures)} DECLARATIONS CHANGED:")
        for x in failures[:80]:
            print("  " + x)
        if len(failures) > 80:
            print(f"  ...and {len(failures)-80} more")
        return 1
    print("every CSS declaration expands to what it expanded to before")
    return 0


if __name__ == "__main__":
    sys.exit(main())
