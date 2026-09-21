#!/usr/bin/env python3
"""Static and import-level safety checks for historical ingestion."""
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PIPELINE = ROOT / "pipeline"
sys.path.insert(0, str(PIPELINE))

import scrape_history  # noqa: E402
import scrape_league  # noqa: E402
from scrape_and_load import upsert_players_and_lineups  # noqa: E402


class FakeQuery:
    def __init__(self, client, table):
        self.client = client
        self.table = table

    def upsert(self, *args, **kwargs):
        self.client.writes.append((self.table, "upsert"))
        return self

    def insert(self, *args, **kwargs):
        self.client.writes.append((self.table, "insert"))
        return self

    def delete(self, *args, **kwargs):
        self.client.writes.append((self.table, "delete"))
        return self

    def eq(self, *args, **kwargs):
        return self

    def execute(self):
        return self


class FakeClient:
    def __init__(self):
        self.writes: list[tuple[str, str]] = []

    def table(self, name):
        return FakeQuery(self, name)


class FakeRpcResponse:
    def __init__(self, data):
        self.data = data

    def execute(self):
        return self


class FakeRpcClient:
    def __init__(self):
        self.calls = []

    def rpc(self, name, params):
        self.calls.append((name, params))
        return FakeRpcResponse([{"game_id": "101"}, {"game_id": 202}])


def main() -> int:
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        print(("PASS  " if condition else "FAIL  ") + message)
        if not condition:
            failures.append(message)

    args = scrape_history.build_parser().parse_args([])
    require(scrape_history.selected_seasons(args) == ("2526",),
            "default run targets 2025/26 only")
    require(not args.execute, "default run is read-only")
    fake = FakeClient()
    upsert_players_and_lineups(
        fake,
        {
            "home": {"teamId": 1, "name": "Old Club", "players": []},
            "away": {"teamId": 2, "name": "Other Club", "players": []},
            "playerIdNameDictionary": {"10": "Example Player"},
            "events": [{"playerId": 10, "teamId": 1}],
        },
        "historical-game",
        "ENG-Premier League",
        write_shared_players=False,
    )
    require(not any(table == "players" for table, _ in fake.writes),
            "historical lineup write does not touch shared players")
    require(any(table == "lineups" for table, _ in fake.writes),
            "historical lineup data remains available")
    require(scrape_history.TRAINING_SEASONS == ("2526", "2425", "2324"),
            "training seasons run newest to oldest")
    require(len(scrape_history.TOP_FIVE) == 5 and
            "GER-Bundesliga" in scrape_history.TOP_FIVE,
            "exact top-five league population is declared")

    loader = (PIPELINE / "scrape_and_load.py").read_text(encoding="utf-8")
    league = (PIPELINE / "scrape_league.py").read_text(encoding="utf-8")
    history = (PIPELINE / "scrape_history.py").read_text(encoding="utf-8")
    require("write_shared_players=not historical" in loader and
            "if players_payload and write_shared_players:" in loader,
            "historical writes leave the shared player identity table untouched")
    require("if not historical:" in loader,
            "live whitelist remains enforced outside historical mode")
    require("args.no_rebuild = True" in league and "no_rebuild=True" in history,
            "historical ingestion cannot trigger live analytics rebuilds")
    require('"historical_loaded_game_ids"' in league and
            '"p_league": league, "p_season": season' in league,
            "historical resume detection uses its scoped service-only RPC")
    require('table("v_loaded_games")' not in league,
            "live resume detection avoids the global loaded-games scan")
    rpc = FakeRpcClient()
    loaded = scrape_league.loaded_game_ids(rpc, league="USA-MLS", season="2627")
    require(loaded == {"101", "202"} and rpc.calls == [(
        "historical_loaded_game_ids",
        {"p_league": "USA-MLS", "p_season": "2627"},
    )], "live resume lookup is scoped to league and season")
    attempted = []
    def fake_scrape(_sb, _args, league_id, _season):
        attempted.append(league_id)
        if league_id == "ENG-Premier League":
            raise RuntimeError("simulated lookup timeout")
        return 1, 0, 0, 1207
    totals = scrape_league.scrape_targets(
        None,
        object(),
        [("ENG-Premier League", "2627"), ("USA-MLS", "2627")],
        scrape_fn=fake_scrape,
    )
    require(attempted == ["ENG-Premier League", "USA-MLS"] and totals == (1, 1, 1, 1207),
            "one league failure cannot block later league targets")
    require('parser.add_argument("--execute"' in history,
            "database writes require an explicit execute flag")
    require("historical schedule has no played fixtures" in league and
            "target failed:" in history,
            "unavailable historical targets fail visibly without stopping later targets")

    if failures:
        print(f"\n{len(failures)} historical scraper check(s) failed.")
        return 1
    print("\nAll historical scraper safety checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
