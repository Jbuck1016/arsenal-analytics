# Historical training-data scrape

This runner archives league matches, events and lineups for prediction-model
research without changing the live current-season dashboard.

## Safety boundary

- Default mode is a read-only schedule manifest. Writes require `--execute`.
- Historical rows use the existing raw tables and explicit `matches.season`.
- Live analytical views continue to read only the season registered in
  `leagues.season`.
- Historical ingestion never calls an analytics rebuild.
- Historical ingestion does not mutate the shared `players` identity table;
  event names and lineup player IDs remain available for training joins.
- Resume detection uses a league-and-season-scoped, service-only RPC; reruns
  skip games that already have events without exposing the archive publicly.
- A consecutive-failure circuit breaker stops a league cleanly when the source
  appears blocked. Healthy runs continue until the selected season is complete.

## Order

Run and validate one season before starting the next:

1. `2526` — 2025/26
2. `2425` — 2024/25
3. `2324` — 2023/24

Each season covers Premier League, La Liga, Serie A, Bundesliga and Ligue 1.

## Verified 2025/26 manifest

The read-only production manifest on 31 August 2026 found:

| League | Played source fixtures | Complete archive feeds | Missing |
| --- | ---: | ---: | ---: |
| Premier League | 349 | 32 | 317 |
| La Liga | 380 | 0 | 380 |
| Serie A | 380 | 0 | 380 |
| Bundesliga | 306 | 0 | 306 |
| Ligue 1 | 306 | 0 | 306 |
| **Total** | **1,721** | **32** | **1,689** |

At the default 90-second average interval, the missing 2025/26 fixtures require
about 42 hours. Three seasons are approximately 130 hours before retries. Based
on the current indexed event-table footprint, the eventual archive is expected
to add roughly 6–7 GB. Recheck database capacity and billing before the first
large execution.

## Commands

Read-only manifest for 2025/26:

```powershell
python pipeline\scrape_history.py --season 2526
```

Add `--verbose-plan` only when the full fixture-by-fixture list is useful.

Two-match ingestion test:

```powershell
python pipeline\scrape_history.py --season 2526 --max-matches 2 --execute
```

Continuous resumable season run:

```powershell
powershell -ExecutionPolicy Bypass -File pipeline\run_history_nightly.ps1 `
  -Season 2526 -Execute
```

Run this with the normal visible Chrome session on the current host. Headless
Chrome failed to connect during the verified manifest, while the visible session
completed all five leagues. The `-Headless` switch remains available for a
future bounded retest, but it is not the supported nightly configuration yet.

The process runs until the selected season is complete unless it is interrupted
or the consecutive-failure circuit breaker detects source blocking. Rerun the
same command to resume after either case. After the season is complete, repeat
it with `2425`, then `2324`. `--all-seasons` exists for supervised continuous
runs but should not be the first production invocation.

The default 60–120 second interval is deliberate anti-block protection. Do not
reduce it until a bounded test demonstrates that WhoScored remains stable.
