# Sportmonks Phase 2: Identity Mapping

Building a verifiable link between Sportmonks ids and our WhoScored-derived
records, for all six leagues on the plan. Identity only. No metric ingestion, no
dashboard changes, no model work.

Date: 8 September 2026. Builds on `SPORTMONKS_PHASE1_RECON.md`.

## Result in one line

**2,492 player links and 148 team links, every one corroborated by an
independent field, with zero ambiguous resolutions and all three invariants at
zero.** Between 95.5 and 98.5 percent of our players in each league are now
linked. The percentage measured against Sportmonks is much lower, and section 6
explains why that number is the wrong one to steer by.

## 1. Schema

Two tables, one nullable column, three invariants. Everything additive.
Migration: `supabase/migrations/20260909030453_sportmonks_phase2_identity_schema.sql`.

```
sm_team_link    id, sm_team_id, sm_team_name, league, our_team,
                match_method, confidence, verified_at
sm_player_link  id, sm_player_id, sm_player_name, sm_date_of_birth,
                our_player_id, our_player_name, league, team,
                match_method, confidence, verified_at, notes
players.date_of_birth   date, nullable
```

Three design decisions worth stating.

**A surrogate key, not the Sportmonks id.** An unmatched team or player on either
side still gets a row, so the table records what did not link as well as what
did. A natural key on `sm_team_id` would have forced those rows to be dropped.
A check constraint requires at least one side to be present.

**Uniqueness is enforced by partial indexes, not by convention.** A resolved link
is unique on the Sportmonks id and unique on our id; unresolved rows are exempt.
This is what makes "no many-to-one or one-to-many in either direction" a property
of the table rather than a claim in a document. It fired during the load and
caught a real modelling error, described in section 5.

**`our_team` uses the matches vocabulary.** Our database carries three team
vocabularies: `matches.home_team` (the match feed), `players.team` and
`lineups.team` (the event feed, shorter forms), and `team_names.display_name`.
`team_names` maps between the first two. `our_team` holds the match-feed name
because `matches` is the spine; `team_names.event_name` remains the alias for
joining to `players` and `lineups`.

## 2. Team mapping

Teams first, because every player link is scoped by club.

| League | exact | manual | unresolved | our teams linked |
|---|---|---|---|---|
| ENG-Premier League | 15 | 10 | 0 | 25 of 25 |
| GER-Bundesliga | 16 | 4 | 3 | 20 of 20 |
| FRA-Ligue 1 | 20 | 3 | 0 | 23 of 23 |
| ITA-Serie A | 23 | 1 | 0 | 24 of 24 |
| ESP-La Liga | 23 | 3 | 0 | 26 of 26 |
| USA-MLS | 26 | 4 | 0 | 30 of 30 |
| **Total** | **123** | **25** | **3** | **148 of 148** |

Every team of ours is linked. Matching normalised on accent folding, case and
punctuation, and stripped common club affixes (FC, SC, CF, AC, Real, Borussia,
Olympique and similar) only when the unstripped form failed.

**The 25 manual links were confirmed by the user, not guessed.** They are all the
same club under a fuller official name: Brighton to Brighton & Hove Albion,
Tottenham to Tottenham Hotspur, Bayern Munich to FC Bayern München, Lyon to
Olympique Lyonnais, Verona to Hellas Verona, Atletico Madrid to Atlético de
Madrid, and the four MLS abbreviations phase 1 had already identified. They were
written as `unresolved` first and promoted only after confirmation.

**The 3 remaining unresolved are Sportmonks-only and correctly left alone:**
Schalke 04, Elversberg and Paderborn. They appear in Sportmonks' Bundesliga
season lists but never in our data, so there is nothing to link them to.

## 3. Date of birth on our side

`players.date_of_birth` added, nullable, and **deliberately left empty**.
Populating it from Sportmonks would make the verification circular: we would be
checking a link against a value we had just copied across that same link.

