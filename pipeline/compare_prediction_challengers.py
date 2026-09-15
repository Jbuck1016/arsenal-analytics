#!/usr/bin/env python3
"""Compare two immutable prediction snapshots fixture by fixture."""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


PROBABILITY_FIELDS = ("home_win_probability", "draw_probability", "away_win_probability")


def index(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = {str(row["game_id"]): row for row in payload.get("predictions", [])}
    if len(rows) != len(payload.get("predictions", [])):
        raise RuntimeError("prediction snapshot contains duplicate game ids")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--primary", type=Path, required=True)
    parser.add_argument("--challenger", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    primary_payload = json.loads(args.primary.read_text(encoding="utf-8"))
    challenger_payload = json.loads(args.challenger.read_text(encoding="utf-8"))
    identity = ("season", "as_of", "forecast_kind", "fixture_manifest_sha256")
    mismatched = [key for key in identity if primary_payload.get(key) != challenger_payload.get(key)]
    if mismatched:
        raise RuntimeError(f"snapshots do not share an immutable fixture identity: {mismatched}")
    primary, challenger = index(primary_payload), index(challenger_payload)
    if set(primary) != set(challenger):
        raise RuntimeError("snapshots do not contain exactly the same fixtures")

    rows = []
    for game_id in primary:
        left, right = primary[game_id], challenger[game_id]
        deltas = {
            field: float(right[field]) - float(left[field]) for field in PROBABILITY_FIELDS
        }
        max_field = max(PROBABILITY_FIELDS, key=lambda field: abs(deltas[field]))
        primary_pick = max(PROBABILITY_FIELDS, key=lambda field: float(left[field]))
        challenger_pick = max(PROBABILITY_FIELDS, key=lambda field: float(right[field]))
        rows.append({
            "game_id": game_id,
            "date": left["date"],
            "league": left["league"],
            "home_team": left["home_team"],
            "away_team": left["away_team"],
            "primary": {field: float(left[field]) for field in PROBABILITY_FIELDS} | {
                "home_expected_goals": float(left["home_expected_goals"]),
                "away_expected_goals": float(left["away_expected_goals"]),
                "pick": primary_pick,
            },
            "challenger": {field: float(right[field]) for field in PROBABILITY_FIELDS} | {
                "home_expected_goals": float(right["home_expected_goals"]),
                "away_expected_goals": float(right["away_expected_goals"]),
                "pick": challenger_pick,
            },
            "probability_delta": deltas,
            "maximum_absolute_probability_delta": abs(deltas[max_field]),
            "largest_moved_outcome": max_field,
            "different_favourite": primary_pick != challenger_pick,
            "primary_drivers": (left.get("explanation") or {}).get("drivers", [])[:3],
            "challenger_drivers": (right.get("explanation") or {}).get("drivers", [])[:3],
        })
    rows.sort(key=lambda row: row["maximum_absolute_probability_delta"], reverse=True)
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "scope": {key: primary_payload.get(key) for key in identity},
        "primary_model": primary_payload.get("model_version"),
        "challenger_model": challenger_payload.get("model_version"),
        "fixtures_compared": len(rows),
        "different_favourite_count": sum(row["different_favourite"] for row in rows),
        "mean_maximum_probability_delta": (
            sum(row["maximum_absolute_probability_delta"] for row in rows) / len(rows)
            if rows else 0.0
        ),
        "largest_disagreements": rows[:25],
        "all_fixture_comparisons": rows,
        "interpretation": (
            "Disagreement is diagnostic, not proof that either model is right. "
            "Resolved frozen forecasts must decide which philosophy generalizes live."
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Compared {len(rows)} identical fixtures: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
