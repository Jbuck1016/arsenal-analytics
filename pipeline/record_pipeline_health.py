#!/usr/bin/env python3
"""Publish bounded Windows-task health rows to private Supabase state."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from dotenv import load_dotenv

import train_match_baselines as baseline


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="JSON file; stdin is used when omitted")
    args = parser.parse_args()
    load_dotenv(ROOT / ".env")
    if args.input:
        payload = json.loads(args.input.read_text(encoding="utf-8-sig"))
    else:
        payload = json.load(sys.stdin)
    records = payload if isinstance(payload, list) else [payload]
    db = baseline.db_client()
    for record in records:
        db.rpc(
            "record_pipeline_health",
            {
                "p_pipeline_name": record["pipeline_name"],
                "p_status": record["status"],
                "p_observed_at": record.get("observed_at"),
                "p_next_run_at": record.get("next_run_at"),
                "p_host": record.get("host"),
                "p_detail": record.get("detail") or {},
                "p_error": record.get("error"),
            },
        ).execute()
    print(f"Published {len(records)} bounded pipeline health row(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
