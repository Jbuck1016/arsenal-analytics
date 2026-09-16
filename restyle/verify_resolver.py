"""Does the resolver agree with a browser?

The three static gates all rest on one assumption: that assert_tokens.resolve()
models the cascade the way Chrome does. Specificity, source order, :not(),
selector lists, the alias chain -- all of it is a reimplementation, and every
conclusion in this phase inherits its mistakes. Two of its bugs have already
been found by accident rather than by testing it.

So this tests it. For every page, in both themes, it loads the real file in a
browser and compares getComputedStyle on the root element against what the
resolver predicts, for every custom property the page's cascade defines.

A disagreement means the gates are certifying a model rather than the site.

    python restyle/verify_resolver.py
"""
from __future__ import annotations

import pathlib
import re
import sys

from playwright.sync_api import sync_playwright

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import assert_tokens as A  # noqa: E402
import assert_page_parity as P  # noqa: E402

# match.html writes --accent, --accent-dim and --accent-glow onto the root
# element with setProperty at runtime, so the browser is right and the
# resolver is right and they disagree. That is hole 1 in gate-limitations.md,
# not a resolver bug.
RUNTIME_OVERRIDDEN = {"dashboard/match.html": {"--accent", "--accent-dim",
                                               "--accent-glow", "--bg", "--bg2"}}


def main() -> int:
    pages = [f"dashboard/{p.name}"
             for p in sorted((A.ROOT / "dashboard").glob("*.html"))
             if f"dashboard/{p.name}" in A.FAMILY]
    bad, checked = [], 0

    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        for page in pages:
            src = (A.ROOT / page).read_text(encoding="utf-8")
            fam = P._family(src)
            blocks = P._cascade(src, None)
            names = sorted({n for _, decls in blocks for n in decls})
            skip = RUNTIME_OVERRIDDEN.get(page, set())

            tab = browser.new_page()
            tab.goto((A.ROOT / page).as_uri())
            tab.wait_for_timeout(1200)
            for theme in ("light", "dark"):
                tab.evaluate("t => document.documentElement.classList.toggle('dark', t==='dark')",
                             theme)
                got = tab.evaluate(
                    """ns => { const cs = getComputedStyle(document.documentElement), o = {};
                               for (const n of ns) o[n] = cs.getPropertyValue(n).trim();
                               return o; }""", names)
                for n in names:
                    if n in skip:
                        continue
                    want = A.resolve(n, A.STATE[(fam, theme)], blocks)
                    have = got[n] or None
                    checked += 1
                    if want is None and have is None:
                        continue
                    if want is None or have is None or A.norm(want) != A.norm(have):
                        bad.append(f"{page} {theme:5} {n:24} browser {have!r}, "
                                   f"resolver {want!r}")
            tab.close()
        browser.close()

    print(f"{checked} custom-property resolutions compared against Chrome "
          f"across {len(pages)} pages")
    if bad:
        print(f"\n{len(bad)} DISAGREEMENTS -- the gates are modelling something "
              f"the browser does not do:")
        for x in bad[:60]:
            print("  " + x)
        if len(bad) > 60:
            print(f"  ...and {len(bad)-60} more")
        return 1
    print("the resolver and the browser agree everywhere")
    return 0


if __name__ == "__main__":
    sys.exit(main())
