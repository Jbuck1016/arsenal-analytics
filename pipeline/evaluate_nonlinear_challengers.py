#!/usr/bin/env python3
"""Test focused nonlinear and interaction challengers on two season holdouts.

Every candidate uses only information available before kickoff.  The report is
local research evidence and cannot change a model lifecycle.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.pipeline import Pipeline

import analyze_match_feature_families as family_tools
import evaluate_model_philosophies as philosophies
import evaluate_multiseason_model as multi
import train_match_baselines as baseline


SEASONS = ("2324", "2425", "2526")
RNG_SEED = 20260914


def nonlinear_goal_metrics(train: pd.DataFrame, test: pd.DataFrame, columns: list[str]) -> dict[str, Any]:
    train_n, test_n = multi.normalize_model_features(train), multi.normalize_model_features(test)
    models = []
    for target in ("home_goals", "away_goals"):
        models.append(Pipeline([
            ("prepare", baseline.preprocessing(columns, ["league"])),
            ("model", HistGradientBoostingRegressor(
                loss="poisson", max_iter=220, learning_rate=0.035,
                max_leaf_nodes=9, min_samples_leaf=40,
                l2_regularization=4.0, random_state=RNG_SEED,
            )),
        ]).fit(train_n, train_n[target]))
    home_xg = np.clip(models[0].predict(test_n), 0.05, 6.0)
    away_xg = np.clip(models[1].predict(test_n), 0.05, 6.0)
    probabilities = baseline.poisson_result_probabilities(home_xg, away_xg)
    metrics = baseline.score(
        test_n["result"].to_numpy(), probabilities,
        test_n["home_goals"].to_numpy(), test_n["away_goals"].to_numpy(),
        home_xg, away_xg,
    )
    return {key: metrics[key] for key in (
        "log_loss", "brier", "accuracy", "calibration_error",
        "home_goals_mae", "away_goals_mae",
    )}


def with_interactions(frame: pd.DataFrame) -> pd.DataFrame:
    result = frame.copy()
    for side in ("team", "opponent"):
        for window in (3, 5, 10):
            tilt = pd.to_numeric(result[f"{side}.field_tilt_pct_{window}"], errors="coerce")
            ppda = pd.to_numeric(result[f"{side}.ppda_{window}"], errors="coerce")
            entries = pd.to_numeric(result[f"{side}.box_entries_pass_{window}"], errors="coerce")
            height = pd.to_numeric(result[f"{side}.defensive_height_{window}"], errors="coerce")
            result[f"{side}.territory_press_intensity_{window}"] = tilt / ppda.replace(0, np.nan)
            result[f"{side}.box_access_height_interaction_{window}"] = entries * height
    return result


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    multi.require_quality_gates(root, list(SEASONS), 1)
    db = baseline.db_client()
    frames = {}
    for season in SEASONS:
        frame = baseline.load_matches(db, season, 1)
        frame["season"] = season
        frames[season] = frame
    combined = pd.concat(frames.values(), ignore_index=True).sort_values(["date", "game_id"]).reset_index(drop=True)
    baseline.add_pre_match_elo(combined)
    numeric = multi.select_features(combined, "all")
    grouped = family_tools.family_columns(numeric)
    core = multi.select_features(combined, "core")
    hybrid = philosophies.selected_columns("shooting_territory", numeric, grouped, core)
    tactical = philosophies.selected_columns("territory_pressing", numeric, grouped, core)
    interaction_frame = with_interactions(combined)
    interaction_columns = sorted(set(hybrid + tactical + [
        column for column in interaction_frame.columns
        if "_interaction_" in column or "territory_press_intensity" in column
    ]))
    folds = (
        ("train_2324_test_2425", ("2324",), "2425"),
        ("train_2324_2425_test_2526", ("2324", "2425"), "2526"),
    )
    report_folds = {}
    for fold_name, training_seasons, test_season in folds:
        train = combined[combined.season.isin(training_seasons)].copy()
        test = combined[combined.season.eq(test_season)].copy()
        train_i = interaction_frame[interaction_frame.season.isin(training_seasons)].copy()
        test_i = interaction_frame[interaction_frame.season.eq(test_season)].copy()
        linear_hybrid, *_ = multi.model_metrics(train, test, hybrid)
        linear_tactical, *_ = multi.model_metrics(train, test, tactical)
        linear_interactions, *_ = multi.model_metrics(train_i, test_i, interaction_columns)
        candidates = {
            "linear_hybrid": philosophies.compact_metrics(linear_hybrid),
            "linear_tactical": philosophies.compact_metrics(linear_tactical),
            "linear_explicit_interactions": philosophies.compact_metrics(linear_interactions),
            "nonlinear_hybrid": nonlinear_goal_metrics(train, test, hybrid),
            "nonlinear_tactical": nonlinear_goal_metrics(train, test, tactical),
        }
        for row in candidates.values():
            row.pop("by_league", None)
            row.pop("matches", None)
        report_folds[fold_name] = {
            "train_seasons": list(training_seasons),
            "test_season": test_season,
            "models": candidates,
        }
        print(f"{fold_name}: " + ", ".join(
            f"{name}={row['log_loss']:.5f}" for name, row in candidates.items()
        ))
    model_names = list(next(iter(report_folds.values()))["models"])
    summary = []
    for name in model_names:
        losses = [fold["models"][name]["log_loss"] for fold in report_folds.values()]
        hybrid_losses = [fold["models"]["linear_hybrid"]["log_loss"] for fold in report_folds.values()]
        summary.append({
            "name": name,
            "mean_log_loss": float(np.mean(losses)),
            "beats_linear_hybrid_both_holdouts": all(a < b for a, b in zip(losses, hybrid_losses)),
            "holdout_log_losses": losses,
        })
    summary.sort(key=lambda row: row["mean_log_loss"])
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "purpose": "Test whether nonlinear tactical interactions generalize beyond the focused linear hybrid.",
        "folds": report_folds,
        "summary": summary,
        "winner": summary[0]["name"],
        "decision": (
            "candidate_for_further_review" if summary[0]["beats_linear_hybrid_both_holdouts"]
            else "retain_linear_hybrid"
        ),
        "guardrail": "Research only; no artifact registration, promotion, activation, or publication.",
    }
    output = root / "artifacts" / "model_reports" / "nonlinear_challenger_tournament.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Decision: {report['decision']} ({report['winner']})")
    print(f"Report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
