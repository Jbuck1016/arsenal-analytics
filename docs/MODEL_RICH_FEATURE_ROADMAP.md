# Rich match-model feature roadmap

## What the current private artifact is

The current private forecast is the schema-v2 field-tilt and box-entry
challenger in `shadow`. Its 29 inputs cover pre-match Elo strength, rest, and
rolling shots, shots allowed, field tilt, and completed pass entries into the
penalty area over 3, 5, and 10 matches.

## Audited first challenger

The first controlled upgrade adds rolling territory to that control:

- field tilt over 3, 5, and 10 matches for both clubs;
- completed open-play pass entries into the penalty box over 3, 5, and 10
  matches for both clubs.

That is a 29-field contract. It beat the exact 17-field control on both
chronological out-of-season holdouts and passed prediction-time parity plus the
five-league forecast review gates. It remains private shadow output until real
weekly forecasts are scored; site deployment does not imply model activation.

## Feature schema v2

The next schema must persist the raw match observations needed to derive, from
strictly prior matches, at least:

- total open-play xT created and conceded;
- xT difference and xT per possession;
- final-third touches for and against, plus the share already represented by
  field tilt;
- penalty-area touches and entries for and against;
- non-penalty xG for and against, where historical shot-model coverage passes
  the same completeness gates in every league and season;
- set-piece shot and xG threat;
- progressive passes and carries, possession-chain progression, PPDA,
  defensive height, possession share, rest, and schedule congestion.

Every rolling value must be computed only from matches completed before the
forecast cutoff.  Raw totals and opponent-adjusted or per-possession rates
should be separate fields; a ratio must not erase volume.

## Selection policy

Feature depth is not the same as forcing every field into production.  Each
family is added to the validated control, tested on chronological season
holdouts, checked league by league, and ablated.  A richer candidate advances
only when it improves result log loss without materially worsening goal error
or probability calibration.  This protects the product from overfitting while
still allowing tactical metrics to influence forecasts when the evidence says
they generalize.

## Explanation contract

The site should show the actual model contract and the largest match-specific
drivers.  For a rich candidate those drivers can include team strength, recent
shot creation and prevention, field tilt, box entries, xT difference,
progression, pressing, possession, and rest.  Each explanation must display
the two clubs' underlying pre-match values and must never name a feature the
loaded artifact did not use.
