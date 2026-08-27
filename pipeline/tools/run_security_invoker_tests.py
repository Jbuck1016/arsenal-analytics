#!/usr/bin/env python3
"""Execute the public-view security-invoker migration in positive and negative fixtures."""
from __future__ import annotations

import argparse
import os
import shutil
import socket
import subprocess
import sys
import tempfile
from pathlib import Path


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def run(cmd: list[object], *, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run([str(x) for x in cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and result.returncode:
        raise RuntimeError(
            f"exit {result.returncode}: {subprocess.list2cmdline([str(x) for x in cmd])}\n"
            + (result.stdout + result.stderr).decode("utf-8", "replace")
        )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pg-bin", required=True, type=Path)
    parser.add_argument("--migration", type=Path)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    fixture = root / "pipeline/tools/fixture/security_invoker_fixture.sql"
    assertions = root / "pipeline/tools/fixture/assert_security_invoker.sql"
    migration = (args.migration or
                 root / "supabase/migrations/20260827180929_harden_existing_public_views.sql").resolve()
    pg = args.pg_bin.resolve()
    exe = lambda name: pg / (name + ".exe" if os.name == "nt" else name)
    initdb, pg_ctl, createdb, psql = map(exe, ("initdb", "pg_ctl", "createdb", "psql"))
    work = Path(tempfile.mkdtemp(prefix="security-invoker-e2e-"))
    cluster, server_log = work / "cluster", work / "postgres.log"
    port = free_port()
    db_url = lambda db: f"postgresql://postgres@127.0.0.1:{port}/{db}"
    started = False

    try:
        run([initdb, "-D", cluster, "-U", "postgres", "--auth=trust", "--encoding=UTF8", "--no-sync"])
        start_cmd = [pg_ctl, "-D", cluster, "-l", server_log,
                     "-o", f"-p {port} -h 127.0.0.1", "-w", "start"]
        capture = work / "pg_ctl_start.txt"
        with capture.open("wb") as stream:
            start = subprocess.run([str(x) for x in start_cmd], stdout=stream, stderr=subprocess.STDOUT)
        if start.returncode:
            raise RuntimeError(capture.read_text(encoding="utf-8", errors="replace"))
        started = True

        for db in ("security_ok", "security_blocked"):
            run([createdb, "-h", "127.0.0.1", "-p", port, "-U", "postgres", db])
            run([psql, "-X", "-v", "ON_ERROR_STOP=1", "-d", db_url(db), "-f", fixture])

        run([psql, "-X", "-v", "ON_ERROR_STOP=1", "-d", db_url("security_ok"), "-f", migration])
        positive = run([psql, "-X", "-v", "ON_ERROR_STOP=1", "-d", db_url("security_ok"), "-f", assertions])
        if b"SECURITY_INVOKER_ASSERTIONS_OK" not in positive.stdout:
            raise RuntimeError("positive fixture did not emit its success sentinel")

        run([psql, "-X", "-v", "ON_ERROR_STOP=1", "-d", db_url("security_blocked"),
             "-c", "revoke select on source_data from anon"])
        negative = run([psql, "-X", "-v", "ON_ERROR_STOP=1", "-d", db_url("security_blocked"),
                        "-f", migration], check=False)
        negative_text = (negative.stdout + negative.stderr).decode("utf-8", "replace")
        if negative.returncode == 0 or "browser roles cannot read dependencies" not in negative_text:
            raise RuntimeError("dependency-access negative fixture did not fail for the expected reason")

        rollback = run([psql, "-X", "-qAt", "-d", db_url("security_blocked"), "-c",
                        "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace "
                        "where n.nspname='public' and c.relkind='v' "
                        "and coalesce('security_invoker=true'=any(c.reloptions),false)"])
        if rollback.stdout.strip() != b"0":
            raise RuntimeError("negative fixture did not roll back all view changes")

        print("PASS positive migration execution")
        print("PASS owner, ACL, comment and reloptions preservation")
        print("PASS anon reads after caller-rights conversion")
        print("PASS missing dependency privilege aborts preflight")
        print("PASS negative transaction rolls back exactly")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    finally:
        if started:
            subprocess.run([str(pg_ctl), "-D", str(cluster), "-m", "fast", "-w", "stop"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
