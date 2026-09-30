#!/usr/bin/env python3
"""Regression checks for the nightly rescrape completion gate."""
from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audit_live_ingestion import audit_league


def main() -> None:
    registry = {"league": "ENG-Premier League", "season": "2627", "expected_teams": 0}
    today = date(2026, 9, 30)

    def audit(queue: list[dict]) -> dict:
        return audit_league(registry, [], set(), today, rescrape_rows=queue)

    fresh = {"game_id": "1", "league": registry["league"], "status": "queued",
             "queued_at": "2026-09-30T08:00:00Z", "attempts": 0}
    assert audit([fresh])["healthy"]
    failed_once = dict(fresh, attempts=1)
    result = audit([failed_once])
    assert not result["healthy"]
    assert result["blocked_rescrape_games"] == ["1"]
    assert result["aged_rescrape_games"] == []
    assert audit([dict(fresh, status="exhausted")])["blocked_rescrape_games"] == ["1"]
    assert audit([dict(fresh, queued_at="2026-09-29T08:00:00Z")])["blocked_rescrape_games"] == ["1"]
    assert audit([dict(fresh, status="done", attempts=3)])["healthy"]

    small_league = dict(registry, expected_teams=2)
    home = {"game_id": "home", "home_team": "A", "away_team": "B",
            "date": "2026-10-01", "home_score": None, "away_score": None}
    away = dict(home, game_id="away", home_team="B", away_team="A")
    assert audit_league(small_league, [home, away], set(), today)["healthy"]
    incomplete = audit_league(small_league, [home], set(), today)
    assert not incomplete["healthy"]
    assert "1/2 expected matches" in " ".join(incomplete["warnings"])
    duplicated = audit_league(small_league, [home, dict(home, game_id="duplicate")], set(), today)
    assert "duplicate home/away" in " ".join(duplicated["warnings"])
    print("Nightly rescrape completion gate checks passed")


if __name__ == "__main__":
    main()
