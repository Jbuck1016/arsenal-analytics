#!/usr/bin/env python3
"""Static and deterministic checks for the market-odds pipeline."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

import build_market_edge_report as report  # noqa: E402
import capture_market_odds as capture  # noqa: E402


migration = (ROOT / "supabase" / "migrations" / "20260918190016_market_odds_snapshots.sql").read_text(encoding="utf-8").lower()
assert "enable row level security" in migration
assert "revoke all on table public.ml_market_odds_snapshots from anon, authenticated" in migration
assert "with (security_invoker = true)" in migration
assert "captured_at < commence_time" in migration
assert "payload_hash" in migration and "unique" in migration

fair, overround = capture.fair_probabilities(2.0, 4.0, 4.0)
assert abs(sum(fair) - 1.0) < 1e-12
assert fair == [0.5, 0.25, 0.25]
assert abs(overround) < 1e-12

sample = {
    "game_id": "game-1", "source": "test", "source_event_id": "event-1",
    "bookmaker_key": "book", "market_key": "h2h", "snapshot_kind": "thursday",
    "source_updated_at": "2026-09-18T12:00:00+00:00",
    "home_odds": 2.0, "draw_odds": 4.0, "away_odds": 4.0,
}
assert capture.row_hash(sample) == capture.row_hash(dict(reversed(list(sample.items()))))

scored = [{
    "actual_index": 0,
    "model_probabilities": [0.6, 0.25, 0.15],
    "market_probabilities": [0.5, 0.3, 0.2],
}]
result = report.metrics(scored)
assert result["resolved"] == 1
assert result["model_log_loss"] < result["market_log_loss"]
assert result["model_brier"] < result["market_brier"]

source = (ROOT / "pipeline" / "capture_market_odds.py").read_text(encoding="utf-8")
assert "successful no-op" in source

print("Market odds pipeline checks passed")
