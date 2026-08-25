#!/usr/bin/env python3
"""Static safety checks. Runtime tests remain mandatory and are separate."""
from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path

RAW = ("events", "matches", "sequences", "lineups")
DROP = re.compile(r"^drop\s+(materialized view|view)\s+if exists\s+public\.(\w+);", re.I | re.M)
CREATE = re.compile(r"^create\s+(materialized view|view)\s+public\.(\w+)\s+as\n(.*?);\n", re.I | re.M | re.S)
DEPTH = re.compile(r"^-- DEPTH (\w+)=(\d+)$", re.M)
STATUS = re.compile(r"^(?:CREATE|DROP|SELECT|INSERT|UPDATE|DELETE|SET|DO|ALTER|GRANT|REVOKE|COMMENT|BEGIN|COMMIT)(?: [A-Z]+)*(?: \d+)*$", re.M)
STRIP = re.compile(r"'(?:[^']|'')*'|--[^\n]*", re.S)


def raw_reads(body: str) -> list[str]:
    clean = STRIP.sub(" ", body)
    ctes = {m.group(1).lower() for m in re.finditer(
        r"(?:with|,)\s+(?:recursive\s+)?\"?(\w+)\"?\s+as\s*\(", clean, re.I)}
    found = []
    for m in re.finditer(r"\b(?:from|join)\s+(?:(?:public|\"public\")\s*\.\s*)?\"?(\w+)\"?", clean, re.I):
        name = m.group(1).lower()
        if name in RAW and name not in ctes:
            found.append(name)
    return found


def validate(path: Path, direction: str, objects: int, matviews: int, views: int) -> list[str]:
    sql = path.read_text(encoding="utf-8")
    failures: list[str] = []

    def check(label: str, condition: bool, detail=""):
        print(("PASS  " if condition else "FAIL  ") + label + (f" [{detail}]" if detail and not condition else ""))
        if not condition:
            failures.append(f"{path.name}: {label}")

    created = [(k.lower(), n, body) for k, n, body in CREATE.findall(sql)]
    dropped = [(k.lower(), n) for k, n in DROP.findall(sql)]
    names = [n for _, n, _ in created]
    depths = {n: int(d) for n, d in DEPTH.findall(sql)}
    check("unique creates", len(names) == len(set(names)))
    check("drop/create sets identical", sorted(n for _, n in dropped) == sorted(names))
    check(f"object count {objects}", len(names) == objects, len(names))
    check(f"matview count {matviews}", sum(k == "materialized view" for k, _, _ in created) == matviews)
    check(f"view count {views}", sum(k == "view" for k, _, _ in created) == views)
    check("depth manifest complete", set(depths) == set(names), set(depths) ^ set(names))
    create_depths = [depths.get(n, -1) for _, n, _ in created]
    drop_depths = [depths.get(n, -1) for _, n in dropped]
    check("create depth nondecreasing", create_depths == sorted(create_depths), create_depths)
    check("drop depth nonincreasing", drop_depths == sorted(drop_depths, reverse=True), drop_depths)
    executable = STRIP.sub(" ", sql)
    check("no executable CASCADE", not re.search(r"\bcascade\b", executable, re.I))
    check("one transaction", len(re.findall(r"^begin;$", sql, re.M)) == 1 and len(re.findall(r"^commit;$", sql, re.M)) == 1)
    check("no psql status leakage", STATUS.search(sql) is None)
    check("no raw writes", not re.search(r"\b(?:insert into|update|delete from)\s+(?:public\.)?(?:events|matches|sequences|lineups)\b", executable, re.I))
    check("bidirectional preflight", "MISSING from live" in sql and "EXTRA in live" in sql)
    check("preflight covers kind/depth/hash", all(x in sql for x in ("KIND CHANGED", "DEPTH CHANGED", "DEFINITION DRIFTED")))
    check("exact metadata runtime assertion", "METADATA ASSERT FAILED" in sql and all(x in sql for x in ("reloptions", "indexes", "acl", "comment", "owner")))

    offenders = [(n, raw_reads(body)) for _, n, body in created]
    offenders = [(n, hits) for n, hits in offenders if hits and not (direction == "forward" and n == "mv_game_goals")]
    if direction == "forward":
        check("no raw reads outside match-fact exception", not offenders, offenders)
        gg = [body for _, n, body in created if n == "mv_game_goals"]
        check("null-safe shootout rule", bool(gg) and "period is distinct from 5" in gg[0])
        check("no MLS fallback", "USA-MLS" not in "\n".join(body for _, _, body in created))
        check("raw conservation assertion", "Raw data changed" in sql)
        check("forward calls verify_rebuild", "select verify_rebuild();" in sql)
        check("forward promotes only after zero check", "Scoping violations" in sql and "set severity='error'" in sql)
    else:
        check("original definitions restored", "period is distinct from 5" not in "\n".join(body for _, _, body in created))
        check("reverse never calls verify_rebuild", "select verify_rebuild();" not in sql)
        check("reverse compares captured invariant baseline", "Invariant results differ" in sql)
        check("reverse restores exact registry JSON", "jsonb_populate_record" in sql and "fixture original registry note" in sql)
        check("reverse restores captured severities", "baseline jsonb" in sql and "set severity=item.severity" in sql)
        check("reverse does not hardcode warn", "set severity='warn'" not in sql and "set severity = 'warn'" not in sql)
    return failures


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("forward", type=Path)
    p.add_argument("reverse", type=Path)
    p.add_argument("--objects", type=int, required=True)
    p.add_argument("--matviews", type=int, required=True)
    p.add_argument("--views", type=int, required=True)
    a = p.parse_args()
    print(f"=== {a.forward} (forward) ===")
    failures = validate(a.forward, "forward", a.objects, a.matviews, a.views)
    print(f"\n=== {a.reverse} (reverse) ===")
    failures += validate(a.reverse, "reverse", a.objects, a.matviews, a.views)
    print("\n" + ("ALL STATIC CHECKS PASSED" if not failures else f"STATIC VALIDATION FAILED ({len(failures)})"))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
