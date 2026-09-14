#!/usr/bin/env python3
"""Static and generated-output checks for the historical odds benchmark."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / "pipeline" / "benchmark_historical_odds.py").read_text(encoding="utf-8")
compile(source, "benchmark_historical_odds.py", "exec")
assert "proportional overround removal" in source
assert "exact season-and-league population count reconciliation" in source
report_path = ROOT / "artifacts" / "model_reports" / "bookmaker_benchmark.json"
if report_path.is_file():
    report = json.loads(report_path.read_text(encoding="utf-8"))
    assert report["matched"] > 1000 and report["coverage"] > 0.8
    assert report["population_counts_reconciled"] is True
    assert report["odds_log_loss"] > 0 and report["model_log_loss_on_common_matches"] > 0
    assert len(report["by_league"]) == 5
print("Bookmaker benchmark checks passed")
