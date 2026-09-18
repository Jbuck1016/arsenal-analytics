#!/usr/bin/env python3
"""Capture immutable pre-match 1X2 odds and persist de-vigged snapshots.

The collector is dry-run by default. It deliberately stores bookmaker prices
instead of only a consensus so overround, staleness, and bookmaker coverage
remain auditable. ``ODDS_API_KEY`` is read from the repository ``.env`` and is
never written to an artifact or log.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv

import sync_future_fixtures as fixtures
import train_match_baselines as baseline


ROOT = Path(__file__).resolve().parents[1]
SPORTS = {
    "ENG-Premier League": "soccer_epl",
    "ESP-La Liga": "soccer_spain_la_liga",
    "ITA-Serie A": "soccer_italy_serie_a",
    "GER-Bundesliga": "soccer_germany_bundesliga",
    "FRA-Ligue 1": "soccer_france_ligue_one",
}


def instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def canonical_matches(db, season: str, leagues: list[str]) -> list[dict[str, Any]]:
    return baseline.fetch_pages(
        db.table("matches")
        .select("game_id,season,league,date,kickoff_at,home_team,away_team,home_score,away_score")
        .eq("season", season)
        .in_("league", leagues)
        .order("date")
    )


def match_event(
    event: dict[str, Any], league: str, matches: list[dict[str, Any]], teams: set[str],
) -> tuple[dict[str, Any] | None, str | None]:
    try:
        home = fixtures.resolve_team(str(event["home_team"]), teams)
        away = fixtures.resolve_team(str(event["away_team"]), teams)
    except RuntimeError as exc:
        return None, str(exc).replace("football-data.org", "odds provider")
    commence = instant(event["commence_time"])
    candidates = []
    for row in matches:
        if row["league"] != league or row["home_team"] != home or row["away_team"] != away:
            continue
        kickoff = instant(row.get("kickoff_at") or f"{row['date']}T12:00:00+00:00")
        if abs((kickoff - commence).total_seconds()) <= 12 * 3600:
            candidates.append(row)
    if len(candidates) == 1:
        return candidates[0], None
    return None, (
        f"expected one canonical match for {league} {home} vs {away} near "
        f"{commence.isoformat()}, found {len(candidates)}"
    )


def fair_probabilities(home: float, draw: float, away: float) -> tuple[list[float], float]:
    if min(home, draw, away) <= 1:
        raise ValueError("decimal 1X2 odds must all exceed 1")
    raw = [1.0 / home, 1.0 / draw, 1.0 / away]
    total = sum(raw)
    return [value / total for value in raw], total - 1.0


def row_hash(row: dict[str, Any]) -> str:
    identity = {key: row[key] for key in (
        "game_id", "source", "source_event_id", "bookmaker_key", "market_key",
        "snapshot_kind", "source_updated_at", "home_odds", "draw_odds", "away_odds",
    )}
    return hashlib.sha256(
        json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def fetch_sport(
    sport: str, api_key: str, regions: str, start: datetime, end: datetime,
) -> tuple[list[dict[str, Any]], dict[str, str | None]]:
    provider_time = lambda value: value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    response = requests.get(
        f"https://api.the-odds-api.com/v4/sports/{sport}/odds",
        params={
            "apiKey": api_key,
            "regions": regions,
            "markets": "h2h",
            "oddsFormat": "decimal",
            "dateFormat": "iso",
            "commenceTimeFrom": provider_time(start),
            "commenceTimeTo": provider_time(end),
        },
        timeout=45,
    )
    if response.status_code != 200:
        try:
            detail = str(response.json().get("message") or response.json().get("error") or "")
        except ValueError:
            detail = response.text[:300]
        raise RuntimeError(f"odds provider returned HTTP {response.status_code}: {detail}")
    quota = {
        "requests_remaining": response.headers.get("x-requests-remaining"),
        "requests_used": response.headers.get("x-requests-used"),
        "requests_last": response.headers.get("x-requests-last"),
    }
    return list(response.json()), quota


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2627")
    parser.add_argument("--snapshot-kind", choices=("thursday", "pre_kickoff", "ad_hoc"), required=True)
    parser.add_argument("--league", action="append", choices=tuple(SPORTS))
    parser.add_argument("--regions", default="uk")
    parser.add_argument("--window-hours", type=float)
    parser.add_argument("--as-of", help="timezone-aware capture time; defaults to now")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()

    load_dotenv(ROOT / ".env")
    api_key = os.environ.get("ODDS_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("ODDS_API_KEY is missing from .env")
    captured_at = instant(args.as_of) if args.as_of else datetime.now(UTC)
    default_window = 168.0 if args.snapshot_kind == "thursday" else 8.0
    window_hours = args.window_hours if args.window_hours is not None else default_window
    if window_hours <= 0 or window_hours > 336:
        raise ValueError("--window-hours must be in (0, 336]")
    evaluation_end = captured_at + timedelta(hours=window_hours)
    leagues = args.league or list(SPORTS)
    output = args.output or ROOT / "artifacts" / "market_odds" / (
        f"{args.season}_{args.snapshot_kind}_{captured_at:%Y%m%dT%H%M%SZ}.json"
    )

    db = baseline.db_client()
    matches = canonical_matches(db, args.season, leagues)
    teams = {
        league: fixtures.canonical_teams(db, league, args.season)
        for league in leagues
    }
    rows: list[dict[str, Any]] = []
    unmatched: list[dict[str, str]] = []
    quotas: dict[str, dict[str, str | None]] = {}
    event_count = 0
    for league in leagues:
        events, quota = fetch_sport(
            SPORTS[league], api_key, args.regions, captured_at, evaluation_end,
        )
        quotas[league] = quota
        event_count += len(events)
        for event in events:
            canonical, error = match_event(event, league, matches, teams[league])
            if canonical is None:
                unmatched.append({
                    "league": league,
                    "source_event_id": str(event.get("id")),
                    "home_team": str(event.get("home_team")),
                    "away_team": str(event.get("away_team")),
                    "reason": str(error),
                })
                continue
            commence = instant(event["commence_time"])
            if not captured_at < commence:
                continue
            for bookmaker in event.get("bookmakers", []):
                for market in bookmaker.get("markets", []):
                    if market.get("key") != "h2h":
                        continue
                    prices = {str(outcome.get("name")): outcome.get("price") for outcome in market.get("outcomes", [])}
                    try:
                        home_odds = float(prices[str(event["home_team"])])
                        draw_odds = float(prices["Draw"])
                        away_odds = float(prices[str(event["away_team"])])
                        fair, overround = fair_probabilities(home_odds, draw_odds, away_odds)
                    except (KeyError, TypeError, ValueError):
                        continue
                    updated = market.get("last_update") or bookmaker.get("last_update")
                    row = {
                        "game_id": str(canonical["game_id"]),
                        "source": "the_odds_api",
                        "source_event_id": str(event["id"]),
                        "bookmaker_key": str(bookmaker["key"]),
                        "bookmaker_name": str(bookmaker.get("title") or bookmaker["key"]),
                        "market_key": "h2h",
                        "snapshot_kind": args.snapshot_kind,
                        "captured_at": captured_at.isoformat(),
                        "commence_time": commence.isoformat(),
                        "source_updated_at": instant(updated).isoformat() if updated else None,
                        "home_odds": home_odds,
                        "draw_odds": draw_odds,
                        "away_odds": away_odds,
                        "home_probability_fair": round(fair[0], 10),
                        "draw_probability_fair": round(fair[1], 10),
                        "away_probability_fair": round(fair[2], 10),
                        "overround": round(overround, 10),
                    }
                    row["payload_hash"] = row_hash(row)
                    rows.append(row)

    report = {
        "report_schema_version": 1,
        "season": args.season,
        "snapshot_kind": args.snapshot_kind,
        "captured_at": captured_at.isoformat(),
        "window_hours": window_hours,
        "regions": args.regions.split(","),
        "leagues": leagues,
        "provider_events": event_count,
        "bookmaker_rows": len(rows),
        "matched_games": len({row["game_id"] for row in rows}),
        "unmatched_events": unmatched,
        "quota": quotas,
        "rows": rows,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Market odds capture: events={event_count} matched_games={report['matched_games']} "
        f"bookmaker_rows={len(rows)} unmatched={len(unmatched)} execute={args.execute}"
    )
    print(f"Artifact: {output}")
    if args.execute:
        if not rows:
            raise RuntimeError("no matched bookmaker rows to persist")
        for offset in range(0, len(rows), 500):
            db.table("ml_market_odds_snapshots").upsert(
                rows[offset:offset + 500], on_conflict="payload_hash"
            ).execute()
        print(f"Persisted {len(rows)} idempotent bookmaker rows")
    else:
        print("Dry run only; no Supabase rows written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