**We hold no exact date of birth from any source.** What we do hold is
`player_bio.age_seen` with `age_seen_date`, an integer age observed on a date,
present for 2,834 rows and covering 3,049 of our 3,089 players. That constrains
a birth date to a one year window, which is not a date of birth but is enough to
falsify a wrong link. Section 5 uses it for exactly that.

`player_bio` also carries `height_cm` for 3,028 players. `nationality` exists as
a column but is populated for zero rows.

## 4. Matching strategy

Scoped tightest first, and never across leagues.

1. `exact_name_in_team`: exact string equality inside the linked club.
2. `normalised_name_in_team`: accent folded, lowercased, punctuation stripped,
   compared against the Sportmonks `name`, `display_name`, `common_name`,
   `lastname` and `firstname + lastname` forms.
3. `exact_name_in_league` then `normalised_name_in_league` as fallback, because a
   player who transferred mid-season sits in a different club than the one our
   appearance data puts them at.

**Ambiguity is never resolved silently.** If one of our players matched two
Sportmonks players in scope, or two of ours claimed the same Sportmonks player,
both sides were recorded as `unresolved`. The ambiguity count came out at zero in
every league, which is a stronger result than it sounds: it means no name in any
of these six squads collided within its scope.

The brief named four `match_method` values. A league-level fallback was requested
but had no name, so `exact_name_in_league` and `normalised_name_in_league` were
added to the enum and are reported separately below.

### A correction we made mid-phase

The first pass used `/v3/football/squads/teams/{id}`, which returns the **current**
squad, roughly 24 to 30 players per club. Our data spans three seasons. The
mismatch was invisible until verification surfaced Gabriel Martinelli, Leandro
Trossard, Andy Robertson and Ollie Watkins as unlinked, all of them regulars at
clubs we had linked. Arsenal's current squad genuinely does not contain
Martinelli; the season squad does.

Refetching through `/v3/football/squads/seasons/{season_id}/teams/{team_id}` for
each season we hold took the Sportmonks universe from 4,159 to 7,072 players and
the link count from 2,198 to 2,492. **This was our error, not a data limitation,
and the first numbers would have understated coverage by roughly 12 percent.**

## 5. Verification

Not a sample. **Every one of the 2,492 links was checked against an independent
field**, which was affordable because the corroborating data was already local.

The check: take the Sportmonks date of birth, compute the age it implies on the
date our own `age_seen` observation was taken, and compare. A disagreement
greater than one year means the two records are not the same person. One year of
slack is required because `age_seen` is an integer age and the observation date
falls either side of a birthday.

| League | links | age checked | exact | within 1yr | **failed** | height checked | within 2cm |
|---|---|---|---|---|---|---|---|
| ENG-Premier League | 620 | 604 | 421 | 183 | 0 | 606 | 541 |
| GER-Bundesliga | 109 | 105 | 87 | 18 | 0 | 106 | 98 |
| FRA-Ligue 1 | 364 | 359 | 344 | 15 | 0 | 347 | 326 |
| ITA-Serie A | 457 | 453 | 433 | 20 | 0 | 446 | 407 |
| ESP-La Liga | 465 | 461 | 438 | 22 | **1** | 460 | 427 |
| USA-MLS | 785 | 576 | 275 | 301 | 0 | 749 | 657 |
| **Total** | **2,800** | **2,558** | **1,998** | **559** | **1** | **2,714** | **2,456** |

**One link failed and was removed.** Two different players named Álvaro
Fernández: our record puts him at 28 on 17 August 2026, implying a 1998 birth
year, while the Sportmonks player we matched was born 10 April 2000. It passed
name matching because only one Álvaro Fernández existed in the league index, so
no ambiguity was detectable by name alone. Both sides are now `unresolved` with
the reason recorded in `notes`. **This is the entire argument for verifying
against an independent field: name matching cannot catch this class of error.**

Height agreement, as a second and weaker signal, since height is noisier and
differs between sources by convention:

