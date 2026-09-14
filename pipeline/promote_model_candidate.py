#!/usr/bin/env python3
"""Explicitly advance an exact reviewed candidate to validated or shadow.

Dry-run is the default. The command enforces training -> validated -> shadow,
rechecks artifact/report digests, and cannot activate or publish a model.
"""

from __future__ import annotations

import argparse
from datetime import UTC, datetime
from pathlib import Path

import register_model_candidate as registration
import train_match_baselines as baseline


TRANSITIONS = {"validated": "training", "shadow": "validated"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-run-id", type=int, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--validation-report", type=Path, required=True)
    parser.add_argument("--to", choices=sorted(TRANSITIONS), required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()

    _, _, artifact_digest, report_digest = registration.load_evidence(args.artifact, args.validation_report)
    db = baseline.db_client()
    rows = db.table("ml_model_runs").select("id,status,artifact_sha256,metrics").eq("id", args.model_run_id).execute().data or []
    if len(rows) != 1:
        raise RuntimeError("model run id did not resolve to exactly one row")
    row = rows[0]
    if row.get("artifact_sha256") != artifact_digest:
        raise RuntimeError("registered artifact digest does not match reviewed bytes")
    if (row.get("metrics") or {}).get("validation_report_sha256") != report_digest:
        raise RuntimeError("registered validation evidence does not match reviewed report")
    required_status = TRANSITIONS[args.to]
    if row.get("status") != required_status:
        raise RuntimeError(f"{args.to} requires current status {required_status}; found {row.get('status')}")

    print(f"Promotion plan: model_run_id={args.model_run_id} {required_status} -> {args.to} execute={args.execute}")
    if not args.execute:
        print("Dry run only; registry status was not changed")
        return 0
    values = {"status": args.to}
    if args.to == "shadow":
        values["promoted_at"] = datetime.now(UTC).isoformat()
    updated = db.table("ml_model_runs").update(values).eq("id", args.model_run_id).eq("status", required_status).execute().data or []
    if len(updated) != 1 or updated[0].get("status") != args.to:
        raise RuntimeError("compare-and-set promotion did not update exactly one model")
    print(f"Model {args.model_run_id} is now {args.to}; no forecasts were generated or published")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
