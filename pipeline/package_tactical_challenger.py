#!/usr/bin/env python3
"""Package the reviewed territory-plus-pressing challenger locally.

This is deliberately a research-only operation.  It verifies the exact
two-holdout contract saved by the philosophy tournament, refits that contract
on all release-ready seasons, and writes a private artifact and sidecar.  It
never registers, uploads, promotes, activates, or publishes a model.
"""

from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path

import model_artifact
import train_match_baselines as baseline


SEASONS = ["2324", "2425", "2526"]
CANDIDATE = "territory_pressing"


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    report_path = root / "artifacts" / "model_reports" / "model_philosophy_tournament.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report_digest = hashlib.sha256(report_path.read_bytes()).hexdigest()
    existing_sidecars = sorted(
        (root / "artifacts" / "models").glob(
            "territory-pressing-poisson-2324-2425-2526-*.json"
        ),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    for sidecar_path in existing_sidecars:
        existing = json.loads(sidecar_path.read_text(encoding="utf-8"))
        artifact_path = sidecar_path.with_suffix(".pkl")
        if (
            artifact_path.is_file()
            and existing.get("holdout_audit_sha256") == report_digest
            and hashlib.sha256(artifact_path.read_bytes()).hexdigest() == existing.get("artifact_sha256")
        ):
            print(f"Reusing reviewed tactical artifact: {artifact_path}")
            print("No duplicate artifact created and no lifecycle or remote write occurred")
            return 0
    fold_models = [fold["models"][CANDIDATE] for fold in report["folds"].values()]
    columns = fold_models[0]["columns"]
    if any(model["columns"] != columns for model in fold_models[1:]):
        raise RuntimeError("territory-plus-pressing feature contract changes between holdouts")
    if any("shots" in column for column in columns):
        raise RuntimeError("tactical challenger unexpectedly contains shooting inputs")
    if not all(token in {family for model in fold_models for family in model["families"]}
               for token in ("territory", "pressing_defense")):
        raise RuntimeError("tactical challenger is missing a required feature family")

    model_artifact.multiseason.require_quality_gates(root, SEASONS, 1)
    frame = model_artifact.completed_training_frame(baseline.db_client(), SEASONS, 1)
    artifact = model_artifact.train_poisson(
        frame, 1, columns, "territory_pressing_poisson"
    )
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ").lower()
    version = f"territory-pressing-poisson-{'-'.join(SEASONS)}-{stamp}"
    path = root / "artifacts" / "models" / f"{version}.pkl"
    digest = model_artifact.save_artifact(artifact, path)
    summary = next(row for row in report["summary"] if row["name"] == CANDIDATE)
    metadata = model_artifact.metadata_json(artifact, digest) | {
        "model_version": version,
        "status": "research",
        "registered": False,
        "published": False,
        "candidate_family": CANDIDATE,
        "feature_philosophy": "territory_and_pressing_without_shots",
        "holdout_audit": str(report_path),
        "holdout_audit_sha256": report_digest,
        "holdout_mean_log_loss": summary["mean_log_loss"],
        "final_holdout_log_loss": summary["final_holdout_log_loss"],
        "beats_shooting_both_holdouts": summary["beats_shooting_both_holdouts"],
        "lifecycle_change_authorized": False,
    }
    metadata_path = path.with_suffix(".json")
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Artifact: {path}")
    print(f"Metadata: {metadata_path}")
    print(f"Features: {len(columns)} (shots excluded)")
    print("Research-only tactical challenger; no lifecycle or remote write occurred")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
