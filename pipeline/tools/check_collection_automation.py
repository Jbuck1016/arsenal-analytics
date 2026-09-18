#!/usr/bin/env python3
"""Safety and scheduling contract checks for unattended collection."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)
    print(f"PASS  {message}")


def main() -> int:
    import sync_future_fixtures as fixtures
    import score_prediction_snapshot as scoring
    import audit_forecast_readiness as readiness

    postponed = {
        "status": "POSTPONED",
        "score": {"fullTime": {"home": 0, "away": 0}},
    }
    finished = {
        "status": "FINISHED",
        "score": {"fullTime": {"home": 0, "away": 0}},
    }
    require(not fixtures.is_completed_fixture(postponed),
            "postponed placeholder scores never count as completed matches")
    require(fixtures.is_completed_fixture(finished),
            "genuine finished 0-0 matches remain completed")

    eligible, _ = scoring.evaluation_predictions({
        "as_of": "2026-09-17T12:00:00Z",
        "evaluation_through": "2026-09-24T12:00:00+00:00",
        "predictions": [{"date": "2026-09-18T20:00:00"}],
    })
    require(len(eligible) == 1,
            "shadow scoring normalizes legacy timezone-naive kickoff timestamps")
    require(readiness.legacy_manifest_identity_matches(
        [{
            "game_id": "fd-1", "league": "ENG-Premier League",
            "home_team": "Home", "away_team": "Away",
            "kickoff_at": "2026-09-18T20:00:00Z",
        }],
        [{
            "game_id": "fd-1", "league": "ENG-Premier League",
            "home_team": "Home", "away_team": "Away",
            "date": "2026-09-18T13:00:00-07:00",
        }],
    ), "legacy frozen manifests require stable fixture identity")

    result_wrapper = (ROOT / "pipeline" / "refresh_match_results.ps1").read_text(encoding="utf-8")
    market_tasks = (ROOT / "pipeline" / "register_market_odds_tasks.ps1").read_text(encoding="utf-8")
    result_tasks = (ROOT / "pipeline" / "register_match_result_task.ps1").read_text(encoding="utf-8")
    model_tasks = (ROOT / "pipeline" / "register_model_operations_task.ps1").read_text(encoding="utf-8")
    quick_worker = (ROOT / "pipeline" / "process_writing_lab_queue.py").read_text(encoding="utf-8")
    shadow_wrapper = (ROOT / "pipeline" / "run_shadow_weekly.ps1").read_text(encoding="utf-8")
    feature_builder = (ROOT / "pipeline" / "build_ml_features.py").read_text(encoding="utf-8")
    migration = (ROOT / "supabase" / "migrations" / "20260918202920_pipeline_run_health.sql").read_text(encoding="utf-8")

    require("allowedDays" not in result_wrapper, "result watcher covers midweek league fixtures")
    require(market_tasks.count("New-ScheduledTaskTrigger -Daily") >= 2,
            "both pre-kickoff odds captures run daily")
    for source, label in ((market_tasks, "odds"), (result_tasks, "results"), (model_tasks, "model operations")):
        require('else { "S4U" }' in source and "-LogonType $logonType" in source and "-WakeToRun" in source,
                f"{label} tasks run after sleep without an interactive login")
    require("return 1 if failed else 0" in quick_worker,
            "manual-ingest errors propagate to Windows Task Scheduler")
    require("[DateTimeOffset]::new($now.UtcDateTime.Date.AddHours(12))" in shadow_wrapper,
            "Thursday snapshot calculation keeps UTC values type-compatible")
    require("$immutableFixturePath" in shadow_wrapper and "Copy-Item" in shadow_wrapper,
            "new Thursday snapshots preserve an immutable fixture manifest")
    require("--defer-unverified-results" in shadow_wrapper and "pending_results" in feature_builder,
            "live feature refresh defers score-only matches until events are verified")
    require("pipeline_name text primary key" in migration and "check_pipeline_health_alerts" in migration,
            "central health uses bounded rows and existing webhook alerts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
