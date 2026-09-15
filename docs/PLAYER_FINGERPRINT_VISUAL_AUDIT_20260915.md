# Player fingerprints visual audit

Audited 15 September 2026 against the live Declan Rice profile (`player=332325`) and the Player, Chain roles, Rank, Scatter, Scout, Compare, metric drill-down, pattern, and event-map paths. The audit covered desktop navigation, information density, chart interpretation, interaction cost, accessibility text, loading feedback, and narrow-screen behavior.

## What already works

- The profile contains unusually deep evidence: 114 metrics, role-relative percentiles, raw values, chain roles, spatial events, and player-comparison tools.
- Raw value and percentile are shown together. This prevents a high percentile from being mistaken for the underlying football quantity.
- Role pools make comparisons substantially fairer than one global population.
- The Pattern/Event switch is the right abstraction for movement data. Pattern reveals repeated routes; Events exposes individual evidence.
- Pitch orientation, outcome legends, and the current data timestamp are explicit.

## Findings and changes

### P0 — make the depth usable

1. **A profile had no visual summary below the broad pillars.** A user had to scan dozens of bars to understand a player's passing, creation, or defensive shape.
   - Added one-click category pizzas to every populated metric family.
   - Added direct values beside percentiles so the pizza remains an index into evidence rather than decoration.
   - Kept the role and league comparison population next to the chart.

2. **There was no from-scratch player visual builder.** Scatter could combine only two numeric measures, while pitch panels were fixed to predefined families.
   - Added Plot studio as a first-class analysis tab.
   - Percentile mode accepts metrics from any family. More than eight are split into multiple readable pizzas; nothing is silently dropped.
   - Pitch mode can layer passes, failed passes, progressive passes, box entries, key passes, through balls, carries, receptions, shots, tackles, interceptions, and recoveries.
   - Pattern mode is the default for dense movement; Events remains available for individual actions.

3. **Metric rows and chart explanations were too small for sustained analysis.**
   - Increased row spacing, label size, section-heading contrast, chart title size, and explanatory-copy size.
   - Enlarged pitch-evidence dialogs and retained responsive fallbacks.

### P1 — reduce visual noise

4. **Dense pass maps become spaghetti plots.** Fifty or more paths conceal the structure they are intended to show.
   - Existing Pattern mode should remain the default for passing, carrying, and combined maps.
   - Plot studio also defaults to Pattern and explicitly explains the difference.
   - Event mode remains an evidence drill-down, not the default summary.

5. **Sparse shot and defensive maps waste most of a full pitch.** Small, low-xG attempts are especially easy to miss.
   - Recommended next iteration: an attacking-half crop for shots and an automatic extent/focus option for sparse point events.
   - Maintain a minimum visible shot-marker radius while retaining area-by-xG encoding.

6. **Line start and end were not immediately obvious in every map.**
   - Existing hollow-origin and solid-destination encoding is sound, but it needs a persistent legend in every movement drill-down.
   - Keep arrow direction for aggregated Pattern flows.

### P1 — shorten the path to an answer

7. **The All view is comprehensive but long.** It is useful as an inventory, not as the default analytical path.
   - Category buttons and the new pizza actions provide a faster summary-to-evidence route.
   - Recommended next iteration: remember the last category per user and add a compact “strengths / questions / evidence” synopsis above the grid.

8. **Chain-role similarity is a very wide table.** The role shape is hard to compare row by row and the most important columns compete with secondary raw columns.
   - Recommended next iteration: make Player, Similarity, Touches, and Team sticky; move the role percentages into an expandable row or a small profile glyph.
   - Add a “compare with selected” action so a similar player can be inspected without losing the original.

9. **Player selection in analysis tools scales poorly.** A 2,000-player native select is technically usable but not efficient.
   - Recommended next iteration: replace long selects with searchable comboboxes scoped by league and role.

### P2 — interpretability and evidence

10. **Metric drill-downs lack match and time context.** The current browser views expose coordinates and outcomes, but not fixture, opponent, minute, period, or score state.
    - Extend the public read views with match ID, opponent, kickoff, minute, period, and game state.
    - Then add fixture, score-state, phase, and minute filters plus event hover details.

11. **Percentile labels used naive `th` suffixes.** Examples included “42th” and “23th.”
    - Corrected ordinal rendering (`42nd`, `23rd`, including 11th–13th exceptions).

12. **Loading can look like a frozen page.** Scatter and Chain roles can show a small spinner on a mostly empty canvas for several seconds.
    - Recommended next iteration: preserve the panel shell, show labelled skeletons, cache already loaded player evidence, and report which data is loading.

13. **The evidence is stale.** During the audit the site explicitly reported data as of 31 August, roughly 342 hours old.
    - This is a data-freshness problem, not a chart problem, but visual confidence depends on it. Keep the timestamp prominent and never imply a current-season profile is current when ingestion is behind.

## Visual rules going forward

- Start with the question: profile shape, relationship, location, or sequence. Do not put all four into one chart.
- Use pizzas for a focused set of role-relative percentiles, not raw values and not causal importance.
- Use Pattern for repeated movements and Events for verification.
- Use no more than six simultaneous colors; use shape and line style for additional event distinctions.
- Put the comparison population and sample beside every percentile visualization.
- Prefer direct labels and counts to legends that require memorisation.
- Never hide selected measures. Split overloaded pizzas and explicitly count the resulting panels.
- Keep raw value, percentile, sample, and freshness visible together.

## Verification checklist

- Profile opens directly from a player URL and preserves the selected player.
- Every populated category offers a pizza action.
- Plot studio loads the same player's percentile and event evidence.
- Selecting and clearing metrics cannot leave a misleading chart.
- Selecting multiple event layers updates counts and the legend.
- Pattern and Events show the same underlying selected layers.
- Keyboard focus returns after closing a modal.
- Narrow screens stack controls above the visual without horizontal page overflow.
- Empty and low-sample players receive an explanation rather than a blank plot.

