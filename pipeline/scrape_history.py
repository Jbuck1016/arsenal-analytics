"""Resumable historical ingestion for prediction-model training data.

Defaults to a read-only manifest for 2025/26. Add --execute to write raw
matches/events/lineups. Historical rows remain outside the live season views,
never trigger an analytics rebuild, and never overwrite a current player team.
"""
from __future__ import annotations

import argparse
import time
from types import SimpleNamespace

from scrape_and_load import get_supabase
from scrape_league import install_league_dict, scrape_one_league


TOP_FIVE = (
    "ENG-Premier League",
    "ESP-La Liga",
    "ITA-Serie A",
    "GER-Bundesliga",
    "FRA-Ligue 1",
)
TRAINING_SEASONS = ("2526", "2425", "2324")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Archive top-five European league events for model training."
    )
    parser.add_argument("--season", action="append", choices=TRAINING_SEASONS,
                        help="season code; repeatable (default: 2526 only)")
    parser.add_argument("--all-seasons", action="store_true",
                        help="run 2526, then 2425, then 2324")
    parser.add_argument("--league", action="append", choices=TOP_FIVE,
                        help="league id; repeatable (default: all five)")
    parser.add_argument("--execute", action="store_true",
                        help="write data; omission is a read-only schedule manifest")
    parser.add_argument("--verbose-plan", action="store_true",
                        help="print every missing fixture in read-only mode")
    parser.add_argument("--hours", type=float, default=8.0,
                        help="cleanly stop after this many hours (default: 8)")
    parser.add_argument("--max-matches", type=int, default=0,
                        help="overall write cap for a test run; 0 means no cap")
    parser.add_argument("--limit-per-league", type=int, default=0,
                        help="per-league fixture cap; 0 means all missing")
    parser.add_argument("--min-gap", type=float, default=60.0)
    parser.add_argument("--max-gap", type=float, default=120.0)
    parser.add_argument("--max-consecutive-failures", type=int, default=5)
    parser.add_argument("--headless", action="store_true")
    return parser


def selected_seasons(args: argparse.Namespace) -> tuple[str, ...]:
    if args.all_seasons:
        if args.season:
            raise SystemExit("use --season or --all-seasons, not both")
        return TRAINING_SEASONS
    return tuple(args.season or (TRAINING_SEASONS[0],))


def main() -> int:
    args = build_parser().parse_args()
    seasons = selected_seasons(args)
    leagues = tuple(args.league or TOP_FIVE)
    if args.hours <= 0:
        raise SystemExit("--hours must be greater than zero")
    if args.min_gap > args.max_gap:
        args.min_gap, args.max_gap = args.max_gap, args.min_gap

    install_league_dict()
    sb = get_supabase()
    stop_at = time.monotonic() + args.hours * 3600
    total_ok = total_failed = total_remaining = 0

    mode = "EXECUTE" if args.execute else "READ-ONLY MANIFEST"
    print(f"Historical training scrape · {mode}", flush=True)
    print(f"Seasons: {', '.join(seasons)}", flush=True)
    print(f"Leagues: {', '.join(leagues)}", flush=True)
    if not args.execute:
        print("No database rows will be written. Add --execute after reviewing this manifest.",
              flush=True)

    for season in seasons:
        for league in leagues:
            if args.execute and time.monotonic() >= stop_at:
                print("Nightly time budget reached before the next league.", flush=True)
                break
            remaining_cap = 0
            if args.max_matches:
                remaining_cap = args.max_matches - total_ok
                if remaining_cap <= 0:
                    print("Overall match cap reached.", flush=True)
                    break
            limit = args.limit_per_league
            if remaining_cap:
                limit = min(limit, remaining_cap) if limit else remaining_cap

            worker_args = SimpleNamespace(
                headless=args.headless,
                min_gap=args.min_gap,
                max_gap=args.max_gap,
                limit=limit,
                max_consecutive_failures=args.max_consecutive_failures,
                list=not args.execute,
                list_details=args.verbose_plan,
                historical=True,
                no_rebuild=True,
                stop_at_monotonic=stop_at if args.execute else None,
            )
            try:
                ok, failed, remaining = scrape_one_league(
                    sb, worker_args, league, season
                )
            except Exception as exc:  # noqa: BLE001 - continue to the next target
                print(f"  !! target failed: {league} {season}: {exc}", flush=True)
                total_failed += 1
                continue
            total_ok += ok
            total_failed += failed
            total_remaining += remaining
        else:
            continue
        break

    print("\n=== Historical scrape summary ===", flush=True)
    print(f"  ingested : {total_ok}", flush=True)
    print(f"  failed   : {total_failed}", flush=True)
    print(f"  remaining: {total_remaining}", flush=True)
    print("  live analytics rebuild: intentionally skipped", flush=True)
    return 1 if total_failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
