#!/usr/bin/env python3
"""Build a key-free static review payload from private forecast artifacts."""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions-file", type=Path, required=True)
    parser.add_argument("--simulations-dir", type=Path, default=ROOT / "artifacts" / "simulations")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts" / "model-review" / "model-review-data.js")
    parser.add_argument("--page-template", type=Path, default=ROOT / "dashboard" / "model-review.html")
    parser.add_argument("--readiness-report", type=Path)
    args = parser.parse_args()

    source = json.loads(args.predictions_file.read_text(encoding="utf-8"))
    as_of = datetime.fromisoformat(str(source["as_of"]).replace("Z", "+00:00"))
    evaluation_through = datetime.fromisoformat(
        str(source.get("evaluation_through") or (as_of + timedelta(days=7)).isoformat()).replace("Z", "+00:00")
    )
    predictions = [
        {key: row[key] for key in (
            "game_id", "date", "league", "home_team", "away_team",
            "home_expected_goals", "away_expected_goals", "home_win_probability",
            "draw_probability", "away_win_probability", "explanation",
        )}
        for row in source.get("predictions", [])
        if as_of < datetime.fromisoformat(str(row["date"]).replace("Z", "+00:00")) <= evaluation_through
    ]
    if not predictions:
        raise RuntimeError("prediction artifact contains no fixtures")

    simulations = {}
    for league in sorted({row["league"] for row in predictions}):
        path = args.simulations_dir / f"{league}_{source['season']}_{source['forecast_kind']}.json"
        if not path.is_file():
            raise RuntimeError(f"missing simulation bundle: {path}")
        simulation = json.loads(path.read_text(encoding="utf-8"))
        simulations[league] = {
            "simulations": simulation["simulations"],
            "rules_version": simulation["rules_version"],
            "ranking_method": simulation["ranking_method"],
            "special_playoff_policy": simulation.get("special_playoff_policy"),
            "teams": [
                {key: team[key] for key in (
                    "team", "current_played", "current_points", "current_points_per_match",
                    "current_points_pace", "projected_remaining_points",
                    "expected_position", "expected_points", "champion_probability",
                    "top_four_probability", "relegation_probability",
                )}
                for team in simulation["teams"]
            ],
        }

    readiness_path = args.readiness_report or (
        ROOT / "artifacts" / "data_quality"
        / f"forecast_readiness_{source['season']}_{source['forecast_kind']}.json"
    )
    readiness = None
    if readiness_path.is_file():
        candidate = json.loads(readiness_path.read_text(encoding="utf-8"))
        if Path(str(candidate.get("prediction_file", ""))).resolve() == args.predictions_file.resolve():
            readiness = candidate
    review_ready = bool(readiness and readiness.get("ready_for_private_review"))
    blockers = [
        check["detail"] for check in (readiness or {}).get("checks", [])
        if not check.get("passed") and check.get("name") != "publication approval"
    ]
    payload = {
        "season": source["season"],
        "as_of": source["as_of"],
        "evaluation_through": evaluation_through.isoformat(),
        "forecast_kind": source["forecast_kind"],
        "status": "shadow",
        "model_version": source.get("model_version") or Path(str(source["artifact"])).stem,
        "feature_schema_version": source.get("feature_schema_version"),
        "algorithm": source.get("algorithm"),
        "trained_through": source.get("trained_through"),
        "feature_count": source.get("feature_count"),
        "publication_allowed": False,
        "review_ready": review_ready,
        "review_blockers": blockers or ([] if review_ready else ["matching readiness report is unavailable"]),
        "predictions": predictions,
        "simulations": simulations,
    }
    encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True).replace("<", "\\u003c")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(f"window.MODEL_REVIEW_DATA={encoded};\n", encoding="utf-8")
    page_output = args.output.parent / "model-review.html"
    page = args.page_template.read_text(encoding="utf-8")
    if page_output.parent.resolve() != (ROOT / "dashboard").resolve():
        page = page.replace('src="gate.js"', 'src="../../dashboard/gate.js"')
    page_output.write_text(page, encoding="utf-8")
    print(
        f"Model review bundle: fixtures={len(predictions)} leagues={len(simulations)} "
        f"page={page_output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
