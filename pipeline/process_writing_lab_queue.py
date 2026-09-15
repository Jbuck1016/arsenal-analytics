"""Process Writing Lab match requests without exposing database credentials.

The browser may enqueue a WhoScored match URL, but it cannot run Selenium or
hold a service-role key.  This worker claims those rows, downloads the match
centre payload with the existing scraper, and writes cup data only to the
isolated ``*_cup`` tables.  League-only analytics and model features therefore
remain untouched.

Run once::

    python pipeline/process_writing_lab_queue.py

Keep a local worker available while writing::

    python pipeline/process_writing_lab_queue.py --watch
"""
from __future__ import annotations

import argparse
import json
import re
import time
from datetime import datetime, timezone

import pandas as pd

from scrape_and_load import cached_event_json_path, get_scraper, get_supabase
from scrape_cup import (
    install_league_dict,
    purge_null_cache,
    record_cup_clubs,
    upsert_cup_events,
    upsert_cup_players_and_lineups,
)

MATCH_RE = re.compile(r"/matches/(\d+)", re.I)


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def score(side: dict) -> int | None:
    scores = (side or {}).get("scores") or {}
    value = scores.get("fulltime", scores.get("running"))
    try:
        return int(value) if value is not None else None
    except (TypeError, ValueError):
        return None


def claim_next(sb) -> dict | None:
    rows = (
        sb.table("writing_lab_projects")
        .select("*")
        .eq("scrape_status", "queued")
        .order("created_at")
        .limit(1)
        .execute()
        .data
        or []
    )
    if not rows:
        return None
    row = rows[0]
    claimed = (
        sb.table("writing_lab_projects")
        .update({"scrape_status": "scraping", "scrape_error": None, "updated_at": iso_now()})
        .eq("id", row["id"])
        .eq("scrape_status", "queued")
        .execute()
        .data
        or []
    )
    return claimed[0] if claimed else None


def upsert_match(sb, game_data: dict, game_id: str, competition: str, season: str) -> dict:
    home = game_data.get("home") or {}
    away = game_data.get("away") or {}
    started = game_data.get("startDate") or game_data.get("startTime")
    payload = {
        "game_id": game_id,
        "season": season,
        "competition": competition,
        "date": str(started)[:10] if started else None,
        "home_team": home.get("name"),
        "away_team": away.get("name"),
        "home_score": score(home),
        "away_score": score(away),
        "venue": game_data.get("venueName"),
        "stage": game_data.get("stage"),
    }
    sb.table("matches_cup").upsert(payload, on_conflict="game_id").execute()
    return payload


def process(sb, project: dict, *, headless: bool) -> None:
    url = project.get("whoscored_url") or ""
    found = MATCH_RE.search(url)
    if not found:
        raise ValueError("The URL does not contain a WhoScored match id")
    game_id = found.group(1)
    competition = project.get("competition") or "ENG-League Cup"
    season = project.get("season") or "2627"

    # A match centre can go live before soccerdata has indexed that new season.
    # Direct match-id downloads do not depend on the schedule, so a known valid
    # competition/season may safely carry the browser and cache context.
    candidates = [(competition, season)]
    if season != "2526":
        candidates.append((competition, "2526"))
    candidates.append(("ENG-Premier League", "2526"))
    ws = None
    cache_league = cache_season = None
    errors: list[str] = []
    for candidate_league, candidate_season in candidates:
        try:
            ws = get_scraper(candidate_league, candidate_season, headless=headless)
            cache_league, cache_season = candidate_league, candidate_season
            break
        except Exception as exc:  # noqa: BLE001 - try the direct-match carrier
            errors.append(str(exc))
    if ws is None or cache_league is None or cache_season is None:
        raise RuntimeError("Could not initialise a WhoScored match browser: " + errors[-1])

    purge_null_cache(ws, game_id, cache_league, cache_season)
    path = cached_event_json_path(ws, game_id, cache_league, cache_season)
    if not path.is_file():
        ws.read_events(match_id=int(game_id), output_fmt="raw")
    if not path.is_file() or path.stat().st_size <= 50:
        raise RuntimeError("WhoScored did not publish a usable event payload for this match")
    with path.open(encoding="utf-8") as handle:
        game_data = json.load(handle)
    if not isinstance(game_data, dict) or not game_data.get("events"):
        raise RuntimeError("The downloaded match payload contains no events")

    match = upsert_match(sb, game_data, game_id, competition, season)
    upsert_cup_players_and_lineups(sb, game_data, game_id)
    event_count = upsert_cup_events(sb, game_data, game_id)
    record_cup_clubs(
        sb,
        game_data,
        pd.Series({"home_team": match["home_team"], "away_team": match["away_team"]}),
    )
    if not event_count:
        raise RuntimeError("The event payload produced zero canonical events")

    sb.table("writing_lab_projects").update(
        {
            "game_id": game_id,
            "home_team": match["home_team"],
            "away_team": match["away_team"],
            "home_score": match["home_score"],
            "away_score": match["away_score"],
            "match_date": match["date"],
            "scrape_status": "ready",
            "scrape_error": None,
            "ingested_at": iso_now(),
            "updated_at": iso_now(),
        }
    ).eq("id", project["id"]).execute()
    print(
        f"READY {match['home_team']} {match['home_score']}-{match['away_score']} "
        f"{match['away_team']} · {event_count} events",
        flush=True,
    )


def fail(sb, project: dict, error: Exception) -> None:
    message = str(error)[:1000]
    sb.table("writing_lab_projects").update(
        {"scrape_status": "error", "scrape_error": message, "updated_at": iso_now()}
    ).eq("id", project["id"]).execute()
    print(f"ERROR {project.get('whoscored_url')}: {message}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--watch", action="store_true", help="poll continuously for queued work")
    parser.add_argument("--poll-seconds", type=int, default=15)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    install_league_dict()
    sb = get_supabase()

    handled = 0
    while True:
        project = claim_next(sb)
        if project:
            try:
                process(sb, project, headless=args.headless)
            except Exception as exc:  # noqa: BLE001 - persist a useful queue error
                fail(sb, project, exc)
            handled += 1
            continue
        if not args.watch:
            print(f"Writing Lab queue empty · processed {handled}", flush=True)
            return 0
        time.sleep(max(5, args.poll_seconds))


if __name__ == "__main__":
    raise SystemExit(main())
