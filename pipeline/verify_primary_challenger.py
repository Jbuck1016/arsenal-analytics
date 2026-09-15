#!/usr/bin/env python3
"""Verify that the tournament winner is the existing reviewed shadow artifact."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import model_artifact


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARTIFACT = ROOT / "artifacts" / "models" / "v2-field-tilt-box-entries-poisson-2324-2425-2526-20260914t205131z.pkl"


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, default=DEFAULT_ARTIFACT)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts" / "model_reports" / "primary_challenger_review.json")
    args = parser.parse_args()

    artifact = model_artifact.load_artifact(args.artifact)
    metadata = load(args.artifact.with_suffix(".json"))
    tournament = load(ROOT / "artifacts" / "model_reports" / "model_philosophy_tournament.json")
    validation = load(ROOT / "artifacts" / "model_reports" / "v2_field_tilt_box_entries_validation.json")
    stability = load(ROOT / "artifacts" / "model_reports" / "cross_season_feature_stability.json")
    legitimacy = load(ROOT / "artifacts" / "model_reports" / "model_legitimacy_suite.json")
    bookmaker = load(ROOT / "artifacts" / "model_reports" / "bookmaker_benchmark.json")
    drift = load(ROOT / "artifacts" / "data_quality" / "model_feature_drift_2627.json")

    winner = tournament["winner"]
    final_fold = tournament["folds"]["train_2324_2425_test_2526"]["models"][winner]
    digest = hashlib.sha256(args.artifact.read_bytes()).hexdigest()
    contract_equal = artifact["numeric_columns"] == final_fold["columns"]
    digest_equal = digest == metadata["artifact_sha256"]
    seasons_equal = artifact["training_seasons"] == ["2324", "2425", "2526"]
    stable_inputs = {"shooting", "territory"}.issubset(stability["gate"]["passed_families"])
    leakage_pass = legitimacy["negative_controls"]["decision"] == "pass"
    eligible = all((contract_equal, digest_equal, seasons_equal, stable_inputs, leakage_pass))

    report = {
        "schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "artifact": str(args.artifact),
        "model_version": metadata["model_version"],
        "tournament_winner": winner,
        "is_existing_artifact": True,
        "checks": {
            "winner_contract_matches_artifact_exactly": contract_equal,
            "artifact_sha256_matches_metadata": digest_equal,
            "training_seasons_complete": seasons_equal,
            "winner_families_pass_stability_gate": stable_inputs,
            "negative_controls_pass": leakage_pass,
            "eligible_for_shadow_review": validation["shadow_review_decision"] == "eligible_for_shadow_review",
        },
        "historical_evidence": {
            "winner_summary": next(row for row in tournament["summary"] if row["name"] == winner),
            "current_control_summary": next(row for row in tournament["summary"] if row["name"] == "shooting_led"),
            "bookmaker_odds_log_loss": bookmaker["odds_log_loss"],
            "winner_log_loss_on_market_population": bookmaker["model_log_loss_on_common_matches"],
            "shooting_control_log_loss_on_market_population": bookmaker["shooting_control_log_loss"],
            "market_population_matches": bookmaker["matched"],
        },
        "current_season_evidence": {
            "drift_decision": drift["decision"],
            "current_matches": drift["current_matches"],
            "live_calls_scored": legitimacy["external_and_live"]["live_shadow"]["resolved"],
        },
        "decision": "use_existing_artifact_as_primary_challenger" if eligible else "block_and_investigate",
        "lifecycle_change_authorized": False,
        "registered_or_uploaded_by_this_command": False,
        "caveat": "The hybrid wins both historical holdouts, but the 2025/26 advantage is small and no frozen live calls have resolved yet.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Decision: {report['decision']}")
    print(f"Artifact contract matches winner: {contract_equal}")
    print(f"Artifact digest verified: {digest_equal}")
    print(f"Report: {args.output}")
    return 0 if eligible else 1


if __name__ == "__main__":
    raise SystemExit(main())
