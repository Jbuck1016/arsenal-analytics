#!/usr/bin/env python3
"""Score several immutable weekly snapshots as one deduplicated shadow history."""
from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

import score_prediction_snapshot as scoring
import train_match_baselines as baseline


# V2 began with the 17 September slate. The agreed review point is that
# initial slate plus two further complete frozen weekends (29 September and
# 6 October scorecards), alongside the 100-overall/20-per-league sample gate.
MIN_COMPLETE_FROZEN_WEEKENDS = 3


def combine_snapshots(payloads: list[dict]) -> tuple[list[dict], int]:
    """Keep the earliest eligible frozen call for each game across weekly files."""
    chosen = {}
    repeats = 0
    for payload in sorted(payloads, key=lambda item: item["as_of"]):
        eligible, _ = scoring.evaluation_predictions(payload)
        for row in eligible:
            game_id = str(row["game_id"])
            if game_id in chosen:
                repeats += 1
                continue
            chosen[game_id] = row
    return list(chosen.values()), repeats


def complete_frozen_weekends(payloads: list[dict]) -> int:
    """Count frozen windows that contain at least one eligible call in every league."""
    required = set(baseline.TOP_FIVE)
    complete = 0
    for payload in payloads:
        eligible, _ = scoring.evaluation_predictions(payload)
        if {row["league"] for row in eligible} == required:
            complete += 1
    return complete


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions-file", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, default=Path("artifacts/model_reports/shadow_score_history.json"))
    args = parser.parse_args()
    payloads = [json.loads(path.read_text(encoding="utf-8")) for path in args.predictions_file]
    if any(payload.get("forecast_kind") != "thursday_frozen" for payload in payloads):
        raise RuntimeError("shadow history accepts only immutable thursday_frozen snapshots")
    predictions, repeats = combine_snapshots(payloads)
    seasons = sorted({str(payload["season"]) for payload in payloads})
    if len(seasons) != 1:
        raise RuntimeError("all shadow snapshots must belong to one season")
    db = baseline.db_client()
    matches = baseline.fetch_pages(
        db.table("matches")
        .select("game_id,season,league,home_score,away_score")
        .eq("season", seasons[0])
        .in_("league", list(baseline.TOP_FIVE))
        .order("game_id")
    )
    evaluated = scoring.evaluate(predictions, matches)
    complete_weekends = complete_frozen_weekends(payloads)
    sample_gate = evaluated["sample_gate"]
    sample_gate["minimum_complete_frozen_weekends"] = MIN_COMPLETE_FROZEN_WEEKENDS
    sample_gate["complete_frozen_weekends"] = complete_weekends
    sample_gate["ready"] = (
        bool(sample_gate["ready"])
        and complete_weekends >= MIN_COMPLETE_FROZEN_WEEKENDS
    )
    if not sample_gate["ready"]:
        sample_gate["decision"] = (
            "collect_more_complete_frozen_weekends"
            if complete_weekends < MIN_COMPLETE_FROZEN_WEEKENDS
            else "collect_more_results"
        )

    report = {
        "report_schema_version": 1,
        "generated_at": datetime.now(UTC).isoformat(),
        "season": seasons[0],
        "snapshot_count": len(payloads),
        "duplicate_game_forecasts_ignored": repeats,
        "selection_policy": "earliest_evaluation_eligible_thursday_frozen_prediction_per_game",
        "snapshots": [str(path) for path in args.predictions_file],
        **evaluated,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Shadow history: snapshots={len(payloads)} eligible={len(predictions)} "
        f"resolved={report['resolved']} repeats_ignored={repeats}"
    )
    print(f"Sample decision: {report['sample_gate']['decision']}")
    print(f"Report: {args.output}")
    print("Read-only scoring; no Supabase rows were written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
