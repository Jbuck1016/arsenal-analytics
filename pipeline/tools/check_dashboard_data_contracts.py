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

    if failures:
        print(f"\n{len(failures)} dashboard contract check(s) failed.")
        return 1
    print("\nAll dashboard data contracts passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
