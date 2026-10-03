# Writing Lab and Quick ingest audit implementation

Baseline: `5020f50b6a4cab67df28c5ed4cb8d855cb5ddf45`. Branch: `codex/ux-audit-complete`.

## Scope completed

| Finding | Implemented behavior | Verification |
|---|---|---|
| F07 | Draft payload, revision, dirty state, debounce and in-flight save keyed by immutable project ID. Immediate browser-local recovery before server sync. Old responses merge without replacing newer text or the active project. Failed sync preserves local text, retry and download; leaving while dirty warns. Metadata polling never rebuilds notes/draft editors. AI is manual, project-bound, retains prior brief on error, and records source fingerprint/provenance for stale detection. | A → B → A within debounce; two captured IDs; switch during delayed save; typing during save; offline failure/reload; dirty editor focus during poll; AI reply after switch. All synthetic browser fixtures. |
| F08 | Separate evidence state (`loading`, `ready`, `empty`, `error`) per project; queued → ready initiates event fetch even from metadata polling; guarded responses; explicit retry/terminal empty state. | Ready transition without reopening, failed fetch/retry, zero records. |
| F24 | Fixed-order descriptive leads explicitly not ranked. IDs for supporting events and selected evidence/notes included in evidence pack and brief context. Source, fixture, season, loaded time (not source freshness), metric version/definitions, plot subset and raw-only status visible. Exact event table removes hover dependence. Deliberate plot PNG/PDF/SVG, complete JSON evidence and article Markdown outputs. Published clearly means bookkeeping, not external publication. | Downloaded actual PNG/PDF in both themes, SVG and JSON; IDs/metadata assertions; Poppler-rendered PDFs inspected. Selected checks expose supporting IDs; absent pass denominator is `n/a`; missing coordinates excluded, valid zero retained. |
| F25 | Both forms disable duplicate in-flight submission, validate WhoScored host/ID, check existing game before insert and preserve input on error. Retry guards; inline errors; queue status timestamps and stale-on-refresh failure handling. Ready explicitly means raw rows, not verified analytics publication. Every queue row has workspace link; only canonical competitions link to league Match. | Duplicate command → one in-memory POST; existing game → no POST or automatic retry; workspace link ID and raw/publication distinction asserted. No real submission occurred. |
| F09/F10/F12 | Native labelled controls, pressed state, live save/command statuses, named local event-table scrolling, text evidence, readable paired selectors, responsive stacks, reduced motion. Plot filter focus retained after rerender. | Both routes no page-level overflow at 320/375/390/640/768/1024/1440/1920; initial controls/no JavaScript error checks; exact-event alternative; screenshots inspected. |
| F14/F15 | Project, desk tab, plot type/team/player URL state, Back handling, compatible fixture links. Invalid workspace clears prior evidence. Terminal missing/error states preserve shell. | Desk URL/Back; incompatible team reset; invalid workspace clears plot; offline reload. |
| F26 | Plot view model passed to shared capture API: identity, source, season/date, selected subject/plot, coordinate-valid eligible/shown counts, units, orientation, loaded time and metric version. JSON preserves complete records and article text separately. | Actual downloadable light/dark PNG/PDF, JSON, SVG. Shared PDF orientation update produces one A4 portrait page for tested plot; no pitch/legend/context clipping in rendered inspection. |

## Tests and artifacts

`node pipeline/tools/test_writing_ingest_audit.cjs`

- 52 assertions pass on local headless Microsoft Edge, Playwright.
- A local HTTP server serves repository assets. **Every non-local request is intercepted**. Supabase reads/writes and brief generation use synthetic in-memory fixtures only; no production requests, queue entries, drafts or paid generations.
- CDN export-library URLs are fulfilled from local copies at `artifacts/ux-audit-writing/vendor/`; fonts are blocked so fallback fonts are exercised.
- To capture the pinned-source baseline with the same fixture: set `BASELINE_CAPTURE=1`, run the same script, unset it. It reads baseline assets through `git show`; no checkout/reset.
- `PLAYWRIGHT_MODULE` and `BROWSER_PATH` may override the machine-specific default test dependencies.

Artifacts in `artifacts/ux-audit-writing/`:

