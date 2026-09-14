#!/usr/bin/env python3
"""Load and validate narrowly scoped historical event-source exceptions."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


MANIFEST = Path(__file__).with_name("historical_source_exceptions.json")
SUMMARY_MARKER = "=== Historical scrape summary ==="


def load_exceptions(path: Path = MANIFEST) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1 or not isinstance(payload.get("exceptions"), list):
        raise ValueError("unsupported historical source-exception manifest")
    rows = payload["exceptions"]
    required = {
        "season", "league", "game_id", "date", "home_team", "away_team",
        "reason", "disposition", "accepted_at",
    }
    seen: set[tuple[str, str]] = set()
    for row in rows:
        if not isinstance(row, dict) or required - set(row):
            raise ValueError("historical source exception is missing required fields")
        key = (str(row["season"]), str(row["game_id"]))
        if key in seen:
            raise ValueError(f"duplicate historical source exception: {key}")
        if row["disposition"] != "retain_match_outcome_exclude_event_features":
            raise ValueError(f"unsupported exception disposition for {key}")
        seen.add(key)
    return rows


def for_season(season: str, path: Path = MANIFEST) -> list[dict[str, Any]]:
    return [row for row in load_exceptions(path) if str(row["season"]) == season]


def ids_for_season(season: str, path: Path = MANIFEST) -> set[str]:
    return {str(row["game_id"]) for row in for_season(season, path)}


def is_valid_event_payload(path: Path) -> bool:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return isinstance(payload, dict) and isinstance(payload.get("events"), list)


def validate_local_exception(row: dict[str, Any], cache_root: Path) -> None:
    path = cache_root / f"{row['league']}_{row['season']}" / f"{row['game_id']}.json"
    if is_valid_event_payload(path):
        raise ValueError(
            f"stale exception {row['season']}/{row['game_id']}: valid event payload now exists"
        )


def validate_log(season: str, log: Path, cache_root: Path) -> list[dict[str, Any]]:
    rows = for_season(season)
    raw = log.read_bytes()
    encoding = "utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8"
    text = raw.decode(encoding, errors="replace")
    marker = text.rfind(SUMMARY_MARKER)
    if marker < 0:
        raise ValueError("final Historical scrape summary is absent")
    block = text[marker:]
    failed = re.search(r"(?m)^\s*failed\s*:\s*(\d+)\s*$", block)
    remaining = re.search(r"(?m)^\s*remaining\s*:\s*(\d+)\s*$", block)
    if not failed or not remaining:
        raise ValueError("final Historical scrape summary is incomplete")
    expected = len(rows)
    if int(failed.group(1)) != expected or int(remaining.group(1)) != expected:
        raise ValueError(
            f"summary does not match {expected} accepted exception(s): "
            f"failed={failed.group(1)} remaining={remaining.group(1)}"
        )
    for row in rows:
        validate_local_exception(row, cache_root)
        if str(row["game_id"]) not in text:
            raise ValueError(f"exception game_id {row['game_id']} is absent from scrape log")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--cache-root", type=Path, required=True)
    args = parser.parse_args()
    rows = validate_log(args.season, args.log, args.cache_root)
    print(json.dumps({"accepted": len(rows), "game_ids": [row["game_id"] for row in rows]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
