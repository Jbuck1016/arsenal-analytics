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

import traceback
from typing import Any

from scrape_and_load import get_supabase


def drain_rescrape_queue(scraper: Any = None, limit: int = 10) -> int:
    """Re-fetch every fixture the database has flagged as unusable.

    Claims a batch server side, which increments attempts before the work starts,
    so a crash mid-fetch still counts as an attempt and the fixture cannot retry
    forever. Three failures marks it exhausted and raises an alert.
    """
    client = get_supabase()
    try:
        claimed = client.rpc("claim_rescrape_batch", {"p_limit": limit}).execute().data or []
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
            # process_match is the same single-match path the normal backfill uses,
            # so a requeued fixture is fetched exactly like any other.
            from scrape_and_load import process_match

            process_match(game_id, scraper=scraper)
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
