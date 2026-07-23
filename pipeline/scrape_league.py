"""League-wide backfill: WhoScored -> Supabase.

Reads the league schedule ONCE, then scrapes every PLAYED match that is not
already loaded, one at a time, with a jittered pause between event reads to
stay under WhoScored's anti-bot rate limit.

Design notes (why it's built this way):
  * The block is rate-based, not volume-based. One schedule read up front, then
    a randomised 60-120s gap between per-match event reads, keeps us under it.
  * Idempotent + resumable. "Done" is defined by rows existing in the events
    table (via the v_loaded_games view), NOT by the local JSON cache. Re-running
    only scrapes what's still missing, so an interrupted run just resumes.
  * Null cache files (written when a read is blocked) are purged before each
    match so a prior failure re-fetches instead of re-reading an empty file.
  * A consecutive-failure circuit breaker stops the run if we look blocked,
    rather than failing every remaining match for hours. Resume later.

Usage:
  python pipeline/scrape_league.py --list                 # show the plan, scrape nothing
  python pipeline/scrape_league.py                        # backfill all missing played matches
  python pipeline/scrape_league.py --limit 5             # do only the next 5 (good first test)
  python pipeline/scrape_league.py --min-gap 45 --max-gap 90
"""
from __future__ import annotations

import argparse
import pathlib
import random
import shutil
import sys
import time

import pandas as pd

# Reuse the battle-tested single-match machinery. Importing is safe: that module
# is guarded by `if __name__ == "__main__"`, so nothing runs on import.
from scrape_and_load import (
    cached_event_json_path,
    get_scraper,
    get_supabase,
    process_match,
)

DEFAULT_LEAGUE = "USA-MLS"
DEFAULT_SEASON = "2627"
NULL_CACHE_MAX_BYTES = 50  # a real event json is >100KB; anything tiny is a null/blocked write


def install_league_dict() -> None:
    """Copy the bundled custom league_dict.json into soccerdata's config dir."""
    src = pathlib.Path(__file__).parent / "league_dict.json"
    dst = pathlib.Path.home() / "soccerdata" / "config" / "league_dict.json"
    if src.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, dst)


def read_full_schedule(ws) -> pd.DataFrame:
    """Whole-league schedule as a flat DataFrame (one row per fixture)."""
    sched = ws.read_schedule()
    if sched.index.names and any(n for n in sched.index.names):
        sched = sched.reset_index()
    return sched


def played_matches(sched: pd.DataFrame) -> pd.DataFrame:
    """Fixtures that have actually been played (a real home_score)."""
    df = sched[sched["home_score"].notna()].copy()
    if "date" in df.columns:
        df = df.sort_values("date")
    return df


def loaded_game_ids(sb) -> set[str]:
    """game_ids that already have events in Supabase (the resume set)."""
    resp = sb.table("v_loaded_games").select("game_id").execute()
    return {str(r["game_id"]) for r in (resp.data or [])}


def purge_null_cache(ws, game_id: str, league: str, season: str) -> None:
    """Remove a null/blocked cache file so the match re-fetches from source."""
    path = cached_event_json_path(ws, game_id, league, season)
    try:
        if path.is_file() and path.stat().st_size < NULL_CACHE_MAX_BYTES:
            path.unlink()
    except OSError:
        pass


def main() -> int:
    install_league_dict()

    p = argparse.ArgumentParser(description="League-wide WhoScored -> Supabase backfill.")
    p.add_argument("--league", default=DEFAULT_LEAGUE, help="league id (default: USA-MLS)")
    p.add_argument("--season", default=DEFAULT_SEASON, help="season code (default: 2627)")
    p.add_argument("--headless", action="store_true",
                   help="run browser headless (default: headful, needed to get past the anti-bot)")
    p.add_argument("--min-gap", type=float, default=60.0, help="min seconds between matches (default: 60)")
    p.add_argument("--max-gap", type=float, default=120.0, help="max seconds between matches (default: 120)")
    p.add_argument("--limit", type=int, default=0, help="only scrape the next N missing matches (0 = all)")
    p.add_argument("--max-consecutive-failures", type=int, default=5,
                   help="abort if this many matches fail in a row (likely blocked)")
    p.add_argument("--list", action="store_true", help="print the plan and exit without scraping")
    args = p.parse_args()

    if args.min_gap > args.max_gap:
        args.min_gap, args.max_gap = args.max_gap, args.min_gap

    league, season = args.league, args.season
    sb = get_supabase()
    ws = get_scraper(league, season, headless=args.headless)

    print(f"Reading full schedule for {league} {season} (one time)...", flush=True)
    sched = read_full_schedule(ws)
    played = played_matches(sched)
    loaded = loaded_game_ids(sb)

    todo = played[~played["game_id"].astype(str).isin(loaded)].copy()
    if args.limit and args.limit > 0:
        todo = todo.head(args.limit)

    total_played = len(played)
    already = total_played - len(played[~played["game_id"].astype(str).isin(loaded)])
    n = len(todo)
    avg_gap = (args.min_gap + args.max_gap) / 2
    est_min = round((n * avg_gap) / 60) if n else 0

    print("=== Plan ===", flush=True)
    print(f"  played matches in schedule : {total_played}", flush=True)
    print(f"  already loaded (has events): {already}", flush=True)
    print(f"  to scrape this run         : {n}", flush=True)
    print(f"  est. runtime               : ~{est_min} min "
          f"(gap {args.min_gap:.0f}-{args.max_gap:.0f}s/match)", flush=True)

    if args.list or n == 0:
        if n:
            cols = [c for c in ("date", "home_team", "away_team", "home_score", "away_score", "game_id")
                    if c in todo.columns]
            print(todo[cols].to_string(index=False), flush=True)
        else:
            print("  nothing to do — all played matches already loaded.", flush=True)
        return 0

    succeeded = failed = 0
    consecutive_failures = 0

    for i, (_, row) in enumerate(todo.iterrows(), start=1):
        gid = str(row.get("game_id"))
        print(f"[{i}/{n}] {row.get('date')} {row.get('home_team')} vs {row.get('away_team')} "
              f"(game_id={gid})", flush=True)

        purge_null_cache(ws, gid, league, season)
        try:
            process_match(sb, ws, row, league, season)
            print("  -> success", flush=True)
            succeeded += 1
            consecutive_failures = 0
        except Exception as e:  # noqa: BLE001 - one bad match must not kill the run
            print(f"  !! failed: {e}", file=sys.stderr, flush=True)
            failed += 1
            consecutive_failures += 1
            if consecutive_failures >= args.max_consecutive_failures:
                print(f"\n!! {consecutive_failures} failures in a row — looks blocked. "
                      f"Stopping. Re-run later to resume from where this left off.",
                      file=sys.stderr, flush=True)
                break

        if i < n:
            time.sleep(random.uniform(args.min_gap, args.max_gap))

    print("\n=== Summary ===", flush=True)
    print(f"  succeeded: {succeeded}", flush=True)
    print(f"  failed:    {failed}", flush=True)
    print(f"  remaining: {n - succeeded - failed}", flush=True)
    if n - succeeded - failed > 0:
        print("  (re-run the same command to resume — it only scrapes what's still missing)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
