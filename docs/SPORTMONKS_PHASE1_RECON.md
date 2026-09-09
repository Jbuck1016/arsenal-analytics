# Sportmonks Phase 1 Reconnaissance

Read-only investigation of the Sportmonks v3 football API against the account
token in `.env`. No writes to Supabase, no changes to `dashboard/` or
`pipeline/`. Every figure below came from a live call; responses were cached
locally so no call was spent twice.

Date of investigation: 8 September 2026.

## Premise

WhoScored stays. It is the only source with a coordinate per action, and every
pitch plot, heatmap, sequence chain and territory metric on the site depends on
that. Sportmonks is being evaluated as a **second, complementary** source for
per-match aggregates that WhoScored cannot produce: goalkeeper metrics, measured
minutes played, ratings, big chances, errors leading to shots and similar.

Nothing in this document proposes replacing WhoScored. Section 6 records the one
finding that touches the premise, and it does not change the conclusion.

## A note on scope

Tasks 2, 3 and 4 were specified precisely in the brief and are answered as asked.
The brief referred to tasks 1 and 5 by number only, and no written spec for them
exists in this repository or in the current session. They have been reconstructed
from the stated purpose:

- **Task 1** read as: what does the subscription actually grant, and what are the
  rate limits.
- **Task 5** read as: which per-match aggregate fields exist and are populated,
  specifically the ones named in the brief.

If either reconstruction is wrong, that section needs redoing. The other three
are unaffected.

---

## Task 2. Historical depth per league

Priority one in the brief. The headline is that **season listings go back much
further than usable data**, so the listing is not the answer.

### Seasons offered

| League | Seasons listed | Earliest | Latest |
|---|---|---|---|
| Premier League | 27 | 2000/2001 | 2026/2027 |
| Bundesliga | 22 | 2005/2006 | 2026/2027 |
| Ligue 1 | 22 | 2005/2006 | 2026/2027 |
| Serie A | 22 | 2005/2006 | 2026/2027 |
| La Liga | 22 | 2005/2006 | 2026/2027 |
| Major League Soccer | 22 | 2005 | 2026 |

### Where the statistics actually start

One fixture was sampled per season per league and inspected for team statistic
rows and player statistic rows. Cells are `teamStatRows/playerStatRows`.

| League | 2005/06 | 2010/11 | 2013/14 | 2015/16 | 2018/19 | 2021/22 | 2024/25 | 2025/26 |
|---|---|---|---|---|---|---|---|---|
| Premier League | 0/61 | 0/18 | 0/47 | 34/464 | 66/406 | 74/521 | 76/795 | 80/815 |
| Bundesliga | 0/53 | 0/70 | 0/70 | 36/390 | 66/518 | 82/513 | 78/700 | 82/803 |
| Ligue 1 | 0/0 | 0/76 | 0/69 | 32/442 | 70/476 | 80/471 | 78/663 | 84/764 |
| Serie A | 0/63 | 0/49 | 0/78 | 30/436 | 68/495 | 72/511 | 78/802 | 84/878 |
| La Liga | 0/28 | 0/22 | 0/22 | 30/391 | 66/544 | 80/516 | 78/716 | 86/834 |

MLS, sampled by calendar year:

| Year | 2005 | 2010 | 2011 | 2012 | 2013 | 2014 | 2015 | 2016 | 2019 | 2022 | 2025 | 2026 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| team stat rows | 0 | 0 | 0 | 0 | 14 | 20 | 36 | 42 | 68 | 84 | 84 | 80 |
| player stat rows | 0 | 0 | 21 | 21 | 24 | 18 | 425 | 534 | 519 | 479 | 764 | 798 |

**Conclusion.** Team-level statistics begin at **2015/16 across all six leagues**,
and MLS player-level statistics become substantial in **2015**. Anything earlier
is a season record with no measurements attached. The 2013 and 2014 MLS rows
carry a thin team-stat set (14 and 20 types) and almost no player detail, so
treat 2015 as the first usable season and 2013 to 2014 as partial.

Breadth also grows over time: 30 to 36 team statistic types in 2015/16 against 80
to 86 in 2025/26. A metric present today is not guaranteed present in 2016, so
any backfill needs a per-metric availability check rather than a per-season one.

