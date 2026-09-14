#!/usr/bin/env python3
"""Static safety checks for unattended V2 shadow operations."""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
weekly = (ROOT / "pipeline" / "run_shadow_weekly.ps1").read_text(encoding="utf-8")
score = (ROOT / "pipeline" / "refresh_shadow_scorecard.ps1").read_text(encoding="utf-8")
register = (ROOT / "pipeline" / "register_model_operations_task.ps1").read_text(encoding="utf-8")
generator = (ROOT / "pipeline" / "generate_match_predictions.py").read_text(encoding="utf-8")
policy = json.loads((ROOT / "pipeline" / "reviewed_model_feature_drift_policy_v2.json").read_text(encoding="utf-8"))

assert '[int]$ModelRunId = 4' in weekly
assert "v2-field-tilt-box-entries-poisson" in weekly
assert "--observation-schema-version 2 --feature-schema-version 2" in weekly
assert "--reuse-output --execute" in weekly and "--reuse-output" in generator
assert "promote_model_candidate" not in weekly and "activate" not in weekly.lower()
assert "snapshot.model_version -eq" in score
assert "FutScout Thursday Shadow Forecast" in register
assert "FutScout Tuesday Shadow Scorecard" in register
assert "-WindowStyle Hidden" in register and "-PublishSite" in register
assert policy["scope"] == "private_shadow_only"
assert policy["activation_approved"] is False
assert all("field_tilt" not in name and "shots" not in name for name in policy["allowed_severe_features"])
print("Shadow model operation checks passed")
