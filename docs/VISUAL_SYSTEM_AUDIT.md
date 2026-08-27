# Visual system audit

Reviewed against the live local dashboard on 27 August 2026. This pass covered the Player pass, shot, carry and scatter views; Team season maps and League Map; and Match pass and shot views. The review used live Supabase-backed renders at desktop and phone widths, not markup inspection alone.

## What changed in this pass

### Player

- The complete appearance population now feeds the player directory, so substitutes are not lost when role metadata is absent or starts are zero.
- All pitch primitives share one WhoScored-to-screen Y transform. Attack is left to right; the attacking right side is drawn at the bottom of the horizontal pitch.
- Every horizontal pitch now states that attacking right is the bottom edge.
- Pass, carry and combined views open on a 6 by 4 pattern summary. Individual events remain a drill-down.
- On single-column layouts the pitch now appears before the long metric table.
- Nine overview cards fit on one desktop row, moving the visual answer higher in the viewport.
- Scatter plots now state the relationship, population, units and median context; show the percentile legend; and do not invent negative axis space for metrics that cannot be negative.
- Shot maps now include a proportional symbol key for 0.05, 0.20 and 0.50 xG rather than a text-only list.
- Plot PDFs use a compressed high-quality image rather than embedding a multi-megabyte lossless canvas.
- Incomplete pass vectors are dashed and labelled as such, so success versus failure does not depend on green versus red alone.

### Match

- The first passing view is Progressive rather than the all-pass hairball.
- Every vertical Match panel states that attack is bottom to top and team right is screen right.
- Dense team-level Progressive views aggregate the strongest repeated completed routes. Player selections and smaller samples retain event-level vectors.
- The all-pass drill-down fades dense team context and tells the viewer to select a player or time window to trace routes.
- Shot markers are uniform when xG is unavailable. Distance remains hover detail and is no longer encoded as a false chance-quality proxy.
- Incomplete pass vectors use a dashed treatment in addition to colour.
- Visualization selectors expose button roles, keyboard activation and live pressed state.

### Team

- Season passing, carrying and combined maps open in Pattern mode, using repeated 6 by 4 zone flows rather than thousands of overlapping paths.
- Individual-event drill-downs cap rendered SVG density with a deterministic sample from the returned population. The full population, displayed count and refinement instruction are shown together.
- Team exports render from a fully expanded clone instead of clipping the scrolling dashboard at the viewport edge; PDFs use the compressed export path.
- The League Map now states the relationship, scope, units and median basis.
- Its axes cannot extend below zero when both displayed metrics are nonnegative.
- Only the selected team and structural X/Y extremes are labelled. Every dot retains exact values on hover.

## Visual principles now enforced

1. **Pattern first, evidence second.** Season-scale plots open on an aggregate that reveals structure. Raw events are an intentional drill-down.
2. **Never encode an unavailable measure.** If xG is absent, marker area does not pretend distance is chance quality.
3. **State the question and population.** Relationship plots identify both variables, scope, units and comparison basis on the canvas.
4. **Orientation is explicit.** Every pitch states the attack direction; transforms are shared rather than repeated ad hoc.
5. **Density is disclosed.** Sampling never changes the stated population and is called out beside the visual.
6. **The visual answer gets layout priority.** On narrow screens the pitch precedes supporting tables.

## Remaining work, in priority order

### P1 — next visual implementation pass

- Add automated visual baselines for the export layouts. Team sampled-event PNG/PDF, Player plot PNG/PDF and Match flow PNG were generated in this pass; all PNGs were visually inspected.
- Extend non-colour distinctions beyond pass success/failure to the remaining multi-action maps so meaning survives colour-vision deficiencies and monochrome exports.

### P2 — clarity and interaction

- Add short quadrant descriptions to relationship plots when the selected pair has a defensible football interpretation. Do not generate generic high/high labels that imply quality.
- Consolidate duplicated layer counts where filter chips and the export legend repeat the same information without adding meaning.
- Add keyboard focus, pressed state and concise accessible names to the remaining clickable metric rows and layer chips.
- Consider a collapsible Player overview on small screens; pitch-first fixes the ordering, but summary cards still consume substantial height.
- Add a graphical outcome-shape key to shot maps so goal, saved, blocked, post and off-target remain distinguishable without colour.

### Data issues intentionally not disguised by styling

- Team populations still reflect the known cross-competition contamination until the reviewed Stage 3 database migration is applied. For example, Arsenal currently reports 54 matches in the live source. The UI must not locally rewrite that number.
- European teams below the six-match evidence threshold remain excluded from comparative plots by design.
- Match shots do not currently expose xG in this view; uniform markers are the honest fallback.

## Regression coverage

`pipeline/tools/check_dashboard_data_contracts.py` now protects directory completeness, the shared pitch transform and orientation labels, Player scatter context, responsive pitch priority, the xG size key, Match defaults and shot semantics, Team scatter context and labelling, and disclosed season-event sampling. Inline JavaScript parsing and browser renders remain required because these checks protect contracts, not layout quality by themselves.