## Task 3. Odds, and whether closing odds exist

Priority two. The short answer is that **closing odds effectively exist, but they
are not labelled as such and there is no price history**.

What the API returns for a single MLS fixture (`19352579`, 2025):

- 3,334 pre-match odds rows, 22 bookmakers, 105 distinct markets.
- 489 in-play odds rows.
- No `/odds/closing/...` endpoint. Probed and returns 404. Likewise no
  `historical` odds path.

Each row is one price for one `(bookmaker, market, label, total, handicap)`
combination and carries `created_at` and `latest_bookmaker_update`. Keying every
row on that tuple plus `participants` gives 2,812 unique combinations from 3,334
rows, and the 33 that repeat are label collisions inside a single market, for
example Winning Margin where several margins share the label `2`. **There is no
time series.** You get one final price per outcome, not an opening and closing
pair.

How close to kickoff that final price sits, measured against a 00:30 kickoff:

| Window before kickoff | Rows | Share |
|---|---|---|
| under 1 hour | 1,144 | 34.3% |
| 1 to 3 hours | 15 | 0.4% |
| 3 to 12 hours | 1,861 | 55.8% |
| 12 to 48 hours | 86 | 2.6% |
| over 48 hours | 228 | 6.8% |

For the headline **Fulltime Result** market the picture is much tighter: 24 rows
across 8 bookmakers, median last update **0.25 hours, about 15 minutes before
kickoff**, minimum 0.24 hours. One bookmaker's row updated at 00:14:41 for a
00:30 start.

**Conclusion.** For 1X2 the stored price is a de facto closing line. For the long
tail of exotic markets, more than half were last touched 3 to 12 hours out, so
calling those closing prices would be wrong. If closing odds matter, restrict to
the main markets and record `latest_bookmaker_update` alongside the price so the
staleness is auditable rather than assumed.

Historical odds are present well before the statistics improve:

| MLS season | pre-match rows on sampled fixture | Fulltime Result rows |
|---|---|---|
| 2018 | 898 | 63 |
| 2021 | 4,293 | 138 |
| 2023 | 3,669 | 24 |
| 2025 | 3,334 | 24 |

## Task 4. Identity mapping, and whether date of birth is populated

Priority three. Both halves are good news.

### Date of birth

All 30 MLS squads were pulled, giving **862 distinct players**.

- `date_of_birth` populated: **862 of 862, 100%**
- `display_name` populated: **862 of 862, 100%**
- Player objects also carry `firstname`, `lastname`, `common_name`,
  `nationality_id`, `position_id`, `detailed_position_id`, `height`, `weight`.

### The catch on our side

Our `players` table has four columns: `player_id`, `player_name`, `team`,
`league`. **There is no date of birth.** So date of birth is available to
*verify* a match, and to enrich our records once joined, but it cannot be used to
*make* the join today. Name plus club is the only key we currently have on both
sides.

### Does name matching actually work

Our table holds 3,083 players across six competitions, which is why a naive
whole-table comparison against MLS squads matches only 24%. Restricted to like
for like, our 277 players at MLS clubs against the 862 Sportmonks MLS players:

| Outcome | Count | Share |
|---|---|---|
| exact match on normalised name | 242 | 87.4% |
| ambiguous, name maps to more than one | 0 | 0.0% |
| no match | 35 | 12.6% |

Normalisation was accent folding, lowercasing and stripping punctuation, tested
against `name`, `display_name` and `firstname + lastname`.

**Zero ambiguity** is the important number. There are also no duplicate
normalised display names inside the 862, so within MLS a name is currently a
unique key and date of birth is not needed as a tiebreak. That will not hold at
six-league scale, which is exactly where the date of birth earns its place.

The 35 misses are squad drift rather than a matching failure. Sportmonks squads
are current membership, our player list is anyone who appeared in a scraped
match, so departed and newly signed players appear on one side only. Examples:
Marcel Hartel, Stephen Eustaquio, Sergio Cordova, Kerwin Vargas.

### Club mapping

Our 30 MLS clubs against their 30, on normalised names with common suffixes
stripped: **26 of 30 match exactly**. The four that need an alias are all obvious
abbreviations, so a four row alias table closes the gap completely.

