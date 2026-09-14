#!/usr/bin/env python3
"""Package the audited schema-v2 challenger locally without publishing it."""

from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path

import model_artifact
import train_match_baselines as baseline


SEASONS = ["2324", "2425", "2526"]
CANDIDATE = "field_tilt_box_entries"


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    report_path = root / "artifacts" / "model_reports" / "v2_feature_candidate_audit.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    summary = report["summary"][CANDIDATE]
    if not summary.get("beats_control_both_holdouts"):
        raise RuntimeError(f"{CANDIDATE} did not beat the control on both holdouts")
    if report.get("feature_schema_version") != 2:
        raise RuntimeError("candidate audit is not for feature schema v2")

    fold_columns = [fold[CANDIDATE]["columns"] for fold in report["folds"].values()]
    if not fold_columns or any(columns != fold_columns[0] for columns in fold_columns[1:]):
        raise RuntimeError("candidate feature contract differs between holdout folds")
    columns = fold_columns[0]
    for season in SEASONS:
        gate_path = root / "artifacts" / "data_quality" / f"model_data_quality_v2_{season}.json"
        gate = json.loads(gate_path.read_text(encoding="utf-8"))
        if not gate.get("release_ready_for_core_v2_experiments"):
            raise RuntimeError(f"{season} failed the schema-v2 quality gate")

    db = baseline.db_client()
    frame = model_artifact.completed_training_frame(db, SEASONS, 2)
    artifact = model_artifact.train_poisson(frame, 2, columns, "v2_field_tilt_box_entries_poisson")
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    version = f"v2-field-tilt-box-entries-poisson-{'-'.join(SEASONS)}-{stamp.lower()}"
    path = root / "artifacts" / "models" / f"{version}.pkl"
    digest = model_artifact.save_artifact(artifact, path)
    metadata = model_artifact.metadata_json(artifact, digest) | {
        "model_version": version,
        "status": "training",
        "registered": False,
        "published": False,
        "candidate_family": CANDIDATE,
        "holdout_audit": str(report_path),
        "holdout_audit_sha256": hashlib.sha256(report_path.read_bytes()).hexdigest(),
        "holdout_mean_log_loss": summary["mean_log_loss"],
        "control_mean_log_loss": report["summary"]["current_compact_control"]["mean_log_loss"],
        "beats_control_both_holdouts": True,
    }
    metadata_path = path.with_suffix(".json")
    metadata_path.write_text(json.dumps(metadata,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(f"Artifact: {path}")
    print(f"Metadata: {metadata_path}")
    print(f"sha256={digest}")
    print(f"Features: {len(columns)}")
    print("Local schema-v2 challenger only; nothing registered, uploaded, promoted, or published")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
