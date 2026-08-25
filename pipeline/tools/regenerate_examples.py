#!/usr/bin/env python3
"""Delete and regenerate both fixture examples; optionally require clean git diff."""
from __future__ import annotations
import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--psql", required=True, type=Path)
    p.add_argument("--database", required=True)
    p.add_argument("--repo-root", type=Path)
    p.add_argument("--check", action="store_true")
    a = p.parse_args()
    root = (a.repo_root or Path(__file__).resolve().parents[2]).resolve()
    tool = root / "pipeline/tools/generate_cup_isolation.sql"
    fixture = root / "pipeline/tools/fixture"
    outputs = {
        "reverse": fixture / "EXAMPLE_reverse_fixture.sql",
        "forward": fixture / "EXAMPLE_forward_fixture.sql",
    }
    for path in outputs.values():
        path.unlink(missing_ok=True)
    for direction, path in outputs.items():
        cmd = [str(a.psql), "-X", "-qAt", "-d", a.database,
               "-v", f"direction={direction}", "-v", "expect_objects=12",
               "-v", "expect_matviews=9", "-v", "expect_views=3", "-f", str(tool)]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode:
            sys.stderr.buffer.write(result.stderr)
            return result.returncode
        path.write_bytes(result.stdout)
        if result.stderr:
            sys.stderr.buffer.write(result.stderr)
        print(f"generated {path.relative_to(root)} ({len(result.stdout)} bytes)")
    if a.check:
        cmd = ["git", "diff", "--exit-code", "--",
               "pipeline/tools/fixture/EXAMPLE_forward_fixture.sql",
               "pipeline/tools/fixture/EXAMPLE_reverse_fixture.sql"]
        result = subprocess.run(cmd, cwd=root)
        print(f"git diff regeneration check exit {result.returncode}")
        return result.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
