#!/usr/bin/env python3
"""Audit immutable frozen-slate scoring without changing Supabase."""

from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path

import score_prediction_history as history
import score_prediction_snapshot as scoring


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    snapshots = sorted((root / "artifacts" / "predictions").glob("2627_thursday_frozen_*.json"))
    payloads = [json.loads(path.read_text(encoding="utf-8")) for path in snapshots]
    checks = {
        "at_least_one_frozen_snapshot": bool(payloads),
        "all_snapshots_are_thursday_frozen": all(p.get("forecast_kind") == "thursday_frozen" for p in payloads),
        "all_have_valid_evaluation_horizon": all(
            scoring.evaluation_predictions(payload)[1] for payload in payloads
        ),
        "all_have_probabilities": all(
            all(key in row for key in ("home_win_probability", "draw_probability", "away_win_probability"))
            for payload in payloads for row in payload.get("predictions", [])
        ),
    }
    eligible_counts = []
    for payload in payloads:
        eligible, _ = scoring.evaluation_predictions(payload)
        eligible_counts.append(len(eligible))
    chosen, repeats = history.combine_snapshots(payloads) if payloads else ([], 0)
    checks["earliest_forecast_deduplication"] = len(chosen) + repeats == sum(eligible_counts)
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "checks": checks,
        "ready": all(checks.values()),
        "snapshot_count": len(snapshots),
        "evaluation_eligible_calls": sum(eligible_counts),
        "unique_calls_after_earliest_policy": len(chosen),
        "duplicate_calls_ignored": repeats,
        "legacy_seven_day_horizon_fallbacks": sum(
            not bool(payload.get("evaluation_through")) for payload in payloads
        ),
        "snapshots": [
            {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            for path in snapshots
        ],
        "live_resolution_status": "requires_current_result_read",
        "policy": "Score the earliest eligible immutable Thursday call per fixture; never overwrite it with a later forecast.",
    }
    output = root / "artifacts" / "model_reports" / "shadow_scoring_readiness.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Frozen scoring pipeline ready: {report['ready']}")
    print(f"Unique eligible calls: {len(chosen)}")
    print(f"Report: {output}")
    return 0 if report["ready"] else 3


if __name__ == "__main__":
    raise SystemExit(main())
