# FutScout audit implementation — 2 October 2026

Branch: `codex/ux-audit-complete`. Baseline/remote main verified: `5020f50b6a4cab67df28c5ed4cb8d855cb5ddf45`.

Implementation covers all 28 findings; verification boundaries below remain explicit. **Not pushed, merged or deployed. Production rollout requires approval.** No authentication, policies, database objects, models, frozen predictions, worker schedules or production records changed. The separate dirty backend checkout was not touched.

## Finding ledger

| ID | Implemented | Verification / boundary |
|---|---|---|
| F01 | Paired overlay/export surfaces and active/hover text | 72 normal/hover navigation contrast pairs >=4.5:1; actual exports |
| F02 | Canonical fixture participants, player identity and network names | Synthetic All/home/away/alias checks |
| F03 | Consistent plot filters, including Shape/Dominance/Key Passes | All 17 non-empty plot contracts and both-theme renders |
| F04 | Missing xG remains missing, zero remains valid; unavailable isn't average | `[0,null,.30]` = .30 known xG, 2/3 coverage |
| F05 | Conceded-map fixture membership independent of own shots | Zero-own-shot fixture tested |
| F06 | Async generation/subject guards | Reverse-response Player/Teams/Search/Sequence tests |
| F07 | Project-owned drafts/revisions, saves and local recovery | Late saves, switching, typing during save, offline/reload |
| F08 | Ready transition fetches evidence; empty/error/retry explicit | Queued→ready and evidence failure tests |
| F09 | Reachable narrow tabs, filters and profile context | 18 routes ×8 widths ×2 themes, plus populated tests |
| F10 | Native controls, named fields, keyboard sort/quiz/timeline and landmarks | Browser keyboard assertions, not screen-reader certification |
| F11 | Dialog focus containment/Escape/return/background isolation | Player and Match tests |
| F12 | Exact data alternatives to hover-only marks | Event tables, scatter/sequence traces, Writing trace |
| F13 | Search profile links and complete contextual TSV | 70/70 linked shortlist; stale NL suppression |
| F14 | URL/Back continuity and stable identities | Player, Model Lab fixture/reload, Writing, Match/Team tests |
| F15 | Explicit failure/empty states; shell retained | Blocked-network matrix, retry controls and stale-subject clearing |
| F16 | One 18-destination registry/home grouping/disclosure | All18 links on each route; stable sizing; stale numbering removed |
| F17 | Semantic themes, fallback type, local overflow, reduced motion | 288 route states; targeted contrast and screenshot inspection |
| F18 | Units, population, season/filter scope and saved-shot wording | Source/unit/filter tests; provider qualifiers not re-certified |
| F19 | No220-player/16-club caps; square-root/population disclosure | 230 players and20 clubs tested |
| F20 | All coefficients, stable global axis, ordered values | All60 saved terms tested |
| F21 | Empty insights no longer imply average performance | Directory includes zero-read teams; retry and factual copy |
| F22 | Invented histogram removed | Real min/median/max/N only; static regression |
| F23 | All forecasts/status filter/result-feed retry | Bundle count matches; no30 cap; forecasts unchanged |
| F24 | Reproducible Writing pack, IDs/provenance, stale AI and exports | Mocked flows; real JSON/SVG/PNG/PDF downloads |
| F25 | Duplicate in-flight guards; raw-ready != published | Mocked POST count/existing-ID tests; no server-idempotency claim |
| F26 | Explicit context, full-width capture, readable rows, pagination/headers and CSV | Actual Player/Scout/Match/Squad/Writing/model/forecast/outlook exports |
| F27 | Full player directory | 331/331 reachable |
| F28 | Source-specific eligibility and historical reference copy | Distinct3/6-ninety repository views; deployed gate not asserted |

## Tests and evidence

