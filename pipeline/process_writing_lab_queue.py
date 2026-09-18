"""Process browser-submitted WhoScored matches without exposing credentials.

The browser may enqueue a WhoScored match URL, but it cannot run Selenium or
hold a service-role key.  This worker claims those rows, downloads the match
centre payload with the existing scraper. Modeled domestic leagues are written
to the canonical ``matches``/``events`` path and enqueue the normal governed
analytics rebuild. Cups, Europe and other competitions remain isolated in the
``*_cup`` tables so they cannot contaminate league features.

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

from scrape_and_load import (
    cached_event_json_path,
    get_scraper,
    get_supabase,
    league_club_count,
    league_expected_clubs,
    league_whitelist,
    upsert_events,
    upsert_match as upsert_canonical_match,
    upsert_players_and_lineups,
)
from scrape_cup import (
    install_league_dict,
    purge_null_cache,
    record_cup_clubs,
    upsert_cup_events,
    upsert_cup_players_and_lineups,
)

MATCH_RE = re.compile(r"/matches/(\d+)", re.I)
CANONICAL_COMPETITIONS = frozenset(
    {
        "ENG-Premier League",
        "ESP-La Liga",
        "FRA-Ligue 1",
        "GER-Bundesliga",
        "ITA-Serie A",
        "USA-MLS",
    }
)


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


def match_payload(game_data: dict, game_id: str, competition: str, season: str) -> dict:
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
    return payload


def canonical_schedule_row(payload: dict) -> pd.Series:
    """Shape a direct match-centre payload like the governed league loader."""
    return pd.Series(
        {
            "game_id": payload["game_id"],
            "date": payload["date"],
            "home_team": payload["home_team"],
            "away_team": payload["away_team"],
            "home_score": payload["home_score"],
            "away_score": payload["away_score"],
            "week": None,
            "venue": payload["venue"],
        }
    )


def _same_team(left: str | None, right: str | None, aliases: list[dict]) -> bool:
    a, b = str(left or "").strip().casefold(), str(right or "").strip().casefold()
    if not a or not b:
        return False
    if a == b:
        return True
    for row in aliases:
        values = {
            str(row.get(key) or "").strip().casefold()
            for key in ("match_name", "event_name", "display_name")
            if row.get(key)
        }
        if a in values and b in values:
            return True
    return False


def resolve_canonical_fixture_id(sb, payload: dict, competition: str, season: str) -> str:
    """Match a WhoScored payload to the preloaded scheduled fixture.

    The schedule uses independent provider IDs (``fd-*``), while WhoScored URLs
    use numeric IDs. Requiring a unique fixture-key match prevents a manual
    request from creating a duplicate match at a second identifier.
    """
    if not payload.get("date"):
        raise RuntimeError("The submitted match payload has no date for fixture reconciliation")
    candidates = (
        sb.table("matches")
        .select("game_id,date,home_team,away_team")
        .eq("league", competition)
        .eq("season", season)
        .eq("date", payload["date"])
        .execute()
        .data
        or []
    )
    aliases = (
        sb.table("team_names")
        .select("match_name,event_name,display_name")
        .eq("league", competition)
        .execute()
        .data
        or []
    )
    matched = [
        row
        for row in candidates
        if _same_team(payload["home_team"], row.get("home_team"), aliases)
        and _same_team(payload["away_team"], row.get("away_team"), aliases)
    ]
    if len(matched) != 1:
        raise RuntimeError(
            "Quick ingest could not uniquely reconcile this match to the future-fixture "
            f"schedule ({len(matched)} matches). Run the fixture sync before retrying."
        )
    return str(matched[0]["game_id"])


def assert_canonical_teams(sb, payload: dict, competition: str) -> None:
    allowed = league_whitelist(sb, competition)
    expected = league_expected_clubs(sb, competition)
    known = league_club_count(sb, competition)
    if expected and known >= expected:
        unknown = [
            name
            for name in (payload.get("home_team"), payload.get("away_team"))
            if name and name not in allowed
        ]
        if unknown:
            raise RuntimeError(
                f"{', '.join(unknown)} are not registered to {competition}; canonical write refused"
            )


def ingest_match(sb, ws, game_data: dict, game_id: str, competition: str, season: str):
    """Route modeled leagues to canonical data and everything else to cup isolation."""
    payload = match_payload(game_data, game_id, competition, season)
    if competition in CANONICAL_COMPETITIONS:
        assert_canonical_teams(sb, payload, competition)
        payload["game_id"] = resolve_canonical_fixture_id(sb, payload, competition, season)
        row = canonical_schedule_row(payload)
        loaded_id = upsert_canonical_match(sb, row, competition, season)
        upsert_players_and_lineups(sb, game_data, loaded_id, competition)
        event_count = upsert_events(sb, game_data, loaded_id, competition)
        if not event_count:
            raise RuntimeError("The canonical event payload produced zero events")
        try:
            sb.rpc("enqueue_rebuild_if_new_data", {}).execute()
        except Exception as exc:  # noqa: BLE001 - scheduled enqueue is the fallback
            print(
                f"  analytics enqueue deferred to the scheduled worker: {exc}",
                flush=True,
            )
        return payload, event_count, "canonical"

    sb.table("matches_cup").upsert(payload, on_conflict="game_id").execute()
    upsert_cup_players_and_lineups(sb, game_data, game_id)
    event_count = upsert_cup_events(sb, game_data, game_id)
    record_cup_clubs(
        sb,
        game_data,
        pd.Series({"home_team": payload["home_team"], "away_team": payload["away_team"]}),
    )
    return payload, event_count, "isolated"


def process(sb, project: dict, *, headless: bool) -> None:
    url = project.get("whoscored_url") or ""
    found = MATCH_RE.search(url)
    if not found:
        raise ValueError("The URL does not contain a WhoScored match id")
    game_id = found.group(1)
    competition = project.get("competition") or "ENG-League Cup"
    season = project.get("season") or "2627"

    # A match centre can go live before soccerdata has indexed that new season.
    # ``read_events`` refuses IDs absent from its selected schedule, even though
    # WhoScored's match-centre URL is already live.  Initialise any working
    # browser context, then call the reader directly with the submitted ID.
    candidates = [(competition, season), ("ENG-Premier League", "2526")]
    ws = None
    errors: list[str] = []
    for candidate_league, candidate_season in candidates:
        try:
            ws = get_scraper(candidate_league, candidate_season, headless=headless)
            break
        except Exception as exc:  # noqa: BLE001 - try the direct-match carrier
            errors.append(f"{candidate_league} {candidate_season}: {exc}")
    if ws is None:
        detail = errors[-1] if errors else "no compatible carrier was available"
        raise RuntimeError("Could not initialise a WhoScored browser: " + detail)

    purge_null_cache(ws, game_id, competition, season)
    path = cached_event_json_path(ws, game_id, competition, season)
    if path.is_file() and path.stat().st_size > 50:
        with path.open(encoding="utf-8") as handle:
            game_data = json.load(handle)
    else:
        url = f"https://www.whoscored.com/Matches/{game_id}/Live"
        reader = ws.get(
            url,
            path,
            var="require.config.params['args'].matchCentreData",
            no_cache=False,
        )
        value = reader.read()
        if value in (b"null", b""):
            reader = ws.get(
                url,
                path,
                var="require.config.params['args'].matchCentreData",
                no_cache=True,
            )
        reader.seek(0)
        game_data = json.load(reader)
    if not isinstance(game_data, dict) or not game_data.get("events"):
        raise RuntimeError("The downloaded match payload contains no events")

    match, event_count, scope = ingest_match(
        sb, ws, game_data, game_id, competition, season
    )
    if not event_count:
        raise RuntimeError("The event payload produced zero canonical events")

    sb.table("writing_lab_projects").update(
        {
            "game_id": game_id,
            "canonical_game_id": match["game_id"],
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
        f"READY [{scope}] {match['home_team']} {match['home_score']}-"
        f"{match['away_score']} {match['away_team']} · {event_count} events",
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
    failed = 0
    while True:
        project = claim_next(sb)
        if project:
            try:
                process(sb, project, headless=args.headless)
            except Exception as exc:  # noqa: BLE001 - persist a useful queue error
                fail(sb, project, exc)
                failed += 1
            handled += 1
            continue
        if not args.watch:
            print(f"Writing Lab queue empty · processed {handled}", flush=True)
            return 1 if failed else 0
        time.sleep(max(5, args.poll_seconds))


if __name__ == "__main__":
    raise SystemExit(main())
