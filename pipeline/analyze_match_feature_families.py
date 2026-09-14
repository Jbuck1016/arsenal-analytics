#!/usr/bin/env python3
"""Walk-forward feature-family ablations for the domestic Poisson baseline.

This is an offline, read-only experiment. It never registers or promotes a
model and never writes predictions to Supabase.
"""

from __future__ import annotations

import argparse
import itertools
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

import train_match_baselines as baseline


FAMILY_TOKENS: dict[str, tuple[str, ...]] = {
    "team_strength": ("elo_",),
    "results_form": ("points_per_match",),
    "goals_form": ("goals_for", "goals_against"),
    "shooting": ("shots_", "shots_against"),
    "possession": ("pass_completion", "possession_proxy"),
    "territory": (
        "field_tilt", "box_entries_pass", "final_third_touch", "penalty_area_touch",
    ),
    "expected_threat": ("xt_created", "xt_conceded", "xt_difference"),
    "chance_quality": ("npxg_", "set_piece_xg_"),
    "possession_sequences": (
        "sequence_count", "shot_ending_sequences", "box_entry_sequences",
        "progressive_sequences",
    ),
    "progression": ("progressive_passes", "directness", "successful_takeons"),
    "pressing_defense": ("ppda", "defensive_actions", "defensive_height"),
    "availability_context": (
        "rest_days", "matches_last_14_days", "matches_last_21_days",
        "prior_matches", "source_match_count",
    ),
}


def family_columns(columns: list[str]) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    claimed: set[str] = set()
    for family, tokens in FAMILY_TOKENS.items():
        selected = sorted(column for column in columns if any(token in column for token in tokens))
        result[family] = selected
        claimed.update(selected)
    unclaimed = sorted(set(columns) - claimed)
    if unclaimed:
        result["other"] = unclaimed
    return result


def evaluate_poisson(frame: pd.DataFrame, numeric: list[str], folds: list[tuple[np.ndarray, np.ndarray]]) -> dict[str, Any]:
    fold_metrics: list[dict[str, Any]] = []
    oof: list[dict[str, Any]] = []
    for number, (train_idx, test_idx) in enumerate(folds, start=1):
        train = frame.iloc[train_idx]
        test = frame.iloc[test_idx]
        home_model = baseline.poisson_model(numeric).fit(train, train["home_goals"])
        away_model = baseline.poisson_model(numeric).fit(train, train["away_goals"])
        home_rate = np.clip(home_model.predict(test), 0.05, 6.0)
        away_rate = np.clip(away_model.predict(test), 0.05, 6.0)
        probabilities = baseline.poisson_result_probabilities(home_rate, away_rate)
        metrics = baseline.score(
            test["result"].to_numpy(), probabilities,
            test["home_goals"].to_numpy(), test["away_goals"].to_numpy(),
            home_rate, away_rate,
        )
        fold_metrics.append({
            "fold": number,
            "train_through": str(train["date"].max().date()),
            "test_from": str(test["date"].min().date()),
            "test_through": str(test["date"].max().date()),
            **metrics,
        })
        for index, (_, row) in enumerate(test.iterrows()):
            oof.append({
                "date": row["date"], "league": row["league"], "result": row["result"],
                "home_goals": row["home_goals"], "away_goals": row["away_goals"],
                "probabilities": probabilities[index],
                "home_xg": home_rate[index], "away_xg": away_rate[index],
            })

    overall = score_rows(oof)
    by_league = {
        league: score_rows([row for row in oof if row["league"] == league])
        for league in baseline.TOP_FIVE
    }
    return {
        "columns": numeric,
        "column_count": len(numeric),
        "overall": overall,
        "folds": fold_metrics,
        "by_league": by_league,
        "probability_bands": baseline.probability_bands(
            np.asarray([row["result"] for row in oof]),
            np.asarray([row["probabilities"] for row in oof]),
        ),
        "premier_league_diagnostic": premier_league_diagnostic(oof),
    }


