"""Scraper heartbeat: one row in public.scraper_runs per invocation.

Why this exists. Every freshness check the database can run is derived from
events, and all of them are blind to the one failure mode that actually happened:
the laptop never woke up. No new events looks exactly like no matches played.
Only the scraper reporting its own existence can tell those apart, and it has to
report runs that fail or return nothing just as loudly as runs that succeed,
otherwise silence remains ambiguous.

Credentials: reuses get_supabase() from scrape_and_load, which reads
SUPABASE_URL and SUPABASE_SERVICE_KEY from the .env file at the repo root via
load_dotenv. Nothing new is needed and no key belongs in this file.

Wiring, in pipeline/scrape_league.py main():

    from scraper_heartbeat import heartbeat

    with heartbeat(leagues=leagues) as hb:
        ...existing scrape loop...
        hb.record(matches_attempted=n_attempted,
                  matches_written=n_written,
                  events_written=n_events)

The context manager writes a 'running' row on entry and settles it on exit:
'success' if the body completed, 'failed' with the traceback if it raised, and
'partial' if it completed having attempted matches but written none.
"""
from __future__ import annotations

import socket
import traceback
from contextlib import contextmanager
from typing import Iterator, Sequence

from scrape_and_load import get_supabase


class _Heartbeat:
    def __init__(self, row_id: int | None, client) -> None:
        self._id = row_id
        self._client = client
        self.matches_attempted = 0
        self.matches_written = 0
        self.events_written = 0

    def record(self, *, matches_attempted: int = 0, matches_written: int = 0,
               events_written: int = 0) -> None:
        """Accumulate counters. Safe to call repeatedly, per league or per match."""
        self.matches_attempted += int(matches_attempted or 0)
        self.matches_written += int(matches_written or 0)
        self.events_written += int(events_written or 0)

    def _settle(self, status: str, error: str | None) -> None:
        if self._id is None:
            return
        payload = {
            "status": status,
            "matches_attempted": self.matches_attempted,
            "matches_written": self.matches_written,
            "events_written": self.events_written,
            "error": (error or "")[:2000] or None,
        }
        # finished_at is stamped server side by trg_scraper_run_finished, so a
        # crashed client cannot leave a settled row without an end time.
        try:
            self._client.table("scraper_runs").update(payload).eq("id", self._id).execute()
        except Exception:  # noqa: BLE001
            # A heartbeat must never be the reason a scrape fails.
            traceback.print_exc()


@contextmanager
def heartbeat(leagues: Sequence[str] | None = None) -> Iterator[_Heartbeat]:
    client = None
    row_id = None
    try:
        client = get_supabase()
        res = (
            client.table("scraper_runs")
            .insert({
                "host": socket.gethostname(),
                "leagues": list(leagues) if leagues else None,
                "status": "running",
            })
            .execute()
        )
        row_id = res.data[0]["id"] if res.data else None
    except Exception:  # noqa: BLE001
        traceback.print_exc()

    hb = _Heartbeat(row_id, client)
    try:
        yield hb
    except BaseException:
        hb._settle("failed", traceback.format_exc())
        raise
    else:
        # Attempted matches but wrote none is not success. It is the signature of
        # an anti-bot block, which otherwise looks identical to a quiet week.
        if hb.matches_attempted > 0 and hb.matches_written == 0:
            hb._settle("partial", "attempted matches but wrote none")
        else:
            hb._settle("success", None)
