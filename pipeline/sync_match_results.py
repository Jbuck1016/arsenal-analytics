#!/usr/bin/env python3
"""Update scores for known provider fixtures without touching event data.

Only existing ``fd-`` fixture rows with null scores can be updated. The command
never inserts a completed match, never overwrites a non-null result, and never
pretends that score availability means WhoScored event ingestion is complete.
"""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

import sync_future_fixtures as provider
import train_match_baselines as baseline


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2627")
    parser.add_argument("--league", action="append", choices=tuple(provider.COMPETITIONS))
    parser.add_argument(
        "--output", type=Path,
        default=Path("artifacts/model_reports/result_sync_2627.json"),
    )
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()

    load_dotenv(ROOT / ".env")
    import os

    token = os.environ.get("FOOTBALL_DATA_API_KEY", "").strip()
    if not token:
        raise RuntimeError("FOOTBALL_DATA_API_KEY is missing from .env")
    db = baseline.db_client()
    leagues = args.league or list(provider.COMPETITIONS)
    canonical = baseline.fetch_pages(
        db.table("matches")
        .select("game_id,season,league,home_team,away_team,home_score,away_score")
        .eq("season", args.season)
        .in_("league", leagues)
        .order("game_id")
    )
    tracked = {
        str(row["game_id"]): row for row in canonical
        if str(row["game_id"]).startswith("fd-")
    }
    updates: list[dict[str, Any]] = []
    unchanged = 0
    conflicts: list[dict[str, Any]] = []
    completed_seen = 0
    for league in leagues:
        teams = provider.canonical_teams(db, league, args.season)
        matches = provider.fetch_api_matches(
            token, provider.COMPETITIONS[league], provider.api_start_year(args.season),
        )
        for match in matches:
            if not provider.is_completed_fixture(match):
                continue
            completed_seen += 1
            row = provider.build_row(match, league, args.season, teams, include_score=True)
            game_id = str(row["game_id"])
            existing = tracked.get(game_id)
            if existing is None:
                continue
            current = (existing.get("home_score"), existing.get("away_score"))
            result = (row["home_score"], row["away_score"])
            if current == result:
                unchanged += 1
            elif current == (None, None):
                updates.append({
                    "game_id": game_id,
                    "league": league,
                    "home_team": existing["home_team"],
                    "away_team": existing["away_team"],
                    "home_score": result[0],
                    "away_score": result[1],
                })
            else:
                conflicts.append({
                    "game_id": game_id,
                    "database_score": list(current),
                    "provider_score": list(result),
                })

    report = {
        "report_schema_version": 1,
        "generated_at": datetime.now(UTC).isoformat(),
        "season": args.season,
        "leagues": leagues,
        "provider_completed_seen": completed_seen,
        "tracked_provider_fixtures": len(tracked),
        "updates": updates,
        "unchanged": unchanged,
        "conflicts": conflicts,
        "execute": args.execute,
        "scope_note": "score-only result sync; event ingestion and model features remain governed separately",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Result sync: completed_seen={completed_seen} tracked={len(tracked)} "
        f"updates={len(updates)} unchanged={unchanged} conflicts={len(conflicts)} "
        f"execute={args.execute}"
    )
    print(f"Report: {args.output}")
    if conflicts:
        raise RuntimeError("provider result conflicts with a non-null canonical score")
    if not args.execute:
        print("Dry run only; no Supabase rows written")
        return 0
    for row in updates:
        db.table("matches").update({
            "home_score": row["home_score"],
            "away_score": row["away_score"],
        }).eq("game_id", row["game_id"]).is_("home_score", "null").is_("away_score", "null").execute()
    if updates:
        ids = [row["game_id"] for row in updates]
        verified = baseline.fetch_pages(
            db.table("matches").select("game_id,home_score,away_score").in_("game_id", ids)
        )
        expected = {row["game_id"]: (row["home_score"], row["away_score"]) for row in updates}
        actual = {str(row["game_id"]): (row["home_score"], row["away_score"]) for row in verified}
        if actual != expected:
            raise RuntimeError(f"post-write score verification failed: expected={expected} actual={actual}")
    print(f"Persisted and verified {len(updates)} newly completed result(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
