#!/usr/bin/env python3
"""Replay every checked-in Supabase migration on a fresh local PostgreSQL."""
from __future__ import annotations
import argparse, os, shutil, socket, subprocess, sys, tempfile
from pathlib import Path

def port():
    with socket.socket() as s: s.bind(("127.0.0.1",0)); return s.getsockname()[1]

def run(cmd, **kw):
    r=subprocess.run([str(x) for x in cmd],capture_output=True,text=True,**kw)
    if r.returncode:
        raise RuntimeError(f"FAILED ({r.returncode}): {subprocess.list2cmdline([str(x) for x in cmd])}\n{r.stdout}\n{r.stderr}")
    return r

def main():
    a=argparse.ArgumentParser();a.add_argument('--pg-bin',required=True,type=Path);a.add_argument('--python-lib',type=Path);a.add_argument('--baseline',type=Path);args=a.parse_args()
    if args.python_lib:
        sys.path.insert(0,str(args.python_lib))
    import psycopg
    root=Path(__file__).resolve().parents[2]
    migrations=[args.baseline.resolve()] if args.baseline else sorted((root/'supabase/migrations').glob('*.sql'))
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
        with psycopg.connect(url,autocommit=True) as conn:
            conn.execute('create schema if not exists extensions; create role anon nologin; create role authenticated nologin; create role service_role nologin;')
            for i,m in enumerate(migrations,1):
                try:
                    conn.execute(m.read_text(encoding='utf-8'))
                except Exception as exc:
                    print(f'FAIL {i}/{len(migrations)} {m.name}\n{exc}')
                    return 1
                print(f'PASS {i}/{len(migrations)} {m.name}')
            count=conn.execute("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','v','m','p')").fetchone()[0]
            if args.baseline:
                missing=conn.execute("select count(*) from unnest(array['events','matches','v_league_events','mv_shot_xg','player_search','v_match_events']) n where to_regclass('public.'||n) is null").fetchone()[0]
                mutable=conn.execute("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e') and not exists(select 1 from unnest(coalesce(p.proconfig,'{}'::text[])) x where x like 'search_path=%')").fetchone()[0]
                seeded=conn.execute("select (select count(*) from metric_catalog)+(select count(*) from invariants)+(select count(*) from xt_grid)").fetchone()[0]
                raw=conn.execute("select (select count(*) from events)+(select count(*) from matches)+(select count(*) from lineups)").fetchone()[0]
                if missing or mutable or seeded == 0 or raw:
                    raise RuntimeError(f'baseline assertions failed: missing={missing}, mutable_search_path={mutable}, seeded={seeded}, raw_rows={raw}')
        print(f'RESET PASS: {len(migrations)} migrations; {count} public relations')
        return 0
    finally:
        if started: subprocess.run([str(exe('pg_ctl')),'-D',str(cluster),'-m','fast','-w','stop'],capture_output=True)
        shutil.rmtree(work,ignore_errors=True)
if __name__=='__main__': raise SystemExit(main())
