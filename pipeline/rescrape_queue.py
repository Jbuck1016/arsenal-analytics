"""Drain the re-scrape queue at the start of every scraper run.

Why this exists. A fixture whose event feed is truncated is worse than one that
is missing: mv_match_length derives length from the events themselves, and
mv_player_minutes scales each spell by 90.0/length_min, so a feed that stops at
minute 50 credits every player a full 90 of exposure against a numerator that
stopped halfway. Every per-90 for those players is diluted and the percentile
pools they sit in are depressed with them, silently.

So the pipeline pulls the fixture out of the metrics layer, records it here, and
fetches it again. Nothing is left for a human to notice.

Credentials come from get_supabase() in scrape_and_load, which reads
SUPABASE_URL and SUPABASE_SERVICE_KEY from the .env at the repo root. No key
belongs in this file.

Wiring, in pipeline/scrape_league.py main(), immediately after the scraper is
built and before the normal backfill loop:

    from rescrape_queue import drain_rescrape_queue
    drain_rescrape_queue(scraper, limit=10)
"""
from __future__ import annotations

import argparse
import json
import traceback
from pathlib import Path, PurePosixPath
from typing import Any

from scrape_and_load import (
    cached_event_json_path,
    get_scraper,
    get_supabase,
    upsert_events,
    upsert_players_and_lineups,
)


def _claim_rows(client: Any, limit: int, game_ids: list[str] | None) -> list[dict]:
    if game_ids:
        return (
            client.rpc("claim_rescrape_games", {"p_game_ids": game_ids})
            .execute()
            .data
            or []
        )
    return (
        client.rpc("claim_rescrape_batch", {"p_limit": limit}).execute().data or []
    )


