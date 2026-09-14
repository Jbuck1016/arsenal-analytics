#!/usr/bin/env python3
"""Audit feature-schema v2 coverage without mutating Supabase.

The report distinguishes structural release readiness from feature-family
eligibility.  A missing optional family (notably xG) cannot be silently imputed
into training: the family remains blocked while complete v2 observations and
other independently covered families can continue through evaluation.
"""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import model_artifact
import train_match_baselines as baseline
from historical_source_exceptions import ids_for_season


SCHEMA_VERSION = 2


def rate(rows: list[dict[str, Any]], fields: list[str]) -> float:
    if not rows or not fields:
        return 0.0
    present = sum(row.get(field) is not None for row in rows for field in fields)
    return present / (len(rows) * len(fields))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    manifest = json.loads(
        (root / "pipeline" / "model_feature_schema_v2.json").read_text(encoding="utf-8")
    )
    gates = manifest["coverage_gates"]
    db = baseline.db_client()
    outcomes = baseline.fetch_pages(
        db.table("v_ml_team_match_outcomes")
        .select("game_id,season,league,team,opponent,is_home")
        .eq("season", args.season)
        .eq("is_home", True)
        .in_("league", list(baseline.TOP_FIVE))
        .order("game_id")
    )
    excluded = ids_for_season(args.season)
    game_ids = {str(row["game_id"]) for row in outcomes} - excluded
    columns = (
        "game_id,team,season,league,match_date,observation_schema_version,"
        + ",".join(model_artifact.V2_ROLLING_OBSERVATION_METRICS)
        + ",xg_shot_count,non_penalty_shot_count"
    )
    observations = baseline.fetch_pages(
        db.table("ml_team_match_observations")
        .select(columns)
        .eq("season", args.season)
        .eq("observation_schema_version", SCHEMA_VERSION)
        .in_("league", list(baseline.TOP_FIVE))
        .order("game_id").order("team")
    )
    observations = [row for row in observations if str(row["game_id"]) in game_ids]
    features = baseline.fetch_pages(
        db.table("ml_team_match_features")
        .select("game_id,team,source_match_count,history_cutoff_date,target_match_date,features")
        .eq("feature_schema_version", SCHEMA_VERSION)
        .order("game_id").order("team")
    )
    features = [row for row in features if str(row["game_id"]) in game_ids]

    expected_sides = len(game_ids) * int(gates["required_observation_sides_per_match"])
    observation_keys = [(str(row["game_id"]), str(row["team"])) for row in observations]
    feature_keys = [(str(row["game_id"]), str(row["team"])) for row in features]
    leakage = [
        row for row in features
        if not (
            int(row["source_match_count"]) == 0 and row.get("history_cutoff_date") is None
            or int(row["source_match_count"]) > 0
            and row.get("history_cutoff_date") is not None
            and str(row["history_cutoff_date"]) < str(row["target_match_date"])
        )
    ]

    family_observation_fields = {
        "territory": [
            "field_tilt_pct", "final_third_touches", "final_third_touches_against",
            "penalty_area_touches", "penalty_area_touches_against", "box_entries_pass",
        ],
        "threat": [
            "xt_created", "xt_conceded", "xt_difference",
            "open_play_xt_created", "open_play_xt_conceded", "open_play_xt_difference",
        ],
        "possession_sequences": [
            "sequence_count", "sequence_count_against", "shot_ending_sequences",
            "shot_ending_sequences_against", "box_entry_sequences",
            "box_entry_sequences_against", "progressive_sequences",
            "progressive_sequences_against",
        ],
        "chance_quality": [
            "npxg_for", "npxg_against", "npxg_difference",
            "set_piece_xg_for", "set_piece_xg_against",
        ],
    }
    family_coverage = {
        family: {
            "fields": fields,
            "non_null_rate": rate(observations, fields),
        }
        for family, fields in family_observation_fields.items()
    }
    for family, result in family_coverage.items():
        threshold = (
            gates["required_sequence_match_coverage"]
            if family in {"threat", "possession_sequences"}
            else gates["required_non_null_rate"]
        )
        result["required_rate"] = threshold
        result["eligible"] = result["non_null_rate"] >= threshold

    reconciled = [
        row for row in observations
        if row.get("xg_shot_count") == row.get("non_penalty_shot_count")
    ]
    xg_reconciliation_rate = len(reconciled) / len(observations) if observations else 0.0
    family_coverage["chance_quality"]["xg_shot_reconciliation_rate"] = xg_reconciliation_rate
    family_coverage["chance_quality"]["eligible"] = bool(
        family_coverage["chance_quality"]["eligible"]
        and xg_reconciliation_rate >= gates["required_xg_shot_reconciliation_rate"]
    )

    structural = {
        "completed_matches": len(game_ids),
        "expected_observation_rows": expected_sides,
        "observation_rows": len(observations),
        "feature_rows": len(features),
        "duplicate_observation_rows": len(observation_keys) - len(set(observation_keys)),
        "duplicate_feature_rows": len(feature_keys) - len(set(feature_keys)),
        "leakage_violations": len(leakage),
    }
    structural_ready = bool(
        len(observations) == expected_sides
        and len(features) == expected_sides
        and structural["duplicate_observation_rows"] == 0
        and structural["duplicate_feature_rows"] == gates["required_duplicate_feature_rows"]
        and structural["leakage_violations"] == gates["required_leakage_violations"]
    )
    report = {
        "created_at": datetime.now(UTC).isoformat(),
        "season": args.season,
        "schema_version": SCHEMA_VERSION,
        "structural": structural,
        "structural_ready": structural_ready,
        "family_coverage": family_coverage,
        "release_ready_for_core_v2_experiments": bool(
            structural_ready
            and family_coverage["territory"]["eligible"]
        ),
        "eligible_optional_families": sorted(
            family for family, result in family_coverage.items() if result["eligible"]
        ),
        "blocked_optional_families": sorted(
            family for family, result in family_coverage.items() if not result["eligible"]
        ),
    }
    output = args.output or root / "artifacts" / "data_quality" / f"model_data_quality_v2_{args.season}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    print(f"Report: {output}")
    return 0 if report["release_ready_for_core_v2_experiments"] else 3


if __name__ == "__main__":
    raise SystemExit(main())
