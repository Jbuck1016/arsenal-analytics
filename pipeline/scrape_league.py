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


def fetch_leagues(sb) -> list[dict]:
    """Active leagues from the registry, so adding a league needs no code change."""
    try:
        res = (
            sb.table("leagues")
            .select("league, display_name, season, is_active")
            .eq("is_active", True)
            .execute()
        )
        rows = res.data or []
    except Exception as e:  # noqa: BLE001
        print(f"Could not read the leagues registry ({e}); falling back to {DEFAULT_LEAGUE}.",
              file=sys.stderr, flush=True)
        rows = []
    if not rows:
        rows = [{"league": DEFAULT_LEAGUE, "display_name": "Major League Soccer",
                 "season": DEFAULT_SEASON}]
    rows.sort(key=lambda r: r["league"])
    return rows


def choose_leagues(sb, args) -> list[tuple[str, str]]:
    """Resolve which leagues to scrape: flags first, then an interactive menu."""
    registry = fetch_leagues(sb)
    by_id = {r["league"]: r for r in registry}

    def with_season(lid: str) -> tuple[str, str]:
        reg = by_id.get(lid, {})
        return lid, (args.season or reg.get("season") or DEFAULT_SEASON)

    if args.all:
        return [with_season(r["league"]) for r in registry]

    if args.league:
        picked: list[str] = []
        for chunk in args.league:
            picked.extend([x.strip() for x in chunk.split(",") if x.strip()])
        unknown = [x for x in picked if x not in by_id]
        if unknown:
            print(f"Unknown league(s): {', '.join(unknown)}", file=sys.stderr, flush=True)
            print(f"Known: {', '.join(by_id)}", file=sys.stderr, flush=True)
            raise SystemExit(2)
        return [with_season(x) for x in picked]

    # non-interactive (Task Scheduler, cron): default rather than block on a prompt
    if not sys.stdin.isatty():
        return [with_season(DEFAULT_LEAGUE)]

    print("\nWhich league(s) do you want to scrape?\n", flush=True)
    for i, r in enumerate(registry, start=1):
        print(f"  {i}. {r['display_name']}  ({r['league']}, season {r.get('season') or DEFAULT_SEASON})",
              flush=True)
    print("  a. all of the above\n", flush=True)
    raw = input("Enter number(s), e.g. 1  or  1,3  or  a  [default 1]: ").strip().lower()

    if raw in ("a", "all"):
        return [with_season(r["league"]) for r in registry]
    if not raw:
        return [with_season(registry[0]["league"])]

    chosen: list[tuple[str, str]] = []
    for tok in raw.replace(" ", "").split(","):
        if not tok:
            continue
        if tok.isdigit() and 1 <= int(tok) <= len(registry):
            chosen.append(with_season(registry[int(tok) - 1]["league"]))
        elif tok in by_id:
            chosen.append(with_season(tok))
        else:
            print(f"Ignoring '{tok}' — not a listed option.", file=sys.stderr, flush=True)
    if not chosen:
        print("Nothing selected.", file=sys.stderr, flush=True)
        raise SystemExit(2)
    # de-duplicate, keep order
    seen, out = set(), []
    for c in chosen:
        if c[0] not in seen:
            out.append(c)
            seen.add(c[0])
    return out


def scrape_one_league(sb, args, league: str, season: str) -> tuple[int, int, int]:
    """Scrape every missing played match for one league. Returns (ok, failed, remaining)."""
    print(f"\n{'=' * 62}", flush=True)
    print(f"  {league}  season {season}", flush=True)
    print(f"{'=' * 62}", flush=True)

    ws = get_scraper(league, season, headless=args.headless)
    print(f"Reading full schedule for {league} {season}...", flush=True)
    try:
        sched = read_full_schedule(ws)
    except Exception as e:  # noqa: BLE001 - one bad league must not kill the rest
        print(f"  !! could not read schedule: {e}", file=sys.stderr, flush=True)
        return 0, 0, 0

    played = played_matches(sched)
    loaded = loaded_game_ids(sb)
    todo = played[~played["game_id"].astype(str).isin(loaded)].copy()
    if args.limit and args.limit > 0:
        todo = todo.head(args.limit)

    n = len(todo)
    avg_gap = (args.min_gap + args.max_gap) / 2
    print(f"  played in schedule : {len(played)}", flush=True)
    print(f"  already loaded     : {len(played) - n if not args.limit else 'n/a'}", flush=True)
    print(f"  to scrape          : {n}", flush=True)
    if n:
        print(f"  est. runtime       : ~{round((n * avg_gap) / 60)} min", flush=True)

    if args.list:
        if n:
            cols = [c for c in ("date", "home_team", "away_team", "home_score", "away_score", "game_id")
                    if c in todo.columns]
            print(todo[cols].to_string(index=False), flush=True)
        else:
            print("  nothing to do.", flush=True)
        return 0, 0, n
    if n == 0:
        print("  nothing to do — all played matches already loaded.", flush=True)
        return 0, 0, 0

    succeeded = failed = consecutive = 0
    for i, (_, row) in enumerate(todo.iterrows(), start=1):
        gid = str(row.get("game_id"))
        print(f"[{i}/{n}] {row.get('date')} {row.get('home_team')} vs {row.get('away_team')} "
              f"(game_id={gid})", flush=True)
        purge_null_cache(ws, gid, league, season)
        try:
            process_match(sb, ws, row, league, season)
            print("  -> success", flush=True)
            succeeded += 1
            consecutive = 0
        except Exception as e:  # noqa: BLE001
            print(f"  !! failed: {e}", file=sys.stderr, flush=True)
            failed += 1
            consecutive += 1
            if consecutive >= args.max_consecutive_failures:
                print(f"\n!! {consecutive} failures in a row for {league} — looks blocked. "
                      f"Moving on.", file=sys.stderr, flush=True)
                break
        if i < n:
            time.sleep(random.uniform(args.min_gap, args.max_gap))

    print(f"  {league}: {succeeded} loaded, {failed} failed, "
          f"{n - succeeded - failed} remaining", flush=True)
    return succeeded, failed, n - succeeded - failed


