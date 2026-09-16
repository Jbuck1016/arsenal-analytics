"""Prove the canvas bridge in a browser, because no static gate can.

restyle/gate-limitations.md names two blind spots. This closes the second one
for match.html: a canvas silently discards a value it cannot parse, so
ctx.fillStyle='var(--pitch-fill)' leaves the previous fill in place and
reports nothing. A stylesheet gate cannot see that, and neither can a reader.

So this loads match.html in a real browser and asks three things:

  1. CT() returns, in each theme, exactly the ten values the hand-mirrored
     palette returned before the bridge replaced it. Those values are written
     out below rather than read from tokens.css -- reading them from the file
     the bridge reads would make this a tautology.
  2. The export case works: with EXP_LIGHT set while the document is dark,
     CT() returns the LIGHT palette. That is the case an element-scoped
     approach cannot do, and the reason both palettes are captured up front.
  3. Every value the bridge produces is one a canvas actually accepts. Each is
     assigned to ctx.fillStyle and read back; a canvas normalises what it
     accepts and ignores what it does not, so a value that comes back as the
     previous fill was silently discarded.

    python restyle/verify_canvas_bridge.py
"""
from __future__ import annotations

import pathlib
import sys

from playwright.sync_api import sync_playwright

PAGE = pathlib.Path(__file__).resolve().parent.parent / "dashboard" / "match.html"

# What CT() returned before the bridge, transcribed from the deleted literals.
EXPECT = {
    "dark": {"pitch": "#111722", "line": "rgba(182,194,212,0.22)",
             "lineStrong": "rgba(226,184,119,0.52)", "band": "rgba(90,169,255,0.018)",
             "text": "rgba(242,245,250,0.90)", "textSoft": "rgba(182,194,212,0.48)",
             "chipBg": "rgba(14,18,25,0.92)", "chipText": "#f2f5fa",
             "passOk": "#3ddc97", "passFail": "#ff6b63"},
    "light": {"pitch": "#f0ead6", "line": "#888", "lineStrong": "#666",
              "band": "rgba(0,0,0,0.012)", "text": "#333",
              "textSoft": "rgba(0,0,0,0.40)", "chipBg": "rgba(25,28,34,0.90)",
              "chipText": "#fff", "passOk": "#12855a", "passFail": "#cc4038"},
}

PROBE = """() => {
  const out = {};
  const root = document.documentElement;
  const was = root.classList.contains('dark');
  const snap = () => { const c = CT(), o = {}; for (const k in c) o[k] = c[k]; return o; };

  root.classList.add('dark');    EXP_LIGHT = false; out.dark  = snap();
  root.classList.remove('dark'); EXP_LIGHT = false; out.light = snap();
  // The export case: document dark, palette light.
  root.classList.add('dark');    EXP_LIGHT = true;  out.exportWhileDark = snap();
  EXP_LIGHT = false;
  if (!was) root.classList.remove('dark');

  // Does a canvas accept each value? Set a known fill first, then assign the
  // token value; if the canvas rejected it the read-back is still the marker.
  const ctx = document.createElement('canvas').getContext('2d');
  out.canvas = {};
  for (const theme of ['dark', 'light']) {
    out.canvas[theme] = {};
    for (const k in out[theme]) {
      ctx.fillStyle = '#010203';
      ctx.fillStyle = out[theme][k];
      out.canvas[theme][k] = ctx.fillStyle;
    }
  }
  return out;
}"""


def main() -> int:
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page()
        page.goto(PAGE.as_uri())
        page.wait_for_function("() => typeof CT === 'function'", timeout=15_000)
        got = page.evaluate(PROBE)
        browser.close()

    bad = []
    for theme, want in EXPECT.items():
        for k, v in want.items():
            if got[theme].get(k) != v:
                bad.append(f"CT() in {theme}: {k} is {got[theme].get(k)!r}, expected {v!r}")
    for k, v in EXPECT["light"].items():
        if got["exportWhileDark"].get(k) != v:
            bad.append(f"export case: {k} is {got['exportWhileDark'].get(k)!r}, "
                       f"expected the light {v!r}")
    for theme in ("dark", "light"):
        for k, v in got["canvas"][theme].items():
            if v == "#010203":
                bad.append(f"canvas DISCARDED {theme} {k} = "
                           f"{got[theme][k]!r}; it would paint the previous fill")

    n = sum(len(v) for v in EXPECT.values())
    print(f"{n * 2} palette values checked, {n} export values, "
          f"{n * 2} canvas acceptance checks")
    if bad:
        print(f"\n{len(bad)} FAILURES:")
        for x in bad:
            print("  " + x)
        return 1
    print("the bridge returns the pre-conversion palette in both themes, "
          "returns light during an export from a dark page, and every value "
          "it produces is one a canvas accepts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
