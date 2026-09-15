#!/usr/bin/env python3
"""Audit rich schema-v2 feature coverage at season-league-team-match grain."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import train_match_baselines as baseline


SEASONS = ("2324", "2425", "2526", "2627")
FAMILIES = {
    "territory": (
        "field_tilt_pct", "final_third_touches", "final_third_touches_against",
        "penalty_area_touches", "penalty_area_touches_against", "box_entries_pass",
    ),
    "expected_threat": (
        "xt_created", "xt_conceded", "xt_difference", "open_play_xt_created",
        "open_play_xt_conceded", "open_play_xt_difference",
    ),
    "possession_sequences": (
        "sequence_count", "sequence_count_against", "shot_ending_sequences",
        "shot_ending_sequences_against", "box_entry_sequences",
        "box_entry_sequences_against", "progressive_sequences", "progressive_sequences_against",
    ),
    "chance_quality": (
        "npxg_for", "npxg_against", "npxg_difference", "set_piece_xg_for", "set_piece_xg_against",
    ),
}


def coverage(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> float:
    if not rows:
        return 0.0
    return sum(row.get(field) is not None for row in rows for field in fields) / (len(rows) * len(fields))


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    db = baseline.db_client()
    fields = sorted({field for values in FAMILIES.values() for field in values})
    rows = baseline.fetch_pages(
        db.table("ml_team_match_observations")
        .select("game_id,team,season,league," + ",".join(fields))
        .eq("observation_schema_version", 2)
        .in_("season", list(SEASONS))
        .in_("league", list(baseline.TOP_FIVE))
        .order("season").order("league").order("game_id").order("team")
    )
    groups = []
    for season in SEASONS:
        for league in baseline.TOP_FIVE:
            subset = [row for row in rows if row["season"] == season and row["league"] == league]
            groups.append({
                "season": season,
                "league": league,
                "team_match_rows": len(subset),
                "families": {
                    family: {
                        "non_null_rate": coverage(subset, fields_for_family),
                        "eligible": coverage(subset, fields_for_family) >= 0.995,
                    }
                    for family, fields_for_family in FAMILIES.items()
                },
            })
    report = {
        "report_schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "grain": "season × league over team-match observation fields",
        "required_non_null_rate": 0.995,
        "groups": groups,
        "repair_queue": [
            {
                "season": row["season"], "league": row["league"], "family": family,
                "non_null_rate": result["non_null_rate"],
            }
            for row in groups for family, result in row["families"].items()
            if not result["eligible"]
        ],
        "policy": "A family is withheld from cross-season training if any required season-league block is below 99.5%.",
    }
    output = root / "artifacts" / "data_quality" / "rich_feature_coverage_by_league.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Rows audited: {len(rows)}")
    print(f"Repair queue blocks: {len(report['repair_queue'])}")
    print(f"Report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
