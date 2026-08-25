#!/usr/bin/env python3
"""End-to-end execution harness for the generated fixture migrations."""
from __future__ import annotations
import argparse
import hashlib
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import re
from pathlib import Path


class Log:
    def __init__(self): self.parts: list[str] = []
    def phase(self, name: str):
        self.parts.append(f"\n{'='*78}\nPHASE: {name}\n{'='*78}\n")
    def command(self, cmd, result, redirected: Path | None = None):
        self.parts.append("COMMAND: " + subprocess.list2cmdline([str(x) for x in cmd]) + "\n")
        if redirected is not None:
            data = redirected.read_bytes()
            self.parts.append(f"STDOUT: redirected to {redirected} ({len(data)} bytes, sha256={hashlib.sha256(data).hexdigest()})\n")
        elif result.stdout:
            output="\n".join(line.rstrip() for line in result.stdout.decode("utf-8","replace").replace("\r\n","\n").replace("\r","\n").splitlines())
            self.parts.append("STDOUT:\n"+output+"\n")
        else: self.parts.append("STDOUT: <empty>\n")
        if result.stderr:
            error="\n".join(line.rstrip() for line in result.stderr.decode("utf-8","replace").replace("\r\n","\n").replace("\r","\n").splitlines())
            self.parts.append("STDERR:\n"+error+"\n")
        else: self.parts.append("STDERR: <empty>\n")
        self.parts.append(f"EXIT STATUS: {result.returncode}\n")
    def text(self): return "".join(self.parts)


