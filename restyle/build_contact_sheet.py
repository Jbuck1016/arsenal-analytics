"""Build restyle/contact-sheet.html: every view in the app, in both themes,
on one page, for a human to scroll.

Live iframes rather than captured images, deliberately. A screenshot harness
was tried in Phase 0 and abandoned because the pages fetch live data and a
database rebuild was refreshing matviews underneath it: 32 of 52 surfaces
"differed" on an unchanged tree. Iframes have none of that problem. They also
pick up whatever the data says in the morning rather than what it said
tonight, and they inherit the reviewer's gate session, so the password overlay
does not cover every panel.

Each frame carries ?theme=, which theme.js honours as a one-page override that
does not persist -- so a sheet with thirty frames on it does not fight the
reviewer's own choice, and light and dark can sit side by side.
"""
from __future__ import annotations

import html
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "restyle" / "contact-sheet.html"

# page -> the tabs worth a frame each. A page with no tabs gets one frame.
# The tab names are exactly the strings the pages' TABS arrays hold, because
# ?tab= is compared against those.
VIEWS = [
    ("players.html", "Player Fingerprints",
     ["Player", "Chain roles", "Rank", "Scatter", "Scout", "Compare", "Plot studio"]),
    ("teams.html", "Team Profiles",
     ["Profile", "Sequences", "Maps", "Rankings", "League Map", "Matches", "Squad"]),
    ("match.html", "Match workspace", []),
    ("index.html", "Home", []),
    ("insights.html", "Insights", []),
    ("search.html", "Search", []),
    ("sequences.html", "Sequence Explorer", []),
    ("glossary.html", "Metric reference", []),
    ("market-values.html", "Market intelligence", []),
    ("model-lab.html", "Model laboratory", []),
    ("model-review.html", "Domestic forecast lab", []),
    ("writing-lab.html", "Writing lab", []),
    ("guide.html", "Field guide", []),
    ("methodology.html", "Methodology", []),
    ("validation.html", "Metrics validation", []),
]

HEAD = """<!doctype html>
<html lang="en" class="dark fam-doc">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Contact sheet &middot; every view, both themes</title>
<script src="../dashboard/theme.js"></script>
<link rel="stylesheet" href="../dashboard/tokens.css">
<link rel="stylesheet" href="../dashboard/theme.css">
<style>
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font-family:var(--f-body,Inter,system-ui,sans-serif)}
header{position:sticky;top:0;z-index:5;background:var(--panel);border-bottom:1px solid var(--line);
  padding:14px 20px;display:flex;gap:16px;align-items:baseline;flex-wrap:wrap}
h1{font:800 17px/1.2 var(--f-disp,inherit);margin:0;letter-spacing:-.02em}
.lede{font:500 11.5px/1.6 var(--f-body,inherit);color:var(--dim);max-width:70ch}
.controls{margin-left:auto;display:flex;gap:6px}
.controls button{font:600 10px/1 var(--f-body,inherit);padding:7px 11px;border-radius:5px;
  background:var(--surface2,var(--panel2));border:1px solid var(--line);color:var(--dim);cursor:pointer}
.controls button.on{background:var(--amber-dim,var(--accent-dim));border-color:var(--amber-line,var(--accent-glow));
  color:var(--amber,var(--accent))}
main{padding:18px 20px 60px}
section{margin:0 0 26px}
h2{font:700 12px/1 var(--f-mono,monospace);letter-spacing:.14em;text-transform:uppercase;
  color:var(--dim2);margin:0 0 10px;padding-bottom:7px;border-bottom:1px solid var(--line)}
.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;margin-bottom:16px}
@media(max-width:1100px){.pair{grid-template-columns:1fr}}
figure{margin:0;border:1px solid var(--line);border-radius:7px;overflow:hidden;background:var(--panel)}
figcaption{font:600 10px/1 var(--f-mono,monospace);letter-spacing:.06em;color:var(--dim);
  padding:8px 10px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;gap:10px}
figcaption b{color:var(--text);font-weight:700}
.shot{height:520px;overflow:hidden;position:relative;background:var(--panel2)}
/* The app is built for a wide window. Render each frame at desktop width and
   scale it down, rather than showing every page in its mobile layout. */
.shot iframe{width:1440px;height:1040px;border:0;transform:scale(.5);transform-origin:0 0;
  display:block}
body.one .pair{grid-template-columns:1fr}
body.hide-light figure[data-theme="light"],body.hide-dark figure[data-theme="dark"]{display:none}
</style>
</head>
<body>
<header>
  <div>
    <h1>Contact sheet</h1>
    <div class="lede">Every view in the app, light and dark, side by side. Live
      frames, not captures, so this shows whatever the data says now &mdash; and
      it needs your gate session, so unlock one page in this browser first if the
      frames show the password overlay. Each frame is rendered at 1440px and
      scaled to half, which is why the type looks small; open a frame in its own
      tab to read it.</div>
  </div>
  <div class="controls">
    <button type="button" class="on" onclick="setMode('both',this)">Both</button>
    <button type="button" onclick="setMode('light',this)">Light only</button>
    <button type="button" onclick="setMode('dark',this)">Dark only</button>
  </div>
</header>
<main>
"""

TAIL = """</main>
<script>
function setMode(m,btn){
  document.body.classList.toggle('hide-light',m==='dark');
  document.body.classList.toggle('hide-dark',m==='light');
  document.body.classList.toggle('one',m!=='both');
  document.querySelectorAll('.controls button').forEach(function(b){b.classList.toggle('on',b===btn)});
}
</script>
</body>
</html>
"""


def frame(src: str, label: str, theme: str) -> str:
    return (f'    <figure data-theme="{theme}">\n'
            f'      <figcaption><b>{html.escape(label)}</b><span>{theme}</span></figcaption>\n'
            f'      <div class="shot"><iframe loading="lazy" title="{html.escape(label)} '
            f'{theme}" src="{html.escape(src)}"></iframe></div>\n'
            f'    </figure>\n')


def main() -> int:
    missing = [p for p, _, _ in VIEWS if not (ROOT / "dashboard" / p).exists()]
    if missing:
        print("these pages do not exist: " + ", ".join(missing))
        return 1

    out = [HEAD]
    frames = 0
    for page, title, tabs in VIEWS:
        out.append(f'  <section>\n    <h2>{html.escape(title)} &mdash; {html.escape(page)}</h2>\n')
        for tab in (tabs or [None]):
            q = "?theme={t}" + (f"&tab={tab.replace(' ', '%20')}" if tab else "")
            label = title + (f" · {tab}" if tab else "")
            out.append('    <div class="pair">\n')
            for theme in ("light", "dark"):
                out.append(frame("../dashboard/" + page + q.format(t=theme), label, theme))
                frames += 1
            out.append("    </div>\n")
        out.append("  </section>\n")
    out.append(TAIL)
    OUT.write_text("".join(out), encoding="utf-8")
    print(f"contact-sheet.html: {len(VIEWS)} pages, "
          f"{sum(len(t) or 1 for _, _, t in VIEWS)} views, {frames} frames")
    return 0


if __name__ == "__main__":
    sys.exit(main())