| Ours | Sportmonks |
|---|---|
| New England Revolution | New England |
| Red Bull New York | New York RB |
| San Jose Earthquakes | SJ Earthquakes |
| Sporting Kansas City | Sporting KC |

### Fixture overlap

Our matches table holds **351 MLS rows** for 2026, dated 2026-02-21 to
2026-11-08. Sportmonks lists **510 fixtures** for the same season, 343 with a
result, over exactly the same date range. The two are close enough that fixture
matching on date plus the two club ids should be reliable once the four aliases
exist.

## Task 1. Plan entitlements and access surface

Reconstructed task. See the scope note above.

Six leagues, all active: Premier League (8), Bundesliga (82), Ligue 1 (301),
Serie A (384), La Liga (564), Major League Soccer (779). These are exactly the
six competitions already in our matches table, so the plan lines up with the
current footprint with nothing to spare and nothing wasted.

**56 enrichments granted**, 143 resources. The ones that matter here: odds,
in-play odds, fixtures, lineups, events, statistics, timelines, players, teams,
squads, standings, topscorers, predictions, formations, referees, venues, and
**Ball Coordinates**.

Endpoint reachability, probed read-only:

| Endpoint | Result |
|---|---|
| `/football/fixtures` | ok |
| `/football/players` | ok |
| `/football/teams` | ok |
| `/football/standings/seasons/{id}` | ok, 30 rows |
| `/football/topscorers/seasons/{id}` | ok |
| `/football/predictions/probabilities` | ok |
| `/football/venues`, `/football/referees`, `/core/types` | ok |
| **`/football/expected/fixtures`** | **HTTP 403** |

**Expected goals is not on this plan.** There is no expected-goals enrichment in
the 56 granted and the endpoint refuses. This costs us nothing, because the site
already fits its own expected-goals model on WhoScored shot data, but it does rule
out cross-checking our model against theirs without a plan upgrade.

### Rate limits

`rate_limit.remaining` starts at **2,000 per entity** and `resets_in_seconds`
counts down from 3,600, so the budget is roughly 2,000 calls per entity per hour.
Entities are counted separately, so league calls and fixture calls draw on
different pools. This whole reconnaissance used about 130 live calls and never
dropped below 1,900 remaining on any single entity.

Practical consequence for a backfill: one fixture-detail call per match, 510
fixtures per MLS season, is comfortably inside a single hourly window. Six leagues
of full history from 2015 is roughly 30,000 fixtures, so about 15 hours of
wall-clock at the cap, or less with `include` batching on the season endpoint.

## Task 5. Per-match aggregate coverage

Reconstructed task. See the scope note above. This is the section that decides
whether the integration is worth building, and the answer is yes.

**Every metric named in the brief exists.** Ten finished 2025 MLS fixtures were
inspected for the specific fields:

| Metric | Fixtures present | Avg rows per fixture |
|---|---|---|
| Minutes Played | 10/10 | 29.7 |
| Rating | 10/10 | 28.6 |
| Saves | 10/10 | 1.9 |
| Saves Insidebox | 10/10 | 1.5 |
| Goalkeeper Goals Conceded | 9/10 | 1.5 |
| Good High Claim | 7/10 | 0.8 |
| Big Chances Created | 10/10 | 4.2 |
| Big Chances Missed | 10/10 | 3.5 |
| Error Lead To Shot | 7/10 | 1.0 |
| Error Lead To Goal | 6/10 | 0.9 |
| Goals Conceded | 9/10 | 18.0 |
| Touches | 10/10 | 29.4 |

Mapping to the brief: goalkeeper metrics are covered by Saves, Saves Insidebox,
Goalkeeper Goals Conceded and Good High Claim. Measured minutes played, ratings,
big chances and errors leading to shots are all present by name.

**The sparse-row trap.** Sportmonks emits a statistic row only when there is a
value to report. Minutes Played appears on 29.7 of 40 lineup entries because
unused substitutes have none, and Error Lead To Shot appears in 7 of 10 fixtures
because in the other 3 nobody made one. **An absent row means "not applicable or
zero", not "unknown", and the two must not be collapsed.** Any loader needs to
decide per metric which reading applies, or it will silently turn a clean sheet
into a null.

