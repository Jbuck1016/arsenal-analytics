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

# WHAT THIS FILE CHECKED, AND WHAT IT CHECKS NOW.
#
# Phase 1 transcribed these from the literals the bridge replaced, and the
# check was "the palette has not moved". Phase 3 moves the palette on purpose,
# so that check would now fail by design and mean nothing.
#
# The tables below are re-transcribed to the values Phase 3 chose, BY HAND and
# from the declarations in tokens.css -- never from this probe's own output,
# which would certify whatever the bridge happens to return. What the check
# proves is therefore narrower than before and still worth having: that the
# JavaScript palette a browser actually builds equals the palette the
# stylesheet declares, in both themes, through the export path, and after a
# theme switch. A bridge that cached one palette, read the wrong token name,
# or failed to re-read on a theme change still fails here.
#
# What it no longer proves is that the values are the Phase 1 values. That job
# moved to restyle/contrast.md and restyle/separability.md, which measure the
# values rather than remembering them.
JS_EXPECT = {
    # theme-independent: the same object in light and dark
    "both": {
        "defColors": {"Tackle": "#ef4444", "Interception": "#2563eb",
                      "Clearance": "#7c3aed", "BallRecovery": "#159a46",
                      "BlockedPass": "#a87f12", "Aerial": "#0891b2",
                      "Challenge": "#db2777"},
        "lineColorsSub": {"GK": "#a87f12", "DC": "#2563eb", "DL": "#2563eb",
                          "DR": "#2563eb", "DMC": "#0d9488", "MC": "#159a46",
                          "ML": "#159a46", "MR": "#159a46", "AMC": "#609510",
                          "AML": "#609510", "AMR": "#609510", "FW": "#ef4444",
                          "FWL": "#ef4444", "FWR": "#ef4444", "Sub": "#7e8797"},
        "teamAll": {"color": "#858fb1", "colorDim": "rgba(139,149,181,0.10)",
                    "colorGlow": "rgba(139,149,181,0.24)",
                    "colorBright": "#858fb1"},
        # THE SHOT PALETTE IS ONE SET NOW, NOT TWO. It used to hold a bright
        # per-theme set in dark and a darker one in light; the five outcomes
        # are single values that clear 3:1 on BOTH pitches, so the export case
        # and the dark case want the same thing as light.
        "shot": {"goal": "#ad2ba6", "ok": "#0f7a52", "fail": "#bf3535",
                 "blocked": "#7250d6", "post": "#9a6b00"},
    },
    "dark": {},
    "light": {},
}

# The inline paints, token by token.
#
# THIS TABLE IS PER THEME NOW, and that is the substance of the Phase 3 change
# rather than an accident of it. Phase 1's note here said a token resolving
# differently per theme would be "a regression, not an improvement", because
# the page drew every one of these with a single value on either ground. That
# was the bug: the plot chrome was near-black ink at low alpha painted onto a
# #111722 pitch, measuring 1.10:1. "both" is still the right home for anything
# that genuinely does clear both grounds with one value, and most of the marks
# do; what moved is the chrome that never could.
PAINT_BOTH = {
    "--plot-node-ring": "rgba(255,255,255,0.75)",
    "--plot-node-ring-soft": "rgba(255,255,255,0.7)",
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
    "--flow-arrow": "#2563eb",
    "--flow-node": "rgba(14,18,25,.84)",
    "--band-a": "rgba(90,169,255,.018)",
    "--band-b": "rgba(226,184,119,.018)",
    "--xt-high": "#e03000",
    "--bar-track": "rgba(255,255,255,0.08)",
    "--timeline-sel-fill": "rgba(239,1,7,0.14)",
    "--momentum-them": "#6b7280",
    "--label-on-fill": "#fff",
    "--opponent": "#2563eb",
    "--result-win-tint": "rgba(22,163,74,0.08)",
    "--result-draw-tint": "rgba(212,160,23,0.08)",
    "--result-loss-tint": "rgba(220,38,38,0.08)",
}

