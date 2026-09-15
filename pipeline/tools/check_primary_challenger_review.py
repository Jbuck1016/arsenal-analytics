#!/usr/bin/env python3
"""Regression check for the primary challenger evidence bundle."""
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(ROOT / "pipeline" / "verify_primary_challenger.py")], cwd=ROOT, check=True)
report = json.loads((ROOT / "artifacts" / "model_reports" / "primary_challenger_review.json").read_text(encoding="utf-8"))
assert report["decision"] == "use_existing_artifact_as_primary_challenger"
assert all(report["checks"].values())
assert report["registered_or_uploaded_by_this_command"] is False
assert report["lifecycle_change_authorized"] is False
assert report["historical_evidence"]["market_population_matches"] == 1752
print("Primary challenger review checks passed")
