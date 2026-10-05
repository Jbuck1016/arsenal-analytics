# Post-verification repair — 5 October 2026

Baseline: `4d8acfb95ee553818e06fc4e22b4846810e7938d`, confirmed unchanged on remote main before edits.
Scope: the supplied FutScout Post Codex Verification and original 28-finding audit. Preserve previous fixes; no production mutations, authentication/permission changes, analytical definition changes, or backend publication changes.

## Integrated work checklist

- [x] Writing drafts, save reconciliation, evidence reentry and recovery — local regressions
- [x] Evidence predicates, stable player selection, provenance and brief freshness — source + local tests
- [x] Match request ownership, Network population, exact counts and unknown fixtures — source + local tests
- [x] Player/Sequence restoration and modal ownership — implementation; tested cases below
- [x] Nullable metrics, units, cohorts and reference scope — scoped implementation
- [x] Keyboard semantics, navigation and explanatory states — scoped checks below
- [x] Atomic ingestion command snapshots — mocked requests only
- [x] Immutable card-owned export context — asynchronous mutation regression + real downloads
- [x] Regression and responsive/theme checks — completed local matrix, not full production acceptance
- [x] Per-finding evidence and remaining limitations recorded

## What changed

Writing Lab: acknowledged local revisions remain authoritative against stale GETs; one evidence promise is shared across A→B→A reentry; brief generation updates the active draft before further typing; content fingerprints include events, source, notes and selected evidence; notebook refresh does not replace the editor. Local-storage failures no longer claim recovery succeeded. Territory/box event IDs use the same coordinate/team predicates as the claim. Player selection and brief aggregation use saved player IDs, with explicit name fallback for ID-less evidence. Raw links update with the workspace and clear for invalid/route-only states.

Match: list/event/deep-link generations prevent old responses replacing current selection; Network consistently uses starters, regardless of entry through All/home/away; Key Passes disclosure counts its exact rows. Unknown/invalid fixture links terminate rather than retaining a stale match.

Players/Sequences: cold Studio initialization is awaited before URL settings are applied; Scout value mode and sort, map settings, layers, event filters and omitted defaults restore. Category dialogs invalidate pending Rank drill requests. Null/non-finite metrics remain unavailable rather than becoming zero or average. Compare discloses eligible directory N and explicitly says per-metric N is unavailable. Sequence similarity declares unavailable cohort metadata instead of implying a verified league/season population. Sequence cross-page navigation now uses the shared registry; header wraps under enlarged layout.

Other pages: nullable team percentages, Search clipboard-unavailable fallback and metric-specific TSV units, forecast first-load status, Market valuation dates and visible concentration text, explicit Insight empty causes and Glossary saved-reference scope.

Submissions: URL/game/competition/season are captured before awaits. Input changed during submission is preserved. Retry PATCHes are conditional on `scrape_status=error`, request the returned record, and require a confirmed queued status. No worker scheduling or processing logic changes.

Exports: clone content, canvas pixels, context and URL before loading libraries. Profile map exports cannot inherit a closed drill's fixture filter; Studio/drill exports retain their own scope. Duplicate URL text is omitted from metadata when already present in the source footer.

## Verification performed

All commands run from this implementation clone, using bundled Node and Edge. External traffic is blocked or replaced with synthetic data in the browser suites. No production POST/PATCH, brief-generation request, worker trigger or paid API call was made.

| Command under `pipeline/tools/` | Result this turn |
|---|---|
| `test_post_verification.cjs` | 22 passing checks: Writing reentry, saved revision, brief preservation, content fingerprint, denied storage, same-name IDs; Network entry equivalence, list race, unknown fixture; cold Studio, missing values, modal race, export scope, Scout, route defaults; submission snapshot/preserved input/rejected retry; immutable export; absent/denied clipboard TSV downloads; no script exceptions |
| `test_audit_static.cjs` | 18 routes, 35 inline scripts, shared script parsed; 4 contracts pass |
| `test_writing_ingest_audit.cjs` | 52 passing checks, including real JSON/SVG/PNG/PDF downloads and 8 widths |
| `test_player_research_audit.cjs` | 331-player directory; five view-race guards; xG `[0,null,.30]` gives .30 known / 2 of 3 coverage; 16 populated width/theme cases; 70 linked Search rows; Sequence race; no script errors |
| `test_ux_match_teams.cjs` | 17 non-empty filter contracts plus identity/null-xG assertions pass |
| `test_ux_match_teams_browser.cjs` | 62 checks, no script errors |
| `test_audit_shared.cjs` | All coefficients and forecasts, stable fixture history, 18-link navigation, 230 Market players/20 clubs, actual 50-row PNG/PDF downloads pass |
| `test_reference_audit.cjs` | 73 checks pass |
| `test_audit_navigation_contrast.cjs` | 72 navigation normal/hover foreground-background pairs >=4.5:1 |
| `audit_browser_smoke.cjs` | 288 route × width × theme states; no reported page overflow/script errors/missing destinations. Network-blocked shell states, not 288 populated workflows |
| `test_post_verification_accessibility.cjs` | 32 local states: 8 routes × 2 themes × touch-emulated or CSS-200%-zoom; reduced motion, 18-link menu, Escape/focus, no page overflow |
| `test_player_exports_audit.cjs` | Six views visited; 8 real Player/Scout PNG/PDF files, light/dark, no script errors |
| `test_model_exports_audit.cjs` | 12 real model PNG/PDF downloads |

