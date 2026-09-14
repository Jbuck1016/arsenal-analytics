#!/usr/bin/env python3
"""Bind an audited schema-v2 artifact to immutable promotion evidence.

This step is local-only. It verifies both chronological holdouts, writes the
small lifecycle report consumed by the registry scripts, and records that
report's digest in the artifact metadata. It never uploads or promotes a model.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path

import model_artifact


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--candidate-audit", type=Path, required=True)
    parser.add_argument("--candidate", default="field_tilt_box_entries")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    artifact = model_artifact.load_artifact(args.artifact)
    if int(artifact.get("feature_schema_version", 0)) != 2:
        raise RuntimeError("lifecycle report requires a schema-v2 artifact")
    audit = json.loads(args.candidate_audit.read_text(encoding="utf-8"))
    if int(audit.get("feature_schema_version", 0)) != 2:
        raise RuntimeError("candidate audit is not schema v2")
    summary = audit.get("summary", {}).get(args.candidate) or {}
    if not summary.get("beats_control_both_holdouts"):
        raise RuntimeError("candidate did not beat the control on both holdouts")

    artifact_digest = hashlib.sha256(args.artifact.read_bytes()).hexdigest()
    metadata_path = args.artifact.with_suffix(".json")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    if metadata.get("artifact_sha256") != artifact_digest:
        raise RuntimeError("artifact digest does not match metadata")
    if metadata.get("candidate_family") != args.candidate:
        raise RuntimeError("artifact and audit candidate families differ")

    folds = {}
    for fold_name, fold in (audit.get("folds") or {}).items():
        candidate_metrics = fold.get(args.candidate)
        control_metrics = fold.get("current_compact_control")
        if not candidate_metrics or not control_metrics:
            raise RuntimeError(f"missing candidate/control metrics for {fold_name}")
        if float(candidate_metrics["log_loss"]) >= float(control_metrics["log_loss"]):
            raise RuntimeError(f"candidate did not improve log loss for {fold_name}")
        folds[fold_name] = {
            "candidate": candidate_metrics,
            "control": control_metrics,
            "log_loss_improvement": round(
                float(control_metrics["log_loss"]) - float(candidate_metrics["log_loss"]), 8
            ),
        }

    report = {
        "report_schema_version": 2,
        "created_at": datetime.now(UTC).isoformat(),
        "model_key": model_artifact.MODEL_KEY,
        "feature_schema_version": 2,
        "candidate_family": args.candidate,
        "artifact": {"path": str(args.artifact.resolve()), "sha256": artifact_digest},
        "source_audit": {
            "path": str(args.candidate_audit.resolve()),
            "sha256": hashlib.sha256(args.candidate_audit.read_bytes()).hexdigest(),
        },
        "folds": folds,
        "mean_log_loss": summary["mean_log_loss"],
        "shadow_review_decision": "eligible_for_shadow_review",
        "decision_basis": (
            "The field-tilt and completed-pass box-entry challenger improved log loss "
            "over the compact control on both chronological out-of-season holdouts."
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report_digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    metadata.update({
        "validation_report": str(args.output.resolve()),
        "validation_report_sha256": report_digest,
        "shadow_review_decision": report["shadow_review_decision"],
    })
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Lifecycle report: {args.output}")
    print(f"Artifact sha256: {artifact_digest}")
    print(f"Validation report sha256: {report_digest}")
    print("Candidate is eligible for explicit training -> validated -> shadow review")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
