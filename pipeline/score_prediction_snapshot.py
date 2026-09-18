#!/usr/bin/env python3
"""Score a frozen local prediction snapshot against results known so far.

This command is read-only with respect to Supabase. It writes a local report
and refuses to call a small sample promotion-ready.
"""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import numpy as np

import train_match_baselines as baseline


MIN_OVERALL_SAMPLE = 100
MIN_LEAGUE_SAMPLE = 20


def parse_utc_datetime(value: Any) -> datetime:
    """Normalize stored ISO timestamps so mixed provider formats compare safely."""
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def evaluate(predictions: list[dict[str, Any]], matches: list[dict[str, Any]]) -> dict[str, Any]:
    prediction_by_id = {str(row["game_id"]): row for row in predictions}
    if len(prediction_by_id) != len(predictions):
        raise RuntimeError("prediction snapshot contains duplicate game ids")
    match_by_id = {str(row["game_id"]): row for row in matches}
    resolved = []
    for game_id, prediction in prediction_by_id.items():
        match = match_by_id.get(game_id)
        if not match or match.get("home_score") is None or match.get("away_score") is None:
            continue
        home, away = int(match["home_score"]), int(match["away_score"])
        resolved.append({
            "game_id": game_id,
            "league": prediction["league"],
            "result": "H" if home > away else "D" if home == away else "A",
            "home_goals": home,
            "away_goals": away,
            "probabilities": [
                float(prediction["home_win_probability"]),
                float(prediction["draw_probability"]),
                float(prediction["away_win_probability"]),
            ],
            "home_xg": float(prediction["home_expected_goals"]),
            "away_xg": float(prediction["away_expected_goals"]),
        })

    def score(rows: list[dict[str, Any]]) -> dict[str, Any]:
        if not rows:
            return {"matches": 0, "status": "insufficient_sample"}
        metrics = baseline.score(
            np.asarray([row["result"] for row in rows]),
            np.asarray([row["probabilities"] for row in rows]),
            np.asarray([row["home_goals"] for row in rows]),
            np.asarray([row["away_goals"] for row in rows]),
            np.asarray([row["home_xg"] for row in rows]),
            np.asarray([row["away_xg"] for row in rows]),
        )
        metrics["matches"] = len(rows)
        metrics["probability_bands"] = baseline.probability_bands(
            np.asarray([row["result"] for row in rows]),
            np.asarray([row["probabilities"] for row in rows]),
        )
        return metrics

    overall = score(resolved)
    by_league = {
        league: score([row for row in resolved if row["league"] == league])
        for league in baseline.TOP_FIVE
    }
    league_samples_ready = all(values["matches"] >= MIN_LEAGUE_SAMPLE for values in by_league.values())
    sample_ready = len(resolved) >= MIN_OVERALL_SAMPLE and league_samples_ready
    return {
        "predictions": len(predictions),
        "resolved": len(resolved),
        "pending": len(predictions) - len(resolved),
        "canonical_rows_found": len(set(prediction_by_id) & set(match_by_id)),
        "overall": overall,
        "by_league": by_league,
        "sample_gate": {
            "minimum_overall": MIN_OVERALL_SAMPLE,
            "minimum_per_league": MIN_LEAGUE_SAMPLE,
            "ready": sample_ready,
            "decision": "eligible_for_shadow_metrics_review" if sample_ready else "collect_more_results",
        },
    }


def evaluation_predictions(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], str]:
    as_of = parse_utc_datetime(payload["as_of"])
    through_text = payload.get("evaluation_through")
    through = (
        parse_utc_datetime(through_text)
        if through_text else as_of + timedelta(days=7)
    )
    if through <= as_of:
        raise RuntimeError("evaluation_through must be later than prediction as_of")
    eligible = []
    for row in payload.get("predictions", []):
        kickoff = parse_utc_datetime(row["date"])
        if as_of < kickoff <= through:
            eligible.append(row)
    return eligible, through.isoformat()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions-file", type=Path, required=True)
    parser.add_argument(
        "--matches-file", type=Path,
        help="Optional fixture-provider JSON containing completed_fixtures; bypasses the Data API.",
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    payload = json.loads(args.predictions_file.read_text(encoding="utf-8"))
    simulation_prediction_count = len(payload.get("predictions", []))
    predictions, evaluation_through = evaluation_predictions(payload)
    if not predictions:
        raise RuntimeError("prediction snapshot is empty")
    if args.matches_file:
        match_payload = json.loads(args.matches_file.read_text(encoding="utf-8"))
        matches = list(match_payload.get("completed_fixtures") or [])
        result_source = str(args.matches_file.resolve())
    else:
        db = baseline.db_client()
        leagues = sorted({row["league"] for row in predictions})
        matches = baseline.fetch_pages(
            db.table("matches")
            .select("game_id,season,league,home_score,away_score")
            .eq("season", payload["season"])
            .in_("league", leagues)
            .order("game_id")
        )
        result_source = "Supabase public.matches"
    report = {
        "report_schema_version": 1,
        "generated_at": datetime.now(UTC).isoformat(),
        "prediction_snapshot": str(args.predictions_file),
        "prediction_as_of": payload["as_of"],
        "evaluation_through": evaluation_through,
        "simulation_predictions": simulation_prediction_count,
        "forecast_kind": payload["forecast_kind"],
        "season": payload["season"],
        "result_source": result_source,
        **evaluate(predictions, matches),
    }
    output = args.output or Path(__file__).resolve().parents[1] / "artifacts" / "model_reports" / f"shadow_score_{payload['season']}_{payload['forecast_kind']}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Resolved {report['resolved']}/{report['predictions']} frozen predictions")
    print(f"Sample decision: {report['sample_gate']['decision']}")
    print(f"Report: {output}")
    print("Read-only scoring; no Supabase rows were written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
