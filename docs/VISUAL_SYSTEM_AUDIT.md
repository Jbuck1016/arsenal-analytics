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
- Player and Team shot outcome legends demonstrate the actual goal, save, block, post and off-target glyphs rather than repeating identical colour dots.
- Plot PDFs use a compressed high-quality image rather than embedding a multi-megabyte lossless canvas.
- Incomplete pass vectors are dashed and labelled as such, so success versus failure does not depend on green versus red alone.
- Defensive, tempo, aerial, goalkeeper, discipline and set-piece maps use distinct circles, squares, diamonds, triangles, rings and crosses; carry families also use solid, dashed and dotted routes.
- On phones, the nine-card Player overview is collapsed behind a clear Show/Hide control, while the selected pitch remains immediately visible.
- Repeated counts were removed from plot legends where the interactive layer chips already state them.
- Quadrant labels appear only for progressive-carries/key-passes and PPDA/field-tilt, with explicit wording that they describe involvement or style rather than quality.

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
- At phone width, Team Rankings removes the unreadably compressed all-team bar chart and keeps the complete, scrollable value table with an explicit explanation.
- Player and Team plot modes, filters and layer toggles expose pressed state and visible keyboard focus.
- Team pass maps report completed and incomplete populations separately; incomplete routes are dashed in both pattern and event modes.
- Player metric rows and ranking values that open pitch evidence expose button roles, descriptive names and Enter/Space activation.
- The pitch-evidence overlay exposes dialog semantics, moves focus to Close, responds to Escape and returns focus to its trigger.

## Visual principles now enforced

1. **Pattern first, evidence second.** Season-scale plots open on an aggregate that reveals structure. Raw events are an intentional drill-down.
2. **Never encode an unavailable measure.** If xG is absent, marker area does not pretend distance is chance quality.
3. **State the question and population.** Relationship plots identify both variables, scope, units and comparison basis on the canvas.
4. **Orientation is explicit.** Every pitch states the attack direction; transforms are shared rather than repeated ad hoc.
5. **Density is disclosed.** Sampling never changes the stated population and is called out beside the visual.
6. **The visual answer gets layout priority.** On narrow screens the pitch precedes supporting tables.

## Automated visual coverage

`pipeline/tools/visual_regression.js` now captures and compares eighteen live-data baselines:
Player desktop and mobile, Team tablet-light and desktop-monochrome, Match desktop and mobile-light,
Player Compare, Team Rankings, Insights, Sequences, Validation and Methodology, plus the rendered PNG and first PDF page for
Player, Team and Match export paths. The comparison
fails above a 0.2% pixel-change threshold and retains received/diff evidence on failure.

### Data issues intentionally not disguised by styling

- Competition isolation is now enforced in the database. Arsenal resolves to its 33 Premier League matches; domestic-cup and continental fixtures cannot enter league metrics or rankings.
- European teams below the six-match evidence threshold remain excluded from comparative plots by design.
- Match shots do not currently expose xG in this view; uniform markers are the honest fallback.

## Regression coverage

`pipeline/tools/check_dashboard_data_contracts.py` now protects directory completeness, the shared pitch transform and orientation labels, Player scatter context, responsive pitch priority, the xG size key, Match defaults and shot semantics, Team scatter context and labelling, and disclosed season-event sampling. Inline JavaScript parsing and browser renders remain required because these checks protect contracts, not layout quality by themselves.
