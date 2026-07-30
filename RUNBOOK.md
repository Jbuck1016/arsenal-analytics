# Arsenal-analytics runbook

Two independent routines. Git carries the **site**; Supabase (cloud) carries the **data**.
The database is the same from any machine, so a fresh machine only needs `git pull` plus
the scraper env to be fully current.

Repo: `C:\Users\jbuck\arsenal-analytics` (PC) · `~/arsenal-analytics` (Mac)

---

## Routine A — Ship a site change
Run whenever new/updated `.html` (or other repo files) are handed over. Pushing also
redeploys Vercel, so it goes live in the same step.

**PC (PowerShell)**
```powershell
cd "C:\Users\jbuck\arsenal-analytics"
Move-Item -Force "$HOME\Downloads\<file>.html" ".\<file>.html"   # repeat per file
git add -A
git commit -m "<what changed>"
git push
```

**Mac (bash)**
```bash
cd ~/arsenal-analytics
mv -f ~/Downloads/<file>.html ./<file>.html                      # repeat per file
git add -A
git commit -m "<what changed>"
git push
```

---

## Routine B — Refresh the data (new matchweeks played)

**1. Scrape** (Anaconda Prompt / terminal; `conda activate <env>` first if imports fail)
```
cd "C:\Users\jbuck\arsenal-analytics"      # Mac: cd ~/arsenal-analytics
python scrape_league.py
```

**2. Refresh all analytics** (Supabase SQL editor or psql). These three lines are the
full refresh now that the sequence layer exists:
```sql
select refresh_analytics();
select build_sequences();
refresh materialized view seq_fz;
```
> If `build_sequences()` + `seq_fz` get wired into `refresh_analytics()`, this collapses to
> just `select refresh_analytics();`.

**3. Sync git only if the scrape left local files.** The scrape writes to Supabase, not the
repo, so this is usually a no-op.
```bash
git status
# only if it lists changes:
git add -A && git commit -m "data: matchweek refresh" && git push
```

**4. Verify** the new games landed (Supabase SQL editor):
```sql
select
  (select count(distinct game_id) from public.events)    as games_with_events,
  (select count(distinct game_id) from public.sequences) as games_in_sequences,
  (select count(*) from public.sequences)                as sequence_rows,
  (select max(date) from public.matches
     where game_id in (select distinct game_id from public.events)) as latest_played;
```
`games_with_events` should equal `games_in_sequences`. Baseline before this refresh: **223 games,
57,762 sequences.**

---

## Fresh machine (e.g. Mac in a week)
```bash
git clone <repo-url> ~/arsenal-analytics   # or: cd ~/arsenal-analytics && git pull
```
Site + DB are then current. Only the scraper env (soccerdata/WhoScored + Supabase creds)
needs setting up locally to run Routine B.
