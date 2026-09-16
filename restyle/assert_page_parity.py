"""Phase 1's strongest claim, asserted directly: the page resolves the same
colours it resolved before the restyle.

WHY THIS EXISTS ALONGSIDE assert_tokens.py
token-map.csv is a ledger of what I remembered to record. It checks that each
literal I replaced resolves back to itself, which is necessary and not
sufficient: it says nothing about a token I did not touch whose value moved
underneath me. Two real cases from this branch:

  - the document pages read --amber, but the ledger rows name --accent-base,
    the role token behind it. Moving the --amber alias between scopes could
    have changed what --amber resolves to with every ledger row still passing.
  - a page's own :root light value also matches in DARK, because :root has no
    theme in it. Deleting a page's dark block can therefore let a light value
    leak into dark, and no ledger row is watching the alias it leaked into.

So this asserts the whole surface instead of a remembered subset: for every
var(--x) the page mentions, resolve it in light and in dark, before and after,
and require equality. "Before" is the file as it stood at the branch point,
resolved through that revision's tokens.css and theme.css, under whatever
family class it carried then (none, so app). "After" is the working tree under
the class it carries now. That is the Phase 1 contract stated as an assertion
rather than as an intention.

WHAT IT STILL CANNOT SEE
Everything in gate-limitations.md: values written by setProperty at runtime,
and a canvas silently discarding a var() string. This reads stylesheets.

    python restyle/assert_page_parity.py                  # every converted page
    python restyle/assert_page_parity.py dashboard/index.html
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import assert_tokens as A  # noqa: E402

BASE = "c855423"  # the branch point: the last commit before the restyle
USE = re.compile(r"var\(\s*(--[\w-]+)")


def var_sites(src: str) -> list[str]:
    """Every top-level var(...) expression in the source, text and all.

    A USAGE SITE, NOT A TOKEN, IS THE UNIT OF PARITY. players.html paints its
    selects with var(--bg2,var(--panel,#1a1d24)). Asking whether --panel
    changed value answers nothing, because --bg2 resolves and --panel is never
    reached; asking what the expression evaluates to answers the question the
    refactor is actually on the hook for.
    """
    sites, i = [], 0
    while True:
        i = src.find("var(", i)
        if i < 0:
            return sites
        depth, j = 0, i + 3
        while j < len(src):
            if src[j] == "(":
                depth += 1
            elif src[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j >= len(src):
            return sites
        site = src[i:j + 1]
        # Prose in a comment ("var() resolves exactly as it does in a
        # stylesheet") is not a usage site. A real one names a custom property.
        if re.match(r"var\(\s*--[\w-]+", site):
            sites.append(site)
        i = j + 1


def paint(expr: str, classes: set[str], blocks) -> str | None:
    """What a var() expression evaluates to, or None if the declaration using
    it is invalid. Mirrors the browser: the fallback is used only when the
    custom property is not defined, and the fallback may itself be a var()."""
    inner = expr[expr.index("(") + 1:-1]
    depth, cut = 0, -1
    for k, ch in enumerate(inner):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            cut = k
            break
    name = (inner if cut < 0 else inner[:cut]).strip()
    fallback = None if cut < 0 else inner[cut + 1:].strip()
    got = A.resolve(name, classes, blocks)
    if got is not None:
        return got
    if fallback is None or fallback == "":
        return None
    if fallback.startswith("var("):
        return paint(fallback, classes, blocks)
    return fallback


def _at(rev: str, path: str) -> str | None:
    """A file's contents at a revision, or None if it did not exist there."""
    r = subprocess.run(["git", "show", f"{rev}:{path}"], cwd=A.ROOT,
                       capture_output=True, text=True, encoding="utf-8")
    return r.stdout if r.returncode == 0 else None


# family name <- the fam-* classes that select it, read straight off STATE so
# adding a family to assert_tokens.py is enough. An earlier hand-written
# if-chain here did not know about fam-market and silently called that page
# app-family, which reported all eighteen of its colours as changed.
# "gate" is gate.js's scope, not an HTML page family, and it shares app's empty
# class set; leaving it in made every classless page resolve as gate.
_BY_CLASSES = {frozenset(c for c in classes if c.startswith("fam-")): fam
               for (fam, theme), classes in A.STATE.items()
               if theme == "light" and fam != "gate"}


def _family(html: str) -> str:
    """The family a page's <html> tag puts it in. No fam- class means app."""
    tag = re.search(r"<html[^>]*>", html)
    classes = frozenset(re.findall(r"fam-[\w-]+", tag.group() if tag else ""))
    fam = _BY_CLASSES.get(classes)
    if fam is None:
        raise SystemExit(f"<html> carries {sorted(classes)}, which matches no "
                         f"family in assert_tokens.STATE")
    return fam


def _cascade(page_src: str, tokens_src: str | None, theme_src: str | None):
    """tokens.css, theme.css, then the page's inline <style>, in source order."""
    out = []
    for css in [tokens_src, theme_src]:
        if css:
            out += A._blocks_from(css)
    for style in re.findall(r"<style>(.*?)</style>", page_src, re.S):
        out += A._blocks_from(style)
    return out


def check(page: str) -> list[str]:
    now_src = (A.ROOT / page).read_text(encoding="utf-8")
    was_src = _at(BASE, page)
    if was_src is None:
        return [f"{page}: did not exist at {BASE}; nothing to compare against"]

    was = _cascade(was_src, _at(BASE, "dashboard/tokens.css"),
                   _at(BASE, "dashboard/theme.css"))
    now = _cascade(now_src,
                   (A.ROOT / "dashboard" / "tokens.css").read_text(encoding="utf-8"),
                   (A.ROOT / "dashboard" / "theme.css").read_text(encoding="utf-8"))
    fam_was, fam_now = _family(was_src), _family(now_src)

    # PARITY IS ASKED OF THE EXPRESSIONS THE PAGE PAINTED BEFORE. Comparing the
    # new role names -- --ground, --ink-primary -- against the branch point
    # asks what they resolved to before they existed, and answers None every
    # time; they are the mechanism, not the surface.
    bad = []
    for theme in ("light", "dark"):
        for expr in sorted(set(var_sites(was_src))):
            b = paint(expr, A.STATE[(fam_was, theme)], was)
            a = paint(expr, A.STATE[(fam_now, theme)], now)
            if b is None and a is None:
                continue
            if b is None or a is None or A.norm(b) != A.norm(a):
                bad.append(f"{page} {theme:5} {expr:44} painted {b!r}, now {a!r}")
        # Expressions only the new source paints still have one thing to prove:
        # that they evaluate at all. An unresolved var() with no fallback
        # invalidates the whole declaration, so a typo'd role name paints
        # nothing and raises no error anywhere.
        for expr in sorted(set(var_sites(now_src)) - set(var_sites(was_src))):
            if paint(expr, A.STATE[(fam_now, theme)], now) is None:
                bad.append(f"{page} {theme:5} {expr:44} evaluates to nothing; "
                           f"the declaration using it is invalid")
    return bad


def main() -> int:
    if len(sys.argv) > 1:
        pages = sys.argv[1:]
    else:
        # EVERY page, not just the converted ones. tokens.css is linked by all
        # of them, so a token added there can change a page nobody has touched:
        # match.html reads var(--dim,#8b95b5) and had no --dim at the branch
        # point, so introducing a --dim alias silently replaced its fallback.
        # An unconverted page is exactly where that goes unnoticed.
        pages = [f"dashboard/{p.name}"
                 for p in sorted((A.ROOT / "dashboard").glob("*.html"))
                 if f"dashboard/{p.name}" in A.FAMILY]

    failures = []
    for page in pages:
        failures += check(page)

    print(f"{len(pages)} page(s) checked for paint parity with {BASE}")
    if failures:
        print(f"\n{len(failures)} TOKENS CHANGED VALUE:")
        for x in failures[:80]:
            print("  " + x)
        if len(failures) > 80:
            print(f"  ...and {len(failures)-80} more")
        return 1
    print("every token every page reads resolves to what it resolved before")
    return 0


if __name__ == "__main__":
    sys.exit(main())
