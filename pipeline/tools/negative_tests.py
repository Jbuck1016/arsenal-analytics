#!/usr/bin/env python3
"""Mutate a known-good pair and prove the static validator rejects each fault."""
from __future__ import annotations
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
import re


CREATE_OBJECT = re.compile(r"^create\s+(?:materialized view|view)\s+public\.(\w+)\s+as\n.*?;\n", re.I | re.M | re.S)


def object_block(sql: str, name: str) -> str:
    for match in CREATE_OBJECT.finditer(sql):
        if match.group(1) == name:
            return match.group(0)
    raise ValueError(f"object not found: {name}")


def replace_in_object(sql: str, name: str, old: str, new: str) -> str:
    block = object_block(sql, name)
    changed = block.replace(old, new, 1)
    if changed == block:
        raise ValueError(f"mutation target {old!r} not found in {name}")
    return sql.replace(block, changed, 1)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("forward", type=Path); p.add_argument("reverse", type=Path)
    p.add_argument("--objects", type=int, required=True)
    p.add_argument("--matviews", type=int, required=True)
    p.add_argument("--views", type=int, required=True)
    a = p.parse_args()
    validator = Path(__file__).with_name("validate_generated_migration.py")
    forward = a.forward.read_text(encoding="utf-8")
    reverse = a.reverse.read_text(encoding="utf-8")
    cases = [
      ("duplicate create", "f", forward + "\n" + object_block(forward,"mv_team_match")),
      ("missing drop", "f", forward.replace("drop materialized view if exists public.mv_team_match;", "", 1)),
      ("definition drift guard removed", "f", forward.replace("DEFINITION DRIFTED", "DRIFT CHECK REMOVED", 1)),
      ("MLS fallback", "f", forward.replace("tl.league", "coalesce(tl.league, 'USA-MLS'::text)", 1)),
      ("raw read", "f", replace_in_object(forward,"mv_team_match","v_league_events","events")),
      ("quoted raw read", "f", replace_in_object(forward,"v_team_sample","v_league_sequences",'"public"."sequences"')),
      ("bad drop depth", "f", swap_first_last_drop(forward)),
      ("metadata assertion removed", "f", forward.replace("METADATA ASSERT FAILED", "METADATA CHECK REMOVED", 1)),
      ("unsafe period predicate", "f", forward.replace("period is distinct from 5", "period <> 5", 1)),
      ("cascade", "f", forward.replace("drop materialized view if exists", "drop materialized view if exists", 1).replace("public.mv_team_match;", "public.mv_team_match cascade;", 1)),
      ("psql status leakage", "f", "CREATE FUNCTION\n" + forward),
      ("forward verify removed", "f", forward.replace("select verify_rebuild();", "", 1)),
      ("reverse registry restore removed", "r", reverse.replace("jsonb_populate_record", "jsonb_record_removed", 1)),
      ("reverse hardcoded warn", "r", reverse.replace("set severity=item.severity", "set severity='warn'", 1)),
      ("reverse verify introduced", "r", reverse.replace("commit;", "select verify_rebuild();\ncommit;", 1)),
      ("reverse baseline compare removed", "r", reverse.replace("Invariant results differ", "Invariant comparison removed", 1)),
    ]
    passed = 0
    with tempfile.TemporaryDirectory(prefix="cup-negative-") as td:
        root = Path(td)
        for index, (label, side, mutated) in enumerate(cases, 1):
            f = root / f"{index:02d}-forward.sql"
            r = root / f"{index:02d}-reverse.sql"
            f.write_text(mutated if side == "f" else forward, encoding="utf-8")
            r.write_text(mutated if side == "r" else reverse, encoding="utf-8")
            cmd = [sys.executable, str(validator), str(f), str(r), "--objects", str(a.objects),
                   "--matviews", str(a.matviews), "--views", str(a.views)]
            result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            ok = result.returncode != 0
            print(("PASS" if ok else "FAIL") + f"  {label} (validator exit {result.returncode})")
            if not ok:
                print(result.stdout)
            passed += int(ok)
    print(f"negative tests: {passed}/{len(cases)} rejected")
    return 0 if passed == len(cases) else 1


def swap_first_last_drop(sql: str) -> str:
    lines = sql.splitlines()
    positions = [i for i, line in enumerate(lines) if line.lower().startswith("drop ")]
    if len(positions) >= 2:
        lines[positions[0]], lines[positions[-1]] = lines[positions[-1]], lines[positions[0]]
    return "\n".join(lines) + ("\n" if sql.endswith("\n") else "")


if __name__ == "__main__":
    sys.exit(main())
