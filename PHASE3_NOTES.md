# Phase 3 — objections and judgement calls

The brief says every decision is made and that where I disagree I should
implement it as written and record the objection here. This is that record.
Nothing in it was left undone; each item below describes work that shipped.

---

## 1. The brief puts `market-values.html` in both families

Section 1 lists the app family as "players, teams, match, index, search,
glossary, sequences, insights, guide, methodology, validation,
**market-values**", defines the editorial family as "model-lab, model-review,
writing-lab", and then says four bullets later that "**`fam-market` merges into
`editorial`**. It is a warm print palette that arrived independently; that is
what `editorial` is for."

Those cannot both hold. Two of the three statements put the page in `app`; one
puts it in `editorial`, and that one carries the reasoning.

**Implemented: `market-values.html` is an app page.** Two reasons.

The first is arithmetic about which reading leaves the brief least wrong. If
the page is editorial, both membership lists are wrong. If it is app, only the
merge bullet is wrong. One error is likelier than two.

The second is what the page is. `editorial` is defined by the job its surfaces
do — "print-styled reading surfaces", pages that are read. market-values is a
market intelligence table: a squad list with fee direction, contract status and
coverage, read down a column and sorted. That is a working surface, and it is
the Athletic data-panel treatment in section 2 that it wants, not the serif
reading face. Its warm paper ground is honoured anyway, because the app family
grounds on `#faf8f3`, which is warm cream and only a shade off the `#f2eee4`
the page carried.

**Cost of reversing:** one class on one page (`fam-editorial` on `<html>`), one
row in `assert_tokens.FAMILY`, and a re-run of the audits. Nothing else in the
phase depends on it.

---

## 2. The brief's accent cannot clear the brief's contrast rule

Section 3 says the accent is `#EF0107`, that the warm gold survives only as
`--accent-muted`, and — of `fam-doc-aa` — that "the new accent clears AA
everywhere by construction, so the darkened variant has nothing to do". It also
says every colour must clear 4.5:1 for text, and that this "is not a review
step, it is a constraint on what you are allowed to pick".

`#EF0107` does not clear 4.5:1 as text on either ground:

| | ground | raised | recessed |
|---|---|---|---|
| light `#faf8f3` | 4.23 | 4.42 | 3.81 |
| dark `#0e1219` | 4.18 | 3.85 | 3.47 |

It clears 3:1 everywhere, so it is sound as a **mark** — a fill, a rule, a bar,
a focus ring — and unsound as **text**. The premise that the darkened variant
has nothing to do is therefore false as stated: something still has to carry
accent-coloured text.

**Implemented: the accent is `#EF0107` and there is a separate `--accent-ink`
for text**, `#C10005` in light and `#FF4A42` in dark, both brand-derived and
both clearing 4.5:1 on all three surfaces of their theme.

This is not `fam-doc-aa` under another name, and the difference is the point.
`fam-doc-aa` was a second *scope*: the same role, `--accent-base`, carrying a
different value on three pages, so that what the accent meant depended on which
page you were on. `--accent-ink` is a second *role* in one family: mark and
text are different jobs with different thresholds, every page has both, and no
page disagrees with any other. Splitting by role is what lets the scope die.

---

## 3. "No failures carried forward" is not reachable for every token

The verification section requires the contrast gate to pass with no failures.
Some of the failures in `restyle/contrast.md` are not colour choices and cannot
be fixed by choosing a different colour:

- `--ink-on-accent` is white on the brand red at 4.52:1. It passes, but only
  just, and any darkening of the red to help accent-as-text would push it under.
  The two constraints pull opposite ways on the same pair, which is exactly why
  `--accent-ink` is a separate token.
- A handful of marks are measured as text because the category comes from the
  token's name, which `palette_audit.py` says of itself. Those are reclassified
  rather than recoloured, and each reclassification is listed in
  `PHASE3_REPORT.md` so a wrong one can be spotted.

Where a failure survives, the report says so and says why, rather than the gate
being loosened to hide it.

**Outcome: none survived.** The contrast gate reports 0 failures out of 508
measurements. Two of the three worries above were resolved rather than
tolerated -- `--ink-on-accent` by giving accent-as-fill its own token, and the
mark-measured-as-text cases by fixing the surface each one is measured against
rather than its category. Every reclassification that did happen is listed in
`PHASE3_REPORT.md` under "Two judgements contrast.md asked Phase 3 to make",
with the rule it follows and the seven tokens it does NOT cover.

---

## 4. Four typefaces were removed, not just deprecated

The brief says to "consolidate onto one of each rather than adding a face". I
read that as licence to remove, and removed Archivo, DM Mono, IBM Plex Mono and
IBM Plex Sans Condensed. Every page now loads Inter, JetBrains Mono and
Newsreader and nothing else.

**Implemented as written, and it is the largest visual change in the phase that
nobody asked for explicitly.** `model-lab.html` was set in IBM Plex Mono and IBM
Plex Sans Condensed throughout and now reads in JetBrains Mono and Inter;
`writing-lab.html` loses DM Mono. Those pages had a deliberate typographic
identity of their own, and the argument for taking it away is consistency
rather than anything about those pages.

I think it is right -- six faces is what happens when every page picks its own,
and the editorial family already keeps what actually distinguishes those pages,
which is the paper ground and the serif reading face. But it is a judgement,
the pages looked considered before, and it is one `<link>` and one token per
page to put back.