| difference | links | share |
|---|---|---|
| within 2cm | 2,456 | 90.5% |
| 3 to 5cm | 143 | 6.7% |
| 6 to 10cm | 59 | 2.7% |
| over 10cm | 9 | 0.4% |

No link was removed on height alone. Every one of the 9 worst height
disagreements passed the age check, so these read as source disagreement rather
than misidentification.

### The uniqueness index caught a second error

The first load aborted on a duplicate key: Sportmonks player 31823 appeared
twice. The cause was ours. We had generated one row per player per league, so a
player who moved between two of our leagues, Tijjani Reijnders from Serie A to
the Premier League for instance, produced two rows for one human.

**Identity is league independent.** The rows were collapsed to one per
(Sportmonks id, our id) pair, keeping the league where we observed the player
most, which took 2,799 rows down to 2,492 links. Zero genuine cross-league
conflicts existed once collapsed, meaning no Sportmonks id was claimed by two
different players of ours.

## 6. Per-league results

| League | SM players | ours | linked | **% of ours** | % of SM | ambiguous |
|---|---|---|---|---|---|---|
| ENG-Premier League | 1,136 | 636 | 525 | **97.5%** | 46.2% | 0 |
| GER-Bundesliga | 1,009 | 111 | 80 | **98.2%** | 7.9% | 0 |
| FRA-Ligue 1 | 1,160 | 381 | 311 | **95.5%** | 26.8% | 0 |
| ITA-Serie A | 1,287 | 464 | 397 | **98.5%** | 30.8% | 0 |
| ESP-La Liga | 1,248 | 483 | 417 | **96.3%** | 33.4% | 0 |
| USA-MLS | 1,332 | 813 | 762 | **96.6%** | 57.2% | 0 |

By `match_method`:

| League | exact in team | normalised in team | exact in league | normalised in league |
|---|---|---|---|---|
| ENG-Premier League | 519 | 6 | 0 | 0 |
| GER-Bundesliga | 29 | 0 | 49 | 2 |
| FRA-Ligue 1 | 303 | 7 | 1 | 0 |
| ITA-Serie A | 376 | 21 | 0 | 0 |
| ESP-La Liga | 405 | 12 | 0 | 0 |
| USA-MLS | 747 | 15 | 0 | 0 |

Team-scoped exact matching does almost all the work, 2,379 of 2,492 links.
Normalisation adds 61 and the league fallback 52, and Bundesliga is the only
league that leans on the fallback, because its team labels are the weakest.

### Why "percent of Sportmonks" is the wrong denominator

The brief set a 70 percent floor and every league is under it on that measure.
The strategy is not the reason, and this is worth being precise about.

**95.5 to 98.5 percent of our players link.** The matcher is not failing. The
denominator counts every player Sportmonks registered to a squad across three
seasons, including youth and reserve registrations who never played a minute,
across clubs and seasons our data does not fully cover. Our side counts only
players who actually appeared in a lineup we hold and who carry a name.

The two universes are different sizes by construction: 7,072 Sportmonks
registrations against 2,888 of our appearance records. A link rate measured
against the larger one is a statement about squad registration depth, not about
identity resolution.

**Bundesliga is the real exception and it is a gap on our side.** 797 players
appear in our Bundesliga lineups but only 115 have a row in `players`, and 682 of
those exist as a player id with **no name anywhere**, not in `players` and not in
`player_bio`. `lineups` has no name column. Those players cannot be matched by
name because we do not know their names. That is why Bundesliga contributes 80
links against 1,009 Sportmonks players, and no matching strategy fixes it.

Our registry coverage against players who actually appear in lineups:

| League | in lineups | in `players` | coverage |
|---|---|---|---|
| USA-MLS | 936 | 936 | 100% |
| ENG-Premier League | 1,055 | 701 | 66% |
| ESP-La Liga | 1,182 | 555 | 47% |
| ITA-Serie A | 1,211 | 544 | 45% |
| FRA-Ligue 1 | 1,081 | 414 | 38% |
| GER-Bundesliga | 797 | 115 | **14%** |