def _source_game_id(client: Any, game_id: str) -> str:
    """Resolve a canonical fixture id to the WhoScored id in its raw archive."""
    rows = (
        client.table("archive_match_manifest")
        .select("object_path")
        .eq("game_id", game_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if not rows:
        if game_id.isdigit():
            return game_id
        raise ValueError(f"no archive manifest maps canonical game {game_id}")
    filename = PurePosixPath(rows[0]["object_path"]).name
    if not filename.endswith(".json.gz"):
        raise ValueError(f"unexpected archive object path for {game_id}: {filename}")
    source_id = filename.removesuffix(".json.gz")
    if not source_id.isdigit():
        raise ValueError(f"archive source id is not numeric for {game_id}: {source_id}")
    return source_id


def _fixture_scope(client: Any, game_id: str) -> tuple[str, str]:
    rows = (
        client.table("matches")
        .select("league,season")
        .eq("game_id", game_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if not rows:
        raise ValueError(f"canonical match row is missing for {game_id}")
    return str(rows[0]["league"]), str(rows[0]["season"])


def _last_event_minute(game_data: dict) -> int:
    minutes = []
    for event in game_data.get("events", []):
        value = event.get("expandedMinute", event.get("minute"))
        try:
            minutes.append(int(value))
        except (TypeError, ValueError):
            continue
    return max(minutes, default=0)


def _prune_stale_events(
    client: Any, game_id: str, provider_event_ids: set[int]
) -> int:
    rows = (
        client.table("events")
        .select("ws_id")
        .eq("game_id", game_id)
        .execute()
        .data
        or []
    )
    stored_ids = {int(row["ws_id"]) for row in rows if row.get("ws_id") is not None}
    stale_ids = sorted(stored_ids - provider_event_ids)
    for offset in range(0, len(stale_ids), 200):
        client.table("events").delete().eq("game_id", game_id).in_(
            "ws_id", stale_ids[offset : offset + 200]
        ).execute()
    return len(stale_ids)


def _refresh_canonical_fixture(
    client: Any, game_id: str, *, reuse_cache: bool = False
) -> int:
    """Fetch a fresh provider feed and retain the existing canonical identity."""
    league, season = _fixture_scope(client, game_id)
    source_id = _source_game_id(client, game_id)
    scraper = None
    try:
        # live=True bypasses the truncated cache. read_events still writes the
        # refreshed raw payload to soccerdata's deterministic cache path.
        if reuse_cache:
            path = (
                Path.home()
                / "soccerdata"
                / "data"
                / "WhoScored"
                / "events"
                / f"{league}_{season}"
                / f"{source_id}.json"
            )
        else:
            scraper = get_scraper(league, season, headless=False)
            scraper.read_events(match_id=int(source_id), live=True, output_fmt="raw")
            path = cached_event_json_path(scraper, source_id, league, season)
        with path.open(encoding="utf-8") as handle:
            game_data = json.load(handle)
        provider_events = game_data.get("events", [])
        event_count = len(provider_events)
        provider_event_ids = {
            int(event["id"]) for event in provider_events if event.get("id") is not None
        }
        unique_event_count = len(provider_event_ids)
        last_minute = _last_event_minute(game_data)
        if event_count == 0 or last_minute < 80:
            raise ValueError(
                f"provider feed remains truncated: {event_count} events, "
                f"last minute {last_minute}"
            )
        upsert_players_and_lineups(client, game_data, game_id, league)
        written = upsert_events(client, game_data, game_id, league)
        if written != unique_event_count:
            raise ValueError(
                "event write count mismatch: "
                f"provider_unique={unique_event_count}, written={written}"
            )
        pruned = _prune_stale_events(client, game_id, provider_event_ids)
        if pruned:
            print(f"    -> removed {pruned} stale event row(s)")
        return written
    finally:
        driver = getattr(scraper, "_driver", None) if scraper is not None else None
        if driver is not None:
            driver.quit()


def drain_rescrape_queue(
    scraper: Any = None,
    limit: int = 10,
    game_ids: list[str] | None = None,
    reuse_cache: bool = False,
) -> int:
    """Re-fetch every fixture the database has flagged as unusable.

    Claims a batch server side, which increments attempts before the work starts,
    so a crash mid-fetch still counts as an attempt and the fixture cannot retry
    forever. Three failures marks it exhausted and raises an alert.
    """
    client = get_supabase()
    try:
        claimed = _claim_rows(client, limit, game_ids)
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        return 0

    if not claimed:
        print("rescrape queue: empty")
        return 0

    print(f"rescrape queue: {len(claimed)} fixture(s) to refetch")
    done = 0
    for row in claimed:
        game_id = row["game_id"]
        attempts = row.get("attempts")
        print(f"  refetching {game_id} (attempt {attempts})")
        ok, err = False, None
        try:
            written = _refresh_canonical_fixture(
                client, game_id, reuse_cache=reuse_cache
            )
            print(f"    -> refreshed {written} events under canonical id {game_id}")
            ok = True
        except Exception as exc:  # noqa: BLE001
            err = f"{type(exc).__name__}: {exc}"
            traceback.print_exc()

        try:
            result = client.rpc(
                "record_rescrape_result",
                {"p_game_id": game_id, "p_ok": ok, "p_error": err},
            ).execute()
            print(f"    -> {result.data}")
            if ok:
                done += 1
        except Exception:  # noqa: BLE001
            traceback.print_exc()

    return done


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument(
        "--reuse-cache",
        action="store_true",
        help="Use the latest cached provider payload after a verified fresh fetch.",
    )
    parser.add_argument(
        "--game-id",
        action="append",
        dest="game_ids",
        help="Claim and repair only this canonical game id; repeat as needed.",
    )
    args = parser.parse_args()
    repaired = drain_rescrape_queue(
        limit=args.limit,
        game_ids=args.game_ids,
        reuse_cache=args.reuse_cache,
    )
    return 0 if repaired == len(args.game_ids or []) or not args.game_ids else 1


if __name__ == "__main__":
    raise SystemExit(main())