- `results.json` — exact assertions and network boundary.
- `before-writing-desktop-dark.png`, `before-quick-desktop-dark.png` — pinned source, synthetic records.
- `writing-desktop-dark.png`, `writing-mobile-light.png`, `quick-mobile-light.png` — updated routes.
- `writing-plot-dark.png`, `writing-plot-light.png`, equivalent `.pdf` — actual downloads.
- `writing-pdf-light-final.png`, `writing-pdf-dark-final.png` — Poppler inspection renders.
- `synthetic-evidence.json`, `synthetic-plot.svg` — actual downloaded source artifacts.

PDF inspection command:

`pdftoppm -scale-to 1200 -singlefile -png artifacts/ux-audit-writing/writing-plot-light.pdf artifacts/ux-audit-writing/writing-pdf-light-final`

Poppler logged missing Symbol/ArialUnicode display-font warnings. These PDFs contain rasterized chart/text plus a page footer; inspected output was readable and did not show missing glyph boxes.

## Existing checks and explicit limits

- Original `check_writing_lab.py` initially passed 11 static checks then failed its exact old `CANONICAL.has(CUR.competition)` source-string assertion. The fixed async function captures `p.competition` before awaiting. The coordinator was asked to update the assertion, not revert captured ownership.
- `check_quick_ingest.py` passed 12 static checks, then could not import backend `soccerdata` in the bundled Python runtime. No dependency installation or worker execution attempted.
- These are browser fixture validations, **not production authorization, concurrency, durability or ingestion certification**. Security policies/keys/gate were not changed. The existing browser write endpoints remain subject to the separate security remediation.
- The browser guard prevents duplicate commands within this page instance. Cross-tab/concurrent-client idempotency still depends on server constraints; no unverified guarantee is made.
- Browser-local drafts are recovery on this device/profile, not a backup or multi-device collaboration service. Storage denial is reported; download remains available. A server write returning no project is treated as unconfirmed, not saved.
- Production data/source freshness and governed publication are not inferred from an API fetch timestamp. Publication remains explicitly unverified in these views unless a future authorized backend contract supplies it.
- Real assistive technology, every arbitrary long data population, live AI service compatibility and service outage recovery against production were not exercised. The explicit test inventory above is the evidence, not a universal accessibility certificate.
- No deployment, push, migration, model change or production mutation was performed.
# Reference routes follow-up (F10/F28)

Owned follow-up: guide.html, methodology.html, validation.html, evidence-contracts.html. Added main/h1 where missing, native keyboard theme controls, keyboard quiz buttons with selected/locked state and textual answer feedback. Static examples are explicitly historical with unknown dates where no date was retained. Removed universal three-ninety and obsolete permanent 0.53-ceiling claims. Corrected the obsolete unused-substitute warning to the documented September correction. Live population differences no longer reuse a historical one-player explanation or treat missing counts as zero. Support-request failures no longer overwrite independent holdout status. Evidence definitions now pair dark surfaces, links and text.

Repository evidence: `supabase/baseline/20260831_public_schema.sql` mv_player_percentiles gate at line 4101; `pipeline/generated/stage3_cup_isolation_forward.sql` same six-ninety gate around line 1245; distinct `supabase/migrations/20260807012441_multileague_mv_player_pct.sql` three-ninety gate; `supabase/migrations/20260914180000_scope_unused_sub_minutes_check.sql` documents the unused-bench correction. These are repository contracts, NOT a fresh deployed SQL verification. The frontend three-ninety setting does not establish the database gate. No eligibility or database code was changed.

`node pipeline/tools/test_reference_audit.cjs`: 73 checks passed. Four routes, light/dark, 320/375/390/640/768/1024/1440/1920 width checks, one main/h1, native quiz/theme keyboard operation, failed population request explicit, no JS exceptions. Every external request mocked as 503; no production reads/writes. Screenshots inspected: evidence-contracts dark mobile, guide light mobile. Artifact results/screenshots: `artifacts/ux-audit-reference/`. Success-response live diagnostics, assistive-technology speech, reference print pagination and actual deployed freshness remain untested. No claim of complete manual screen-reader or all-page visual review.