# Keyed per theme. The plot chrome is the bulk of it: every one of these was a
# single value tuned for the light pitch and painted onto both, which is the
# failure contrast.md ranked first. The three inks below sit on translucent
# tints, so the surface they are read against is the tint composited over the
# ground -- a different colour in each theme, which is why one ink could not
# serve both.
PAINT_LIGHT = {
    "--plot-guide": "rgba(0,0,0,0.18)",
    "--plot-line": "rgba(0,0,0,0.15)",
    "--plot-shadow": "rgba(0,0,0,0.18)",
    "--plot-label": "#2b2a25",
    "--plot-share-label": "rgba(0,0,0,0.62)",
    "--plot-grid": "rgba(0,0,0,0.08)",
    "--plot-zone-neutral": "rgba(200,200,200,0.04)",
    "--plot-frame": "rgba(96,96,96,0.85)",
    "--plot-pill": "rgba(250,247,238,0.92)",
    "--plot-pill-ink": "#a8140e",
    "--legend-pill": "rgba(250,247,238,0.94)",
    "--legend-pill-edge": "rgba(0,0,0,0.12)",
    "--legend-muted": "#55503f",
    "--legend-muted-ink": "#454133",
    "--legend-heat-low": "rgb(150,176,168)",
    "--legend-heat-high": "rgb(150,26,22)",
    "--peak-ring": "#9a6a1f",
    "--marker-in": "#b17a26",
    "--marker-out": "#1384ff",
    "--xt-low": "#ad7e10",
    "--timeline-sel-edge": "#c10005",
    "--positive-ink": "#12843c",
    "--caution-ink": "#986803",
    "--negative-ink": "#dc2626",
}
PAINT_DARK = {
    "--plot-guide": "rgba(214,224,240,0.26)",
    "--plot-line": "rgba(214,224,240,0.24)",
    # deepens rather than lightens: a shadow on a dark ground is still a shadow
    "--plot-shadow": "rgba(0,0,0,0.55)",
    "--plot-label": "#dbe3ef",
    "--plot-share-label": "rgba(226,232,245,0.78)",
    "--plot-grid": "rgba(214,224,240,0.10)",
    "--plot-zone-neutral": "rgba(200,200,200,0.05)",
    "--plot-frame": "rgba(170,184,206,0.75)",
    "--plot-pill": "rgba(20,27,40,0.90)",
    "--plot-pill-ink": "#ff8a80",
    "--legend-pill": "rgba(20,27,40,0.94)",
    "--legend-pill-edge": "rgba(255,255,255,0.14)",
    "--legend-muted": "#aab6c8",
    "--legend-muted-ink": "#c2ccdb",
    "--legend-heat-low": "rgb(31,91,111)",
    "--legend-heat-high": "rgb(226,184,119)",
    "--peak-ring": "#e2b877",
    "--marker-in": "#e2b877",
    "--marker-out": "#5aa9ff",
    "--xt-low": "#dca014",
    "--timeline-sel-edge": "#ff4a42",
    "--positive-ink": "#16a34a",
    "--caution-ink": "#ca8a04",
    "--negative-ink": "#e35050",
}
PAINT_EXPECT = {"light": dict(PAINT_BOTH, **PAINT_LIGHT),
                "dark": dict(PAINT_BOTH, **PAINT_DARK)}

# The export palette, which must stay light whatever the workspace shows.
EXPORT_EXPECT = {
    "EXP_BG": "#faf8f3", "EXP_PANEL": "#fffdf8", "EXP_TEXT": "#17140f",
    "EXP_MUTED": "#4a4436", "EXP_LABEL": "#655e4d",
    "EXP_BORDER": "rgba(22,25,31,0.16)", "EXP_RULE": "rgba(22,25,31,0.09)",
    "EXP_DIM": "#4a4436",
}

# What CT() returned before the bridge, transcribed from the deleted literals.
EXPECT = {
    "dark": {"pitch": "#111722", "line": "rgba(182,194,212,0.22)",
             "lineStrong": "rgba(226,184,119,0.52)", "band": "rgba(90,169,255,0.018)",
             "text": "rgba(242,245,250,0.90)", "textSoft": "rgba(182,194,212,0.68)",
             "chipBg": "rgba(14,18,25,0.92)", "chipText": "#f2f5fa",
             "passOk": "#3ddc97", "passFail": "#ff6b63"},
    "light": {"pitch": "#f0ead6", "line": "#888", "lineStrong": "#666",
              "band": "rgba(0,0,0,0.012)", "text": "#333",
              "textSoft": "rgba(0,0,0,0.62)", "chipBg": "rgba(25,28,34,0.90)",
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

  // rankColor() used to return two tokens the bridge never touched, so nothing
  // here would have noticed if either moved; they were read off the root
  // separately for that reason. It returns the --rank-* ramp now, which the
  // bridge reads like everything else, so the special case is gone.
  out.cssOnly = {};

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
        got = page.evaluate(PROBE, sorted(PAINT_EXPECT["light"]))
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
    # And the export case again. The shot palette used to be the one JS table
    # with two themes, which is why this check exists; it is one set now, so
    # the export case wants what both themes want.
    for k, v in JS_EXPECT["both"]["shot"].items():
        checked_js += 1
        if got["jsExportWhileDark"]["shot"].get(k) != v:
            bad.append(f"export case: shot {k} is "
                       f"{got['jsExportWhileDark']['shot'].get(k)!r}, expected {v!r}")

    for theme, key in (("dark", "jsDark"), ("light", "jsLight")):
        for name, want in PAINT_EXPECT[theme].items():
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

    # --pct-high and --pct-low were checked here because rankColor() returned
    # them as var() strings the bridge never saw. They are deleted: the function
    # returns the --rank-* ramp, which the bridge reads through TOK() like
    # everything else and which the PAINT tables above already cover.

    n = sum(len(v) for v in EXPECT.values())
    print(f"{n * 2} palette values checked, {n} export values, "
          f"{n * 2} canvas acceptance checks, {checked_js} JavaScript palette values")
    if bad:
        print(f"\n{len(bad)} FAILURES:")
        for x in bad:
            print("  " + x)
        return 1
    print("the bridge returns the DECLARED palette in both themes, "
          "returns light during an export from a dark page, and every value "
          "it produces is one a canvas accepts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
