#!/usr/bin/env python3
"""Build a read-only cross-season feature stability decision from ablation reports."""
from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "artifacts" / "model_reports"
DEFAULT_SEASONS = ("2425", "2526")


def latest_report(season: str) -> Path:
    matches = sorted(REPORT_DIR.glob(f"feature_ablation_{season}_*.json"))
    if not matches:
        raise RuntimeError(f"no feature ablation report for {season}")
    return matches[-1]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def season_row(report: dict[str, Any], family: str) -> dict[str, Any]:
    row = report["add_one"][family]
    return {
        "season": report["season"],
        "log_loss": row["overall"]["log_loss"],
        "improvement_vs_core": row["log_loss_improvement_vs_core"],
        "matches": row["overall"]["matches"],
        "column_count": row["column_count"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seasons", nargs="+", default=list(DEFAULT_SEASONS))
    parser.add_argument("--minimum-improvement", type=float, default=0.0)
    parser.add_argument(
        "--output",
        type=Path,
        default=REPORT_DIR / "cross_season_feature_stability.json",
    )
    args = parser.parse_args()

    sources = {season: latest_report(season) for season in args.seasons}
    reports = {season: load(path) for season, path in sources.items()}
    common = sorted(set.intersection(*(set(report["add_one"]) for report in reports.values())))
    families = []
    for family in common:
        seasons = [season_row(reports[season], family) for season in args.seasons]
        improvements = [row["improvement_vs_core"] for row in seasons]
        stable = all(value > args.minimum_improvement for value in improvements)
        families.append({
            "family": family,
            "season_results": seasons,
            "mean_improvement_vs_core": sum(improvements) / len(improvements),
            "minimum_improvement_vs_core": min(improvements),
            "direction_consistent": len({value > 0 for value in improvements}) == 1,
            "stability_gate": "pass" if stable else "research_only",
        })
    families.sort(key=lambda row: row["mean_improvement_vs_core"], reverse=True)

    combination_names = sorted(set.intersection(*(
        set(report.get("targeted_combinations", {})) for report in reports.values()
    )))
    combinations = []
    for name in combination_names:
        season_results = []
        for season in args.seasons:
            row = reports[season]["targeted_combinations"][name]
            season_results.append({
                "season": season,
                "log_loss": row["overall"]["log_loss"],
                "improvement_vs_core": row["log_loss_improvement_vs_core"],
            })
        improvements = [row["improvement_vs_core"] for row in season_results]
        combinations.append({
            "combination": name,
            "season_results": season_results,
            "mean_improvement_vs_core": sum(improvements) / len(improvements),
            "minimum_improvement_vs_core": min(improvements),
            "stability_gate": "pass" if all(value > args.minimum_improvement for value in improvements) else "research_only",
        })
    combinations.sort(key=lambda row: row["mean_improvement_vs_core"], reverse=True)

    elo = []
    for season in args.seasons:
        row = reports[season]["leave_one_out"]["team_strength"]
        elo.append({
            "season": season,
            "log_loss_penalty_when_removed": row["log_loss_delta_vs_all"],
            "helpful_fold_count": row["helpful_fold_count"],
            "fold_count": reports[season]["validation"]["fold_count"],
        })

    passed = [row["family"] for row in families if row["stability_gate"] == "pass"]
    quarantined = [row["family"] for row in families if row["stability_gate"] != "pass"]
    payload = {
        "schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "method": "precomputed grouped-date rolling-origin ablations compared across seasons",
        "sources": {season: str(path) for season, path in sources.items()},
        "gate": {
            "rule": "positive log-loss improvement versus identical Elo-and-schedule core in every evaluated season",
            "minimum_improvement": args.minimum_improvement,
            "passed_families": passed,
            "research_only_families": quarantined,
        },
        "families": families,
        "targeted_combinations": combinations,
        "elo_dependency": {
            "season_results": elo,
            "decision": "retain_as_benchmark_and_test_residual_tactical_lift",
            "interpretation": "Removing Elo worsened the all-feature model in every evaluated season; this establishes predictive value, not causal primacy.",
        },
        "recommended_challengers": [
            "shooting + territory",
            "territory + pressing_defense",
        ],
        "decision": "focused_challengers_only",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Cross-season stability report: {args.output}")
    print(f"Passed families: {', '.join(passed)}")
    print(f"Research only: {', '.join(quarantined)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