def score_rows(rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        return {"matches": 0}
    return baseline.score(
        np.asarray([row["result"] for row in rows]),
        np.asarray([row["probabilities"] for row in rows]),
        np.asarray([row["home_goals"] for row in rows]),
        np.asarray([row["away_goals"] for row in rows]),
        np.asarray([row["home_xg"] for row in rows]),
        np.asarray([row["away_xg"] for row in rows]),
    ) | {"matches": len(rows)}


def premier_league_diagnostic(rows: list[dict[str, Any]]) -> dict[str, Any]:
    league_rows = [row for row in rows if row["league"] == "ENG-Premier League"]
    actual = np.asarray([baseline.CLASS_ORDER.index(row["result"]) for row in league_rows])
    probabilities = np.asarray([row["probabilities"] for row in league_rows])
    predicted = probabilities.argmax(axis=1)
    confusion = {
        actual_label: {
            predicted_label: int(((actual == actual_index) & (predicted == predicted_index)).sum())
            for predicted_index, predicted_label in enumerate(baseline.CLASS_ORDER)
        }
        for actual_index, actual_label in enumerate(baseline.CLASS_ORDER)
    }
    class_rates = {
        label: {
            "actual_rate": float((actual == index).mean()),
            "mean_predicted_probability": float(probabilities[:, index].mean()),
        }
        for index, label in enumerate(baseline.CLASS_ORDER)
    }
    ordered = sorted(league_rows, key=lambda row: row["date"])
    midpoint = len(ordered) // 2
    return {
        "matches": len(league_rows),
        "class_rates": class_rates,
        "confusion": confusion,
        "first_half": score_rows(ordered[:midpoint]),
        "second_half": score_rows(ordered[midpoint:]),
    }


def evaluate_prior(frame: pd.DataFrame, folds: list[tuple[np.ndarray, np.ndarray]]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for train_idx, test_idx in folds:
        train = frame.iloc[train_idx]
        test = frame.iloc[test_idx]
        probabilities, home_xg, away_xg = baseline.prior_predictions(train, test)
        for index, (_, row) in enumerate(test.iterrows()):
            rows.append({
                "league": row["league"], "result": row["result"],
                "home_goals": row["home_goals"], "away_goals": row["away_goals"],
                "probabilities": probabilities[index],
                "home_xg": home_xg[index], "away_xg": away_xg[index],
            })
    return {
        "overall": score_rows(rows),
        "by_league": {
            league: score_rows([row for row in rows if row["league"] == league])
            for league in baseline.TOP_FIVE
        },
    }


def markdown_report(report: dict[str, Any]) -> str:
    lines = [
        "# 2025/26 feature-family ablation study",
        "",
        f"Generated: {report['created_at']}",
        "",
        "All results use grouped-date rolling-origin validation. Positive leave-one-out delta means removing the family made log loss worse, so the family helped.",
        "",
        "## Leave-one-family-out",
        "",
        "| Family removed | Columns | Log loss | Delta vs all | Helpful folds |",
        "|---|---:|---:|---:|---:|",
    ]
    for name, value in sorted(report["leave_one_out"].items(), key=lambda item: item[1]["log_loss_delta_vs_all"], reverse=True):
        lines.append(
            f"| {name} | {value['column_count']} | {value['overall']['log_loss']:.4f} | "
            f"{value['log_loss_delta_vs_all']:+.4f} | {value['helpful_fold_count']}/{report['validation']['fold_count']} |"
        )
    lines.extend([
        "", "## Add-one-family to context and team strength", "",
        "| Family added | Columns | Log loss | Improvement vs core |",
        "|---|---:|---:|---:|",
    ])
    for name, value in sorted(report["add_one"].items(), key=lambda item: item[1]["log_loss_improvement_vs_core"], reverse=True):
        lines.append(
            f"| {name} | {value['column_count']} | {value['overall']['log_loss']:.4f} | "
            f"{value['log_loss_improvement_vs_core']:+.4f} |"
        )
    full = report["all_features"]
    prior = report["league_prior"]
    lines.extend([
        "", "## Overall comparison", "",
        f"- League/home prior log loss: {prior['overall']['log_loss']:.4f}",
        f"- Core context + team strength log loss: {report['core']['overall']['log_loss']:.4f}",
        f"- All-feature Poisson log loss: {full['overall']['log_loss']:.4f}",
        f"- All-feature Brier score: {full['overall']['brier']:.4f}",
        f"- All-feature home/away goal MAE: {full['overall']['home_goals_mae']:.3f} / {full['overall']['away_goals_mae']:.3f}",
        "", "## Targeted compact combinations", "",
        "| Families added to core | Columns | Log loss | Improvement vs core |",
        "|---|---:|---:|---:|",
    ])
    for name, value in sorted(report["targeted_combinations"].items(), key=lambda item: item[1]["log_loss_improvement_vs_core"], reverse=True):
        lines.append(
            f"| {name} | {value['column_count']} | {value['overall']['log_loss']:.4f} | "
            f"{value['log_loss_improvement_vs_core']:+.4f} |"
        )
    lines.extend([
        "", "## Premier League diagnostic", "",
    ])
    diagnostic = full["premier_league_diagnostic"]
    for label, name in (("H", "Home win"), ("D", "Draw"), ("A", "Away win")):
        rates = diagnostic["class_rates"][label]
        lines.append(
            f"- {name}: actual {rates['actual_rate']:.1%}; mean predicted {rates['mean_predicted_probability']:.1%}"
        )
    lines.extend([
        f"- First-half log loss: {diagnostic['first_half']['log_loss']:.4f}",
        f"- Second-half log loss: {diagnostic['second_half']['log_loss']:.4f}",
        "", "## Interpretation", "",
        "Treat this as one-season evidence, not a promotion decision. Families should survive a genuine prior-season holdout before they become part of the production feature contract.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2526")
    parser.add_argument("--feature-schema-version", type=int, default=1)
    parser.add_argument("--folds", type=int, default=5)
    parser.add_argument("--initial-fraction", type=float, default=0.50)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    db = baseline.db_client()
    frame = baseline.load_matches(db, args.season, args.feature_schema_version)
    baseline.add_pre_match_elo(frame)
    folds = baseline.date_folds(frame, args.folds, args.initial_fraction)
    metadata = {"game_id", "date", "league", "home_team", "away_team", "home_goals", "away_goals", "result"}
    numeric = sorted(column for column in frame.columns if column not in metadata)
    families = family_columns(numeric)
    core_families = ("team_strength", "availability_context")
    core_columns = sorted({column for family in core_families for column in families[family]})

    print(f"Loaded {len(frame)} matches; {len(numeric)} numeric features; {len(families)} families")
    prior = evaluate_prior(frame, folds)
    core = evaluate_poisson(frame, core_columns, folds)
    full = evaluate_poisson(frame, numeric, folds)
    print(f"Core log loss={core['overall']['log_loss']:.4f}; all={full['overall']['log_loss']:.4f}")

    leave_one_out: dict[str, Any] = {}
    full_fold_losses = [fold["log_loss"] for fold in full["folds"]]
    for family, removed in families.items():
        kept = [column for column in numeric if column not in removed]
        result = evaluate_poisson(frame, kept, folds)
        deltas = [fold["log_loss"] - full_fold_losses[index] for index, fold in enumerate(result["folds"])]
        result["removed_columns"] = removed
        result["log_loss_delta_vs_all"] = result["overall"]["log_loss"] - full["overall"]["log_loss"]
        result["helpful_fold_count"] = int(sum(delta > 0 for delta in deltas))
        leave_one_out[family] = result
        print(f"Removed {family}: delta={result['log_loss_delta_vs_all']:+.4f}")

    add_one: dict[str, Any] = {}
    for family, added in families.items():
        if family in core_families:
            continue
        columns = sorted(set(core_columns + added))
        result = evaluate_poisson(frame, columns, folds)
        result["added_columns"] = added
        result["log_loss_improvement_vs_core"] = core["overall"]["log_loss"] - result["overall"]["log_loss"]
        add_one[family] = result
        print(f"Added {family}: improvement={result['log_loss_improvement_vs_core']:+.4f}")

    targeted_combinations: dict[str, Any] = {}
    candidates = ("shooting", "territory", "pressing_defense")
    for count in (2, 3):
        for combination in itertools.combinations(candidates, count):
            columns = sorted(set(core_columns + [column for family in combination for column in families[family]]))
            result = evaluate_poisson(frame, columns, folds)
            result["added_families"] = list(combination)
            result["log_loss_improvement_vs_core"] = core["overall"]["log_loss"] - result["overall"]["log_loss"]
            name = " + ".join(combination)
            targeted_combinations[name] = result
            print(f"Added {name}: improvement={result['log_loss_improvement_vs_core']:+.4f}")

    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "season": args.season,
        "validation": {
            "method": "grouped-date rolling-origin walk-forward",
            "fold_count": len(folds),
            "initial_train_fraction": args.initial_fraction,
            "random_split": False,
        },
        "families": families,
        "league_prior": prior,
        "core": core,
        "all_features": full,
        "leave_one_out": leave_one_out,
        "add_one": add_one,
        "targeted_combinations": targeted_combinations,
        "promotion_decision": "diagnostic_only_one_season",
    }
    output_dir = args.output_dir or Path(__file__).resolve().parents[1] / "artifacts" / "model_reports"
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    json_path = output_dir / f"feature_ablation_{args.season}_{stamp}.json"
    md_path = Path(__file__).resolve().parents[1] / "docs" / f"MODEL_FEATURE_ABLATION_{args.season}.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    md_path.write_text(markdown_report(report), encoding="utf-8")
    print(f"JSON report: {json_path}")
    print(f"Markdown report: {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