- `test_audit_static.cjs`: 18 routes,35 inline scripts and shared script parse; four contract checks.
- `audit_browser_smoke.cjs`: 288 route/theme/width states; no page exceptions or document overflow in the completed run. Empty/failure coverage does not imply populated correctness.
- `test_audit_navigation_contrast.cjs`: 72 normal/hover pairs >=4.5:1.
- `test_audit_shared.cjs`: 15 model/market/history/shared-download checks.
- `test_writing_ingest_audit.cjs`: 52 mocked workflow assertions.
- `test_reference_audit.cjs`: 73 reference-route checks.
- `test_player_research_audit.cjs`: directory, all six view races, missing xG, modal/history and populated responsive checks.
- `test_player_exports_audit.cjs`: six Player tabs; eight actual PNG/PDFs, long-profile and50-row Scout inspection.
- `test_ux_match_teams.cjs`: all17 non-vacuous filter/identity contracts.
- `test_ux_match_teams_browser.cjs`: 62 checks; actual Match and50-row Squad exports.
- `test_model_exports_audit.cjs`: 12 actual coefficient/forecast/outlook outputs. PDF inspection found and fixed animation fading, collapsed-detail overlap and wide-table clipping.
- `check_writing_lab.py`: 18 existing static checks pass. These source assertions do **not** verify deployed security.
- Existing player metric-unit check passes. Quick-ingest backend check passed12 static checks before missing bundled `soccerdata` blocked its import; no worker launched or dependency installed.
- `git diff --check`: clean. No package/build framework is present; syntax/runtime/regression tests apply.

Tests are under `pipeline/tools/`. Browser runs use installed Edge via Playwright because agent-browser CLI was absent. External requests were blocked or served synthetic fixtures; export libraries came from local test copies. No production test records or mutating calls.

Detailed inventories: [Player research](UX_AUDIT_PLAYER_RESEARCH_2026-10-02.md), [Match/Teams](UX_AUDIT_MATCH_TEAMS_2026-10-02.md), [Writing/References](UX_AUDIT_WRITING_INGEST_VERIFICATION.md).

## Before/after and downloads

Locally retained, reproducible artifacts are excluded from Git (baseline archives/vendor copies/hundreds of generated images):

- [Before dark Model Lab navigation](../artifacts/ux-audit/before/model-lab-dark-390.png) / [after](../artifacts/ux-audit/after/model-lab-dark-390.png). All route captures in `artifacts/ux-audit/before` and `after`.
- Populated screenshots/results: `artifacts/ux-audit/`.
- Player/Scout: `artifacts/ux-audit-player-exports/`.
- Writing evidence/downloads: `artifacts/ux-audit-writing/`.
- Reference keyboard/reflow: `artifacts/ux-audit-reference/`.
- [Inspected full-width outlook](../artifacts/ux-audit-model-exports/outlook-dark-page1.png), [forecast](../artifacts/ux-audit-model-exports/forecast-light-page1.png), plus source PNG/PDFs in that folder.

## Limits and rollout approval

Current deployed percentile eligibility, live source freshness, production aliases/qualifiers and authenticated journeys are not verified by synthetic tests. No statistical/database gate was changed to fit copy. Cross-client duplicate prevention and multi-device draft conflict handling still require server contracts; browser-local recovery is not a backup. Security remains a separate workstream.

Keyboard behavior is tested, but real assistive-technology speech, browser200% zoom and every possible contrast pair are not certified. Eight-width checks are not a substitute for those claims. Coincident network-node labels can overlap; exact-data alternatives remain available. CDN failure can prevent raster/PDF output and is reported.

Legacy redirects are unchanged. Unlinked support/mockup HTML files were not deleted or promoted into the18-destination navigation. No public preview was created because deployment is approval-gated.

After approval: review the isolated commit, verify remote main again, deploy through the existing GitHub/Vercel workflow, and validate authenticated owner access/real fixture context before production promotion. Do not reopen anonymous access to make views pass.

Rollback: revert the isolated implementation commit and redeploy the baseline. No database restoration is needed. Browser-local Writing recovery drafts are not deleted by rollback.
