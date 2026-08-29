# Stage 3 and visual-system release verification — 27 August 2026

## Production data state

- Competition and season scope are enforced through the canonical league views. Raw source data remains intact at 627,748 events and 430 matches; the live current-season league scope contains 550,822 events and 370 matches.
- The earlier 33-match result exposed a second defect: it combined 32 Premier League matches from 2025/26 with 1 from 2026/27. The current-season boundary now resolves Arsenal to 1 active-season Premier League match while retaining older rows only in the raw archive.
- Period 5 shootout conversions are excluded from match goal totals.
- `goals_reconcile` and every error-level invariant pass. The current insight population is 896 insights across 30 MLS clubs; European insights are intentionally suppressed because no European club has reached six current-season matches.
- Detector-specific sample requirements govern suppression.
- Summary publication now occurs only after verification succeeds, in the same transaction. A rollback-only synthetic error probe proved that a failed verification leaves the published timestamp unchanged.
- All public views use `security_invoker`; browser roles have no public-schema write privileges and cannot execute administrative rebuild functions.
- The Player directory reads the complete appearance population. Live data includes 3,692 substitute lineup rows and 28 players with appearances but zero starts.

The executable SQL regression suite passed against production after the final database migrations.

## Current-season production audit — 28 August 2026

- The atomic migration rebuilt 82 analytical objects (58 materialized views and 24 views) and committed in 13 minutes.
- All 106 current-season club rows exactly match their event-derived match counts. Premier League clubs are uniformly at 1 match; Arsenal is at 1, not 33 or 54.
- Player exposure has zero violations across every league. The highest Premier League player exposure is 1.00 nineties.
- Current team sample ranges are: Premier League 1; La Liga 1–2; Ligue 1 1; Serie A 1; MLS 20–22.
- All 34 raw-reading analytical entry points now resolve through the four current-season sources. The catalogue audit found zero raw-table bypasses.
- Raw history was conserved inside the migration and rechecked after commit.
- The season catalogue is selectable by `anon` and `authenticated` because caller-rights canonical views require access to their dependency; it contains only already-public match and registry fields. Every public view uses `security_invoker`, and intended browser-facing scoped views remain readable.
- A browser smoke test exposed an anonymous Team-map timeout after scoping. The added `events(team, game_id)` index reduced the measured Arsenal action query from about 2.2 seconds to 7 milliseconds.
- The Supabase migration ledger recorded the production migration as `20260829000555_current_season_analytics_boundary.sql`.

## Migration verification

- The generated cup-isolation forward and reverse SQL were both executed against fresh disposable PostgreSQL databases.
- Forward assertions, reverse assertions, exact baseline restoration, topology checks, negative tests and deterministic regeneration all passed before production application.
- The production forward application and finalization migrations completed; the reverse remains a tested recovery artifact and was not applied to production.
- The migration SHA-256 snapshot passes for all 192 recorded migrations plus the three intentional later migrations.
- The repository now includes `pipeline/tools/test_schema_reset.py`, which replays the complete history against disposable PostgreSQL. It exposes an older migration-history defect at `20260806001605_player_stints_and_squad_role_safe.sql`: an historical cascade removed objects that later migrations assume still exist. A canonical squashed baseline is still required before claiming `supabase db reset` support; this long-term item is not disguised as complete.

## Visual verification

- Player action layers have colour-independent markers and route patterns.
- Pitch orientation is explicit and shared across pass, shot, carry, receipt and zone rendering.
- Player mobile overview is collapsible; Team mobile Rankings uses the complete table instead of an unreadably compressed all-team chart.
- Repeated chip/legend counts were removed where they duplicated the same population.
- Quadrants are limited to the two defensible style/involvement relationships and explicitly avoid quality claims.
- Eighteen deterministic baselines pass at a 0.2% threshold: desktop, tablet and mobile; dark, light and monochrome; Player Compare, Team Rankings, Insights, Sequences, Validation and Methodology; and the actual Player, Team and Match PNG/PDF export paths.
- The static dashboard contract suite passes every data, accessibility, density, orientation and responsive rule.

## Release gates executed

```text
PASS dashboard data contracts
PASS migration order check
PASS migration SHA-256 snapshot
PASS JavaScript syntax checks
PASS 18 visual screenshot/export comparisons
PASS production SQL regression suite
PASS production anonymous browser smoke: Validation, Methodology, Player, Team, Match, Insights, Sequences
PASS Vercel production deployment status
```

Production URL: <https://futscout.xyz>
