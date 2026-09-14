#!/usr/bin/env python3
"""Read-only feature-drift audit for the current domestic match model.

The audit compares the current season with completed training seasons using
only the compact candidate's pre-match feature contract. It never writes to
Supabase or changes a model lifecycle state.
"""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

import evaluate_multiseason_model as multi
import model_artifact
import train_match_baselines as baseline


ROOT = Path(__file__).resolve().parents[1]
MIN_CURRENT_MATCHES = 100
MIN_CURRENT_PER_LEAGUE = 10


def population_stability_index(reference: pd.Series, current: pd.Series) -> float | None:
    ref = pd.to_numeric(reference, errors="coerce").dropna().to_numpy(dtype=float)
    cur = pd.to_numeric(current, errors="coerce").dropna().to_numpy(dtype=float)
    if len(ref) < 20 or len(cur) < 10:
        return None
    boundaries = np.unique(np.quantile(ref, np.linspace(0, 1, 11)))
    if len(boundaries) < 3:
        return None
    bins = np.concatenate(([-np.inf], boundaries[1:-1], [np.inf]))
    ref_counts = np.histogram(ref, bins=bins)[0].astype(float)
    cur_counts = np.histogram(cur, bins=bins)[0].astype(float)
    epsilon = 1e-6
    ref_share = np.clip(ref_counts / ref_counts.sum(), epsilon, None)
    cur_share = np.clip(cur_counts / cur_counts.sum(), epsilon, None)
    return float(np.sum((cur_share - ref_share) * np.log(cur_share / ref_share)))


def feature_drift(reference: pd.Series, current: pd.Series) -> dict[str, Any]:
    ref = pd.to_numeric(reference, errors="coerce")
    cur = pd.to_numeric(current, errors="coerce")
    ref_valid = ref.dropna()
    cur_valid = cur.dropna()
    ref_std = float(ref_valid.std(ddof=0)) if len(ref_valid) else 0.0
    mean_shift = (
        float((cur_valid.mean() - ref_valid.mean()) / ref_std)
        if len(ref_valid) and len(cur_valid) and ref_std > 1e-12 else None
    )
    psi = population_stability_index(ref, cur)
    missing_change = float(cur.isna().mean() - ref.isna().mean())
    severe = (
        (psi is not None and psi > 0.25)
        or (mean_shift is not None and abs(mean_shift) > 1.0)
        or abs(missing_change) > 0.20
    )
    moderate = severe or (
        (psi is not None and psi > 0.10)
        or (mean_shift is not None and abs(mean_shift) > 0.50)
        or abs(missing_change) > 0.10
    )
    return {
        "reference_non_null": int(len(ref_valid)),
        "current_non_null": int(len(cur_valid)),
        "reference_mean": float(ref_valid.mean()) if len(ref_valid) else None,
        "current_mean": float(cur_valid.mean()) if len(cur_valid) else None,
        "standardized_mean_shift": mean_shift,
        "population_stability_index": psi,
        "missing_rate_change": missing_change,
        "severity": "severe" if severe else "moderate" if moderate else "stable",
    }


