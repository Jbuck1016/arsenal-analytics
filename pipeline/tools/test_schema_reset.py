#!/usr/bin/env python3
"""Replay every checked-in Supabase migration on a fresh local PostgreSQL."""
from __future__ import annotations
import argparse, os, shutil, socket, subprocess, tempfile
from pathlib import Path

def port():
    with socket.socket() as s: s.bind(("127.0.0.1",0)); return s.getsockname()[1]

def run(cmd, **kw):
    r=subprocess.run([str(x) for x in cmd],capture_output=True,text=True,**kw)
    if r.returncode:
        raise RuntimeError(f"FAILED ({r.returncode}): {subprocess.list2cmdline([str(x) for x in cmd])}\n{r.stdout}\n{r.stderr}")
    return r

def main():
    a=argparse.ArgumentParser();a.add_argument('--pg-bin',required=True,type=Path);args=a.parse_args()
    root=Path(__file__).resolve().parents[2]; migrations=sorted((root/'supabase/migrations').glob('*.sql'))
    work=Path(tempfile.mkdtemp(prefix='schema-reset-'));cluster=work/'cluster';log=work/'postgres.log';p=port();started=False
    exe=lambda n: args.pg_bin/(n+'.exe' if os.name=='nt' else n)
    try:
        run([exe('initdb'),'-D',cluster,'-U','postgres','--auth=trust','--encoding=UTF8','--no-sync'])
        # On Windows postgres inherits anonymous pipe handles from pg_ctl.
        # Capture through a real file so subprocess.communicate cannot wait on
        # handles held by the long-lived server process.
        start_capture=work/'pg_ctl_start.txt'
        with start_capture.open('w',encoding='utf-8') as out:
            r=subprocess.run([str(exe('pg_ctl')),'-D',str(cluster),'-l',str(log),
                              '-o',f'-p {p} -h 127.0.0.1','-w','start'],stdout=out,stderr=subprocess.STDOUT,text=True)
        if r.returncode: raise RuntimeError(start_capture.read_text(encoding='utf-8'))
        started=True
        url=f'postgresql://postgres@127.0.0.1:{p}/postgres'
        # Minimal Supabase role surface required by the checked-in DDL. This is
        # equivalent to the roles supplied by `supabase start` around Postgres.
        run([exe('psql'),'-X','-v','ON_ERROR_STOP=1','-d',url,'-c',
             'create role anon nologin; create role authenticated nologin; create role service_role nologin;'])
        for i,m in enumerate(migrations,1):
            r=subprocess.run([str(exe('psql')),'-X','-v','ON_ERROR_STOP=1','-d',url,'-f',str(m)],capture_output=True,text=True)
            if r.returncode:
                print(f'FAIL {i}/{len(migrations)} {m.name}\n{r.stdout}\n{r.stderr}')
                return 1
            print(f'PASS {i}/{len(migrations)} {m.name}')
        check=run([exe('psql'),'-X','-qAt','-d',url,'-c',"select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','v','m','p');"])
        print(f'RESET PASS: {len(migrations)} migrations; {check.stdout.strip()} public relations')
        return 0
    finally:
        if started: subprocess.run([str(exe('pg_ctl')),'-D',str(cluster),'-m','fast','-w','stop'],capture_output=True)
        shutil.rmtree(work,ignore_errors=True)
if __name__=='__main__': raise SystemExit(main())
