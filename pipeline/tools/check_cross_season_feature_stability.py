#!/usr/bin/env python3
"""Regression checks for the cross-season feature stability decision."""
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
script = ROOT / "pipeline" / "audit_cross_season_feature_stability.py"
subprocess.run([sys.executable, str(script)], cwd=ROOT, check=True)
report = json.loads((ROOT / "artifacts" / "model_reports" / "cross_season_feature_stability.json").read_text(encoding="utf-8"))

assert report["decision"] == "focused_challengers_only"
assert {"shooting", "territory", "pressing_defense"}.issubset(report["gate"]["passed_families"])
assert {"possession", "progression"}.issubset(report["gate"]["research_only_families"])
assert all(row["log_loss_penalty_when_removed"] > 0 for row in report["elo_dependency"]["season_results"])
assert report["recommended_challengers"] == ["shooting + territory", "territory + pressing_defense"]
print("Cross-season feature stability checks passed")
