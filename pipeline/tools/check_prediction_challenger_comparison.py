#!/usr/bin/env python3
"""Regression checks for immutable same-fixture challenger comparisons."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "pipeline" / "compare_prediction_challengers.py"


def payload(manifest_hash: str, away_team: str = "B") -> dict:
    return {
        "season": "2627",
        "as_of": "2026-09-14T18:00:29+00:00",
        "forecast_kind": "latest",
        "fixture_manifest_sha256": manifest_hash,
        "model_version": manifest_hash,
        "predictions": [{
            "game_id": "g1",
            "date": "2026-09-20T12:00:00+00:00",
            "league": "ENG-Premier League",
            "home_team": "A",
            "away_team": away_team,
            "home_expected_goals": 1.5,
            "away_expected_goals": 1.0,
            "home_win_probability": 0.49,
            "draw_probability": 0.27,
            "away_win_probability": 0.24,
        }],
    }


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    primary, challenger, output = root / "a.json", root / "b.json", root / "out.json"
    primary.write_text(json.dumps(payload("old-source")), encoding="utf-8")
    challenger.write_text(json.dumps(payload("new-source")), encoding="utf-8")
    subprocess.run(
        [sys.executable, str(SCRIPT), "--primary", str(primary), "--challenger", str(challenger), "--output", str(output)],
        check=True,
        capture_output=True,
        text=True,
    )
    report = json.loads(output.read_text(encoding="utf-8"))
    assert report["fixtures_compared"] == 1
    assert report["scope"]["source_manifest_hashes_match"] is False
    assert report["scope"]["fixture_identity_sha256"]

    challenger.write_text(json.dumps(payload("new-source", away_team="C")), encoding="utf-8")
    failed = subprocess.run(
        [sys.executable, str(SCRIPT), "--primary", str(primary), "--challenger", str(challenger), "--output", str(output)],
        capture_output=True,
        text=True,
    )
    assert failed.returncode != 0
    assert "different fixture dates, leagues, or teams" in failed.stderr

print("Prediction challenger comparison checks passed")