Full player-level type list observed on one fixture, 58 types: Accurate Crosses,
Accurate Passes, Accurate Passes Percentage, Aerials, Aerials Lost, Aerials Won,
Aerials Won Percentage, Assists, Backward Passes, Ball Recovery, Big Chances
Created, Big Chances Missed, Blocked Shots, Captain, Chances Created, Clearances,
Dispossessed, Dribble Attempts, Dribbled Past, Duels Lost, Duels Won, Duels Won
Percentage, Error Lead To Goal, Error Lead To Shot, Fouls, Fouls Drawn,
Goalkeeper Goals Conceded, Goals, Goals Conceded, Good High Claim, Interceptions,
Key Passes, Last Man Tackle, Long Balls, Long Balls Won, Long Balls Won
Percentage, Minutes Played, Offsides, Passes, Passes In Final Third, Possession
Lost, Rating, Redcards, Saves, Saves Insidebox, Shots Blocked, Shots Off Target,
Shots On Target, Shots Total, Successful Crosses Percentage, Successful Dribbles,
Tackles, Tackles Won, Tacles Won Percentage, Total Crosses, Total Duels, Touches,
Yellowcards.

Note `Tacles Won Percentage` is spelled that way in their data. Match on type id,
not on name.

Team-level types, 42 distinct on the same fixture, include Ball Possession %, Big
Chances Created, Big Chances Missed, Dangerous Attacks, Successful Passes
Percentage, Successful Long Passes Percentage, Duels Won, Saves and Interceptions.

## Ball coordinates, and why the premise holds

The plan grants "Access Ball Coordinates", which on its face sounds like it
contradicts the premise. It does not.

`include=ballCoordinates` returned 612 rows for the 2025 fixture, each row being
`{id, fixture_id, period_id, timer, x, y}` with x and y normalised to 0 to 1.
There is **no player, no team, no action type and no outcome** on any row.

That makes it a ball position sample, roughly one per ten seconds of match time,
not an event stream. It cannot produce a pass map, a player heatmap, a sequence
chain or a possession-adjusted territory metric, because none of those are
answerable without knowing who did what. Coverage is also patchy: 0 rows on the
sampled 2018, 2021 and 2026 fixtures, 299 on the 2023 fixture, 612 on the 2025
one.

**WhoScored remains the only source of a coordinate per action.** The premise in
the brief is correct.

## Recommendations

1. **Treat 2015 as the earliest usable season** and verify per metric rather than
   per season, since the type count roughly doubles between 2015/16 and 2025/26.
2. **Add a `date_of_birth` column to our players table**, populated from
   Sportmonks on first successful join. Name matching is unambiguous inside MLS
   today but will not stay that way across six leagues, and once the date of birth
   is stored the join becomes stable against name spelling changes.
3. **Build the four-row club alias table** before anything else. It is the whole
   distance between 26 of 30 and 30 of 30.
4. **Store `latest_bookmaker_update` next to every odds price.** Without it a
   consumer cannot tell a genuine closing line from a price that went stale eight
   hours before kickoff, and better than half the rows are the latter.
5. **Decide the zero-versus-null rule per metric before loading anything.** This
   is the most likely source of a quiet data error in the whole integration.
6. **Do not budget for Sportmonks expected goals.** It is 403 on this plan.

## Open questions for the next phase

- Which of the 58 player-level types do we actually want, and at what grain. The
  full set duplicates a good deal of what WhoScored already gives us with
  coordinates attached, and duplicated metrics that disagree are worse than one
  metric.
- Ratings are a vendor composite with an undisclosed formula. If a rating appears
  anywhere user-facing it needs a methodology entry saying whose rating it is and
  that we did not compute it, in line with how the site treats every other
  borrowed figure.
- Whether the five European leagues are in scope at all, or whether this is MLS
  only for now. The plan covers all six and our matches table already holds all
  six, but the dashboard is MLS.
- Squad drift means the player join needs a policy for players who left mid
  season. The 35 unmatched MLS names are all of this kind.

## Method

- All calls read-only GET against `https://api.sportmonks.com/v3`.
- Token read from `.env`, never printed, never placed on a command line.
- Responses cached on disk by request signature so no call was repeated.
- Supabase was read for our own player, team and match lists. No writes.
- Roughly 130 live API calls in total.
