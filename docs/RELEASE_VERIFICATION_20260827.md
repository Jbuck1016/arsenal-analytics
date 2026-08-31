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
- The migration SHA-256 snapshot passes for all 192 frozen live-history migrations plus nine intentional repository-authored migrations. The executable checker is canonical; this sentence must be updated whenever another later migration is added.
- `pipeline/tools/test_schema_reset.py` now executes the SQL itself through psycopg on a disposable PostgreSQL cluster. The unmodified history reproducibly fails at `20260806001641_state_output_and_percentiles_safe.sql` because prior cascades removed `player_search`. `pipeline/tools/capture_canonical_baseline.sql` captures the current catalog instead of editing that frozen history; the generated squash and empty-database replay are the required replacement proof.

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

## Trust-system follow-up — 31 August 2026

- `shots_in_xg_model` now compares current-season, non-own-goal shots to the current-season model. The 28-shot gross difference is entirely intentional own-goal exclusion; unexplained omissions are 0.
- `played_without_events` now checks the canonical current-season match/event views. The three earlier warnings were archived 2025/26 Arsenal fixtures; the live count is 0.
- Bundesliga is inactive until ingestion begins. The migration refuses to deactivate it if current-season matches, events, or team-name coverage exist, so activation must arrive with the ingestion rollout and proper whitelist.
- The xG evidence now includes a genuine temporal holdout: 7,305 training shots and 1,805 later validation shots, Brier 0.07852, log loss 0.27523, 200.53 predicted goals versus 185 actual (+8.4%), maximum estimate 0.5719. This is a first out-of-time baseline, not external validation.
- The xT status surface records 96 borrowed grid cells, `fitted_on_platform_competitions = false`, and `externally_validated = false`. Its live 5.90× shot-ending directional ratio is labelled as an implementation sanity check only.
- Match shot maps now read fitted per-shot xG and scale marker area by xG. The 28 intentionally excluded own goals retain an unscaled fallback marker.
- Supabase's security advisor reports zero mutable-`search_path` application functions after pinning the 11 reported functions. Extension-owned functions were not altered.
- The only non-zero published invariant is the known `xg_bins_sparse` warning at 18; there are no error-level failures.
