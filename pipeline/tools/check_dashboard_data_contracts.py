#!/usr/bin/env python3
"""Static regression checks for dashboard data-to-visual contracts."""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DASHBOARD = ROOT / "dashboard"
ACTIVE_PAGES = ["index.html", "insights.html", "match.html", "players.html", "teams.html"]


def main() -> int:
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        print(("PASS  " if condition else "FAIL  ") + message)
        if not condition:
            failures.append(message)

    pages = {name: (DASHBOARD / name).read_text(encoding="utf-8") for name in ACTIVE_PAGES}

    # Unknown league membership may remain visible in an unscoped list, but it
    # must never be silently filed into MLS or shown as a zero-match MLS state.
    silent_mls = re.compile(r"(?:\|\||\?\?)\s*['\"]USA-MLS['\"]")
    for name, source in pages.items():
        require(not silent_mls.search(source), f"{name}: no silent USA-MLS fallback")
    require("LEAGUES=[{v:'USA-MLS',l:'MLS',n:0}]" not in pages["match.html"],
            "match.html: no fabricated zero-match MLS league list")

    players = pages["players.html"]
    require("sbAll('mv_player_season',{select:'player_id,player_name,team,nineties,apps,starts,minutes'})" in players,
            "players.html: directory reads the complete appearance population")
    require("Object.assign({},s,rmap[s.player_id]||{})" in players,
            "players.html: role classification is optional for directory membership")
    require(".filter(function(p){return +(p.apps||0)>0||+(p.minutes||0)>0})" in players,
            "players.html: substitute appearances qualify for the directory")
    require(not re.search(r"\.filter\([^\n]{0,160}starts[^\n]{0,80}>\s*0", players),
            "players.html: directory is not filtered to starters")

    # WhoScored y=0 is the right touchline. SVG y grows downward, so this
    # transform puts right-sided actions at the bottom of the displayed pitch.
    require("function PY(y){return (100-y)*0.68}" in players,
            "players.html: WhoScored y-axis is inverted once at the renderer boundary")
    require(players.count("PY(") >= 9,
            "players.html: pass, shot, carry, receipt and zone primitives share PY()")
    require("Attack is always left-to-right." in players and "Attack is left to right." in players,
            "players.html: visual and accessible orientation labels agree")
    require("Orientation · attack left → right · team right = bottom edge" in players and
            "Orientation · attack left → right · team right = bottom edge" in pages["teams.html"] and
            "Orientation · attack bottom → top · team right = screen right" in pages["match.html"],
            "player, team and match pitches teach their page-specific orientation")
    require('data-chart-title="scatter"' in players and "raw per-90 values" in players,
            "players.html: scatter has a visible title and measurement context")
    require("x0>=0?Math.max(0,x0-padX)" in players and
            "y0>=0?Math.max(0,y0-padY)" in players,
            "players.html: scatter padding cannot invent negative values for nonnegative metrics")
    require("'</svg>'+legendHtml()" in players,
            "players.html: scatter explains its percentile colour scale")
    require("function shotSizeKey()" in players and
            "Example marker sizes: 0.05, 0.20 and 0.50 expected goals" in players and
            "cfg.sizeKey?shotSizeKey()" in players,
            "players.html: shot xG size encoding has a proportional symbol key")
    require("c.toDataURL('image/jpeg',0.9),'JPEG'" in players and
            "undefined,'FAST'" in players,
            "players.html: plot PDFs use a compressed opaque export image")
    require("@media(max-width:1180px){.split{grid-template-columns:1fr}.split-r{order:-1}}" in players,
            "players.html: pitch precedes the long metric table in single-column layouts")

    match = pages["match.html"]
    require("activeVizs:['progressive']" in match and
            '<div class="viz-btn on" data-viz="progressive">' in match,
            "match.html: first match view defaults to the lower-density progressive-pass map")
    require("if(!S.selPlayer&&evts.length>60)return renderProgressiveFlow" in match and
            "Progressive Pass Flow" in match and
            "select a player for event detail" in match,
            "match.html: dense progressive team views aggregate repeated routes")
    require("dense=!S.selPlayer&&evts.length>250" in match and
            "dense team view" in match,
            "match.html: dense all-pass maps fade context and explain how to refine it")
    require("var r=7;" in match and "uniform marker size" in match and
            "distance proxy (xG unavailable)" not in match,
            "match.html: shots do not encode distance as invented chance quality")
    require("const failed=color===PASS_FAIL" in match and "Incomplete (dashed)" in match and
            "Incomplete · dashed" in players,
            "player and match pass maps distinguish failure without colour alone")
    require("btn.setAttribute('role','button')" in match and
            "btn.setAttribute('aria-pressed'" in match and
            "e.key==='Enter'||e.key===' '" in match,
            "match.html: visualization selectors expose keyboard button semantics")

    teams = pages["teams.html"]
    require('<div class="viz-eyebrow">Relationship</div>' in teams and
            "eligible teams · raw values · dashed guides are displayed-sample medians" in teams,
            "teams.html: league scatter states the relationship and measurement context")
    require("const xmin=x0>=0?Math.max(0,x0-px):x0-px" in teams and
            "const ymin=y0>=0?Math.max(0,y0-py):y0-py" in teams,
            "teams.html: nonnegative scatter metrics cannot gain negative padding")
    require("const labelled={}" in teams and "if(labelled[p.team])" in teams and
            "hover any dot for exact values" in teams,
            "teams.html: league scatter labels only selection and structural extremes")
    require("function mapSample(items,limit)" in teams and
            "mapSample(ps,1200)" in teams and "mapSample(rows,1800)" in teams and
            "evenly sampled from the returned population" in teams,
            "teams.html: season event drill-downs cap SVG density and disclose sampling")
    require("clone=el.cloneNode(true)" in teams and "overflow:visible" in teams and
            "clone.querySelectorAll('.pitch-box')" in teams and
            "c.toDataURL('image/jpeg',0.9),'JPEG'" in teams,
            "teams.html: exports expand scrolling content and compress PDFs")

    if failures:
        print(f"\n{len(failures)} dashboard contract check(s) failed.")
        return 1
    print("\nAll dashboard data contracts passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
