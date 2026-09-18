#!/usr/bin/env python3
"""Compare persisted model calls with immutable market consensus snapshots."""

from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import train_match_baselines as baseline


def instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def actual_index(match: dict[str, Any]) -> int | None:
    home, away = match.get("home_score"), match.get("away_score")
    if home is None or away is None:
        return None
    return 0 if int(home) > int(away) else 1 if int(home) == int(away) else 2


def metrics(rows: list[dict[str, Any]]) -> dict[str, Any]:
    resolved = [row for row in rows if row["actual_index"] is not None]
    if not resolved:
        return {"resolved": 0, "model_log_loss": None, "market_log_loss": None,
                "model_brier": None, "market_brier": None}
    model_ll = market_ll = model_brier = market_brier = 0.0
    for row in resolved:
        actual = int(row["actual_index"])
        model = row["model_probabilities"]
        market = row["market_probabilities"]
        model_ll -= math.log(max(float(model[actual]), 1e-15))
        market_ll -= math.log(max(float(market[actual]), 1e-15))
        target = [1.0 if index == actual else 0.0 for index in range(3)]
        model_brier += sum((float(model[index]) - target[index]) ** 2 for index in range(3))
        market_brier += sum((float(market[index]) - target[index]) ** 2 for index in range(3))
    count = len(resolved)
    return {
        "resolved": count,
        "model_log_loss": model_ll / count,
        "market_log_loss": market_ll / count,
        "model_delta_vs_market_log_loss": (model_ll - market_ll) / count,
        "model_brier": model_brier / count,
        "market_brier": market_brier / count,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2627")
    parser.add_argument("--model-run-id", type=int, default=4)
    parser.add_argument("--edge-threshold", type=float, default=0.05)
    parser.add_argument(
        "--output", type=Path,
        default=Path("artifacts/model_reports/market_edge_report_2627.json"),
    )
    args = parser.parse_args()
    if not 0 < args.edge_threshold < 1:
        raise ValueError("--edge-threshold must be in (0, 1)")

    db = baseline.db_client()
    matches = baseline.fetch_pages(
        db.table("matches")
        .select("game_id,season,league,kickoff_at,date,home_team,away_team,home_score,away_score")
        .eq("season", args.season)
        .order("game_id")
    )
    match_by_id = {str(row["game_id"]): row for row in matches}
    predictions = baseline.fetch_pages(
        db.table("ml_match_predictions")
        .select("model_run_id,game_id,forecast_kind,as_of,home_win_probability,draw_probability,away_win_probability")
        .eq("model_run_id", args.model_run_id)
        .order("as_of")
    )
    predictions_by_game: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in predictions:
        predictions_by_game[str(row["game_id"])].append(row)
    consensus = baseline.fetch_pages(
        db.table("v_ml_market_odds_consensus")
        .select("game_id,source,snapshot_kind,captured_at,commence_time,bookmaker_count,"
                "home_probability_fair,draw_probability_fair,away_probability_fair,"
                "mean_overround,oldest_source_update,newest_source_update,minutes_before_kickoff")
        .order("captured_at")
    )

    comparisons = []
    skipped_without_prediction = 0
    for market in consensus:
        game_id = str(market["game_id"])
        match = match_by_id.get(game_id)
        if match is None:
            continue
        captured = instant(market["captured_at"])
        eligible = [row for row in predictions_by_game.get(game_id, []) if instant(row["as_of"]) <= captured]
        if not eligible:
            skipped_without_prediction += 1
            continue
        prediction = eligible[-1]
        model_probs = [float(prediction[key]) for key in (
            "home_win_probability", "draw_probability", "away_win_probability",
        )]
        market_probs = [float(market[key]) for key in (
            "home_probability_fair", "draw_probability_fair", "away_probability_fair",
        )]
        deltas = [model_probs[index] - market_probs[index] for index in range(3)]
        largest = max(range(3), key=lambda index: abs(deltas[index]))
        minutes = float(market["minutes_before_kickoff"])
        newest_update = instant(market["newest_source_update"]) if market.get("newest_source_update") else None
        commence = instant(market["commence_time"])
        source_age_at_kickoff = (
            (commence - newest_update).total_seconds() / 60 if newest_update else None
        )
        closing_eligible = (
            0 <= minutes <= 90
            and source_age_at_kickoff is not None
            and 0 <= source_age_at_kickoff <= 180
        )
        comparisons.append({
            "game_id": game_id,
            "league": match["league"],
            "home_team": match["home_team"],
            "away_team": match["away_team"],
            "kickoff_at": match.get("kickoff_at") or match["date"],
            "snapshot_kind": market["snapshot_kind"],
            "market_captured_at": market["captured_at"],
            "prediction_as_of": prediction["as_of"],
            "forecast_kind": prediction["forecast_kind"],
            "bookmaker_count": int(market["bookmaker_count"]),
            "minutes_before_kickoff": minutes,
            "source_age_at_kickoff_minutes": source_age_at_kickoff,
            "closing_eligible": closing_eligible,
            "model_probabilities": model_probs,
            "market_probabilities": market_probs,
            "probability_edge": deltas,
            "largest_edge_outcome": ("home", "draw", "away")[largest],
            "largest_absolute_edge": abs(deltas[largest]),
            "research_flag": (
                int(market["bookmaker_count"]) >= 3
                and abs(deltas[largest]) >= args.edge_threshold
            ),
            "actual_index": actual_index(match),
        })

    groups = {}
    for kind in sorted({row["snapshot_kind"] for row in comparisons}):
        rows = [row for row in comparisons if row["snapshot_kind"] == kind]
        groups[kind] = {"comparisons": len(rows), **metrics(rows)}
    closing_rows = [row for row in comparisons if row["closing_eligible"]]
    report = {
        "report_schema_version": 1,
        "generated_at": datetime.now(UTC).isoformat(),
        "season": args.season,
        "model_run_id": args.model_run_id,
        "comparison_policy": (
            "latest model call at or before the market capture; proportional de-vig per bookmaker; "
            "equal-weight bookmaker consensus"
        ),
        "edge_policy": (
            "research flag only: at least three bookmakers and absolute probability difference at "
            f"least {args.edge_threshold:.1%}; not evidence of profitability or betting advice"
        ),
        "closing_policy": (
            "reported as closing-eligible only when captured within 90 minutes of kickoff and the "
            "newest provider price was updated within 180 minutes of kickoff"
        ),
        "market_snapshots": len(consensus),
        "comparisons": len(comparisons),
        "skipped_without_prior_prediction": skipped_without_prediction,
        "research_flags": sum(bool(row["research_flag"]) for row in comparisons),
        "groups": groups,
        "closing_eligible": {"comparisons": len(closing_rows), **metrics(closing_rows)},
        "matches": comparisons,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Market edge report: snapshots={len(consensus)} comparisons={len(comparisons)} "
        f"closing_eligible={len(closing_rows)} research_flags={report['research_flags']}"
    )
    print(f"Report: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
