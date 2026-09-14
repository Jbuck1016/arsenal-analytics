#!/usr/bin/env python3
"""Register the exact evaluated three-season artifact as a training candidate.

Dry-run is the default. Even with ``--execute``, this command only creates a
private Storage object and a ``training`` registry row; it never validates,
promotes, scores fixtures, or publishes forecasts.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import model_artifact
import train_match_baselines as baseline


def load_evidence(artifact_path: Path, report_path: Path) -> tuple[dict, dict, str, str]:
    artifact = model_artifact.load_artifact(artifact_path)
    metadata_path = artifact_path.with_suffix(".json")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    report_bytes = report_path.read_bytes()
    report = json.loads(report_bytes)
    artifact_digest = hashlib.sha256(artifact_path.read_bytes()).hexdigest()
    report_digest = hashlib.sha256(report_bytes).hexdigest()
    if metadata.get("artifact_sha256") != artifact_digest:
        raise RuntimeError("artifact digest does not match its metadata")
    if report.get("artifact", {}).get("sha256") != artifact_digest:
        raise RuntimeError("validation report does not identify this artifact")
    if metadata.get("validation_report_sha256") != report_digest:
        raise RuntimeError("validation report digest does not match artifact metadata")
    if sorted(artifact.get("training_seasons", [])) != ["2324", "2425", "2526"]:
        raise RuntimeError("registration requires the final three-season artifact")
    if report.get("shadow_review_decision") != "eligible_for_shadow_review":
        raise RuntimeError("validation report did not make the candidate eligible for shadow review")
    if metadata.get("status") != "training":
        raise RuntimeError("local candidate metadata must remain training")
    return artifact, report, artifact_digest, report_digest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--validation-report", type=Path, required=True)
    parser.add_argument("--bucket", default="ml-model-artifacts")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()

    artifact, report, artifact_digest, report_digest = load_evidence(args.artifact, args.validation_report)
    version = args.artifact.stem
    object_path = f"{model_artifact.MODEL_KEY}/{version}.pkl"
    print(f"Verified exact evaluated artifact sha256={artifact_digest}")
    print(f"Verified validation report sha256={report_digest}")
    print(f"Registration plan: version={version} status=training execute={args.execute}")
    if not args.execute:
        print("Dry run only; no Storage object or registry row written")
        return 0

    db = baseline.db_client()
    existing = db.table("ml_model_runs").select("id,model_version,status,artifact_sha256").eq("model_key", model_artifact.MODEL_KEY).eq("model_version", version).execute().data or []
    if existing:
        row = existing[0]
        if row.get("status") != "training" or row.get("artifact_sha256") != artifact_digest:
            raise RuntimeError("model version already exists with different status or digest")
        print(f"Already registered safely as training id={row['id']}")
        return 0

    buckets = db.storage.list_buckets()
    if not any(bucket.name == args.bucket for bucket in buckets):
        db.storage.create_bucket(args.bucket, options={"public": False, "file_size_limit": 25 * 1024 * 1024})
    try:
        db.storage.from_(args.bucket).upload(
            object_path, args.artifact.read_bytes(),
            {"content-type": "application/octet-stream", "upsert": "false"},
        )
    except Exception as exc:
        if "already exists" not in str(exc).lower() and "duplicate" not in str(exc).lower():
            raise

    row = {
        "model_key": model_artifact.MODEL_KEY,
        "model_version": version,
        "status": "training",
        "algorithm": artifact["algorithm"],
        "feature_schema_version": artifact["feature_schema_version"],
        "trained_through": artifact["trained_through"],
        "hyperparameters": {
            "class_order": artifact["class_order"],
            "numeric_columns": artifact["numeric_columns"],
            "training_seasons": artifact["training_seasons"],
        },
        "metrics": {
            "training_matches": artifact["training_match_count"],
            "validation_report_sha256": report_digest,
            "shadow_review_decision": report["shadow_review_decision"],
            "folds": report["folds"],
        },
        "artifact_bucket": args.bucket,
        "artifact_path": object_path,
        "artifact_sha256": artifact_digest,
        "notes": "Exact three-season artifact linked to two chronological holdouts; training only, never auto-promote.",
    }
    created = db.table("ml_model_runs").insert(row).execute().data or []
    if len(created) != 1:
        raise RuntimeError("model registry insert did not return exactly one row")
    print(f"Registered exact training candidate id={created[0]['id']} at {args.bucket}/{object_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
