#!/usr/bin/env python3
"""Audit a private forecast bundle without publishing model output."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import train_match_baselines as baseline
from generate_match_predictions import provider_completion_gaps


TOP_FIVE = tuple(baseline.TOP_FIVE)
PERSISTABLE_STATUSES = {"validated", "shadow", "active"}


def instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError(f"timezone is required: {value}")
    return parsed.astimezone(UTC)


def match_instant(row: dict[str, Any]) -> datetime:
    return instant(row.get("kickoff_at") or f"{row['date']}T12:00:00+00:00")


def finding(name: str, passed: bool, detail: str) -> dict[str, Any]:
    return {"name": name, "passed": passed, "detail": detail}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions-file", type=Path, required=True)
    parser.add_argument("--simulations-dir", type=Path, default=Path("artifacts/simulations"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    payload = json.loads(args.predictions_file.read_text(encoding="utf-8"))
    season = str(payload["season"])
    as_of = instant(str(payload["as_of"]))
    forecast_kind = str(payload["forecast_kind"])
    predictions = list(payload.get("predictions") or [])
    db = baseline.db_client()
    matches = baseline.fetch_pages(
        db.table("matches")
        .select("game_id,season,league,date,kickoff_at,home_team,away_team,home_score,away_score")
        .eq("season", season)
        .in_("league", list(TOP_FIVE))
        .order("date")
        .order("game_id")
    )
    active_provider_ids: set[str] | None = None
    completed_provider: list[dict[str, Any]] = []
    manifest_ok = True
    manifest_detail = "not supplied"
    if payload.get("fixture_manifest"):
        manifest_path = Path(str(payload["fixture_manifest"]))
        manifest_digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
        manifest_ok = manifest_digest == payload.get("fixture_manifest_sha256")
        manifest_payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        active_provider_ids = {
            str(row["game_id"]) for row in manifest_payload.get("fixtures", [])
        }
        completed_provider = list(manifest_payload.get("completed_fixtures", []))
        manifest_detail = f"active={len(active_provider_ids)} digest_match={manifest_ok}"
    checks: list[dict[str, Any]] = []
    checks.append(finding("fixture manifest integrity", manifest_ok, manifest_detail))
    expected = {}
    for row in matches:
        if match_instant(row) <= as_of:
            continue
        game_id = str(row["game_id"])
        scored_after_cutoff = row.get("home_score") is not None and row.get("away_score") is not None
        provider_row_is_active = active_provider_ids is None or game_id in active_provider_ids
        if scored_after_cutoff or not game_id.startswith("fd-") or provider_row_is_active:
            expected[game_id] = row
    prediction_ids = [str(row["game_id"]) for row in predictions]
    predicted = set(prediction_ids)
    expected_ids = set(expected)
    checks.append(finding(
        "fixture coverage",
        predicted == expected_ids,
        f"expected={len(expected_ids)} predicted={len(predicted)} missing={len(expected_ids-predicted)} extras={len(predicted-expected_ids)}",
    ))
    duplicate_predictions = sum(count - 1 for count in Counter(prediction_ids).values() if count > 1)
    checks.append(finding("prediction identity uniqueness", duplicate_predictions == 0, f"duplicates={duplicate_predictions}"))
    malformed = 0
    for row in predictions:
        probabilities = [float(row[key]) for key in ("home_win_probability", "draw_probability", "away_win_probability")]
        if any(value < 0 or value > 1 for value in probabilities) or abs(sum(probabilities) - 1) > 0.000001:
            malformed += 1
        if float(row["home_expected_goals"]) <= 0 or float(row["away_expected_goals"]) <= 0:
            malformed += 1
    checks.append(finding("prediction probability contract", malformed == 0, f"malformed={malformed}"))

    completed_ids = {
        str(row["game_id"])
        for row in matches
        if match_instant(row) <= as_of
        and row.get("home_score") is not None
        and row.get("away_score") is not None
    }
    observations = baseline.fetch_pages(
        db.table("ml_team_match_observations")
        .select("game_id,team")
        .eq("season", season)
        .eq("observation_schema_version", int(payload.get("feature_schema_version") or 1))
        .in_("league", list(TOP_FIVE))
        .order("game_id")
    )
    observation_counts = Counter(str(row["game_id"]) for row in observations)
    bad_observations = sorted(game_id for game_id in completed_ids if observation_counts[game_id] != 2)
    checks.append(finding(
        "as-of observation coverage",
        not bad_observations,
        f"completed={len(completed_ids)} invalid_side_counts={len(bad_observations)}",
    ))
    provider_gaps = provider_completion_gaps(
        completed_provider, matches, set(observation_counts), as_of
    )
    checks.append(finding(
        "provider current-result coverage",
        not provider_gaps,
        f"provider_completed={len(completed_provider)} gaps={len(provider_gaps)}"
        + (f" first={provider_gaps[0]}" if provider_gaps else ""),
    ))

    simulation_details: dict[str, Any] = {}
    for league in TOP_FIVE:
        path = args.simulations_dir / f"{league}_{season}_{forecast_kind}.json"
        league_expected = sum(1 for row in expected.values() if row["league"] == league)
        if not path.is_file():
            simulation_details[league] = {"passed": False, "reason": "missing file"}
            continue
        simulation = json.loads(path.read_text(encoding="utf-8"))
        teams = simulation.get("teams") or []
        position_ok = all(
            abs(sum(float(value) for value in team["position_probabilities"].values()) - 1) < 0.000001
            for team in teams
        )
        title_ok = abs(sum(float(team["champion_probability"]) for team in teams) - 1) < 0.000001
        rules_ok = (
            int(simulation.get("rules_version", 0)) >= 2
            if league in {"ESP-La Liga", "ITA-Serie A"}
            else int(simulation.get("rules_version", 0)) >= 1
        )
        ranking_ok = (
            simulation.get("ranking_method") == "head_to_head_mini_table"
            if league in {"ESP-La Liga", "ITA-Serie A"}
            else simulation.get("ranking_method") == "overall_table_keys"
        )
        passed = (
            simulation.get("remaining_fixtures") == league_expected
            and position_ok
            and title_ok
            and rules_ok
            and ranking_ok
        )
        simulation_details[league] = {
            "passed": passed,
            "teams": len(teams),
            "expected_fixtures": league_expected,
            "simulated_fixtures": simulation.get("remaining_fixtures"),
            "rules_version": simulation.get("rules_version"),
            "ranking_method": simulation.get("ranking_method"),
        }
    checks.append(finding(
        "league simulation bundle",
        all(value["passed"] for value in simulation_details.values()),
        f"valid={sum(value['passed'] for value in simulation_details.values())}/{len(TOP_FIVE)}",
    ))
    serie_a_path = args.simulations_dir / f"ITA-Serie A_{season}_{forecast_kind}.json"
    serie_a_playoff_modelled = False
    serie_a_playoff_policy = None
    if serie_a_path.is_file():
        serie_a = json.loads(serie_a_path.read_text(encoding="utf-8"))
        serie_a_playoff_modelled = bool(serie_a.get("special_playoff_modelled"))
        serie_a_playoff_policy = serie_a.get("special_playoff_policy")
    checks.append(finding(
        "simulation publication scope",
        serie_a_playoff_modelled,
        (
            f"Serie A special playoffs modelled with policy={serie_a_playoff_policy}"
            if serie_a_playoff_modelled
            else "Serie A title and 17th/18th playoff must be modelled before all-five table persistence"
        ),
    ))

    artifact_path = Path(str(payload["artifact"]))
    artifact_digest = hashlib.sha256(artifact_path.read_bytes()).hexdigest()
    model_rows = (
        db.table("ml_model_runs")
        .select("id,status,model_version,artifact_sha256")
        .eq("artifact_sha256", artifact_digest)
        .execute()
        .data
        or []
    )
    model_status = str(model_rows[0]["status"]) if len(model_rows) == 1 else "unregistered"
    checks.append(finding(
        "publication approval",
        model_status in PERSISTABLE_STATUSES,
        f"status={model_status}; persistence requires validated, shadow, or active",
    ))
    publication_only = {"publication approval", "simulation publication scope"}
    data_checks = [check for check in checks if check["name"] not in publication_only]
    report = {
        "generated_at": datetime.now(UTC).isoformat(),
        "season": season,
        "as_of": as_of.isoformat(),
        "forecast_kind": forecast_kind,
        "prediction_file": str(args.predictions_file.resolve()),
        "artifact_sha256": artifact_digest,
        "model_status": model_status,
        "ready_for_private_review": all(check["passed"] for check in data_checks),
        "ready_for_persistence": all(check["passed"] for check in checks),
        "checks": checks,
        "simulations": simulation_details,
    }
    output = args.output or Path("artifacts/data_quality") / f"forecast_readiness_{season}_{forecast_kind}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Forecast readiness report: {output.resolve()}")
    for check in checks:
        print(f"{'PASS' if check['passed'] else 'BLOCK'} {check['name']}: {check['detail']}")
    print(f"ready_for_private_review={report['ready_for_private_review']}")
    print(f"ready_for_persistence={report['ready_for_persistence']}")
    return 0 if report["ready_for_private_review"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
