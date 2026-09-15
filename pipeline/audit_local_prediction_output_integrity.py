#!/usr/bin/env python3
"""Audit saved forecasts and table simulations without a database connection."""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any


PROBABILITY_FIELDS = ("home_win_probability", "draw_probability", "away_win_probability")


def instant(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions-file", type=Path, required=True)
    parser.add_argument("--fixture-snapshot", type=Path, required=True)
    parser.add_argument("--simulations-dir", type=Path, default=Path("artifacts/simulations"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/data_quality/local_prediction_output_integrity.json"))
    args = parser.parse_args()

    payload = json.loads(args.predictions_file.read_text(encoding="utf-8"))
    fixture_payload = json.loads(args.fixture_snapshot.read_text(encoding="utf-8"))
    predictions = list(payload.get("predictions") or [])
    prediction_ids = [str(row["game_id"]) for row in predictions]
    counts = Counter(prediction_ids)
    malformed, bad_scorelines = [], []
    for row in predictions:
        probabilities = [float(row[field]) for field in PROBABILITY_FIELDS]
        if (
            any(not math.isfinite(value) or not 0 <= value <= 1 for value in probabilities)
            or abs(sum(probabilities) - 1) > 1e-6
            or min(float(row["home_expected_goals"]), float(row["away_expected_goals"])) <= 0
        ):
            malformed.append(str(row["game_id"]))
        scorelines = row.get("scoreline_distribution") or {}
        if not scorelines or abs(sum(float(value) for value in scorelines.values()) - 1) > 1e-6:
            bad_scorelines.append(str(row["game_id"]))

    active_ids = {str(row["game_id"]) for row in fixture_payload.get("fixtures", [])}
    completed_ids = {str(row["game_id"]) for row in fixture_payload.get("completed_fixtures", [])}
    predicted_ids = set(prediction_ids)
    retired_since_forecast = predicted_ids - active_ids
    unexplained_retired = retired_since_forecast - completed_ids
    simulation_reports: list[dict[str, Any]] = []
    for path in sorted(args.simulations_dir.glob(f"*_{payload['season']}_{payload['forecast_kind']}.json")):
        simulation = json.loads(path.read_text(encoding="utf-8"))
        teams = list(simulation.get("teams") or [])
        bad_positions = sum(
            abs(sum(float(value) for value in team["position_probabilities"].values()) - 1) > 1e-6
            for team in teams
        )
        maximum_remaining_points = 3 * int(simulation.get("remaining_fixtures") or 0)
        bad_points = sum(
            not (
                float(team["current_points"])
                <= float(team["expected_points"])
                <= float(team["current_points"]) + maximum_remaining_points
            )
            for team in teams
        )
        title_sum = sum(float(team["champion_probability"]) for team in teams)
        simulation_reports.append({
            "path": str(path.resolve()),
            "league": simulation.get("league"),
            "teams": len(teams),
            "remaining_fixtures": simulation.get("remaining_fixtures"),
            "rules_version": simulation.get("rules_version"),
            "title_probability_sum": title_sum,
            "bad_position_distributions": bad_positions,
            "bad_expected_points_bounds": bad_points,
            "passed": bad_positions == 0 and bad_points == 0 and abs(title_sum - 1) <= 1e-6,
        })

    report = {
        "report_schema_version": 1,
        "prediction_file": str(args.predictions_file.resolve()),
        "fixture_snapshot": str(args.fixture_snapshot.resolve()),
        "fixture_snapshot_generated_at": fixture_payload.get("generated_at"),
        "prediction_as_of": payload.get("as_of"),
        "prediction_count": len(predictions),
        "duplicate_prediction_ids": sum(count - 1 for count in counts.values()),
        "malformed_probabilities_or_expected_goals": malformed,
        "bad_scoreline_distributions": bad_scorelines,
        "provider_active_fixture_count": len(active_ids),
        "provider_active_not_predicted": sorted(active_ids - predicted_ids),
        "predictions_retired_after_forecast": sorted(retired_since_forecast),
        "retired_predictions_confirmed_completed": sorted(retired_since_forecast & completed_ids),
        "unexplained_retired_predictions": sorted(unexplained_retired),
        "simulations": simulation_reports,
    }
    report["passed"] = (
        not report["duplicate_prediction_ids"]
        and not malformed
        and not bad_scorelines
        and not report["provider_active_not_predicted"]
        and not unexplained_retired
        and len(simulation_reports) == 5
        and all(row["passed"] for row in simulation_reports)
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Local prediction integrity: {'PASS' if report['passed'] else 'BLOCK'}")
    print(f"Predictions={len(predictions)} active_provider={len(active_ids)} retired_completed={len(retired_since_forecast & completed_ids)}")
    print(f"Simulations={sum(row['passed'] for row in simulation_reports)}/{len(simulation_reports)} valid")
    print(f"Report: {args.output.resolve()}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
