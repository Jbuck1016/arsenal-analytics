"""What does adding a family class to a page actually change?

THE PROBLEM THIS EXISTS FOR
tokens.css keys values by a class on <html>, and no page sets one yet, so every
page currently resolves as app family. Steps 1-6 of the conversion order set
fam-doc, fam-doc-aa or fam-lab on pages that have never carried one. The family
scopes sit at (0,2,1), above a page's own :root at (0,1,0), so adding the class
can overwrite a value the page declared for itself -- silently, with no error,
and invisibly to assert_tokens.py, which only checks rows already in the ledger.

A page that renders differently the moment its family class lands has failed
Phase 1 before a single literal is tokenised. So this reports, for every token
the page actually reads, what it resolves to under the app chain it has today
and under the family chain it is about to get, and lists only the differences.

    python restyle/family_diff.py dashboard/index.html doc
    python restyle/family_diff.py dashboard/guide.html doc-aa

Exit code is non-zero if any referenced token changes value, so "no output, exit
0" is the result that means the class is safe to add. A token the page declares
but never reads is reported separately as dead: it cannot change what is
painted, and it is not a reason to hold the class back.
"""
from __future__ import annotations

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from assert_tokens import (ROOT, STATE, _blocks_from, norm,  # noqa: E402
                           parse_cascade, resolve)

# Every var(--x) in the page, including inside JS string literals, since several
# pages hand var() strings to inline styles at runtime.
USE = re.compile(r"var\(\s*(--[\w-]+)")


def referenced(page: str) -> set[str]:
    return set(USE.findall((ROOT / page).read_text(encoding="utf-8")))


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    page, fam = sys.argv[1], sys.argv[2]
    if not (ROOT / page).exists():
        print(f"no such page: {page}")
        return 2

    # THIS IS A PRE-CONVERSION INSTRUMENT AND ONLY ANSWERS A PRE-CONVERSION
    # QUESTION. It compares the page against the app chain it has today and the
    # family chain it is about to get. Once the class is on the page, the page
    # has been rewritten to depend on the family, so an app-chain comparison
    # reports every family value as a difference -- true, and no longer a
    # warning about anything. Refuse rather than print a scary and meaningless
    # list; assert_tokens.py is what certifies a converted page.
    html_tag = re.search(r"<html[^>]*>", (ROOT / page).read_text(encoding="utf-8"))
    already = re.search(r"\bfam-[\w-]+", html_tag.group()) if html_tag else None
    if already:
        print(f"{page} already carries {already.group()} on <html>; it has been "
              f"converted.\nRun assert_tokens.py instead: this tool only compares "
              f"an UNCONVERTED page against the family it is about to join.")
        return 0

    blocks = parse_cascade(page)
    used = referenced(page)

    # Tokens reachable only through an alias chain count as referenced too: a
    # page that reads var(--bg) is reading --ground, and --ground is where the
    # family scopes actually differ. Walking the aliases would duplicate
    # resolve(); comparing the resolved value of the name the page reads
    # already covers it, because resolve() follows the alias to the end.
    changed, dead = [], []
    for theme in ("light", "dark"):
        before = STATE[("app", theme)]
        after = STATE[(fam, theme)]
        for tok in sorted(used):
            b = resolve(tok, before, blocks)
            a = resolve(tok, after, blocks)
            if b is None and a is None:
                continue
            if b is None or a is None or norm(b) != norm(a):
                changed.append((theme, tok, b, a))

    # Declarations THE PAGE ITSELF makes that nothing on it reads. Scanned from
    # the page's own inline <style> only: reading them off the merged cascade
    # instead would report every token tokens.css declares as dead on every
    # page, which is true and useless.
    declared = set()
    for style in re.findall(r"<style>(.*?)</style>",
                            (ROOT / page).read_text(encoding="utf-8"), re.S):
        for _sel, decls in _blocks_from(style):
            declared |= set(decls)
    dead = sorted(declared - used)

    print(f"{page}  ->  family {fam}")
    print(f"  {len(used)} tokens referenced by the page")
    if dead:
        print(f"\n  {len(dead)} declared but never read (safe to delete, cannot "
              f"change a pixel):\n    " + "  ".join(dead))
    if changed:
        print(f"\n  {len(changed)} REFERENCED TOKENS CHANGE VALUE:")
        for theme, tok, b, a in changed:
            print(f"    {theme:5}  {tok:24} {b!r}  ->  {a!r}")
    else:
        print("\n  no referenced token changes value; the class is safe to add")
    return 1 if changed else 0


if __name__ == "__main__":
    sys.exit(main())