def run(log: Log, name: str, cmd, *, cwd=None, stdout_file: Path | None = None, check=True):
    log.phase(name)
    result = subprocess.run([str(x) for x in cmd], cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if stdout_file is not None and result.returncode == 0:
        stdout_file.write_bytes(result.stdout)
    log.command(cmd, result, stdout_file if stdout_file is not None and stdout_file.exists() else None)
    if check and result.returncode:
        raise RuntimeError(f"{name} failed with exit {result.returncode}")
    return result


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0)); return s.getsockname()[1]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--pg-bin", required=True, type=Path)
    p.add_argument("--keep-temp", action="store_true")
    p.add_argument("--update-examples", action="store_true",
                   help="replace checked-in examples with this run's exact generated output")
    a = p.parse_args()
    pg = a.pg_bin.resolve(); root = Path(__file__).resolve().parents[2]
    fixture = root / "pipeline/tools/fixture/fixture.sql"
    snapshot_sql = root / "pipeline/tools/fixture/state_snapshot.sql"
    assert_forward = root / "pipeline/tools/fixture/assert_forward.sql"
    generator = root / "pipeline/tools/generate_cup_isolation.sql"
    validator = root / "pipeline/tools/validate_generated_migration.py"
    negatives = root / "pipeline/tools/negative_tests.py"
    regenerator = root / "pipeline/tools/regenerate_examples.py"
    results_path = root / "pipeline/tools/fixture/END_TO_END_TEST_RESULTS.txt"
    work = Path(tempfile.mkdtemp(prefix="cup-isolation-e2e-")); log = Log(); port = free_port()
    cluster = work / "cluster"; server_log = work / "postgres.log"
    psql = pg / ("psql.exe" if os.name == "nt" else "psql")
    initdb = pg / ("initdb.exe" if os.name == "nt" else "initdb")
    pg_ctl = pg / ("pg_ctl.exe" if os.name == "nt" else "pg_ctl")
    createdb = pg / ("createdb.exe" if os.name == "nt" else "createdb")
    env_db = lambda db: f"postgresql://postgres@127.0.0.1:{port}/{db}"
    started = False
    try:
        run(log,"local PostgreSQL initdb",[initdb,"-D",cluster,"-U","postgres","--auth=trust","--encoding=UTF8","--no-sync"])
        # postgres.exe inherits anonymous pipes on Windows even after pg_ctl
        # exits. Capture pg_ctl through a real file so communicate() cannot
        # wait forever for the long-lived server to close a pipe handle.
        start_cmd=[pg_ctl,"-D",cluster,"-l",server_log,"-o",f"-p {port} -h 127.0.0.1","-w","start"]
        log.phase("local PostgreSQL start")
        start_capture=work/"pg_ctl_start.txt"
        with start_capture.open("wb") as capture:
            start_result=subprocess.run([str(x) for x in start_cmd],stdout=capture,stderr=subprocess.STDOUT)
        captured=start_capture.read_bytes()
        completed=subprocess.CompletedProcess(start_cmd,start_result.returncode,captured,b"")
        log.command(start_cmd,completed)
        if start_result.returncode: raise RuntimeError(f"local PostgreSQL start failed with exit {start_result.returncode}")
        started=True
        for db in ("regen_fixture","execution_fixture","cte_guard_fixture"):
            run(log,f"create fresh database {db}",[createdb,"-h","127.0.0.1","-p",str(port),"-U","postgres",db])
            run(log,f"fresh fixture creation ({db})",[psql,"-X","-v","ON_ERROR_STOP=1","-d",env_db(db),"-f",fixture])

        forward = work / "forward.sql"; reverse = work / "reverse.sql"
        common = ["-X","-qAt","-d",env_db("execution_fixture"),"-v","expect_objects=12","-v","expect_matviews=9","-v","expect_views=3","-f",generator]
        run(log,"generator: reverse",[psql,*common[:4],"-v","direction=reverse",*common[4:]],stdout_file=reverse)
        run(log,"generator: forward",[psql,*common[:4],"-v","direction=forward",*common[4:]],stdout_file=forward)
        if a.update_examples:
            (root/"pipeline/tools/fixture/EXAMPLE_forward_fixture.sql").write_bytes(forward.read_bytes())
            (root/"pipeline/tools/fixture/EXAMPLE_reverse_fixture.sql").write_bytes(reverse.read_bytes())
        log.phase("seed-to-seed topology assertion")
        depths={name:int(depth) for name,depth in re.findall(r"^-- DEPTH (\w+)=(\d+)$",forward.read_text(encoding="utf-8"),re.M)}
        topology_ok=depths.get("mv_team_breakdown",-1)>depths.get("v_team_sample",-1)
        log.parts.append(f"v_team_sample depth={depths.get('v_team_sample')}\n")
        log.parts.append(f"mv_team_breakdown depth={depths.get('mv_team_breakdown')}\n")
        log.parts.append(f"RESULT: {'PASS' if topology_ok else 'FAIL'}\nEXIT STATUS: {0 if topology_ok else 1}\n")
        if not topology_ok: raise RuntimeError("seed-to-seed edge missing from topology")

        cte_sql=("drop materialized view mv_team_lanes; "
                 "create materialized view mv_team_lanes as with events as (select 1 x) "
                 "select m.game_id,m.home_team team from matches m cross join events;")
        run(log,"CTE guard setup",[psql,"-X","-v","ON_ERROR_STOP=1","-d",env_db("cte_guard_fixture"),"-c",cte_sql])
        cte_cmd=[psql,"-X","-qAt","-d",env_db("cte_guard_fixture"),"-v","direction=forward",
                 "-v","expect_objects=12","-v","expect_matviews=9","-v","expect_views=3","-f",generator]
        cte_result=run(log,"CTE collision negative test",cte_cmd,check=False)
        cte_output=(cte_result.stdout+cte_result.stderr).decode("utf-8","replace")
        if cte_result.returncode==0 or "Raw-table CTE collision" not in cte_output:
            raise RuntimeError("CTE collision guard did not fail with the expected error")
        run(log,"static validator",[sys.executable,validator,forward,reverse,"--objects","12","--matviews","9","--views","3"])
        run(log,"all negative tests",[sys.executable,negatives,forward,reverse,"--objects","12","--matviews","9","--views","3"])
        baseline_file=work/"baseline.json"
        baseline_result=run(log,"capture exact baseline",[psql,"-X","-qAt","-d",env_db("execution_fixture"),"-f",snapshot_sql],stdout_file=baseline_file)
        baseline=baseline_result.stdout
        run(log,"execute generated forward migration",[psql,"-X","-v","ON_ERROR_STOP=1","-d",env_db("execution_fixture"),"-f",forward])
        run(log,"forward assertions",[psql,"-X","-v","ON_ERROR_STOP=1","-d",env_db("execution_fixture"),"-f",assert_forward])
        run(log,"execute generated reverse migration",[psql,"-X","-v","ON_ERROR_STOP=1","-d",env_db("execution_fixture"),"-f",reverse])
        restored_file=work/"restored.json"
        after_result=run(log,"capture restored baseline",[psql,"-X","-qAt","-d",env_db("execution_fixture"),"-f",snapshot_sql],stdout_file=restored_file)
        after=after_result.stdout
        log.phase("exact baseline comparison")
        equal = baseline == after
        log.parts.append(f"baseline sha256={hashlib.sha256(baseline).hexdigest()}\nrestored sha256={hashlib.sha256(after).hexdigest()}\n")
        log.parts.append(f"RESULT: {'EXACT MATCH' if equal else 'MISMATCH'}\nEXIT STATUS: {0 if equal else 1}\n")
        if not equal: raise RuntimeError("restored fixture differs from exact baseline")

        # Prove the checked-in examples are reproducible with a literal git-diff check.
        repro = work / "repro-repo"
        shutil.copytree(root / "pipeline",repro / "pipeline",
                        ignore=shutil.ignore_patterns("__pycache__","*.pyc","END_TO_END_TEST_RESULTS.txt"))
        run(log,"example check: initialize disposable git repo",["git","init"],cwd=repro)
        run(log,"example check: commit exact inputs and examples",["git","add","pipeline/tools"],cwd=repro)
        run(log,"example check: create baseline commit",["git","-c","user.name=fixture-test","-c","user.email=fixture@test.invalid","commit","-m","fixture baseline"],cwd=repro)
        run(log,"example regeneration (delete + regenerate + git diff)",[
            sys.executable,repro/"pipeline/tools/regenerate_examples.py","--psql",psql,
            "--database",env_db("regen_fixture"),"--repo-root",repro,"--check"],cwd=repro)

        log.phase("SUMMARY")
        log.parts.append("ALL REQUIRED PHASES PASSED\nEXIT STATUS: 0\n")
        with results_path.open("w", encoding="utf-8", newline="\n") as results:
            results.write(log.text())
        print(log.text())
        return 0
    except Exception as exc:
        log.phase("SUMMARY"); log.parts.append(f"FAILED: {exc}\nEXIT STATUS: 1\n")
        with results_path.open("w", encoding="utf-8", newline="\n") as results:
            results.write(log.text())
        print(log.text()); return 1
    finally:
        if started:
            subprocess.run([str(pg_ctl),"-D",str(cluster),"-m","fast","-w","stop"],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        if not a.keep_temp: shutil.rmtree(work,ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
