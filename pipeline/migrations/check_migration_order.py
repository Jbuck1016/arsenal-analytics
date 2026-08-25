#!/usr/bin/env python3
"""Repository-side migration order check.

SQL cannot verify filenames, so this covers the one ordering rule that
matters: the Stage 2 prerequisite must sort before the privilege
lockdown. CREATE OR REPLACE FUNCTION grants EXECUTE to PUBLIC, so if the
Stage 2 file ever ran after the lockdown, a clean sequential replay would
silently re-expose refresh_site_summaries() to PUBLIC.

Exits 0 on success, 1 on failure. Intended for CI or a pre-push hook.

    python3 pipeline/migrations/check_migration_order.py
"""
import os
import re
import sys

MIG_DIR = os.path.dirname(os.path.abspath(__file__))

# (must sort before, must sort after)
ORDER_RULES = [
    ("20260824_00_stage2_db_objects.sql", "20260824_01_privilege_lockdown.sql"),
    ("20260824_02_competition_registry.sql", "20260824_03_scoping_invariants.sql"),
    ("20260824_03_scoping_invariants.sql", "20260824_04_scope_view_entry_objects.sql"),
    ("20260824_04_scope_view_entry_objects.sql", "20260824_05_rebuild_safe_insight_eligibility.sql"),
]

# Files that must not come back.
FORBIDDEN = [
    "20260824_01_stage2_db_objects.sql",
    "20260824_03_cup_isolation.sql",
    "20260824_stage3_cup_isolation.sql",
]

# A migration running after the lockdown must not widen browser privileges.
GRANT_ALL = re.compile(r"grant\s+all\s+on\s+.*\bto\b.*\b(anon|authenticated|public)\b",
                       re.IGNORECASE)


def main():
    # Item 12: only NUMBERED migrations form the runnable chain. Regression
    # suites and tooling live elsewhere and are reported separately.
    all_sql = sorted(f for f in os.listdir(MIG_DIR) if f.endswith(".sql"))
    names = [f for f in all_sql if re.match(r"^\d{8}_\d{2}_", f)]
    suites = [f for f in all_sql if f not in names]
    failures = []

    for f in FORBIDDEN:
        if f in names:
            failures.append("superseded migration is present again: %s" % f)

    for earlier, later in ORDER_RULES:
        if earlier not in names or later not in names:
            failures.append("missing migration for order rule: %s before %s" % (earlier, later))
            continue
        if not earlier < later:
            failures.append("order rule broken: %s must sort before %s" % (earlier, later))

    lockdown = "20260824_01_privilege_lockdown.sql"
    if lockdown in names:
        for f in names:
            if f <= lockdown:
                continue
            path = os.path.join(MIG_DIR, f)
            with open(path, encoding="utf-8") as fh:
                for i, line in enumerate(fh, 1):
                    if line.lstrip().startswith("--"):
                        continue
                    if GRANT_ALL.search(line):
                        failures.append(
                            "%s:%d widens browser privileges after the lockdown: %s"
                            % (f, i, line.strip()))

    if failures:
        print("MIGRATION ORDER CHECK FAILED")
        for x in failures:
            print("  - %s" % x)
        return 1

    print("Migration order check passed. %d numbered migrations in the chain:" % len(names))
    for n in names:
        print("  %s" % n)
    if suites:
        print("Regression suites in this directory (not part of the chain):")
        for n in suites:
            print("  %s" % n)
    print("Tooling lives in pipeline/tools and is not a migration.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
