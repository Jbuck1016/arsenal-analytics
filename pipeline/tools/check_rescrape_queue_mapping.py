"""Offline regression for a queued WhoScored ID with only a provider fixture row."""

from __future__ import annotations

import io
import json
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import rescrape_queue as queue  # noqa: E402


def main() -> None:
    game_data = {
        "startDate": "2026-09-19T13:30:00",
        "home": {"name": "Hamburger SV", "scores": {"fulltime": 2}},
        "away": {"name": "FC Koln", "scores": {"fulltime": 1}},
        "events": [{"id": 1, "expandedMinute": 90}],
    }
    class FakeQuery:
        def __init__(self, name):
            self.name = name

        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def execute(self):
            rows = {
                "matches": [{"game_id": "fd-565808", "home_team": "Hamburger SV", "away_team": "FC Koln"}],
                "team_names": [{"match_name": "FC Koln", "event_name": "FC Köln", "display_name": "Cologne"}],
            }
            return SimpleNamespace(data=rows[self.name])

    class FakeClient:
        def table(self, name):
            return FakeQuery(name)

    game_data["away"]["name"] = "FC Köln"
    with patch.object(queue, "upsert_match", return_value="fd-565808") as upsert:
        canonical = queue._canonicalize_missing_fixture(
            FakeClient(), game_data, "1995438", "GER-Bundesliga", "2627"
        )
    assert canonical == "fd-565808"
    assert upsert.call_count == 1
    assert str(upsert.call_args.args[1]["game_id"]) == "fd-565808"
    assert upsert.call_args.args[1]["away_team"] == "FC Koln"

    class FakeScraper:
        def get(self, url, path, *, var, no_cache):
            assert url.endswith("/Matches/1995438/Live")
            assert no_cache is True
            return io.BytesIO(json.dumps(game_data).encode("utf-8"))

    with tempfile.TemporaryDirectory() as temp:
        with patch.object(
            queue, "cached_event_json_path", return_value=Path(temp) / "1995438.json"
        ):
            direct = queue._fetch_event_payload(
                FakeScraper(), "1995438", "GER-Bundesliga", "2627"
            )
    assert direct == game_data
    print("PASS: direct fetch needs no season calendar and maps to canonical fixture")


if __name__ == "__main__":
    main()