def main() -> int:
    install_league_dict()

    p = argparse.ArgumentParser(description="Multi-league WhoScored -> Supabase backfill.")
    p.add_argument("--league", action="append",
                   help="league id; repeatable or comma-separated. Omit to be asked.")
    p.add_argument("--all", action="store_true", help="scrape every active league")
    p.add_argument("--season", default=None,
                   help="override the season code (default: whatever the registry says)")
    p.add_argument("--headless", action="store_true",
                   help="run browser headless (default: headful, needed to get past the anti-bot)")
    p.add_argument("--min-gap", type=float, default=60.0, help="min seconds between matches")
    p.add_argument("--max-gap", type=float, default=120.0, help="max seconds between matches")
    p.add_argument("--limit", type=int, default=0, help="only scrape the next N per league (0 = all)")
    p.add_argument("--max-consecutive-failures", type=int, default=5,
                   help="give up on a league after this many failures in a row")
    p.add_argument("--list", action="store_true", help="print the plan and exit without scraping")
    p.add_argument("--no-rebuild", action="store_true", help="skip the analytics rebuild afterwards")
    args = p.parse_args()

    if args.min_gap > args.max_gap:
        args.min_gap, args.max_gap = args.max_gap, args.min_gap

    sb = get_supabase()
    targets = choose_leagues(sb, args)

    print(f"\nScraping {len(targets)} league(s): "
          f"{', '.join(l for l, _ in targets)}", flush=True)

    total_ok = total_failed = total_remaining = 0
    for league, season in targets:
        ok, failed, remaining = scrape_one_league(sb, args, league, season)
        total_ok += ok
        total_failed += failed
        total_remaining += remaining

    print("\n=== Summary ===", flush=True)
    print(f"  leagues:   {len(targets)}", flush=True)
    print(f"  succeeded: {total_ok}", flush=True)
    print(f"  failed:    {total_failed}", flush=True)
    print(f"  remaining: {total_remaining}", flush=True)
    if total_remaining > 0 and not args.list:
        print("  (re-run to resume — it only scrapes what's still missing)", flush=True)

    if args.list:
        return 0

    # One rebuild after ALL leagues, not per league: the analytics layers span leagues,
    # so rebuilding per league would repeat the same expensive work N times.
    if total_ok > 0 and not args.no_rebuild:
        print("\n=== Rebuild ===", flush=True)
        try:
            from backfill_bio import run_backfill
            b = run_backfill(sb, quiet=True)
            print(f"  bio        -> {b.get('written',0)} players "
                  f"(age {b.get('with_age',0)}, ht {b.get('with_height',0)})", flush=True)
        except Exception as e:  # noqa: BLE001 - bio is enrichment, never block the rebuild
            print(f"  bio        -> skipped ({e})", flush=True)
        steps = ["preflight", "metrics", "sequences", "players", "seqfz",
                 "lookups", "state", "chains", "traj", "profiles", "usage",
                 "teamstyle", "search", "percentiles", "insights", "verify"]
        try:
            for step in steps:
                resp = sb.rpc("rebuild_step", {"p_step": step}).execute()
                print(f"  {step:<11} -> {resp.data}", flush=True)
            print("  site is live with the new games.", flush=True)
        except Exception as e:  # noqa: BLE001
            print(f"\n  !! rebuild failed: {e}", file=sys.stderr, flush=True)
            print("  data loaded fine, but the analytics layers did NOT rebuild.",
                  file=sys.stderr, flush=True)
            return 1
    elif total_ok == 0:
        print("\n  no new games -- analytics already current, skipping rebuild.", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
