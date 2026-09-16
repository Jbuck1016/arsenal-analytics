"""Prove the token bridge in a browser, because no static gate can.

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

# What the JavaScript palettes held before the bridge, transcribed from the
# deleted literals. Transcribed, not read from tokens.css: reading them from
# the file the bridge reads would make every check below a tautology.
JS_EXPECT = {
    # theme-independent: the same object in light and dark
    "both": {
        "defColors": {"Tackle": "#ef4444", "Interception": "#2563eb",
                      "Clearance": "#7c3aed", "BallRecovery": "#16a34a",
                      "BlockedPass": "#d4a017", "Aerial": "#0891b2",
                      "Challenge": "#db2777"},
        "lineColorsSub": {"GK": "#d4a017", "DC": "#2563eb", "DL": "#2563eb",
                          "DR": "#2563eb", "DMC": "#0d9488", "MC": "#16a34a",
                          "ML": "#16a34a", "MR": "#16a34a", "AMC": "#84cc16",
                          "AML": "#84cc16", "AMR": "#84cc16", "FW": "#ef4444",
                          "FWL": "#ef4444", "FWR": "#ef4444", "Sub": "#9ca3af"},
        "teamAll": {"color": "#8b95b5", "colorDim": "rgba(139,149,181,0.10)",
                    "colorGlow": "rgba(139,149,181,0.24)",
                    "colorBright": "#8b95b5"},
    },
    "dark": {"shot": {"goal": "#f0a5ff", "ok": "#22e39a", "fail": "#ff5a5a",
                      "blocked": "#a78bfa", "post": "#ffc93c"}},
    "light": {"shot": {"goal": "#a1279b", "ok": "#0f7a52", "fail": "#bf3535",
                       "blocked": "#6641cf", "post": "#9a6b00"}},
}

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

  const js = () => ({
    defColors: defColors(),
    lineColorsSub: lineColors(true),
    shot: (() => { const s = shotPalette(true); return {
      goal: s.goal, ok: s.saved, fail: shotPalette(false).saved,
      blocked: s.blocked, post: s.post }; })(),
    teamAll: (() => { const a = TEAMS && TEAMS['__ALL__']; return a ? {
      color: a.color, colorDim: a.colorDim,
      colorGlow: a.colorGlow, colorBright: a.colorBright } : null; })(),
  });

  root.classList.add('dark');    EXP_LIGHT = false; out.dark  = snap(); out.jsDark  = js();
  root.classList.remove('dark'); EXP_LIGHT = false; out.light = snap(); out.jsLight = js();
  // The export case: document dark, palette light.
  root.classList.add('dark');    EXP_LIGHT = true;  out.exportWhileDark = snap();
  out.jsExportWhileDark = js();
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
        # TEAMS['__ALL__'] is built inside loadTeams(), which init() calls. Its
        # Supabase fetches all fail under file:// and are all caught, so it
        # still reaches the assignment -- but not before the page has been
        # parsed. Wait for it rather than testing whatever happens to exist.
        try:
            page.wait_for_function(
                "() => typeof TEAMS === 'object' && TEAMS && TEAMS['__ALL__']",
                timeout=20_000)
        except Exception:
            print("TEAMS['__ALL__'] never appeared: loadTeams() did not reach "
                  "its assignment, so the pseudo-team colours are UNVERIFIED")
            return 1
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

    # The JavaScript palettes.
    checked_js = 0
    for theme, key in (("dark", "jsDark"), ("light", "jsLight")):
        want = dict(JS_EXPECT["both"])
        want.update(JS_EXPECT[theme])
        for name, table in want.items():
            for k, v in table.items():
                checked_js += 1
                if (got[key].get(name) or {}).get(k) != v:
                    bad.append(f"{name} in {theme}: {k} is "
                               f"{(got[key].get(name) or {}).get(k)!r}, expected {v!r}")
    # And the export case again, for the one JS palette that has two themes.
    for k, v in JS_EXPECT["light"]["shot"].items():
        checked_js += 1
        if got["jsExportWhileDark"]["shot"].get(k) != v:
            bad.append(f"export case: shot {k} is "
                       f"{got['jsExportWhileDark']['shot'].get(k)!r}, expected {v!r}")

    n = sum(len(v) for v in EXPECT.values())
    print(f"{n * 2} palette values checked, {n} export values, "
          f"{n * 2} canvas acceptance checks, {checked_js} JavaScript palette values")
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