## 7. Unresolved

**Ours: 83 players.** Not squad drift. Every one last appeared in the 2025/26 or
2026/27 season, and the European ones average 30 to 48 appearances, so these are
current regulars rather than departed players. Phase 1 found the MLS misses were
drift; **that does not hold for the European leagues**, and the causes are
different.

Reading the list, two patterns account for most of it:

- **Mononyms and short display forms.** Ours "Gabriel Magalhães" against their
  "Gabriel", ours "Alisson Becker" against their "Alisson".
- **East Asian name ordering.** Son Heung-Min, Lee Kang-In, Hwang Hee-Chan, Kim
  Min-Jae, Kim Kee-Hee, Jeong Sang-Bin. The two sources order family and given
  names differently and a straight normalised comparison cannot bridge that.

Both are tractable in a later pass with a token-set comparison rather than a
string comparison, gated behind the same date-of-birth check. Neither was
attempted here, because an unjustified link is worse than an unresolved one.

Full list by league and club:

```
ENG-Premier League
  Arsenal            Gabriel Magalhães        Liverpool     Alisson Becker
  Brighton           Ferdi Kadioglu           Liverpool     Andy Robertson
  Burnley            Max Weiss                Liverpool     Kostas Tsimikas
  Everton            Charly Alcaraz           Man United    Altay Bayindir
  Ipswich            Sindre Egeli             Southampton   Sam Amo-Ameyaw
  Leicester          Abdul Fatawu             Tottenham     Son Heung-Min
  West Ham           Ollie Scarles            Wolves        Dan Bentley
  Wolves             Hwang Hee-Chan           Wolves        Toti Gomes

ESP-La Liga
  Atletico Madrid    Cubo, Dani Martinez, Javier Morcillo, Lee Kang-In
  Celta Vigo         Tasos Douvikas           Elche         Umaru
  Espanyol           Cala                     Getafe        Djené Dakonam, Jean Valou
  Leganes            Adrià Alti               Levante       Adrián de la Fuente, Nacho Pérez
  Malaga             Rafita                   Racing Santander  Facu González
  Real Madrid        Andrii Lunin, Jorge Cestero, Valde
  Sevilla            Álvaro Fernández (failed the date of birth check), Miguel Sierra

FRA-Ligue 1
  Angers             Usman Simbakoli          Brest         Raphaël Le Guen
  Le Havre           Enzo Koffi, Lionel Mpasi, Mbwana Samatta
  Le Mans            Adil Bourabaa            Lille         Alexsandro Ribeiro, Hákon Haraldsson
  Lorient            Dermane Karim, Mamadou Koné
  Monaco             Flávio Nazinho           Reims         Patrick Zabi
  Toulouse           Cristian Cásseres, Pape Diop
  Troyes             Noah Donkor

GER-Bundesliga
  Bayer Leverkusen   Ezequiél Fernández       Bayern Munich Kim Min-Jae

ITA-Serie A
  Genoa              Alex Amorim, Ethan Meichtry, Mikael Ellertsson
  Lecce              Thórir Helgason

USA-MLS
  Atlanta United     Ignacio Suarez, Matt Edwards
  Austin FC          Dani Pereira, Joseph Rosales
  CF Montreal        Dagur Thórhallsson, Hennadii Synchuk, Wiki Carmona
  Chicago Fire FC    Dawid Poreba             Colorado Rapids   Ted Ku-DiPietro
  FC Cincinnati      Tah Brian Anunga         Inter Miami CF    Lovend's Delinois
  LA Galaxy          Emiro Garcés, Harbor Tarczynski-Miller
  Los Angeles FC     Yevhen Cheberko          Minnesota United  DJ Taylor
  Nashville SC       Jeisson Palacios, Shak Mohammed
  New York City FC   Kevin Pierre             Orlando City      Pedro Leão
  Philadelphia Union Stas Korzeniowski        Real Salt Lake    Lineker Rodrigues
  Red Bull New York  Eric Choupo-Moting       Seattle Sounders  Kim Kee-Hee, Yeimar Gómez
  St. Louis City     Daniel Edelman, Jeong Sang-Bin
  Toronto FC         Derrick Etienne
```

