#!/usr/bin/env python3
"""Summarize local evidence freshness for the model operations loop."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path


def age_hours(path: Path, now: datetime) -> float | None:
    if not path.is_file():
        return None
    return (now - datetime.fromtimestamp(path.stat().st_mtime, UTC)).total_seconds() / 3600


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    now = datetime.now(UTC)
    paths = {
        "fixture_provider_snapshot": root / "artifacts" / "fixtures" / "2627_football_data.json",
        "fixture_provider_audit": root / "artifacts" / "fixtures" / "2627_football_data_current_audit.json",
        "live_ingestion_health": root / "artifacts" / "data_quality" / "live_ingestion_health.json",
        "current_feature_quality": root / "artifacts" / "data_quality" / "model_data_quality_v2_2627.json",
        "current_feature_drift": root / "artifacts" / "data_quality" / "model_feature_drift_2627.json",
    }
    evidence = {
        name: {
            "path": str(path),
            "exists": path.is_file(),
            "age_hours": age_hours(path, now),
        }
        for name, path in paths.items()
    }
    max_age = max((row["age_hours"] for row in evidence.values() if row["age_hours"] is not None), default=float("inf"))
    report = {
        "report_schema_version": 1,
        "created_at": now.isoformat(),
        "evidence": evidence,
        "local_evidence_complete": all(row["exists"] for row in evidence.values()),
        "fresh_within_24_hours": max_age <= 24,
        "oldest_evidence_age_hours": max_age,
        "decision": "ready_for_live_refresh" if all(row["exists"] for row in evidence.values()) else "missing_required_evidence",
        "live_verification": "pending_current_supabase_read",
    }
    output = root / "artifacts" / "data_quality" / "model_operations_freshness.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Local evidence complete: {report['local_evidence_complete']}")
    print(f"Fresh within 24 hours: {report['fresh_within_24_hours']}")
    print(f"Report: {output}")
    return 0 if report["local_evidence_complete"] else 3


if __name__ == "__main__":
    raise SystemExit(main())
