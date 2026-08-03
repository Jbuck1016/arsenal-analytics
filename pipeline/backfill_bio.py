"""Backfill player_bio (age / height / weight) from cached WhoScored match JSON.

Reads the event JSONs already on disk from previous scrapes. Makes NO WhoScored
requests, so there is no rate limit or anti-bot risk. Safe to re-run.

Why age is handled the way it is:
  WhoScored gives `age` as a snapshot at match time, not a date of birth. The same
  player reads a year younger in March than in November if his birthday fell between.
  So we keep the HIGHEST age seen and record which match date it came from. That is
  honest and monotonic. If we later scrape profile pages for a real DOB, it replaces this.

Usage:
    python pipeline/backfill_bio.py            # backfill from all cached matches
    python pipeline/backfill_bio.py --dry-run  # report only, write nothing
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import pathlib
import sys

from dotenv import load_dotenv
from supabase import Client, create_client

ROOT = pathlib.Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")


def get_supabase() -> Client:
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])


def cache_roots() -> list[pathlib.Path]:
    """Candidate locations for the soccerdata JSON cache."""
    return [
        pathlib.Path.home() / "soccerdata",
        ROOT / "soccerdata",
        pathlib.Path(os.environ.get("SOCCERDATA_DIR", "")) if os.environ.get("SOCCERDATA_DIR") else None,
    ]


def find_event_files() -> list[str]:
    """All cached event JSONs, preferring paths that contain 'events'."""
    found: list[str] = []
    for root in cache_roots():
        if not root or not root.exists():
            continue
        found.extend(glob.glob(str(root / "**" / "*.json"), recursive=True))
    ev = [f for f in found if "events" in f.lower()]
    return sorted(set(ev or found))


def _int_or_none(v) -> int | None:
    try:
        if v is None:
            return None
        i = int(float(v))
        return i if i > 0 else None
    except (TypeError, ValueError):
        return None


def match_dates(sb: Client) -> dict[str, str]:
    """game_id -> date, so an age snapshot can be attributed to a match date."""
    out: dict[str, str] = {}
    page, off = 1000, 0
    while True:
        res = sb.table("matches").select("game_id, date").range(off, off + page - 1).execute()
        rows = res.data or []
        for r in rows:
            if r.get("date"):
                out[str(r["game_id"])] = r["date"]
        if len(rows) < page:
            break
        off += page
    return out


def run_backfill(sb, dry_run: bool = False, quiet: bool = False) -> dict:
    """Parse cached match JSON and upsert player bio. Returns a summary dict."""
    def say(msg):
        if not quiet:
            print(msg, flush=True)

    files = find_event_files()
    if not files:
        return {"ok": False, "reason": "no cached match json found", "players": 0}
    say(f"Found {len(files)} cached match file(s).")

    dates = match_dates(sb)
    say(f"Loaded {len(dates)} match dates from Supabase.")

    bio: dict[str, dict] = {}
    parsed = skipped = 0

    for path in files:
        gid = pathlib.Path(path).stem
        mdate = dates.get(gid)
        try:
            with open(path, encoding="utf-8") as fh:
                d = json.load(fh)
        except (OSError, json.JSONDecodeError):
            skipped += 1
            continue
        if not isinstance(d, dict):
            skipped += 1
            continue

        got_any = False
        for side in ("home", "away"):
            for pl in (d.get(side, {}) or {}).get("players", []) or []:
                pid = pl.get("playerId")
                if pid is None:
                    continue
                pid = str(int(pid))
                age = _int_or_none(pl.get("age"))
                hgt = _int_or_none(pl.get("height"))
                wgt = _int_or_none(pl.get("weight"))
                if age is None and hgt is None and wgt is None:
                    continue
                got_any = True

                cur = bio.setdefault(pid, {"player_id": pid})
                if age is not None and (cur.get("age_seen") is None or age > cur["age_seen"]):
                    cur["age_seen"] = age
                    cur["age_seen_date"] = mdate
                if hgt is not None and cur.get("height_cm") is None:
                    cur["height_cm"] = hgt
                if wgt is not None and cur.get("weight_kg") is None:
                    cur["weight_kg"] = wgt
        parsed += 1 if got_any else 0

    rows = list(bio.values())
    summary = {
        "ok": bool(rows),
        "files": len(files),
        "files_with_bio": parsed,
        "files_skipped": skipped,
        "players": len(rows),
        "with_age": sum(1 for r in rows if r.get("age_seen") is not None),
        "with_height": sum(1 for r in rows if r.get("height_cm") is not None),
        "with_weight": sum(1 for r in rows if r.get("weight_kg") is not None),
        "written": 0,
    }

    say("\n=== Parsed ===")
    say(f"  files with player bio : {summary['files_with_bio']}")
    say(f"  files skipped/bad     : {summary['files_skipped']}")
    say(f"  distinct players      : {summary['players']}")
    say(f"    with age            : {summary['with_age']}")
    say(f"    with height         : {summary['with_height']}")
    say(f"    with weight         : {summary['with_weight']}")

    if not rows or dry_run:
        if dry_run:
            say("\n--dry-run: nothing written.")
            for r in rows[:5]:
                say(f"  sample: {r}")
        return summary

    say("\nWriting to player_bio...")
    for i in range(0, len(rows), 500):
        sb.table("player_bio").upsert(rows[i : i + 500], on_conflict="player_id").execute()
    summary["written"] = len(rows)
    say(f"  upserted {len(rows)} rows.")
    return summary


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true", help="report only, write nothing")
    args = p.parse_args()

    sb = get_supabase()
    res = run_backfill(sb, dry_run=args.dry_run)
    if not res.get("ok"):
        print(f"\nNothing written: {res.get('reason','no rows parsed')}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
