#!/usr/bin/env python3
"""Run the read-only model legitimacy and feature-strength suite.

The suite deliberately keeps model lifecycle state untouched. It adds paired
block-bootstrap uncertainty, grouped permutation importance, rolling-window
ablations, architecture challenges, stability/calibration slices, negative
controls, robustness attacks, disagreement/error examples, historical table
simulation backtests, and external/live benchmark readiness.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.metrics import log_loss
from sklearn.pipeline import Pipeline

import analyze_match_feature_families as family_tools
import evaluate_model_philosophies as philosophies
import evaluate_multiseason_model as multi
import simulate_league_table as table_sim
import train_match_baselines as baseline


SEASONS = ("2324", "2425", "2526")
RNG_SEED = 20260914
CORE_FAMILIES = {"team_strength", "availability_context"}


def row_log_losses(labels: np.ndarray, probabilities: np.ndarray) -> np.ndarray:
    actual = np.asarray([baseline.CLASS_ORDER.index(value) for value in labels])
    values = np.clip(np.asarray(probabilities, dtype=float), 1e-9, 1.0)
    values /= values.sum(axis=1, keepdims=True)
    return -np.log(values[np.arange(len(actual)), actual])


def fit_poisson(train: pd.DataFrame, test: pd.DataFrame, columns: list[str]) -> tuple[Any, Any, np.ndarray, np.ndarray, np.ndarray]:
    train_n = multi.normalize_model_features(train)
    test_n = multi.normalize_model_features(test)
    home = baseline.poisson_model(columns).fit(train_n, train_n["home_goals"])
    away = baseline.poisson_model(columns).fit(train_n, train_n["away_goals"])
    home_xg = np.clip(home.predict(test_n), 0.05, 6.0)
    away_xg = np.clip(away.predict(test_n), 0.05, 6.0)
    return home, away, baseline.poisson_result_probabilities(home_xg, away_xg), home_xg, away_xg


def score_predictions(test: pd.DataFrame, probabilities: np.ndarray, home_xg: np.ndarray, away_xg: np.ndarray) -> dict[str, Any]:
    return baseline.score(
        test["result"].to_numpy(), probabilities,
        test["home_goals"].to_numpy(), test["away_goals"].to_numpy(),
        home_xg, away_xg,
    ) | {"matches": int(len(test))}


def block_bootstrap(test: pd.DataFrame, left: np.ndarray, right: np.ndarray, iterations: int) -> dict[str, Any]:
    """Paired resampling by league-week to preserve local match dependence."""
    rng = np.random.default_rng(RNG_SEED)
    left_loss = row_log_losses(test["result"].to_numpy(), left)
    right_loss = row_log_losses(test["result"].to_numpy(), right)
    weeks = test["date"].dt.to_period("W").astype(str)
    block_keys = (test["league"].astype(str) + "|" + weeks).to_numpy()
    unique = np.unique(block_keys)
    blocks = [np.flatnonzero(block_keys == key) for key in unique]
    deltas = np.empty(iterations)
    for iteration in range(iterations):
        sampled = rng.integers(0, len(blocks), size=len(blocks))
        indexes = np.concatenate([blocks[index] for index in sampled])
        deltas[iteration] = float((right_loss[indexes] - left_loss[indexes]).mean())
    low, high = np.quantile(deltas, [0.025, 0.975])
    return {
        "definition": "right minus left log loss; negative favors right",
        "observed_delta": float(right_loss.mean() - left_loss.mean()),
        "ci_95": [float(low), float(high)],
        "probability_right_better": float((deltas < 0).mean()),
        "iterations": iterations,
        "blocks": len(blocks),
        "decision": "right_better" if high < 0 else "left_better" if low > 0 else "effectively_tied",
    }


def family_permutation(
    train: pd.DataFrame,
    test: pd.DataFrame,
    columns: list[str],
    grouped: dict[str, list[str]],
    repeats: int,
) -> dict[str, Any]:
    home, away, probabilities, home_xg, away_xg = fit_poisson(train, test, columns)
    base = score_predictions(test, probabilities, home_xg, away_xg)
    rng = np.random.default_rng(RNG_SEED)
    results = []
    requested = dict(grouped)
    requested["team_strength"] = [column for column in columns if column.startswith("elo_")]
    for family, candidates in requested.items():
        selected = sorted(set(candidates) & set(columns))
        if not selected:
            continue
        losses = []
        for _ in range(repeats):
            attacked = multi.normalize_model_features(test)
            order = rng.permutation(len(attacked))
            attacked.loc[:, selected] = attacked[selected].to_numpy()[order]
            hxg = np.clip(home.predict(attacked), 0.05, 6.0)
            axg = np.clip(away.predict(attacked), 0.05, 6.0)
            prob = baseline.poisson_result_probabilities(hxg, axg)
            losses.append(score_predictions(test, prob, hxg, axg)["log_loss"])
        results.append({
            "family": family,
            "columns": selected,
            "column_count": len(selected),
            "baseline_log_loss": base["log_loss"],
            "permuted_log_loss_mean": float(np.mean(losses)),
            "permuted_log_loss_std": float(np.std(losses)),
            "importance_delta": float(np.mean(losses) - base["log_loss"]),
        })
    results.sort(key=lambda row: row["importance_delta"], reverse=True)
    return {"model": "all_available_poisson", "repeats": repeats, "rows": results}


def window_ablations(train: pd.DataFrame, test: pd.DataFrame, columns: list[str]) -> list[dict[str, Any]]:
    core = [column for column in columns if column.startswith("elo_") or "rest_days" in column]
    rows = []
    contracts = {
        "3-match only": core + [column for column in columns if column.endswith("_3")],
        "5-match only": core + [column for column in columns if column.endswith("_5")],
        "10-match only": core + [column for column in columns if column.endswith("_10")],
        "3 + 5": core + [column for column in columns if column.endswith(("_3", "_5"))],
        "5 + 10": core + [column for column in columns if column.endswith(("_5", "_10"))],
        "3 + 5 + 10": core + [column for column in columns if column.endswith(("_3", "_5", "_10"))],
    }
    for label, selected in contracts.items():
        selected = sorted(set(selected))
        metrics, *_ = multi.model_metrics(train, test, selected)
        rows.append({"label": label, "column_count": len(selected), **{key: metrics[key] for key in ("log_loss", "brier", "accuracy", "calibration_error")}})
    rows.sort(key=lambda row: row["log_loss"])
    return rows


def architecture_challenge(train: pd.DataFrame, test: pd.DataFrame, columns: list[str]) -> list[dict[str, Any]]:
    rows = []
    poisson_metrics, *_ = multi.model_metrics(train, test, columns)
    rows.append({"architecture": "regularized Poisson goals", **{key: poisson_metrics[key] for key in ("log_loss", "brier", "accuracy", "calibration_error", "home_goals_mae", "away_goals_mae")}})
    direct_metrics, *_ = multi.model_metrics(train, test, columns, direct_result=True)
    rows.append({"architecture": "multinomial logistic result", **{key: direct_metrics[key] for key in ("log_loss", "brier", "accuracy", "calibration_error", "home_goals_mae", "away_goals_mae")}})

    train_n, test_n = multi.normalize_model_features(train), multi.normalize_model_features(test)
    classifier = Pipeline([
        ("prepare", baseline.preprocessing(columns, ["league"])),
        ("model", HistGradientBoostingClassifier(max_iter=180, learning_rate=0.05, max_leaf_nodes=15, l2_regularization=2.0, random_state=RNG_SEED)),
    ]).fit(train_n, train_n["result"])
    probabilities = baseline.aligned_probabilities(classifier, test_n)
    _, prior_home, prior_away = baseline.prior_predictions(train, test)
    metrics = score_predictions(test, probabilities, prior_home, prior_away)
    rows.append({"architecture": "gradient-boosted result", **{key: metrics[key] for key in ("log_loss", "brier", "accuracy", "calibration_error", "home_goals_mae", "away_goals_mae")}})

    goal_models = []
    for target in ("home_goals", "away_goals"):
        goal_models.append(Pipeline([
            ("prepare", baseline.preprocessing(columns, ["league"])),
            ("model", HistGradientBoostingRegressor(loss="poisson", max_iter=180, learning_rate=0.05, max_leaf_nodes=15, l2_regularization=2.0, random_state=RNG_SEED)),
        ]).fit(train_n, train_n[target]))
    hxg = np.clip(goal_models[0].predict(test_n), 0.05, 6.0)
    axg = np.clip(goal_models[1].predict(test_n), 0.05, 6.0)
    metrics = score_predictions(test, baseline.poisson_result_probabilities(hxg, axg), hxg, axg)
    rows.append({"architecture": "gradient-boosted Poisson goals", **{key: metrics[key] for key in ("log_loss", "brier", "accuracy", "calibration_error", "home_goals_mae", "away_goals_mae")}})
    rows.sort(key=lambda row: row["log_loss"])
    return rows


def class_calibration(labels: np.ndarray, probabilities: np.ndarray) -> list[dict[str, Any]]:
    actual = np.asarray([baseline.CLASS_ORDER.index(value) for value in labels])
    rows = []
    for class_index, label in enumerate(("home win", "draw", "away win")):
        for low in np.arange(0.0, 1.0, 0.1):
            mask = (probabilities[:, class_index] >= low) & (probabilities[:, class_index] < low + 0.1)
            if mask.any():
                rows.append({
                    "outcome": label, "from": float(low), "to": float(low + 0.1),
                    "matches": int(mask.sum()),
                    "mean_probability": float(probabilities[mask, class_index].mean()),
                    "observed_rate": float((actual[mask] == class_index).mean()),
                })
    return rows


def sliced_metrics(test: pd.DataFrame, probabilities: np.ndarray, hxg: np.ndarray, axg: np.ndarray) -> list[dict[str, Any]]:
    midpoint = test["date"].median()
    definitions = {
        "first half of season": test["date"] <= midpoint,
        "second half of season": test["date"] > midpoint,
        "home favorite": test["elo_diff"] >= 80,
        "balanced matchup": test["elo_diff"].abs() < 80,
        "away favorite": test["elo_diff"] <= -80,
    }
    for league in baseline.TOP_FIVE:
        definitions[league] = test["league"].eq(league)
    rows = []
    for label, mask_series in definitions.items():
        mask = mask_series.to_numpy()
        if not mask.any():
            continue
        metrics = score_predictions(test.loc[mask], probabilities[mask], hxg[mask], axg[mask])
        rows.append({"slice": label, **{key: metrics[key] for key in ("matches", "log_loss", "brier", "accuracy", "calibration_error")}})
    return rows


def negative_controls(train: pd.DataFrame, test: pd.DataFrame, columns: list[str]) -> dict[str, Any]:
    rng = np.random.default_rng(RNG_SEED)
    shuffled = train.copy()
    shuffled["home_goals"] = rng.permutation(shuffled["home_goals"].to_numpy())
    shuffled["away_goals"] = rng.permutation(shuffled["away_goals"].to_numpy())
    shuffled["result"] = rng.permutation(shuffled["result"].to_numpy())
    poiss, *_ = multi.model_metrics(shuffled, test, columns)
    direct, *_ = multi.model_metrics(shuffled, test, columns, direct_result=True)
    suspicious_tokens = ("post_match", "final_score", "result", "goals_for_match", "goals_against_match", "points_after", "table_after")
    suspicious = [column for column in columns if any(token in column.lower() for token in suspicious_tokens)]
    return {
        "shuffled_goal_log_loss": poiss["log_loss"],
        "shuffled_result_log_loss": direct["log_loss"],
        "chance_reference_log_loss": math.log(3.0),
        "suspicious_feature_names": suspicious,
        "feature_timestamp_contract": "target_match_date is the cutoff; every rolling feature is generated from matches strictly before it",
        "decision": "pass" if not suspicious and poiss["log_loss"] > 1.0 and direct["log_loss"] > 1.0 else "investigate",
    }


def robustness_attacks(train: pd.DataFrame, test: pd.DataFrame, columns: list[str], grouped: dict[str, list[str]]) -> list[dict[str, Any]]:
    home, away, probabilities, hxg, axg = fit_poisson(train, test, columns)
    base = score_predictions(test, probabilities, hxg, axg)["log_loss"]
    rng = np.random.default_rng(RNG_SEED)
    rows = []
    for family in ("shooting", "territory", "pressing_defense", "progression", "possession"):
        selected = sorted(set(grouped.get(family, [])) & set(columns))
        if not selected:
            continue
        attacked = multi.normalize_model_features(test)
        attacked.loc[:, selected] = np.nan
        ah = np.clip(home.predict(attacked), 0.05, 6.0)
        aa = np.clip(away.predict(attacked), 0.05, 6.0)
        missing_loss = score_predictions(test, baseline.poisson_result_probabilities(ah, aa), ah, aa)["log_loss"]
        noisy = multi.normalize_model_features(test)
        for column in selected:
            scale = float(pd.to_numeric(train[column], errors="coerce").std() or 0.0)
            noisy[column] = pd.to_numeric(noisy[column], errors="coerce") + rng.normal(0.0, 0.1 * scale, len(noisy))
        nh = np.clip(home.predict(noisy), 0.05, 6.0)
        na = np.clip(away.predict(noisy), 0.05, 6.0)
        noise_loss = score_predictions(test, baseline.poisson_result_probabilities(nh, na), nh, na)["log_loss"]
        rows.append({"family": family, "baseline_log_loss": base, "all_missing_delta": missing_loss - base, "ten_percent_noise_delta": noise_loss - base})
    return rows


def disagreement_examples(test: pd.DataFrame, predictions: dict[str, np.ndarray], limit: int = 20) -> dict[str, Any]:
    stack = np.stack(list(predictions.values()))
    spread = stack.max(axis=0) - stack.min(axis=0)
    disagreement = spread.max(axis=1)
    primary = predictions["shooting_led"]
    losses = row_log_losses(test["result"].to_numpy(), primary)
    predicted = primary.argmax(axis=1)
    actual = np.asarray([baseline.CLASS_ORDER.index(value) for value in test["result"]])

    def pack(index: int) -> dict[str, Any]:
        row = test.iloc[index]
        return {
            "game_id": str(row["game_id"]), "date": str(row["date"].date()), "league": row["league"],
            "home_team": row["home_team"], "away_team": row["away_team"], "score": f"{row['home_goals']}-{row['away_goals']}",
            "actual": row["result"], "shooting_probabilities": primary[index].tolist(),
            "territory_probabilities": predictions["territory_led"][index].tolist(),
            "maximum_philosophy_spread": float(disagreement[index]), "shooting_log_loss": float(losses[index]),
        }

    disagreement_idx = np.argsort(disagreement)[::-1][:limit]
    wrong_idx = np.flatnonzero(predicted != actual)
    wrong_idx = wrong_idx[np.argsort(primary[wrong_idx].max(axis=1))[::-1]][:limit]
    return {"largest_disagreements": [pack(int(index)) for index in disagreement_idx], "high_confidence_errors": [pack(int(index)) for index in wrong_idx]}


def standings_from_matches(matches: pd.DataFrame) -> list[dict[str, Any]]:
    teams = sorted(set(matches["home_team"]) | set(matches["away_team"]))
    table = {team: {"team": team, "played": 0, "wins": 0, "draws": 0, "losses": 0, "goals_for": 0, "goals_against": 0, "points": 0} for team in teams}
    for row in matches.itertuples(index=False):
        table_sim.apply_result(table, row.home_team, row.away_team, int(row.home_goals), int(row.away_goals))
    return list(table.values())


def frozen_fixture_rates(completed: pd.DataFrame, remaining: pd.DataFrame) -> list[dict[str, Any]]:
    league_home = max(0.2, float(completed["home_goals"].mean()))
    league_away = max(0.2, float(completed["away_goals"].mean()))
    scored, allowed, games = defaultdict(float), defaultdict(float), defaultdict(int)
    for row in completed.itertuples(index=False):
        scored[row.home_team] += row.home_goals; allowed[row.home_team] += row.away_goals; games[row.home_team] += 1
        scored[row.away_team] += row.away_goals; allowed[row.away_team] += row.home_goals; games[row.away_team] += 1
    league_goal = (league_home + league_away) / 2
    def rate(team: str, bucket: defaultdict[str, float]) -> float:
        return (bucket[team] + 5 * league_goal) / (games[team] + 5)
    fixtures = []
    for row in remaining.itertuples(index=False):
        home = league_home * (rate(row.home_team, scored) / league_goal) * (rate(row.away_team, allowed) / league_goal)
        away = league_away * (rate(row.away_team, scored) / league_goal) * (rate(row.home_team, allowed) / league_goal)
        fixtures.append({"home_team": row.home_team, "away_team": row.away_team, "expected_home_goals": float(np.clip(home, 0.2, 4.5)), "expected_away_goals": float(np.clip(away, 0.2, 4.5))})
    return fixtures


def table_backtests(frames: dict[str, pd.DataFrame], simulations: int) -> dict[str, Any]:
    rows = []
    for season in ("2425", "2526"):
        frame = frames[season]
        for league in baseline.TOP_FIVE:
            league_frame = frame[frame["league"].eq(league)].sort_values(["date", "game_id"]).reset_index(drop=True)
            if league_frame.empty:
                continue
            final = standings_from_matches(league_frame)
            final_rank = {row["team"]: index for index, row in enumerate(table_sim.ranked_table(table_sim.validate_standings(final), table_sim.LEAGUE_RULES[league]), 1)}
            final_points = {row["team"]: row["points"] for row in final}
            dates = league_frame["date"].drop_duplicates().sort_values().tolist()
            for fraction in (0.25, 0.50, 0.75):
                cutoff = pd.Timestamp(dates[min(len(dates) - 1, max(0, int(len(dates) * fraction) - 1))])
                completed = league_frame[league_frame["date"] <= cutoff]
                remaining = league_frame[league_frame["date"] > cutoff]
                result = table_sim.simulate_league(
                    standings_from_matches(completed), frozen_fixture_rates(completed, remaining),
                    simulations=simulations, seed=RNG_SEED + int(fraction * 100),
                    ranking_keys=table_sim.LEAGUE_RULES[league],
                    completed_results=[{"home_team": r.home_team, "away_team": r.away_team, "home_goals": int(r.home_goals), "away_goals": int(r.away_goals)} for r in completed.itertuples(index=False)],
                    head_to_head=league in table_sim.HEAD_TO_HEAD_LEAGUES,
                    serie_a_playoffs=league == "ITA-Serie A",
                )
                for prediction in result["teams"]:
                    probabilities = prediction["position_probabilities"]
                    actual_position = final_rank[prediction["team"]]
                    ordered = sorted((int(position), probability) for position, probability in probabilities.items())
                    cumulative = 0.0; covered = []
                    for position, probability in sorted(ordered, key=lambda item: item[1], reverse=True):
                        covered.append(position); cumulative += probability
                        if cumulative >= 0.80: break
                    rows.append({
                        "season": season, "league": league, "checkpoint": fraction, "cutoff": str(cutoff.date()), "team": prediction["team"],
                        "actual_position": actual_position, "position_probability": float(probabilities[str(actual_position)]),
                        "inside_80pct_position_set": actual_position in covered,
                        "expected_points": prediction["expected_points"], "actual_points": final_points[prediction["team"]],
                        "absolute_points_error": abs(prediction["expected_points"] - final_points[prediction["team"]]),
                    })
    by_checkpoint = []
    for checkpoint in (0.25, 0.50, 0.75):
        subset = [row for row in rows if row["checkpoint"] == checkpoint]
        by_checkpoint.append({
            "checkpoint": checkpoint, "teams": len(subset),
            "position_80pct_coverage": float(np.mean([row["inside_80pct_position_set"] for row in subset])),
            "mean_absolute_points_error": float(np.mean([row["absolute_points_error"] for row in subset])),
            "mean_actual_position_probability": float(np.mean([row["position_probability"] for row in subset])),
        })
    return {"method": "checkpoint-safe frozen team scoring/conceding rates with five-match shrinkage", "simulations_per_league_checkpoint": simulations, "summary": by_checkpoint, "rows": rows}


def external_live_status(root: Path) -> dict[str, Any]:
    bookmaker = root / "artifacts" / "model_reports" / "bookmaker_benchmark.json"
    shadow_candidates = sorted((root / "artifacts" / "model_reports").glob("shadow*_2627*.json"), key=lambda path: path.stat().st_mtime, reverse=True)
    shadow = json.loads(shadow_candidates[0].read_text(encoding="utf-8")) if shadow_candidates else {}
    bookmaker_report = json.loads(bookmaker.read_text(encoding="utf-8")) if bookmaker.is_file() else {}
    return {
        "bookmaker_benchmark": ({"status": "available", "path": str(bookmaker), **bookmaker_report} if bookmaker_report else {"status": "awaiting_historical_odds", "path": None}),
        "live_shadow": {"status": "available" if shadow_candidates else "awaiting_resolved_frozen_forecasts", "path": str(shadow_candidates[0]) if shadow_candidates else None, "resolved": int(shadow.get("resolved", 0))},
        "policy": "Historical tests establish plausibility; only untouched frozen weekly forecasts establish live legitimacy.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bootstrap-iterations", type=int, default=2000)
    parser.add_argument("--permutation-repeats", type=int, default=12)
    parser.add_argument("--table-simulations", type=int, default=750)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    multi.require_quality_gates(root, list(SEASONS), 1)
    db = baseline.db_client()
    frames = {}
    for season in SEASONS:
        frames[season] = baseline.load_matches(db, season, 1)
        frames[season]["season"] = season
    combined = pd.concat(frames.values(), ignore_index=True).sort_values(["date", "game_id"]).reset_index(drop=True)
    baseline.add_pre_match_elo(combined)
    for season in SEASONS:
        frames[season] = combined[combined["season"].eq(season)].copy()
    numeric = multi.select_features(combined, "all")
    grouped = family_tools.family_columns(numeric)
    core = multi.select_features(combined, "core")
    train, test = combined[combined["season"].isin(("2324", "2425"))].copy(), frames["2526"]

    philosophy_predictions = {}
    philosophy_metrics = {}
    for name in philosophies.PHILOSOPHIES:
        columns = philosophies.selected_columns(name, numeric, grouped, core)
        metrics, probabilities, hxg, axg = multi.model_metrics(train, test, columns)
        philosophy_predictions[name] = probabilities
        philosophy_metrics[name] = {"metrics": philosophies.compact_metrics(metrics), "home_xg": hxg, "away_xg": axg, "columns": columns}
        print(f"philosophy {name}: {metrics['log_loss']:.5f}")

    all_columns = philosophy_metrics["all_available"]["columns"]
    shooting_columns = philosophy_metrics["shooting_led"]["columns"]
    shooting_prob = philosophy_predictions["shooting_led"]
    shooting_hxg = philosophy_metrics["shooting_led"]["home_xg"]
    shooting_axg = philosophy_metrics["shooting_led"]["away_xg"]
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "scope": "three completed top-five-league seasons; final untouched holdout is 2526",
        "readiness": "research_evidence_only_no_lifecycle_change",
        "confidence": {
            "shooting_vs_territory_2526": block_bootstrap(test, shooting_prob, philosophy_predictions["territory_led"], args.bootstrap_iterations),
            "shooting_vs_all_available_2526": block_bootstrap(test, shooting_prob, philosophy_predictions["all_available"], args.bootstrap_iterations),
        },
        "family_permutation": family_permutation(train, test, all_columns, grouped, args.permutation_repeats),
        "rolling_windows": window_ablations(train, test, all_columns),
        "architectures": architecture_challenge(train, test, shooting_columns),
        "stability": sliced_metrics(test, shooting_prob, shooting_hxg, shooting_axg),
        "calibration": class_calibration(test["result"].to_numpy(), shooting_prob),
        "negative_controls": negative_controls(train, test, shooting_columns),
        "robustness": robustness_attacks(train, test, all_columns, grouped),
        "investigation": disagreement_examples(test, philosophy_predictions),
        "table_backtests": table_backtests(frames, args.table_simulations),
        "external_and_live": external_live_status(root),
        "decision_policy": {
            "statistical_ties": "If the paired 95% interval crosses zero, models are treated as tied.",
            "feature_strength": "No family is called important from coefficients alone; held-out grouped permutation and ablation must agree.",
            "activation": "No activation until leakage checks pass and sufficient frozen live forecasts are scored.",
        },
    }
    output = args.output or root / "artifacts" / "model_reports" / "model_legitimacy_suite.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Legitimacy suite: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
