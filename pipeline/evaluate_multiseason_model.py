#!/usr/bin/env python3
"""Train on complete earlier seasons and evaluate one untouched later season.

This command is read-only with respect to Supabase. It refuses to run unless
saved data-quality gates mark every requested season release-ready.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from scipy.optimize import minimize_scalar

import train_match_baselines as baseline


METADATA = {"game_id", "date", "league", "season", "home_team", "away_team", "home_goals", "away_goals", "result"}
CORE_TOKENS = ("elo_", "rest_days")
SHOOTING_TOKENS = ("shots_", "shots_against")
MAX_MODEL_REST_DAYS = 30
CALIBRATION_FRACTION = 0.20


def temperature_scale(probabilities: np.ndarray, temperature: float) -> np.ndarray:
    """Apply one multiclass temperature without changing class ordering."""
    values = np.asarray(probabilities, dtype=float)
    if values.ndim != 2 or values.shape[1] != len(baseline.CLASS_ORDER):
        raise ValueError("probabilities must have one column per result class")
    if not np.isfinite(temperature) or temperature <= 0:
        raise ValueError("temperature must be finite and positive")
    logits = np.log(np.clip(values, 1e-12, 1.0)) / temperature
    logits -= logits.max(axis=1, keepdims=True)
    scaled = np.exp(logits)
    return scaled / scaled.sum(axis=1, keepdims=True)


def fit_temperature(probabilities: np.ndarray, actual_labels: np.ndarray) -> float:
    """Fit temperature on a calibration slice that is separate from evaluation."""
    actual = np.array([baseline.CLASS_ORDER.index(label) for label in actual_labels])

    def objective(temperature: float) -> float:
        scaled = temperature_scale(probabilities, temperature)
        return float(-np.log(np.clip(scaled[np.arange(len(actual)), actual], 1e-12, 1.0)).mean())

    result = minimize_scalar(objective, bounds=(0.25, 4.0), method="bounded")
    if not result.success:
        raise RuntimeError("temperature calibration optimization failed")
    return float(result.x)


def normalize_model_features(frame: pd.DataFrame) -> pd.DataFrame:
    """Bound calendar gaps before linear models see them."""
    normalized = frame.copy()
    for column in normalized.columns:
        if column.endswith("rest_days"):
            normalized[column] = pd.to_numeric(
                normalized[column], errors="coerce"
            ).clip(0, MAX_MODEL_REST_DAYS)
    return normalized


def quality_gate_path(root: Path, season: str) -> Path:
    return root / "artifacts" / "data_quality" / f"model_data_quality_{season}.json"


def require_quality_gates(root: Path, seasons: list[str], schema_version: int) -> dict[str, Any]:
    gates: dict[str, Any] = {}
    failures = []
    for season in seasons:
        path = quality_gate_path(root, season)
        if not path.exists():
            failures.append(f"{season}: missing {path}")
            continue
        report = json.loads(path.read_text(encoding="utf-8"))
        gates[season] = report
        if report.get("feature_schema_version") != schema_version:
            failures.append(f"{season}: quality gate is for feature schema {report.get('feature_schema_version')}")
        if not report.get("release_ready"):
            failures.append(f"{season}: quality gate is blocked ({report.get('failed_checks')} failed checks)")
    if failures:
        raise RuntimeError("season quality gate failed:\n- " + "\n- ".join(failures))
    return gates


def select_features(frame: pd.DataFrame, mode: str) -> list[str]:
    numeric = sorted(column for column in frame.columns if column not in METADATA)
    if mode == "all":
        return numeric
    tokens = CORE_TOKENS + (SHOOTING_TOKENS if mode == "core_shooting" else ())
    selected = [column for column in numeric if any(token in column for token in tokens)]
    if not selected:
        raise RuntimeError(f"feature mode {mode!r} selected no columns")
    return selected


def model_metrics(
    train: pd.DataFrame,
    test: pd.DataFrame,
    numeric: list[str],
    direct_result: bool = False,
) -> tuple[dict[str, Any], np.ndarray, np.ndarray, np.ndarray]:
    train = normalize_model_features(train)
    test = normalize_model_features(test)
    if direct_result:
        model = baseline.result_model(numeric).fit(train, train["result"].to_numpy())
        probabilities = baseline.aligned_probabilities(model, test)
        _, home_xg, away_xg = baseline.prior_predictions(train, test)
    else:
        home_model = baseline.poisson_model(numeric).fit(train, train["home_goals"])
        away_model = baseline.poisson_model(numeric).fit(train, train["away_goals"])
        home_xg = np.clip(home_model.predict(test), 0.05, 6.0)
        away_xg = np.clip(away_model.predict(test), 0.05, 6.0)
        probabilities = baseline.poisson_result_probabilities(home_xg, away_xg)
    metrics = baseline.score(
        test["result"].to_numpy(), probabilities,
        test["home_goals"].to_numpy(), test["away_goals"].to_numpy(),
        home_xg, away_xg,
    )
    metrics["matches"] = int(len(test))
    metrics["probability_bands"] = baseline.probability_bands(test["result"].to_numpy(), probabilities)
    metrics["by_league"] = {}
    for league in baseline.TOP_FIVE:
        mask = test["league"].eq(league).to_numpy()
        if not mask.any():
            continue
        metrics["by_league"][league] = baseline.score(
            test.loc[mask, "result"].to_numpy(), probabilities[mask],
            test.loc[mask, "home_goals"].to_numpy(), test.loc[mask, "away_goals"].to_numpy(),
            home_xg[mask], away_xg[mask],
        ) | {"matches": int(mask.sum())}
    return metrics, probabilities, home_xg, away_xg


def temperature_scaled_metrics(
    train: pd.DataFrame,
    test: pd.DataFrame,
    numeric: list[str],
) -> dict[str, Any]:
    """Evaluate a Poisson challenger with a chronological inner calibration set.

    The final holdout is never used to choose the temperature. Base models are
    fitted on the first 80% of training dates to tune temperature on the last
    20%, then refitted on all training rows before the fixed transform is applied
    to the untouched test season.
    """
    dates = pd.DatetimeIndex(train["date"].drop_duplicates().sort_values())
    if len(dates) < 5:
        raise RuntimeError("at least five training dates are required for calibration")
    split = min(len(dates) - 1, max(1, int(len(dates) * (1.0 - CALIBRATION_FRACTION))))
    calibration_start = pd.Timestamp(dates[split])
    fit_rows = train[train["date"] < calibration_start].copy()
    calibration_rows = train[train["date"] >= calibration_start].copy()
    if fit_rows.empty or calibration_rows.empty:
        raise RuntimeError("chronological calibration split produced an empty partition")

    _, calibration_probabilities, _, _ = model_metrics(fit_rows, calibration_rows, numeric)
    temperature = fit_temperature(calibration_probabilities, calibration_rows["result"].to_numpy())
    _, test_probabilities, home_xg, away_xg = model_metrics(train, test, numeric)
    scaled = temperature_scale(test_probabilities, temperature)
    metrics = baseline.score(
        test["result"].to_numpy(), scaled,
        test["home_goals"].to_numpy(), test["away_goals"].to_numpy(),
        home_xg, away_xg,
    )
    metrics = metrics | {
        "matches": int(len(test)),
        "temperature": temperature,
        "calibration_matches": int(len(calibration_rows)),
        "calibration_start": calibration_start.isoformat(),
        "probability_bands": baseline.probability_bands(test["result"].to_numpy(), scaled),
        "by_league": {},
    }
    for league in baseline.TOP_FIVE:
        mask = test["league"].eq(league).to_numpy()
        if mask.any():
            metrics["by_league"][league] = baseline.score(
                test.loc[mask, "result"].to_numpy(), scaled[mask],
                test.loc[mask, "home_goals"].to_numpy(), test.loc[mask, "away_goals"].to_numpy(),
                home_xg[mask], away_xg[mask],
            ) | {"matches": int(mask.sum())}
    return metrics


def evaluate(train: pd.DataFrame, test: pd.DataFrame) -> dict[str, Any]:
    prior_prob, prior_home, prior_away = baseline.prior_predictions(train, test)
    prior = baseline.score(
        test["result"].to_numpy(), prior_prob,
        test["home_goals"].to_numpy(), test["away_goals"].to_numpy(),
        prior_home, prior_away,
    ) | {"matches": int(len(test))}
    core = select_features(pd.concat([train, test], ignore_index=True), "core")
    compact = select_features(pd.concat([train, test], ignore_index=True), "core_shooting")
    all_features = select_features(pd.concat([train, test], ignore_index=True), "all")
    compact_poisson, *_ = model_metrics(train, test, compact)
    calibrated_compact = temperature_scaled_metrics(train, test, compact)
    all_poisson, *_ = model_metrics(train, test, all_features)
    compact_direct, *_ = model_metrics(train, test, compact, direct_result=True)
    return {
        "league_prior": prior,
        "compact_poisson": compact_poisson,
        "compact_poisson_temperature_scaled": calibrated_compact,
        "all_feature_poisson": all_poisson,
        "compact_direct_result": compact_direct,
        "feature_contract": {
            "core_columns": core,
            "compact_columns": compact,
            "all_feature_count": len(all_features),
        },
    }


def markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Multi-season model holdout evaluation",
        "",
        f"Generated: {report['created_at']}",
        "",
        "## Decision",
        "",
        f"Best model: **{report['best_model']}**. Promotion decision: **{report['promotion_decision']}**.",
        "",
        f"Training seasons: {', '.join(report['train_seasons'])}. Untouched test season: {report['test_season']}.",
        "",
        "## Holdout results",
        "",
        "| Model | Log loss | Brier | Accuracy | Home goal MAE | Away goal MAE |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, values in report["models"].items():
        lines.append(
            f"| {name} | {values['log_loss']:.4f} | {values['brier']:.4f} | "
            f"{values['accuracy']:.1%} | {values['home_goals_mae']:.3f} | {values['away_goals_mae']:.3f} |"
        )
    lines.extend([
        "", "## Promotion rule", "",
        "A candidate may move to shadow only if both seasons pass the data-quality gate, it improves holdout log loss over the league prior, no league shows a material regression requiring investigation, and probability-band calibration remains credible. This command never promotes or writes predictions.",
        "", "## Feature contract", "",
        f"The compact candidate contains {len(report['feature_contract']['compact_columns'])} numeric fields: pre-match team-strength/context plus rolling shooting production and prevention. The all-feature model remains a challenger, not the default.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--train-season", action="append", required=True)
    parser.add_argument("--test-season", required=True)
    parser.add_argument("--feature-schema-version", type=int, default=1)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    if args.test_season in args.train_season:
        raise ValueError("test season must not appear in training seasons")

    root = Path(__file__).resolve().parents[1]
    gates = require_quality_gates(root, args.train_season + [args.test_season], args.feature_schema_version)
    db = baseline.db_client()
    frames = []
    for season in args.train_season + [args.test_season]:
        frame = baseline.load_matches(db, season, args.feature_schema_version)
        frame["season"] = season
        frames.append(frame)
    combined = pd.concat(frames, ignore_index=True).sort_values(["date", "game_id"]).reset_index(drop=True)
    baseline.add_pre_match_elo(combined)
    train = combined[combined["season"].isin(args.train_season)].copy()
    test = combined[combined["season"].eq(args.test_season)].copy()
    if train["date"].max() >= test["date"].min():
        raise RuntimeError("training and test seasons overlap or are out of chronological order")

    evaluated = evaluate(train, test)
    models = {key: value for key, value in evaluated.items() if key not in {"feature_contract"}}
    best = min(models, key=lambda name: models[name]["log_loss"])
    improvement = models["league_prior"]["log_loss"] - models[best]["log_loss"]
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "train_seasons": args.train_season,
        "test_season": args.test_season,
        "feature_schema_version": args.feature_schema_version,
        "quality_gate_digests": {
            season: hashlib.sha256(json.dumps(gate, sort_keys=True).encode()).hexdigest()
            for season, gate in gates.items()
        },
        "train_matches": int(len(train)),
        "test_matches": int(len(test)),
        "models": models,
        "feature_contract": evaluated["feature_contract"],
        "best_model": best,
        "holdout_log_loss_improvement_over_prior": improvement,
        "promotion_decision": "eligible_for_shadow_review" if best != "league_prior" and improvement > 0 else "remain_in_training",
    }
    output_dir = args.output_dir or root / "artifacts" / "model_reports"
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    json_path = output_dir / f"multiseason_{'_'.join(args.train_season)}_to_{args.test_season}_{stamp}.json"
    md_path = root / "docs" / "MODEL_MULTISEASON_HOLDOUT.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    md_path.write_text(markdown(report), encoding="utf-8")
    print(f"Best model: {best}; holdout improvement over prior={improvement:+.4f}")
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
