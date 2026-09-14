#!/usr/bin/env python3
"""Contract checks for the model legitimacy suite."""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / "pipeline" / "evaluate_model_legitimacy.py").read_text(encoding="utf-8")
compile(source, "evaluate_model_legitimacy.py", "exec")
for marker in (
    "block_bootstrap", "family_permutation", "window_ablations",
    "architecture_challenge", "negative_controls", "robustness_attacks",
    "disagreement_examples", "table_backtests", "external_live_status",
):
    assert f"def {marker}" in source
assert "research_evidence_only_no_lifecycle_change" in source

report_path = ROOT / "artifacts" / "model_reports" / "model_legitimacy_suite.json"
if report_path.is_file():
    report = json.loads(report_path.read_text(encoding="utf-8"))
    assert report["readiness"] == "research_evidence_only_no_lifecycle_change"
    assert report["confidence"]["shooting_vs_territory_2526"]["iterations"] >= 500
    assert report["family_permutation"]["rows"]
    assert len(report["rolling_windows"]) >= 6
    assert len(report["architectures"]) >= 4
    assert report["calibration"] and report["stability"]
    assert report["negative_controls"]["decision"] in {"pass", "investigate"}
    assert report["table_backtests"]["summary"]
print("Model legitimacy suite checks passed")
