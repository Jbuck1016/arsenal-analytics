#!/usr/bin/env python3
"""Checks earliest-freeze deduplication across weekly shadow snapshots."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
from score_prediction_history import combine_snapshots  # noqa: E402


def payload(as_of: str, game_id: str, kickoff: str, probability: float) -> dict:
    return {
        "as_of": as_of, "evaluation_through": "2026-09-20T00:00:00+00:00",
        "predictions": [{"game_id": game_id, "date": kickoff, "home_win_probability": probability}],
    }


later = payload("2026-09-11T00:00:00+00:00", "g1", "2026-09-12T00:00:00+00:00", 0.7)
earlier = payload("2026-09-10T00:00:00+00:00", "g1", "2026-09-12T00:00:00+00:00", 0.6)
other = payload("2026-09-10T00:00:00+00:00", "g2", "2026-09-13T00:00:00+00:00", 0.5)
rows, repeats = combine_snapshots([later, other, earlier])
assert repeats == 1 and len(rows) == 2
assert next(row for row in rows if row["game_id"] == "g1")["home_win_probability"] == 0.6
print("Prediction history scoring checks passed")
