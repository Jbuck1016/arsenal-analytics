# Stage 3 and visual-system release verification — 27 August 2026

## Production data state

- Competition scope is enforced through the canonical league views. Raw source data remains intact: 627,748 events and 430 matches; league scope contains 597,312 events and 408 matches.
- Arsenal resolves to 33 Premier League matches, not the former 54-match cross-competition pool.
- Period 5 shootout conversions are excluded from match goal totals.
- `goals_reconcile` and every error-level invariant pass. The current insight population is 916 insights across 31 clubs.
- Detector-specific sample requirements govern suppression.
- Summary publication now occurs only after verification succeeds, in the same transaction. A rollback-only synthetic error probe proved that a failed verification leaves the published timestamp unchanged.
- All public views use `security_invoker`; browser roles have no public-schema write privileges and cannot execute administrative rebuild functions.
- The Player directory reads the complete appearance population. Live data includes 3,692 substitute lineup rows and 28 players with appearances but zero starts.

The executable SQL regression suite passed against production after the final database migrations.

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
- Sixteen deterministic baselines pass at a 0.2% threshold: desktop, tablet and mobile; dark, light and monochrome; Player Compare, Team Rankings, Insights and Sequences; and the actual Player, Team and Match PNG/PDF export paths.
- The static dashboard contract suite passes every data, accessibility, density, orientation and responsive rule.

## Release gates executed

```text
PASS dashboard data contracts
PASS migration order check
PASS migration SHA-256 snapshot
PASS JavaScript syntax checks
PASS 16 visual screenshot/export comparisons
PASS production SQL regression suite
PASS production anonymous browser smoke: Validation, Methodology, Player, Team, Match, Insights, Sequences
PASS Vercel production deployment status
```

Production URL: <https://futscout.xyz>
