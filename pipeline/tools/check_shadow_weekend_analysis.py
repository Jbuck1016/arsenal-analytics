#!/usr/bin/env python3
"""Deterministic checks for frozen-weekend retrospective helpers."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

import analyze_shadow_weekend as review  # noqa: E402


prediction = {
    "home_win_probability": 0.6,
    "draw_probability": 0.25,
    "away_win_probability": 0.15,
    "home_expected_goals": 1.7,
    "away_expected_goals": 0.8,
}
match = {"home_score": 0, "away_score": 1}
scored = review.score_row(prediction, match)
assert scored["actual_outcome"] == "A"
assert scored["favorite"] == "H"
assert scored["actual_probability"] == 0.15
assert scored["correct_favorite"] is False

tactical = {
    "multi_metric_leader": "H",
    "home_metric_edges": 4,
    "away_metric_edges": 1,
}
assert review.interpretation(scored, tactical) == "result_swung_against_process"
tactical["multi_metric_leader"] = "A"
assert review.interpretation(scored, tactical) == "pre_match_read_missed_match_process"

scored["actual_probability"] = 0.3
assert review.interpretation(scored, tactical) == "plausible_alternate_outcome"

summary = review.aggregate([{**scored, "home_goal_error": -1.7, "away_goal_error": 0.2}])
assert summary["matches"] == 1
assert summary["observed_outcome_share"]["A"] == 1.0
print("Shadow weekend analysis checks passed")
