#!/usr/bin/env python3
"""Download the catalog capture produced by capture_canonical_baseline.sql."""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "supabase" / "baseline" / "20260831_public_schema.sql"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    load_dotenv(ROOT / ".env")
    client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])
    rows = []
    start = 0
    while True:
        page = (
            client.table("_schema_baseline_export")
            .select("seq,section,ddl")
            .order("seq")
            .range(start, start + 499)
            .execute()
            .data
        )
        rows.extend(page)
        if len(page) < 500:
            break
        start += 500
    if not rows:
        raise RuntimeError("schema capture buffer is empty")
    chunks = []
    last_section = None
    for row in rows:
        if row["section"] != last_section:
            chunks.append(f"\n-- === {row['section']} ===\n")
            last_section = row["section"]
        chunks.append(row["ddl"].rstrip() + "\n")
    content = "".join(chunks).lstrip()
    digest = hashlib.sha256(content.encode()).hexdigest()
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != content:
            raise SystemExit("FAIL canonical baseline differs from live catalog capture")
        print(f"PASS canonical baseline unchanged ({len(rows)} statements, sha256 {digest})")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(content, encoding="utf-8", newline="\n")
    (args.output.with_suffix(".sha256")).write_text(
        f"{digest}  {args.output.name}\n", encoding="ascii", newline="\n"
    )
    print(f"WROTE {args.output} ({len(rows)} statements, sha256 {digest})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
