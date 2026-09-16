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

# The inline paints, token by token, transcribed from the literals each one
# replaced. Same theme in both directions: the page drew every one of these
# with a single value on either ground, so a token that resolved differently
# per theme would be a regression, not an improvement.
PAINT_EXPECT = {
    "--plot-guide": "rgba(0,0,0,0.18)",
    "--plot-line": "rgba(0,0,0,0.15)",
    "--plot-shadow": "rgba(0,0,0,0.18)",
    "--plot-node-ring": "rgba(255,255,255,0.75)",
    "--plot-node-ring-soft": "rgba(255,255,255,0.7)",
    "--plot-label": "#333",
    "--plot-share-label": "rgba(0,0,0,0.55)",
    "--plot-grid": "rgba(0,0,0,0.08)",
    "--plot-zone-neutral": "rgba(200,200,200,0.04)",
    "--plot-frame": "rgba(136,136,136,0.8)",
    "--plot-pill": "rgba(240,234,214,0.88)",
    "--plot-pill-ink": "#c00",
    "--legend-pill": "rgba(240,234,214,0.92)",
    "--legend-pill-edge": "rgba(0,0,0,0.08)",
    "--legend-muted": "#555",
    "--legend-muted-ink": "#444",
    "--legend-heat-low": "#1f5b6f",
    "--legend-heat-high": "#e2b877",
    "--peak-ring": "#e2b877",
    "--zone-fill": "rgba(26,122,58,0.06)",
    "--zone-edge": "rgba(26,122,58,0.25)",
    "--shape-node": "rgba(37,99,235,0.7)",
    "--shape-node-ring": "rgba(37,99,235,0.9)",
    "--shape-node-label": "rgba(37,99,235,0.5)",
    "--shape-out-fill": "rgba(90,169,255,.055)",
    "--shape-out-edge": "rgba(90,169,255,.38)",
    "--shape-in-fill": "rgba(226,184,119,.055)",
    "--shape-in-edge": "rgba(226,184,119,.40)",
    "--shape-shift-line": "rgba(182,194,212,.27)",
    "--shape-shift-head": "rgba(226,184,119,.62)",
    "--marker-in": "#e2b877",
    "--marker-out": "#5aa9ff",
    "--flow-arrow": "#2563eb",
    "--flow-node": "rgba(14,18,25,.84)",
    "--band-a": "rgba(90,169,255,.018)",
    "--band-b": "rgba(226,184,119,.018)",
    "--xt-low": "#dca014",
    "--xt-high": "#e03000",
    "--bar-track": "rgba(255,255,255,0.08)",
    "--timeline-sel-fill": "rgba(239,1,7,0.14)",
    "--timeline-sel-edge": "rgba(239,1,7,0.5)",
    "--momentum-them": "#6b7280",
    "--label-on-fill": "#fff",
    "--opponent": "#2563eb",
    "--positive-ink": "#16a34a",
    "--caution-ink": "#ca8a04",
    "--negative-ink": "#dc2626",
    "--result-win-tint": "rgba(22,163,74,0.08)",
    "--result-draw-tint": "rgba(212,160,23,0.08)",
    "--result-loss-tint": "rgba(220,38,38,0.08)",
}

# The export palette, which must stay light whatever the workspace shows.
EXPORT_EXPECT = {
    "EXP_BG": "#faf8f3", "EXP_PANEL": "#f4f1e9", "EXP_TEXT": "#16191f",
    "EXP_MUTED": "#4a5262", "EXP_LABEL": "#6b7280",
    "EXP_BORDER": "rgba(22,25,31,0.16)", "EXP_RULE": "rgba(22,25,31,0.09)",
    "EXP_DIM": "#4a5262",
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

PROBE = """(PAINT_NAMES) => {
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
    paints: (() => { const o = {};
      for (const n of PAINT_NAMES) o[n] = TOK(n);
      return o; })(),
  });

  root.classList.add('dark');    EXP_LIGHT = false; out.dark  = snap(); out.jsDark  = js();
  root.classList.remove('dark'); EXP_LIGHT = false; out.light = snap(); out.jsLight = js();
  // The export case: document dark, palette light.
  root.classList.add('dark');    EXP_LIGHT = true;  out.exportWhileDark = snap();
  out.jsExportWhileDark = js();
  EXP_LIGHT = false;
  if (!was) root.classList.remove('dark');

  out.exports = {EXP_BG, EXP_PANEL, EXP_TEXT, EXP_MUTED, EXP_LABEL,
                 EXP_BORDER, EXP_RULE, EXP_DIM};

  // Tokens this page reaches for as a var() string rather than through the
  // bridge: pctColor() returns CSS, so nothing above would notice if one of
  // these moved. Read them off the root in both themes.
  out.cssOnly = {};
  for (const theme of ['dark', 'light']) {
    theme === 'dark' ? root.classList.add('dark') : root.classList.remove('dark');
    const cs = getComputedStyle(root);
    out.cssOnly[theme] = {};
    for (const n of ['--pct-high', '--pct-low'])
      out.cssOnly[theme][n] = cs.getPropertyValue(n).trim();
  }
  if (was) root.classList.add('dark'); else root.classList.remove('dark');

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
  out.paintCanvas = {};
  for (const n in out.jsDark.paints) {
    ctx.fillStyle = '#010203';
    ctx.fillStyle = out.jsDark.paints[n];
    out.paintCanvas[n] = ctx.fillStyle;
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
        got = page.evaluate(PROBE, list(PAINT_EXPECT))
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

    for theme, key in (("dark", "jsDark"), ("light", "jsLight")):
        for name, want in PAINT_EXPECT.items():
            checked_js += 1
            if got[key]["paints"].get(name) != want:
                bad.append(f"TOK({name}) in {theme} is "
                           f"{got[key]['paints'].get(name)!r}, expected {want!r}")
    for name, want in EXPORT_EXPECT.items():
        checked_js += 1
        if got["exports"].get(name) != want:
            bad.append(f"{name} is {got['exports'].get(name)!r}, expected {want!r}")

    # Canvas acceptance for the painted tokens too: these are the values that
    # actually reach ctx.fillStyle, and a rejected one paints the last colour.
    for name, v in got["jsDark"]["paints"].items():
        checked_js += 1
        if got["paintCanvas"].get(name) == "#010203":
            bad.append(f"canvas DISCARDED {name} = {v!r}")

    for theme in ("dark", "light"):
        for name, want in {"--pct-high": "#4ade80", "--pct-low": "#f97316"}.items():
            checked_js += 1
            if got["cssOnly"][theme].get(name) != want:
                bad.append(f"{name} in {theme} resolves "
                           f"{got['cssOnly'][theme].get(name)!r}, expected {want!r}")

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
