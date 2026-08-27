#!/usr/bin/env python3
"""Verify the fetched live Supabase migration snapshot and later migrations."""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase/migrations"
MANIFEST = ROOT / "supabase/LIVE_HISTORY_MANIFEST.sha256"
NAME_RE = re.compile(r"^(\d{14})_([a-z0-9_]+)\.sql$")


def main() -> int:
    failures: list[str] = []
    expected: dict[str, str] = {}
    for line_number, line in enumerate(MANIFEST.read_text(encoding="utf-8").splitlines(), 1):
        match = re.fullmatch(r"([0-9a-f]{64})  (\d{14}_[a-z0-9_]+\.sql)", line)
        if not match:
            failures.append(f"manifest line {line_number} is malformed")
            continue
        expected[match.group(2)] = match.group(1)

    files = sorted(MIGRATIONS.glob("*.sql"))
    versions: dict[str, str] = {}
    for path in files:
        match = NAME_RE.fullmatch(path.name)
        if not match:
            failures.append(f"invalid migration filename: {path.name}")
            continue
        version = match.group(1)
        if version in versions:
            failures.append(f"duplicate migration version {version}: {versions[version]}, {path.name}")
        versions[version] = path.name

    for name, digest in expected.items():
        path = MIGRATIONS / name
        if not path.exists():
            failures.append(f"live-history migration missing: {name}")
            continue
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != digest:
            failures.append(f"live-history migration changed: {name}")

    cutoff = max(name[:14] for name in expected)
    historical_extras = [p.name for p in files if p.name[:14] <= cutoff and p.name not in expected]
    if historical_extras:
        failures.append("unmanifested migration at or before live-history cutoff: "
                        + ", ".join(historical_extras))

    later = [p.name for p in files if p.name[:14] > cutoff]
    if failures:
        for failure in failures:
            print("FAIL ", failure)
        return 1

    print(f"PASS {len(expected)} live-history migrations match SHA-256 manifest")
    print(f"PASS migration versions are unique and filenames are canonical")
    print(f"PASS {len(later)} later migration(s): {', '.join(later) if later else 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