def phase_matched_reference(reference: pd.DataFrame, current: pd.DataFrame) -> pd.DataFrame:
    """Match each reference season/league to the current completed-match count."""
    parts = []
    for league in baseline.TOP_FIVE:
        current_count = int(current["league"].eq(league).sum())
        if current_count == 0:
            continue
        for season in sorted(reference["season"].unique()):
            sample = reference[
                reference["league"].eq(league) & reference["season"].eq(season)
            ].sort_values(["date", "game_id"]).head(current_count)
            parts.append(sample)
    if not parts:
        return reference.iloc[0:0].copy()
    return pd.concat(parts, ignore_index=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-season", action="append", choices=("2425", "2526"))
    parser.add_argument("--current-season", default="2627")
    parser.add_argument("--feature-schema-version", type=int, default=1)
    parser.add_argument(
        "--artifact", type=Path,
        help="Use the exact numeric feature contract and schema embedded in a model artifact.",
    )
    parser.add_argument(
        "--output", type=Path,
        default=ROOT / "artifacts" / "data_quality" / "model_feature_drift_2627.json",
    )
    args = parser.parse_args()
    reference_seasons = args.reference_season or ["2425", "2526"]
    artifact_payload = None
    if args.artifact:
        artifact_payload = model_artifact.load_artifact(args.artifact)
        feature_schema_version = int(artifact_payload["feature_schema_version"])
        feature_contract = list(artifact_payload["numeric_columns"])
    else:
        feature_schema_version = args.feature_schema_version
        feature_contract = None
    db = baseline.db_client()
    reference_parts = []
    for season in reference_seasons:
        frame = baseline.load_matches(db, season, feature_schema_version)
        frame["season"] = season
        reference_parts.append(frame)
    reference = pd.concat(reference_parts, ignore_index=True)
    current = baseline.load_matches(db, args.current_season, feature_schema_version)
    current["season"] = args.current_season
    chronological = pd.concat([reference, current], ignore_index=True).sort_values(["date", "game_id"])
    baseline.add_pre_match_elo(chronological)
    reference = chronological[chronological["season"].isin(reference_seasons)].copy()
    current = chronological[chronological["season"].eq(args.current_season)].copy()
    phase_reference = phase_matched_reference(reference, current)
    if phase_reference.empty:
        raise RuntimeError("no phase-matched reference rows for current league coverage")
    phase_reference = multi.normalize_model_features(phase_reference)
    current_model = multi.normalize_model_features(current)
    contract_frame = pd.concat([phase_reference, current_model], ignore_index=True)
    features = feature_contract or multi.select_features(contract_frame, "core_shooting")
    missing_features = sorted(set(features) - set(contract_frame.columns))
    if missing_features:
        raise RuntimeError(f"artifact feature contract is unavailable: {missing_features}")
    metrics = {name: feature_drift(phase_reference[name], current_model[name]) for name in features}
    current_by_league = {
        league: int(current["league"].eq(league).sum()) for league in baseline.TOP_FIVE
    }
    sample_ready = len(current) >= MIN_CURRENT_MATCHES and all(
        value >= MIN_CURRENT_PER_LEAGUE for value in current_by_league.values()
    )
    severe = sorted(name for name, value in metrics.items() if value["severity"] == "severe")
    moderate = sorted(name for name, value in metrics.items() if value["severity"] == "moderate")
    if not sample_ready:
        decision = "insufficient_current_sample"
    elif severe:
        decision = "block_and_investigate"
    elif moderate:
        decision = "review_before_forecasting"
    else:
        decision = "no_material_drift_detected"
    report = {
        "report_schema_version": 1,
        "checked_at": datetime.now(UTC).isoformat(),
        "read_only": True,
        "reference_seasons": reference_seasons,
        "current_season": args.current_season,
        "feature_schema_version": feature_schema_version,
        "feature_contract": (
            artifact_payload["algorithm"] if artifact_payload else "core_shooting"
        ),
        "full_reference_matches": int(len(reference)),
        "phase_matched_reference_matches": int(len(phase_reference)),
        "current_matches": int(len(current)),
        "current_matches_by_league": current_by_league,
        "minimum_current_matches": MIN_CURRENT_MATCHES,
        "minimum_current_matches_per_league": MIN_CURRENT_PER_LEAGUE,
        "sample_ready": sample_ready,
        "decision": decision,
        "severe_features": severe,
        "moderate_features": moderate,
        "features": metrics,
        "thresholds": {
            "moderate_psi": 0.10,
            "severe_psi": 0.25,
            "moderate_absolute_standardized_mean_shift": 0.50,
            "severe_absolute_standardized_mean_shift": 1.0,
            "moderate_absolute_missing_rate_change": 0.10,
            "severe_absolute_missing_rate_change": 0.20,
        },
        "interpretation": (
            "Drift is a diagnostic, not proof of model failure. A decision other than "
            "no_material_drift_detected requires human review and never auto-promotes a model."
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Feature drift: decision={decision} phase_reference={len(phase_reference)} current={len(current)} "
        f"severe={len(severe)} moderate={len(moderate)}"
    )
    print("Current matches by league: " + ", ".join(f"{key}={value}" for key, value in current_by_league.items()))
    print(f"Report: {args.output}")
    print("No Supabase rows or model states were changed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
