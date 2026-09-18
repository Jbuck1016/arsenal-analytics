#!/usr/bin/env python3
"""Score persisted pre-match predictions against canonical results.

This is the operational diagnostic ledger. It is deliberately separate from
the stricter Thursday-frozen legitimacy report: ``latest`` calls are useful
for comparing deployed candidates and investigating individual matches, but
they must never be relabelled as untouched weekly forecasts.
"""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import score_prediction_snapshot as scoring
import train_match_baselines as baseline


def instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError(f"timestamp lacks timezone: {value}")
    return parsed.astimezone(UTC)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2627")
    parser.add_argument("--model-run-id", type=int, action="append")
    parser.add_argument(
        "--output", type=Path,
        default=Path("artifacts/model_reports/prediction_ledger_2627.json"),
    )
    args = parser.parse_args()

    db = baseline.db_client()
    matches = baseline.fetch_pages(
        db.table("matches")
        .select("game_id,season,league,kickoff_at,date,home_team,away_team,home_score,away_score")
        .eq("season", args.season)
        .order("game_id")
    )
    match_by_id = {str(row["game_id"]): row for row in matches}
    query = db.table("ml_match_predictions").select(
        "model_run_id,game_id,forecast_kind,as_of,home_expected_goals,away_expected_goals,"
        "home_win_probability,draw_probability,away_win_probability,scoreline_distribution"
    ).order("as_of")
    if args.model_run_id:
        query = query.in_("model_run_id", args.model_run_id)
    persisted = baseline.fetch_pages(query)
    run_ids = sorted({int(row["model_run_id"]) for row in persisted})
    runs = baseline.fetch_pages(
        db.table("ml_model_runs")
        .select("id,model_key,model_version,status")
        .in_("id", run_ids or [-1])
        .order("id")
    )
    run_by_id = {int(row["id"]): row for row in runs}

    selected: dict[tuple[int, str, str], dict[str, Any]] = {}
    excluded_post_kickoff = 0
    excluded_missing_match = 0
    for prediction in persisted:
        game_id = str(prediction["game_id"])
        match = match_by_id.get(game_id)
        if match is None:
            excluded_missing_match += 1
            continue
        kickoff = instant(match.get("kickoff_at") or f"{match['date']}T12:00:00+00:00")
        if instant(prediction["as_of"]) >= kickoff:
            excluded_post_kickoff += 1
            continue
        key = (int(prediction["model_run_id"]), str(prediction["forecast_kind"]), game_id)
        # For an operational/latest series, the last genuinely pre-kickoff call
        # is the fairest representation of what a user could have acted on.
        selected[key] = prediction | {
            "league": match["league"],
            "date": match.get("kickoff_at") or match["date"],
            "home_team": match["home_team"],
            "away_team": match["away_team"],
        }

    groups: dict[str, Any] = {}
    for model_run_id, forecast_kind in sorted({(key[0], key[1]) for key in selected}):
        rows = [
            row for (run_id, kind, _), row in selected.items()
            if run_id == model_run_id and kind == forecast_kind
        ]
        groups[f"{model_run_id}:{forecast_kind}"] = {
            "model": run_by_id.get(model_run_id),
            "forecast_kind": forecast_kind,
            "selection_policy": "latest_strictly_pre_kickoff_call_per_model_and_game",
            **scoring.evaluate(rows, matches),
        }

    report = {
        "report_schema_version": 1,
        "generated_at": datetime.now(UTC).isoformat(),
        "season": args.season,
        "persisted_rows_examined": len(persisted),
        "selected_pre_match_calls": len(selected),
        "excluded_post_kickoff": excluded_post_kickoff,
        "excluded_missing_match": excluded_missing_match,
        "usage_policy": (
            "latest calls are diagnostic candidate evidence; only untouched Thursday-frozen "
            "snapshots count toward the live legitimacy gate"
        ),
        "groups": groups,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Prediction ledger: persisted={len(persisted)} selected={len(selected)} "
        f"groups={len(groups)} post_kickoff_excluded={excluded_post_kickoff}"
    )
    for key, group in groups.items():
        print(f"  {key}: resolved={group['resolved']}/{group['predictions']}")
    print(f"Report: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
