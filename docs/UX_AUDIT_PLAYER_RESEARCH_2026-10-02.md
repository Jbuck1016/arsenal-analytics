# Player research audit implementation

Scope: `players.html`, `search.html`, `sequences.html`; no database, authentication, production API, or model changes.

## Changes

- F04: shot xG preserves observed zero and unknown values; known totals and coverage replace the invented 0.04 fallback. Unknown marks are neutral and keyed `?`. Scatter and rankings exclude unavailable observations rather than plotting zero.
- F06: generation ownership covers Player, Rank, Scatter, Scout, Compare and Plot studio success/error writes, and Sequence candidate/similarity responses. Cleared natural-language queries cannot reappear.
- F09: mobile profile retains cohort context, collapses the directory after selection, and fixes narrow flex overflow. Search filters are an explicit mobile disclosure with local results-table scrolling. Sequence header reflows through tablet widths.
- F10/F11: native Search chips/theme button and named ranges; player selectors and metric controls labelled; Scout headers keyboard sortable with aria-sort; Player main landmark/profile h1; modal Tab containment, background inert state, Escape, return focus and filter-focus preservation.
- F12: Scatter has exact-value table; Sequence selected and overlay views include ordered action traces and explain unobserved movement links.
- F13/F27: faceted result names are profile links; all eligible shortlist records and all directory records remain browseable. TSV copy includes headers, exposure, metric, cohort, filters, full source URL and export timestamp; denied clipboard falls back to file download.
- F14: versioned URL state for Player view/entity/scope/rank/scatter/scout/compare/pillar/selected metrics; Search filters/query; Sequence candidate/selected/overlay journey. Browser Back is handled, not only in-page back controls.
- F18: Scatter axes use actual metric units; Compare shows numeric percentiles and explains own-league/role reference; filtered shot evidence distinguishes penalty-inclusive season references from open-play subsets. Sequence guide no longer claims a fixed 74,000 population or unsupported league-average xT benchmark.
- F26: Player whole-view and map exports use shared `FutScoutExports.capture` with explicit view-model metadata and full URL. Legacy export fallback no longer falsely labels a filtered map “Full season”. Search exact-data export is independent of screenshot libraries.

## Verified locally

`node pipeline/tools/test_player_research_audit.cjs`

Actual Edge/Playwright runtime, local HTTP server at port8765, all external traffic blocked or fulfilled with synthetic empty API rows. Test overrides are browser-local and never shipped as production records.

- 331 of331 synthetic players browseable;70 of70 shortlist records are profile links.
- `[0,null,0.30]` displays0.30 known xG,2/3 available.
- Delayed Scatter cannot overwrite Player. Delayed Rank, Scatter, Scout, Compare and Plot studio responses cannot replace a newer view.
- Cleared NL request cannot restore its stale answer; stale Sequence candidate response cannot replace a newer list.
- Player1→Player2 URL IDs update; browser Back restoresPlayer1.
- Modal Tab wraps, background is inert, Escape closes.
- Populated synthetic Player profile: no document horizontal overflow at320/375/390/640/768/1024/1440/1920 in both themes.
- Separate Sequence768 smoke: document width768.
- Inline scripts parse; no page errors in regression workflow.

Artifacts: `artifacts/ux-audit/player-research-tests.json`, `player-synthetic-{light,dark}-{390,1440}.png`, `search-synthetic-mobile.png`.

## Actual downloads and six-tab check

`node pipeline/tools/test_player_exports_audit.cjs`

Clicked all six actual tab buttons in the local browser with synthetic populated data. Captured a screenshot of each. Downloaded eight genuine files through the shared exporter:48-measure Player profile and50-row Scout view × light/dark × PNG/PDF. All eight nonempty; no page errors. Local retained html2canvas/jsPDF fixtures supplied the export libraries, with other external requests blocked.

Rendered PDFs using `pdftoppm`; inspected dark Player pages1–2 and light Scout pages1–3. This caught and corrected shared export conversion of metric-row buttons into run-on text, and identified undersized profile labels; integrated exporter now preserves child layout and uses18px metric-row text before A4 scaling. Scout has3 pages, repeated column headers, player names and all50 intact rows followed by the top15 chart and provenance. Player has2 pages and readable metric rows without horizontal clipping. Full source URL and selected context survive export; export time is separate from unavailable data freshness.

Files and results: `artifacts/ux-audit-player-exports/`, including `results.json`, `Player-{light,dark}.{png,pdf}`, `Scout-{light,dark}.{png,pdf}`, six tab screenshots and PDF raster inspection pages. Poppler warned about system Symbol/ArialUnicode display fonts but produced the inspected raster pages; PDF content itself is rasterized by the existing exporter.

## Verification boundaries

Synthetic fixtures are not proof of current production data accuracy. The screenshots intentionally block external font requests and therefore use local fallbacks. This subtask does not claim screen-reader certification, every possible export/filter combination, or exhaustive every-metric Cartesian coverage. Sequence population metadata remains unavailable from the current API; the UI says so rather than inferring a league baseline.
