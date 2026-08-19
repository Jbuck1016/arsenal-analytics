"""Find WhoScored's tournament names for leagues soccerdata does not map, and write them in.

The problem
-----------
soccerdata ships ESP-La Liga, GER-Bundesliga, ITA-Serie A and FRA-Ligue 1 with
"WhoScored": None. They are defined for other sources but not for WhoScored, so the
reader rejects them as invalid leagues. The fix is to supply WhoScored's own internal
tournament name, which this reads off the site rather than guessing.

Usage:
    python pipeline/find_league_names.py                 # discover and report only
    python pipeline/find_league_names.py --write         # discover, then write them in
    python pipeline/find_league_names.py --dump Spain    # list every tournament in a region
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import sys

from scrape_and_load import get_scraper

LOCAL = pathlib.Path(__file__).parent / "league_dict.json"
INSTALLED = pathlib.Path.home() / "soccerdata" / "config" / "league_dict.json"

# league id -> (WhoScored region, regex the tournament name must match)
TARGETS = {
    "ESP-La Liga":    ("Spain",   r"^la ?liga$|^laliga|primera divisi"),
    "GER-Bundesliga": ("Germany", r"^bundesliga$"),
    "ITA-Serie A":    ("Italy",   r"^serie a$"),
    "FRA-Ligue 1":    ("France",  r"^ligue 1$"),
}


def region_tree(ws) -> list[dict]:
    """WhoScored embeds its region/tournament list as a JS array on every page."""
    html = None
    for attr in ("_driver", "driver", "_browser", "browser"):
        drv = getattr(ws, attr, None)
        if drv is None:
            continue
        try:
            drv.get("https://www.whoscored.com/")
            html = drv.page_source
            break
        except Exception:  # noqa: BLE001
            continue
    if not html:
        raise RuntimeError("could not load the WhoScored homepage")

    for pat in (r"allRegions\s*=\s*(\[.*?\]);", r"var\s+allRegions\s*=\s*(\[.*?\]);"):
        m = re.search(pat, html, re.S)
        if not m:
            continue
        raw = m.group(1)
        fixed = re.sub(r"(\{|,)\s*([A-Za-z_][A-Za-z0-9_]*)\s*:", r'\1"\2":', raw).replace("'", '"')
        for cand in (raw, fixed):
            try:
                return json.loads(cand)
            except Exception:  # noqa: BLE001
                continue
    raise RuntimeError("could not parse WhoScored's region list")


def tournaments(regions: list[dict]) -> list[tuple[str, str]]:
    out = []
    for reg in regions:
        rname = reg.get("name") or reg.get("Name") or ""
        for t in (reg.get("tournaments") or reg.get("Tournaments") or []):
            tname = t.get("name") or t.get("Name") or ""
            if rname and tname:
                out.append((rname, tname))
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--write", action="store_true", help="write the discovered names into league_dict.json")
    p.add_argument("--dump", help="print every tournament in this region and exit")
    p.add_argument("--headless", action="store_true")
    args = p.parse_args()

    print("Opening WhoScored (a browser window will appear)...", flush=True)
    try:
        ws = get_scraper("USA-MLS", "2627", headless=args.headless)
        regions = region_tree(ws)
    except Exception as e:  # noqa: BLE001
        print(f"Failed: {e}", file=sys.stderr)
        return 1

    tours = tournaments(regions)
    print(f"  read {len(tours)} tournaments across {len(regions)} regions\n", flush=True)

    if args.dump:
        want = args.dump.strip().lower()
        hits = [(r, t) for r, t in tours if r.strip().lower() == want]
        if not hits:
            print(f"No region called '{args.dump}'. Regions available:", flush=True)
            print("  " + ", ".join(sorted({r for r, _ in tours})), flush=True)
            return 1
        print(f"Tournaments in {args.dump}:", flush=True)
        for r, t in hits:
            print(f'  "{r} - {t}"', flush=True)
        return 0

    found: dict[str, str] = {}
    for lid, (region, pattern) in TARGETS.items():
        rx = re.compile(pattern, re.I)
        matches = [(r, t) for r, t in tours
                   if r.strip().lower() == region.lower() and rx.search(t.strip())]
        if matches:
            r, t = matches[0]
            found[lid] = f"{r} - {t}"
            print(f"  {lid:<18} -> \"{r} - {t}\"", flush=True)
        else:
            print(f"  {lid:<18} -> NOT FOUND in region {region}", flush=True)
            near = [t for r, t in tours if r.strip().lower() == region.lower()]
            if near:
                print(f"       tournaments in {region}: {', '.join(near[:12])}", flush=True)

    if not args.write:
        print("\nReport only. Re-run with --write to save these into league_dict.json.", flush=True)
        return 0 if len(found) == len(TARGETS) else 1

    if not LOCAL.is_file():
        print(f"No league_dict at {LOCAL}", file=sys.stderr)
        return 1
    with LOCAL.open(encoding="utf-8") as fh:
        local = json.load(fh)

    for lid, wsname in found.items():
        entry = dict(local.get(lid) or {})
        entry["WhoScored"] = wsname
        entry.setdefault("season_start", "Aug")
        entry.setdefault("season_end", "May")
        local[lid] = entry

    with LOCAL.open("w", encoding="utf-8") as fh:
        json.dump(local, fh, indent=1, ensure_ascii=False)
    INSTALLED.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(LOCAL, INSTALLED)

    print(f"\nWrote {len(found)} league(s) to {LOCAL}", flush=True)
    print(f"Installed to {INSTALLED}", flush=True)
    print("\nNext: python pipeline\\scrape_league.py --list", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