Artifacts: `artifacts/ux-audit-post-verification/`, `artifacts/ux-audit/after/`, `artifacts/ux-audit-player-exports/`, and the existing Writing/model export artifact directories. These are ignored local evidence, not published research data. Results JSON records exact cases. Test counts are not additive independent guarantees.

Visually inspected this turn: restored Studio screenshot (direction label fully visible), exported Player light PNG, and page 1 rendered from the actual Player light PDF. PDF text and bars remain readable; the full profile is multipage, not shrunk to one page. Poppler reported missing Symbol/ArialUnicode display-font warnings while rendering; the inspected page still rendered. Not every generated file or PDF page was visually inspected. External webfonts were blocked in isolated tests, so these images exercise fallback fonts.

Production read-only observation: the existing deployed Players page loaded a Bundesliga Scatter view with 9 eligible players. A Pass accuracy axis was selected through the UI. This is baseline production, not evidence of these unshipped fixes. No production acceptance claim is made.

## Original 28 findings: closure ledger

`Local` means source repair and listed isolated checks, **not deployed closure**. `Partial` means a specific acceptance gap remains. Earlier fixes are preserved rather than rewritten wholesale.

| ID | Current local evidence | Status / remaining acceptance |
|---|---|---|
| F01 | Paired navigation hover themes; actual exports | Local; all chart-ink contrast not recertified |
| F02 | All/home/away Network membership; stable Writing player IDs | Local; production identities not independently re-audited |
| F03 | 17 non-empty plot filters; Key Passes exact count | Local |
| F04 | Nullable percentages/pillars/chain/scatter/Sequence values; zero-valid xG fixture | Local; no exhaustive database-column audit |
| F05 | Existing conceded-map zero-own-shot regression retained | Local |
| F06 | List/deep-link/view/modal generations; reverse-response tests | Local; not every multi-await interleaving enumerated |
| F07 | Successful-save then stale GET; generated brief then typing; both persistence failures | Local; cross-device conflict resolution not implemented |
| F08 | A→B→A shared evidence load; ready transitions; failure/retry | Local |
| F09 | 288 shell states, populated Player/Writing tests, 32 enlarged/touch cases | Partial: physical mobile and native-browser 200% zoom untested |
| F10 | Named controls, sort keyboard handlers, Sequence pressed states | Partial: no screen-reader certification |
| F11 | Late Rank response cannot replace category dialog; existing focus/inert/Escape tests | Local |
| F12 | Exact event/scatter/Sequence disclosures; Market concentration and date text | Local |
| F13 | 70 linked results; absent and denied clipboard each produce an actual contextual TSV download; explicit units | Local |
| F14 | Cold Studio restored; Scout show/sort; profile maps; omitted defaults; Sequence generation guard | Local; not exhaustive all-tab Back/Forward combinations |
| F15 | Unknown Match/Workspace clears stale data; explicit retry/empty causes | Local |
| F16 | Shared 18-destination registry; obsolete Player/Sequence menu implementation removed | Local; other legacy contextual links intentionally remain |
| F17 | Theme, reflow and reduced-motion checks | Partial: contrast checks target navigation, not every color pair |
| F18 | Units and unavailable cohort/sample metadata; card-specific export scope | Local; upstream metric definitions unchanged |
| F19 | 230-player/20-club tests retained; valuation dates and concentration text added | Local |
| F20 | All coefficient rows, fixed axis test retained | Local |
| F21 | Filtered-empty vs no directory coverage vs no qualifying insights | Local source + reference checks |
| F22 | Real reference summaries retained; saved population explicitly labeled | Local |
| F23 | All predictions; initial result-check message and retry retained | Local |
| F24 | Full content fingerprint; notebook update; numerical/evidence predicates; real evidence downloads | Local mocked generation; live AI deliberately untested |
| F25 | Immutable submission fields; changed form preserved; conditional confirmed retry | Local mocked requests; concurrent server idempotency not claimed |
| F26 | Pre-await content/context/URL snapshot; actual downloads; representative PNG/PDF visual review | Partial: not every card/export format/page inspected |
| F27 | 331-player directory regression retained; explicit zero result | Local |
| F28 | Honest saved-reference/Compare/Sequence cohort labels | Local; upstream eligibility and permissions unchanged |

## Release boundaries, impact and rollback

This is an isolated local application repair. No production deploy, database migration, RLS/grant/auth change, analytical rebuild, scraper change, model lifecycle change, or frozen forecast overwrite was performed. Original user notes/data were not rewritten.

Expected impact: fewer stale views/lost local edits, more accurate unavailable/scope labels, one shared navigation menu on Players/Sequences. Legacy Writing player-name URLs restore only if unambiguous; ambiguous names fall back to All players. A retry racing a worker state change is rejected and asks for refresh rather than overwriting the worker state. Saved local revisions remain preferred in the current browser session; simultaneous edits from another device are not conflict-merged.

Before deployment: review this branch, rerun static/targeted checks, verify remote main has not advanced, and approve application deployment. Then verify the deployed asset version and perform authenticated read-only checks of representative matches, player plots, Writing workspace reentry and exports. Production write workflows still require a safe staging/synthetic owner-authorized environment; they must not be tested against production by implication.

Rollback: revert this repair commit as a whole (or redeploy verified baseline `4d8acfb95ee553818e06fc4e22b4846810e7938d`) through the existing Git/Vercel workflow. There are no migrations to reverse. Preserve local drafts and downloaded recovery files; do not clear browser storage as a rollback step.

The local implementation is ready for review, but this report intentionally does not mark all 28 findings as fully accepted in production.
