#!/usr/bin/env python3
"""Replay every checked-in Supabase migration on a fresh local PostgreSQL."""
from __future__ import annotations
import argparse, hashlib, os, shutil, socket, subprocess, sys, tempfile
from pathlib import Path

def port():
    with socket.socket() as s: s.bind(("127.0.0.1",0)); return s.getsockname()[1]

def run(cmd, **kw):
    r=subprocess.run([str(x) for x in cmd],capture_output=True,text=True,**kw)
    if r.returncode:
        raise RuntimeError(f"FAILED ({r.returncode}): {subprocess.list2cmdline([str(x) for x in cmd])}\n{r.stdout}\n{r.stderr}")
    return r

def main():
    a=argparse.ArgumentParser();a.add_argument('--pg-bin',required=True,type=Path);a.add_argument('--python-lib',type=Path);a.add_argument('--baseline',type=Path);a.add_argument('--post-migration',type=Path);a.add_argument('--cron-shim',action='store_true');args=a.parse_args()
    if args.python_lib:
        sys.path.insert(0,str(args.python_lib))
    import psycopg
    root=Path(__file__).resolve().parents[2]
    migrations=[args.baseline.resolve()] if args.baseline else sorted((root/'supabase/migrations').glob('*.sql'))
    if args.baseline:
        digest=hashlib.sha256(args.baseline.read_bytes()).hexdigest()
        digest_file=args.baseline.with_suffix('.sha256')
        if not digest_file.exists() or digest_file.read_text(encoding='ascii').split()[0] != digest:
            raise RuntimeError(f'baseline checksum missing or stale: {digest_file}')
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
            if args.post_migration:
                if args.cron_shim:
                    conn.execute("""
                      create schema if not exists cron;
                      create table if not exists cron.job(
                        jobid bigint generated always as identity primary key,
                        jobname text unique not null,schedule text not null,
                        command text not null,active boolean not null default true
                      );
                      create or replace function cron.schedule(text,text,text) returns bigint
                      language sql as $$insert into cron.job(jobname,schedule,command)
                        values($1,$2,$3) returning jobid$$;
                      create or replace function cron.unschedule(bigint) returns boolean
                      language plpgsql as $$begin delete from cron.job where jobid=$1; return found; end$$;
                    """)
                conn.execute(args.post_migration.read_text(encoding='utf-8'))
                print(f'PASS post-migration {args.post_migration.name}')
                if args.cron_shim:
                    ready,total=conn.execute("""
                      select count(*) filter(where has_unique),count(*) from (
                        select c.oid,exists(select 1 from pg_index i where i.indrelid=c.oid
                          and i.indisunique and i.indisvalid and i.indpred is null and i.indexprs is null) has_unique
                        from pg_class c join pg_namespace n on n.oid=c.relnamespace
                        where n.nspname='public' and c.relkind='m'
                      ) q
                    """).fetchone()
                    if ready != total: raise RuntimeError(f'concurrent readiness failed: {ready}/{total}')
                    conn.execute('begin; refresh materialized view concurrently public.mv_invariant_status; rollback;')
                    print(f'PASS concurrent refresh inside transaction ({ready}/{total} matviews ready)')
            count=conn.execute("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','v','m','p')").fetchone()[0]
            if args.baseline:
                missing=conn.execute("select count(*) from unnest(array['events','matches','v_league_events','mv_shot_xg','player_search','v_match_events']) n where to_regclass('public.'||n) is null").fetchone()[0]
                mutable=conn.execute("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e') and not exists(select 1 from unnest(coalesce(p.proconfig,'{}'::text[])) x where x like 'search_path=%')").fetchone()[0]
                unpopulated=conn.execute("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='m' and not c.relispopulated").fetchone()[0]
                definer_views=conn.execute("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' and not coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']").fetchone()[0]
                anon_writes=conn.execute("select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p','v','m') and (has_table_privilege('anon',c.oid,'insert') or has_table_privilege('anon',c.oid,'update') or has_table_privilege('anon',c.oid,'delete') or has_table_privilege('anon',c.oid,'truncate'))").fetchone()[0]
                seeded=conn.execute("select (select count(*) from metric_catalog)+(select count(*) from invariants)+(select count(*) from xt_grid)").fetchone()[0]
                raw=conn.execute("""
                    select sum(n) from (
                      select count(*) n from events union all
                      select count(*) from events_cup union all
                      select count(*) from matches union all
                      select count(*) from matches_cup union all
                      select count(*) from lineups union all
                      select count(*) from lineups_cup union all
                      select count(*) from players union all
                      select count(*) from player_bio union all
                      select count(*) from insights union all
                      select count(*) from analytics_rebuild_runs union all
                      select count(*) from lafc_events union all
                      select count(*) from lafc_links union all
                      select count(*) from lafc_projects union all
                      select count(*) from lafc_todos union all
                      select count(*) from lafc_tracker_config
                    ) excluded
                """).fetchone()[0]
                if missing or mutable or unpopulated or definer_views or anon_writes or seeded == 0 or raw:
                    raise RuntimeError(f'baseline assertions failed: missing={missing}, mutable_search_path={mutable}, unpopulated={unpopulated}, definer_views={definer_views}, anon_writes={anon_writes}, seeded={seeded}, excluded_rows={raw}')
        print(f'RESET PASS: {len(migrations)} migrations; {count} public relations')
        return 0
    finally:
        if started: subprocess.run([str(exe('pg_ctl')),'-D',str(cluster),'-m','fast','-w','stop'],capture_output=True)
        shutil.rmtree(work,ignore_errors=True)
if __name__=='__main__': raise SystemExit(main())
