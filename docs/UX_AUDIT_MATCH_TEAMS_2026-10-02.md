# Match / Team implementation evidence

Local branch `codex/ux-audit-complete`; no production API writes, deployment, model change or permission change. Tests intercept external requests with synthetic responses; screenshots are **synthetic**, not production evidence.

## Implemented

- F02: Compare uses canonical fixture pair, not directory sentinel. Timeline, Momentum and player comparison use active event-team identity. Home/away headings resolve schedule aliases. Colliding surnames retain full names in network nodes and connection lists.
- F03: Shape and Dominance retain supported half/time/outcome filters. Network and Combos are classified team-level in titles and summaries; Network node positions now use filtered inputs. Key passes apply the common pass filter without deleting intervening actions before linking the pass and shot. Team-only unsupported player/position filters and carry-outcome limits are disclosed. Summaries use the same filtered input as plots.
- F04: Team xG preserves zero and missing separately; known totals and shot coverage are printed. Null team KPIs/scatter/rank values are not coerced to zero. Missing sequence comparison reads unavailable. Match season cells and known-only summary denominators preserve missingness.
- F05: Conceded scope uses `mv_team_match` fixture membership, independent of own shots. Eligible fixture count is disclosed.
- F06: Team async requests capture view generation, team, tab and filters; stale success/error/cache assignments are discarded. Match loading and season loading have request ownership; cell evidence has instance identity and close guards.
- F09/F10: Match workspace tabs stay visible at narrow widths; concept caveats remain available. Keyboard minute start/end/reset controls accompany drag timeline. Player rows, season sorting/cell evidence receive keyboard equivalents; Team fixtures have real match links.
- F11: Match comparison/cell dialogs have accessible names, initial focus, focus containment, background inertness, Escape and return focus. No privileged behavior changes.
- F12: Every Match plot includes an on-demand exact-input table; Team scatter and shot marks have exact table/list alternatives. Existing hover remains, with canvas letterboxing coordinates corrected.
- F14: Match game/team/view/plot/player/half/outcome/position/window/compare state and Team subject/tab/league/map/axis/ranking state serialize into URLs, with popstate restoration and value validation.
- F15: Empty/All-teams season state clears prior table, totals and trend. Failed Match/season/Team loading has terminal error and retry rather than indefinite spinner.
- F18: Shot summary uses the same recorded saved/goal categories as markers, explicitly not an independently verified on-target count. Team sequence copy refers to stored comparison pool instead of inventing league metadata. Squad no longer asserts an unverified universal six-nineties threshold.
- F26: Per-Match export context records explicit filters, subject, fixture and source. Team export context records view/league/map/axis scope. Team full-view PDF delegates to the shared paginated exporter instead of one-page shrink-to-fit.

## Verification run

`node pipeline/tools/test_ux_match_teams.cjs`

Pass: both pages' inline-JS syntax; all 17 plot half/time contracts; Shape/Dominance retention; key-pass outcome restriction; All-teams/alias/player/surname identity; Team stale-view ownership; missing/zero display; missing z-score; zero-shots-for membership; 0.30 known xG and 2 of 3 coverage.

`node pipeline/tools/test_ux_match_teams_browser.cjs`

Pass: 52 recorded browser checks, zero page JS errors. Chromium/Edge headless, external requests intercepted. All 17 plots render and expose exact tables in light/dark. Match tabs remain reachable at 320, 375, 390, 640, 768, 1024, 1440 and 1920 CSS px. All-teams Compare and Momentum show no sentinel. Comparison dialog focuses Close and Escape closes. Team conceded map includes a fixture with zero own shots and three opponent shots; 0.30 / 2 of 3. A delayed Matches response cannot overwrite the newer Team Profile.

Artifacts: `artifacts/ux-audit/match-teams-browser.json`, `match-synthetic-light.png`, `match-synthetic-dark.png`, `teams-conceded-synthetic-light.png`, `teams-conceded-synthetic-dark.png`.

Visual inspection caught and fixed clipped tall comparison pitches. Network names now disambiguate identities; overlapping synthetic positions can still overlap text, with full exact-data alternatives available. Blocked remote fonts expose legacy font fallbacks; shared theme integration owns typography.

## Not certified by these tests

### Additional acceptance completed

- Extended browser suite: 62 checks, no page errors, including real downloads of Match PNG/PDF and 50-player Squad PNG/PDF in both themes using local cached renderer libraries. No external APIs were contacted. Team PNG now uses the same complete-scroll/context exporter as PDF.
- Inspected rasterized Match PDF and Squad PDF page two. Squad is two A4 pages, repeated table header, rows through player 50 retained. Match export had a real long-name stats collision; fixed stats text fitting and inspected the regenerated artifact. Plot title, fixture, explicit half/time scope, full pitch and attacking direction are retained.
- Non-vacuous selected-player/period/time/outcome matrix now tests all 17 plot filters. Team-level player exclusions and carry outcome limitations are explicitly declared, rather than silently claimed supported.
- Browser Back returns Team Profile to the 50-row Squad. Match URL restoration restores plot and selected time window. Full authenticated reload against actual production data remains untested.
- Captured and inspected Team light-mode 200% CSS zoom at 640px: tabs wrap and controls remain reachable, content scrolls vertically. This is not a full screen-reader or exhaustive contrast certification.
- Remaining network concern: identical synthetic average positions can overlap player labels on the canvas. Full names and exact evidence remain available; no claim is made that all real-world label collisions are solved.

The earlier limitations below describe the original test run; actual download and selected filter/Back coverage are superseded by these additional checks.

- Production database rows, aliases not present in the synthetic fixture, empirical shot-provider qualifier correctness, or true historic season membership beyond the selected aggregate view's existing scope.
- Exhaustive cross-product of all filters and all plots, or every Match/Team tab's Back/reload behavior. URL parsing/serialization is implemented, but those broader interactive journeys need the integrated suite.
- Actual downloaded PNG/PDF artifacts from these pages, long Squad pagination and shared-export row continuity; shared exporter integration requires actual file inspection.
- Screen-reader sampling, all rendered contrast pairs, 200% zoom, and every Team responsive layout.
- Momentum cumulative index and season-trend match/rolling values now have exact tables as well; they are syntax-checked but their keyboard/screen-reader interaction is not certified by the recorded browser suite.

Rollback: restore only these two HTML files and their uniquely named tests from the baseline commit. No database rollback is needed because this work makes no database changes.
