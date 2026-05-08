"""Find matches in Supabase that have zero events and scrape them.

Usage:
    python pipeline/scrape_new.py
"""
from __future__ import annotations

import pathlib
import shutil
import sys
import time
from collections import defaultdict

# Copy bundled league_dict.json to soccerdata config dir so custom leagues are recognised
_src = pathlib.Path(__file__).parent / "league_dict.json"
_dst = pathlib.Path.home() / "soccerdata" / "config" / "league_dict.json"
if _src.exists():
    _dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(_src, _dst)

import pandas as pd  # noqa: E402
from dotenv import load_dotenv  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

# Reuse helpers from the main pipeline script
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from scrape_and_load import (  # noqa: E402
    SLEEP_BETWEEN_MATCHES,
    get_scraper,
    get_supabase,
    process_match,
)


def fetch_played_matches(sb) -> list[dict]:
    """All matches that have been played (home_score not null) and dated before today."""
    today = pd.Timestamp.today().date().isoformat()
    all_rows: list[dict] = []
    page_size = 1000
    offset = 0
    while True:
        res = (
            sb.table("matches")
            .select(
                "game_id, season, competition, date, home_team, away_team, "
                "home_score, away_score, matchday, venue"
            )
            .not_.is_("home_score", "null")
            .lt("date", today)
            .order("date")
            .range(offset, offset + page_size - 1)
            .execute()
        )
        rows = res.data or []
        all_rows.extend(rows)
        if len(rows) < page_size:
            break
        offset += page_size
    return all_rows


def has_events(sb, game_id: str) -> bool:
    res = (
        sb.table("events")
        .select("id", count="exact", head=True)
        .eq("game_id", game_id)
        .execute()
    )
    return (res.count or 0) > 0


def make_sched_row(m: dict) -> pd.Series:
    """Build a pandas Series shaped like a soccerdata schedule row for process_match."""
    return pd.Series(
        {
            "game_id": m["game_id"],
            "date": m.get("date"),
            "home_team": m.get("home_team"),
            "away_team": m.get("away_team"),
            "home_score": m.get("home_score"),
            "away_score": m.get("away_score"),
            "week": m.get("matchday"),
            "venue": m.get("venue"),
        }
    )


def main() -> int:
    sb = get_supabase()

    print("Fetching played matches from Supabase...")
    matches = fetch_played_matches(sb)
    print(f"  total played matches in DB: {len(matches)}")

    print("Checking which matches have zero events...")
    missing: list[dict] = []
    for m in matches:
        if not has_events(sb, m["game_id"]):
            missing.append(m)

    if not missing:
        print("0 match(es) missing events. Nothing to do.")
        return 0

    print(f"\n{len(missing)} match(es) missing events:")
    for m in missing:
        print(
            f"  - {m['date']} [{m['competition']}] "
            f"{m['home_team']} {m['home_score']}-{m['away_score']} {m['away_team']} "
            f"(game_id={m['game_id']})"
        )

    # Group by (competition, season) so WhoScored is initialised once per group
    grouped: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for m in missing:
        grouped[(m["competition"], m["season"])].append(m)

    successes: list[str] = []
    failures: list[tuple[str, str]] = []

    for (league, season), group in grouped.items():
        print(
            f"\n=== {league} {season} ({len(group)} match(es)) ==="
        )
        ws = get_scraper(league, season)
        # Prime the scraper so its internal metadata cache is populated
        try:
            ws.read_schedule()
        except Exception as e:
            print(f"  read_schedule warning: {e}")

        for idx, m in enumerate(group):
            print(
                f"[{idx + 1}/{len(group)}] {m['date']} "
                f"{m['home_team']} vs {m['away_team']} (game_id={m['game_id']})"
            )
            try:
                process_match(sb, ws, make_sched_row(m), league, season)
                successes.append(m["game_id"])
                print("  -> success")
            except Exception as e:
                print(f"  -> FAILED: {e}", file=sys.stderr)
                failures.append((m["game_id"], str(e)))
            if idx < len(group) - 1:
                time.sleep(SLEEP_BETWEEN_MATCHES)

    print("\n=== Summary ===")
    print(f"  succeeded: {len(successes)}")
    print(f"  failed:    {len(failures)}")
    for gid, err in failures:
        print(f"    - {gid}: {err}")

    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
