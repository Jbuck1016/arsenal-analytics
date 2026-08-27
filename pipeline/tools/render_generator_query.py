#!/usr/bin/env python3
"""Render the psql cup-isolation generator as one connector-safe SQL query.

The production generator intentionally emits many result sets for psql. The
Supabase SQL connector returns only the final result set, so this adapter turns
each top-level output SELECT into an INSERT and returns the complete generated
migration as one text value. It does not change the generator's catalog logic.
"""
from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "generate_cup_isolation.sql"
OUTPUT_MARKER = "\\echo '-- GENERATED FILE. DO NOT HAND EDIT.'"


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def render(direction: str, objects: int, matviews: int, views: int) -> str:
    source = SOURCE.read_text(encoding="utf-8")
    head, output = source.split(OUTPUT_MARKER, 1)
    head_lines = head.splitlines()

    # Remove psql-only variable setup. Keep the generator body byte-for-byte
    # apart from replacing its three variable references with session settings.
    body = "\n".join(head_lines[11:])
    body = body.replace(":'direction'", "current_setting('mig.direction')")

    output_lines = (OUTPUT_MARKER + output).splitlines()
    # These are the generator's output SELECT statements. A line beginning
    # with SELECT can also occur inside a dollar-quoted migration fragment, so
    # matching text alone would corrupt that emitted SQL.
    output_select_lines = {155, 158, 161, 214, 215, 216, 217, 219, 220, 239, 255, 258, 284, 333}
    rendered: list[str] = []
    for source_line, line in enumerate(output_lines, start=153):
        if line.startswith("\\echo "):
            rendered.append(
                "insert into _generated_migration(line) values ("
                + sql_literal(line[len("\\echo ") :].strip("'"))
                + ");"
            )
        elif source_line in output_select_lines:
            rendered.append("insert into _generated_migration(line) " + line)
        else:
            rendered.append(line)

    query = "\n".join(
        [
            f"set mig.direction={sql_literal(direction)};",
            f"set mig.expect_objects={sql_literal(str(objects))};",
            f"set mig.expect_matviews={sql_literal(str(matviews))};",
            f"set mig.expect_views={sql_literal(str(views))};",
            body,
            "create temporary table _generated_migration(ord bigint generated always as identity, line text);",
            *rendered,
            "select string_agg(line, E'\\n' order by ord) as migration from _generated_migration;",
            "",
        ]
    )
    return query.replace(":'direction'", "current_setting('mig.direction')")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--direction", choices=("forward", "reverse"), required=True)
    parser.add_argument("--objects", type=int, default=36)
    parser.add_argument("--matviews", type=int, default=28)
    parser.add_argument("--views", type=int, default=8)
    args = parser.parse_args()
    # Binary stdout keeps the generated query on LF even when the adapter runs
    # on Windows. Otherwise CRLF embedded inside dollar-quoted output becomes
    # literal carriage returns in the migration text.
    import sys
    sys.stdout.buffer.write(render(args.direction, args.objects, args.matviews, args.views).encode("utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
