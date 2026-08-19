"""Add leagues to the local league_dict.json using soccerdata's own definitions.

Why this exists
---------------
A custom pipeline/league_dict.json REPLACES soccerdata's built-in list rather than
extending it, so the big European leagues disappeared from the valid set once a custom
file was installed. Rather than retyping WhoScored's internal tournament names and
risking a typo, this reads them straight out of the installed soccerdata package and
merges the ones we want back in.

Usage:
    python pipeline/add_leagues.py                 # add the default set below
    python pipeline/add_leagues.py --list          # show what soccerdata knows about
    python pipeline/add_leagues.py --league "NED-Eredivisie"
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import sys

WANT = [
    "ESP-La Liga",
    "GER-Bundesliga",
    "ITA-Serie A",
    "FRA-Ligue 1",
]

LOCAL = pathlib.Path(__file__).parent / "league_dict.json"
INSTALLED = pathlib.Path.home() / "soccerdata" / "config" / "league_dict.json"


def builtin_dict() -> dict:
    """soccerdata's own league_dict.json, wherever the package is installed."""
    import soccerdata

    base = pathlib.Path(soccerdata.__file__).parent
    for candidate in (
        base / "config" / "league_dict.json",
        base / "league_dict.json",
        base / "datasets" / "league_dict.json",
    ):
        if candidate.is_file():
            with candidate.open(encoding="utf-8") as fh:
                return json.load(fh)
    # newer versions expose it as a module constant
    for attr in ("LEAGUE_DICT", "_LEAGUE_DICT"):
        d = getattr(soccerdata._config, attr, None) if hasattr(soccerdata, "_config") else None
        if isinstance(d, dict):
            return d
    raise FileNotFoundError(
        f"Could not find soccerdata's bundled league_dict.json under {base}"
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--league", action="append",
                   help="league id to add; repeatable. Defaults to the big four.")
    p.add_argument("--list", action="store_true",
                   help="print every league soccerdata ships with, then exit")
    args = p.parse_args()

    try:
        builtin = builtin_dict()
    except Exception as e:  # noqa: BLE001
        print(f"Could not read soccerdata's built-in leagues: {e}", file=sys.stderr)
        return 1

    if args.list:
        print(f"soccerdata ships {len(builtin)} league(s):\n")
        for k in sorted(builtin):
            ws = (builtin[k] or {}).get("WhoScored")
            print(f"  {k:<28} WhoScored: {ws}")
        return 0

    want = args.league or WANT

    if not LOCAL.is_file():
        print(f"No local league_dict at {LOCAL}", file=sys.stderr)
        return 1
    with LOCAL.open(encoding="utf-8") as fh:
        local = json.load(fh)

    added, skipped, missing = [], [], []
    for lg in want:
        if lg in local:
            skipped.append(lg)
            continue
        if lg not in builtin:
            missing.append(lg)
            continue
        entry = dict(builtin[lg])
        if not entry.get("WhoScored"):
            missing.append(f"{lg} (no WhoScored name in soccerdata)")
            continue
        local[lg] = entry
        added.append(f"{lg} -> {entry['WhoScored']}")

    if added:
        with LOCAL.open("w", encoding="utf-8") as fh:
            json.dump(local, fh, indent=1, ensure_ascii=False)
        INSTALLED.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(LOCAL, INSTALLED)

    print("=== league_dict update ===")
    for a in added:
        print(f"  added   {a}")
    for s in skipped:
        print(f"  already {s}")
    for m in missing:
        print(f"  MISSING {m}")
    print(f"\nlocal dict now has {len(local)} league(s):")
    print("  " + ", ".join(sorted(local)))
    if added:
        print(f"\nWritten to {LOCAL}")
        print(f"Installed to {INSTALLED}")
    print("\nNext: python pipeline\\scrape_league.py --list")
    return 0 if not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
