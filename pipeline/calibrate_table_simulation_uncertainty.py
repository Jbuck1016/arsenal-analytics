#!/usr/bin/env python3
"""Backtest persistent team-strength uncertainty for league-table forecasts."""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

import pandas as pd

import evaluate_model_legitimacy as legitimacy
import train_match_baselines as baseline


SEASONS = ("2425", "2526")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulations", type=int, default=500)
    parser.add_argument("--candidate-sd", type=float, action="append")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    db = baseline.db_client()
    frames = {}
    for season in SEASONS:
        frame = baseline.load_matches(db, season, 1)
        frame["season"] = season
        frames[season] = frame.sort_values(["date", "game_id"]).reset_index(drop=True)
    candidates = args.candidate_sd or [0.0, 0.08, 0.12, 0.16, 0.20]
    rows = []
    reports = {}
    for sd in candidates:
        report = legitimacy.table_backtests(frames, args.simulations, sd)
        reports[str(sd)] = report
        early = next(row for row in report["summary"] if row["checkpoint"] == 0.25)
        later = [row for row in report["summary"] if row["checkpoint"] >= 0.5]
        rows.append({
            "team_strength_uncertainty_sd": sd,
            "early_position_80pct_coverage": early["position_80pct_coverage"],
            "early_points_mae": early["mean_absolute_points_error"],
            "later_position_80pct_coverage": sum(row["position_80pct_coverage"] for row in later) / len(later),
            "later_points_mae": sum(row["mean_absolute_points_error"] for row in later) / len(later),
            "calibration_distance": abs(early["position_80pct_coverage"] - 0.80),
        })
        print(f"sd={sd:.2f}: early coverage={early['position_80pct_coverage']:.3f}, points MAE={early['mean_absolute_points_error']:.2f}")
    eligible = [row for row in rows if row["later_points_mae"] <= rows[0]["later_points_mae"] + 0.5]
    winner = min(eligible or rows, key=lambda row: (row["calibration_distance"], row["early_points_mae"]))
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "purpose": "Calibrate early-season position uncertainty without sacrificing later-season points accuracy.",
        "candidates": rows,
        "selected_team_strength_uncertainty_sd": winner["team_strength_uncertainty_sd"],
        "decision": "review_selected_uncertainty_before_default_change",
        "full_results": reports,
        "guardrail": "No live simulation or database row was changed.",
    }
    output = root / "artifacts" / "model_reports" / "table_uncertainty_calibration.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Selected research candidate: {winner['team_strength_uncertainty_sd']:.2f}")
    print(f"Report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
