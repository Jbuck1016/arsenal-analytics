#!/usr/bin/env python3
"""Static safety checks for the score-only match result watcher."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    sync_source = (ROOT / "pipeline" / "sync_match_results.py").read_text(encoding="utf-8")
    wrapper_source = (ROOT / "pipeline" / "refresh_match_results.ps1").read_text(encoding="utf-8")

    required_sync_guards = (
        'str(row["game_id"]).startswith("fd-")',
        "elif current == (None, None):",
        'raise RuntimeError("provider result conflicts with a non-null canonical score")',
        '.is_("home_score", "null").is_("away_score", "null")',
        'raise RuntimeError(f"post-write score verification failed:',
    )
    for guard in required_sync_guards:
        assert guard in sync_source, f"missing score-sync safety guard: {guard}"
    assert ".insert(" not in sync_source, "result watcher must never insert matches"
    assert ".upsert(" not in sync_source, "result watcher must never upsert matches"

    ordered_steps = (
        "pipeline\\sync_match_results.py",
        "pipeline\\score_prediction_ledger.py",
        "pipeline\\build_market_edge_report.py",
    )
    positions = [wrapper_source.index(step) for step in ordered_steps]
    assert positions == sorted(positions), "result, prediction, and market refresh steps are out of order"
    print("Match result watcher safety checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