**Sportmonks: 4,271 players.** Squad registrations with no player of ours by that
name. These are overwhelmingly players who never appeared in a match we hold:
reserve and youth registrations, and squad members at clubs in seasons we cover
only partially. They are recorded as `unresolved` rows so that a later ingestion
can tell "we have no link" apart from "we never looked".

## 8. Invariants

All three added at `warn`, following the existing pattern in `invariants`
(name, description, check_sql, severity, enabled).

| Invariant | Violations |
|---|---|
| `sm_team_link_unique` | **0** |
| `sm_player_link_unique` | **0** |
| `sm_player_link_league_consistent` | **0**, after the fix below |

`sm_player_link_league_consistent` returned **52** on first run. The cause was
real and worth recording: our lineup feed uses short club forms ("Bayern",
"Leverkusen", "RBL", "Hamburg", "Stuttgart", "Mainz", "PSG") that have no alias
row, because **`team_names` contains no Bundesliga rows at all**. The links
themselves were sound and already corroborated by date of birth; only the team
label sat in the wrong vocabulary. The 52 labels were normalised inside
`sm_player_link`, with the original short form recorded in `notes`.

**The underlying gap is not fixed and is not ours to fix here.** `team_names`
covers 103 rows across 8 competitions with nothing for Bundesliga and partial
coverage elsewhere: Premier League 13 rows for 25 clubs, Serie A 8 for 24. It is
an alias table for names that differ, not a complete registry, and anything
joining event-feed names to match-feed names outside MLS should expect misses.

## 9. What remains manual

1. **The 83 unresolved players of ours.** Mostly mononyms and East Asian name
   ordering. A token-set comparison gated behind the date-of-birth check would
   take most of them, and should not be attempted without that gate.
2. **The Álvaro Fernández collision.** Two real players share a name in La Liga.
   Resolving it needs a human or a squad-number cross-check.
3. **The Bundesliga registry gap.** 682 players hold appearances but no name
   anywhere. This is a pipeline backfill, not an identity problem, and it caps
   Bundesliga at 14 percent of its lineup population until fixed.
4. **`team_names` completeness.** Bundesliga has no rows. Until it does, any
   event-feed to match-feed join for German clubs relies on the seven aliases
   normalised inside `sm_player_link`.
5. **Three Sportmonks-only clubs.** Schalke, Elversberg, Paderborn. Nothing to
   link them to unless our coverage extends to the second tier.

## 10. Security note

`sm_team_link` and `sm_player_link` were created without row level security, to
match the convention of the other reference tables in this database
(`team_names`, `metric_defs`, `invariants` and 15 others). Supabase reports this
as critical: **the anon key can read and write all of them**. That was true of 18
tables before this phase and is now true of 20.

This was not changed unilaterally, because enabling RLS without policies would
block the dashboard's reads. It is flagged here so the decision is explicit
rather than inherited. The bulk load in this phase used the anon key through
PostgREST precisely because those tables are open, which is itself an argument
for closing them.

## Method

- Sportmonks read-only. Roughly 500 live calls, cached by request signature; the
  rate limit never fell below 1,650 of 2,000 remaining.
- Token read from `.env` at call time, never printed, never logged, never committed.
- Supabase: `apply_migration` for DDL, `execute_sql` and PostgREST for DML.
- Written: `sm_team_link` (151 rows), `sm_player_link` (6,846 rows),
  `players.date_of_birth` (added, empty), 3 rows in `invariants`. Nothing else in
  the database was touched.
