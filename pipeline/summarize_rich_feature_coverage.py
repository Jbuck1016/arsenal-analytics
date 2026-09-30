#!/usr/bin/env python3
"""Turn the four schema-v2 audits into one explicit backfill decision."""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path


SEASONS = ("2324", "2425", "2526", "2627")
HISTORICAL = ("2324", "2425", "2526")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--league-coverage-report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.league_coverage_report:
        source = json.loads(args.league_coverage_report.read_text(encoding="utf-8"))
        groups = source["groups"]
        families = sorted({family for group in groups for family in group["families"]})
        coverage_by_family = {}
        readiness_by_family = {}
        for family in families:
            coverage_by_family[family] = {}
            readiness_by_family[family] = {}
            for season in SEASONS:
                season_groups = [group for group in groups if group["season"] == season]
                total = sum(group["team_match_rows"] for group in season_groups)
                coverage_by_family[family][season] = (
                    sum(group["team_match_rows"] * group["families"][family]["non_null_rate"]
                        for group in season_groups) / total if total else 0.0
                )
                readiness_by_family[family][season] = bool(season_groups) and all(
                    group["team_match_rows"] > 0 and group["families"][family]["eligible"]
                    for group in season_groups
                )
        source_audits = {"league_coverage": str(args.league_coverage_report)}
        limitation = (
            "Eligibility is based on non-null team-match observation fields, not a proof "
            "that a feature improves out-of-season predictions."
        )
    else:
        audits = {
            season: json.loads((root / "artifacts" / "data_quality" / f"model_data_quality_v2_{season}.json").read_text(encoding="utf-8"))
            for season in SEASONS
        }
        families = sorted({family for audit in audits.values() for family in audit["family_coverage"]})
        coverage_by_family = {
            family: {season: audits[season]["family_coverage"][family]["non_null_rate"] for season in SEASONS}
            for family in families
        }
        readiness_by_family = {
            family: {season: audits[season]["family_coverage"][family]["eligible"] for season in SEASONS}
            for family in families
        }
        source_audits = {
            season: str(root / "artifacts" / "data_quality" / f"model_data_quality_v2_{season}.json")
            for season in SEASONS
        }
        limitation = (
            "The saved audits establish season-level coverage. League-level rates require a fresh "
            "Supabase read and remain pending while the project REST service is unavailable."
        )
    rows = []
    for family in families:
        coverage = coverage_by_family[family]
        historical_ready = all(readiness_by_family[family][season] for season in HISTORICAL)
        current_ready = readiness_by_family[family]["2627"]
        if historical_ready and current_ready:
            decision = "eligible_for_training_and_live_inference"
            action = "retain and test in chronological challengers"
        elif current_ready and not historical_ready:
            decision = "historical_backfill_required"
            action = "backfill from source event data; do not impute missing seasons"
        else:
            decision = "coverage_repair_required"
            action = "repair extraction before modeling"
        rows.append({
            "family": family,
            "coverage_by_season": coverage,
            "historical_ready": historical_ready,
            "current_ready": current_ready,
            "decision": decision,
            "action": action,
        })
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "grain": "team-match observation fields aggregated by season",
        "source_audits": source_audits,
        "families": rows,
        "decision": {
            "trainable_now": [row["family"] for row in rows if row["historical_ready"] and row["current_ready"]],
            "backfill_before_training": [row["family"] for row in rows if row["decision"] == "historical_backfill_required"],
            "policy": "Missing rich historical families are never replaced with zeros or broad imputation.",
        },
        "limitation": limitation,
    }
    output = args.output or root / "artifacts" / "data_quality" / "rich_feature_coverage_decision.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Trainable now: {', '.join(report['decision']['trainable_now'])}")
    print(f"Historical backfill: {', '.join(report['decision']['backfill_before_training'])}")
    print(f"Report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
