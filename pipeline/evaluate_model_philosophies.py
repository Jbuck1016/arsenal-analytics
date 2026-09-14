#!/usr/bin/env python3
"""Compare genuinely different feature philosophies on season holdouts.

Unlike additive candidate checks, this experiment does not force every model
to inherit shooting features. Every challenger shares only pre-match Elo and
rest context, then receives the football-stat families named in its contract.
It is read-only with respect to Supabase and writes a local review report only.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pandas as pd

import analyze_match_feature_families as families
import evaluate_multiseason_model as multi
import train_match_baselines as baseline


SEASONS = ("2324", "2425", "2526")
PHILOSOPHIES: dict[str, dict[str, Any]] = {
    "strength_context": {
        "label": "Strength + schedule",
        "families": (),
        "idea": "A deliberately simple floor: team strength and rest only.",
    },
    "shooting_led": {
        "label": "Shooting-led",
        "families": ("shooting",),
        "idea": "The current compact control: strength, rest, shots created and shots allowed.",
    },
    "territory_led": {
        "label": "Territory-led",
        "families": ("territory",),
        "idea": "Field tilt and completed box entries replace raw shot volume.",
    },
    "pressing_led": {
        "label": "Pressing-led",
        "families": ("pressing_defense",),
        "idea": "PPDA, defensive actions and defensive height replace raw shot volume.",
    },
    "territory_pressing": {
        "label": "Territory + pressing",
        "families": ("territory", "pressing_defense"),
        "idea": "Control of territory and defensive disruption, with no shooting inputs.",
    },
    "territory_progression": {
        "label": "Territory + progression",
        "families": ("territory", "progression"),
        "idea": "Field tilt and box access combined with progressive passing and directness.",
    },
    "possession_progression": {
        "label": "Possession + progression",
        "families": ("possession", "progression"),
        "idea": "Ball retention and progression, with no shots or territory inputs.",
    },
    "tactical_balanced": {
        "label": "Tactical blend",
        "families": ("territory", "pressing_defense", "progression", "possession"),
        "idea": "A broader tactical identity model that deliberately excludes shots.",
    },
    "all_without_shots": {
        "label": "Everything except shots",
        "families": ("__all_without_shots__",),
        "idea": "Every historically covered input except the shooting family.",
    },
    "all_available": {
        "label": "All available",
        "families": ("__all__",),
        "idea": "Every historically covered input, including shots.",
    },
}


def selected_columns(
    name: str,
    numeric: list[str],
    grouped: dict[str, list[str]],
    core: list[str],
) -> list[str]:
    requested = PHILOSOPHIES[name]["families"]
    if requested == ("__all__",):
        return numeric
    if requested == ("__all_without_shots__",):
        shooting = set(grouped.get("shooting", []))
        return sorted(set(numeric) - shooting)
    return sorted(set(core) | {
        column
        for family in requested
        for column in grouped.get(family, [])
    })


def compact_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    keys = (
        "matches", "log_loss", "brier", "accuracy", "calibration_error",
        "home_goals_mae", "away_goals_mae", "by_league",
    )
    return {key: metrics[key] for key in keys}


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    multi.require_quality_gates(root, list(SEASONS), 1)
    db = baseline.db_client()
    season_frames: dict[str, pd.DataFrame] = {}
    for season in SEASONS:
        frame = baseline.load_matches(db, season, 1)
        frame["season"] = season
        season_frames[season] = frame
    combined = pd.concat(season_frames.values(), ignore_index=True)
    combined = combined.sort_values(["date", "game_id"]).reset_index(drop=True)
    baseline.add_pre_match_elo(combined)

    numeric = multi.select_features(combined, "all")
    grouped = families.family_columns(numeric)
    core = multi.select_features(combined, "core")
    folds = (
        ("train_2324_test_2425", ("2324",), "2425"),
        ("train_2324_2425_test_2526", ("2324", "2425"), "2526"),
    )
    report: dict[str, Any] = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "purpose": "Compare feature philosophies without forcing shooting into every model.",
        "common_features": core,
        "available_families": {name: len(columns) for name, columns in grouped.items()},
        "unavailable_families": {
            "expected_threat": "xT did not meet complete three-season coverage",
            "chance_quality": "npxG did not meet complete three-season coverage",
            "possession_sequences": "sequence features did not meet complete three-season coverage",
        },
        "folds": {},
    }
    for fold_name, train_seasons, test_season in folds:
        train = combined[combined.season.isin(train_seasons)].copy()
        test = combined[combined.season.eq(test_season)].copy()
        fold: dict[str, Any] = {
            "train_seasons": list(train_seasons),
            "test_season": test_season,
            "models": {},
        }
        for name, definition in PHILOSOPHIES.items():
            columns = selected_columns(name, numeric, grouped, core)
            metrics, *_ = multi.model_metrics(train, test, columns)
            fold["models"][name] = {
                "label": definition["label"],
                "idea": definition["idea"],
                "families": list(definition["families"]),
                "column_count": len(columns),
                "columns": columns,
                **compact_metrics(metrics),
            }
            print(f"{fold_name} {name}: log loss={metrics['log_loss']:.5f} ({len(columns)} inputs)")
        report["folds"][fold_name] = fold

    shooting_losses = {
        fold_name: fold["models"]["shooting_led"]["log_loss"]
        for fold_name, fold in report["folds"].items()
    }
    summary = []
    for name, definition in PHILOSOPHIES.items():
        losses = [fold["models"][name]["log_loss"] for fold in report["folds"].values()]
        final = report["folds"]["train_2324_2425_test_2526"]["models"][name]
        summary.append({
            "name": name,
            "label": definition["label"],
            "idea": definition["idea"],
            "families": list(definition["families"]),
            "column_count": final["column_count"],
            "mean_log_loss": sum(losses) / len(losses),
            "final_holdout_log_loss": final["log_loss"],
            "final_holdout_brier": final["brier"],
            "final_holdout_accuracy": final["accuracy"],
            "final_holdout_calibration_error": final["calibration_error"],
            "final_holdout_home_goals_mae": final["home_goals_mae"],
            "final_holdout_away_goals_mae": final["away_goals_mae"],
            "delta_vs_shooting_final": final["log_loss"] - shooting_losses["train_2324_2425_test_2526"],
            "beats_shooting_both_holdouts": all(
                fold["models"][name]["log_loss"] < shooting_losses[fold_name]
                for fold_name, fold in report["folds"].items()
            ) if name != "shooting_led" else False,
        })
    summary.sort(key=lambda row: row["mean_log_loss"])
    for rank, row in enumerate(summary, start=1):
        row["rank"] = rank
    report["summary"] = summary
    report["winner"] = summary[0]["name"]
    report["interpretation_rule"] = (
        "Lower log loss is better. Prefer models that improve both chronological holdouts; "
        "accuracy alone is not a probability-quality metric."
    )
    report["promotion_decision"] = "research_only_no_lifecycle_change"

    output = root / "artifacts" / "model_reports" / "model_philosophy_tournament.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Winner by mean chronological log loss: {summary[0]['label']}")
    print(f"Report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
