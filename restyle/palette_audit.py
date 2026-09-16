"""Measure the palette: contrast against the grounds, and separability within
each categorical series.

Phase 3 has to reconcile six families and sixty-odd deliberate skips, and most
of that argument is currently taste. This turns the part of it that is
arithmetic into arithmetic. Three pages already carry an AA-darkened amber
because #9c6b1e failed on the shared surfaces; this says where else that is
true, and it says it for every scope rather than the ones someone happened to
check.

    python restyle/palette_audit.py        # writes contrast.md and separability.md

WHAT IT MEASURES
  contrast     WCAG 2.1 relative-luminance ratio, foreground composited over
               the ground first when it carries alpha. 4.5:1 for text, 3:1 for
               graphical objects and UI boundaries, per WCAG 1.4.3 and 1.4.11.
  separability CIEDE2000 between every pair within a categorical set. A pair
               is flagged below 10, which is roughly where two small marks
               stop being reliably told apart at a glance, and called severe
               below 5, which is near the threshold of noticing any difference
               at all.

WHAT IT DOES NOT MEASURE
  Whether a token is actually used as text, or on that ground. The category
  comes from the name, and the grounds are the family's own --ground and
  --surface-raised. A token painted somewhere else is measured against the
  wrong thing; the tables say what was assumed so a wrong row can be spotted.
"""
from __future__ import annotations

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import assert_tokens as A  # noqa: E402

OUT_CONTRAST = A.ROOT / "restyle" / "contrast.md"
OUT_SEPARABILITY = A.ROOT / "restyle" / "separability.md"

# Which scopes are real surfaces someone reads. gate is the password overlay,
# which is theme-independent and has its own ground.
FAMILIES = ["app", "doc", "doc-aa", "market", "match", "lab", "review", "writing"]

# ---------------------------------------------------------------- category
# Longest prefix wins, so --pitch-text-soft is text and --pitch-line is a
# boundary even though both start --pitch-.
TEXT = ("--ink-primary", "--ink-secondary", "--ink-tertiary", "--ink-quaternary",
        "--ink-on-accent", "--ink-on-state", "--pitch-text", "--pitch-text-soft",
        "--chip-ink", "--label-on-fill", "--gate-ink", "--gate-ink-soft",
        "--gate-mark", "--gate-error", "--print-ink", "--error-ink",
        "--banner-team-ink", "--banner-warn-ink", "--list-group-ink",
        "--positive-ink", "--caution-ink", "--negative-ink",
        "--pos-gk-ink", "--pos-def-ink", "--pos-mid-ink", "--pos-fwd-ink",
        "--plot-label", "--plot-pill-ink", "--legend-muted", "--legend-muted-ink",
        "--plot-share-label")
BOUNDARY = ("--border-hairline", "--border-strong", "--select-edge",
            "--accent-edge", "--gate-card-border", "--gate-field-border",
            "--gate-focus-ring", "--print-rule", "--pitch-line",
            "--pitch-line-strong", "--plot-grid", "--plot-frame", "--plot-line",
            "--plot-guide", "--grid-line", "--zone-edge", "--gold-edge",
            "--gold-edge-soft", "--gold-edge-strong", "--gold-edge-hard",
            "--blue-edge", "--banner-team-edge", "--banner-warn-edge",
            "--error-edge", "--export-border", "--export-rule",
            "--gate-action-edge", "--plot-node-ring", "--plot-node-ring-soft",
            "--shape-node-ring", "--shape-out-edge", "--shape-in-edge",
            "--timeline-sel-edge", "--tier-t2-edge", "--tier-t4-edge",
            "--team-all-edge")
# Data marks: read as objects, so 3:1, same as a boundary.
MARK_PREFIX = ("--series-", "--group-", "--layer-", "--rank-", "--action-",
               "--pos-line-", "--shot-", "--state-", "--style-axis-",
               "--heat-legend-", "--xt-", "--accent-base", "--accent-muted",
               "--opponent", "--marker-", "--team-all", "--pct-", "--signal-alt",
               "--flow-arrow", "--peak-ring", "--legend-heat-", "--momentum-them",
               # the two pass-outcome colours the pitch draws arrows with
               "--pass-ok", "--pass-fail")
# Grounds and fills: measured as backgrounds, never as a foreground.
GROUND_PREFIX = ("--ground", "--surface-", "--pitch-fill", "--pitch-band",
                 "--float-", "--gate-ground", "--gate-card", "--gate-field",
                 "--print-paper", "--chip-ground", "--scrim", "--row-stripe",
                 "--result-", "--moment-", "--badge-", "--banner-team-fill",
                 "--banner-warn-fill", "--pos-gk-fill", "--pos-def-fill",
                 "--pos-mid-fill", "--pos-fwd-fill", "--compare-", "--gold-veil",
                 "--gold-veil-soft", "--gold-veil-strong", "--gold-wash",
                 "--gold-fill", "--blue-veil", "--blue-wash", "--accent-veil",
                 "--state-warn-veil", "--error-veil", "--zone-fill",
                 "--shape-out-fill", "--shape-in-fill", "--shape-node",
                 "--flow-node", "--band-", "--bar-track", "--plot-pill",
                 "--legend-pill", "--plot-zone-neutral", "--timeline-sel-fill",
                 "--gate-action-fill", "--gate-action-fill-hover", "--select-fill",
                 "--elevation", "--label-on-fill-halo", "--plot-shadow",
                 "--shape-shift-", "--live-glow", "--page-wash", "--pill-nb-fill",
                 "--select-ink", "--team-all-veil")


def category(name: str) -> str:
    if name in TEXT:
        return "text"
    if name in BOUNDARY:
        return "boundary"
    if any(name.startswith(p) for p in GROUND_PREFIX):
        return "ground"
    if any(name.startswith(p) for p in MARK_PREFIX):
        return "mark"
    return "?"


# THE GROUND A TOKEN IS ACTUALLY PAINTED ON.
# ---------------------------------------------------------------------------
# A contrast number is only meaningful against the right surface, and a first
# pass that measured everything against the page ground produced 1,146
# "failures" that were almost all arithmetic against a surface the token never
# touches: --ink-on-accent measured on the page rather than on the accent it
# is named for, the gate's ink measured on the page rather than on the gate,
# every pitch colour measured on the page rather than on the pitch. Longest
# prefix wins. Anything not listed is measured against the family's own
# --ground and --surface-raised, which is the common case.
GROUND_FOR = [
    # on the accent, or on a state fill, by name
    ("--ink-on-accent", ["--accent-base"]),
    ("--ink-on-state", ["--state-positive", "--state-negative"]),
    ("--label-on-fill", ["--group-passing", "--group-shooting", "--rank-mid"]),
    # the password overlay, which has its own ground and its own card
    ("--gate-ink", ["--gate-card"]),
    ("--gate-ink-soft", ["--gate-card"]),
    ("--gate-mark", ["--gate-card"]),
    ("--gate-error", ["--gate-card"]),
    ("--gate-card-border", ["--gate-ground"]),
    ("--gate-field-border", ["--gate-card"]),
    ("--gate-focus-ring", ["--gate-card"]),
    ("--gate-action-edge", ["--gate-card"]),
    # the export sheet is always the LIGHT app ground, whatever the workspace
    ("--export-", ["--ground@app-light"]),
    # print is ink on paper
    ("--print-", ["--print-paper"]),
    # the chip sits on its own ground
    ("--chip-ink", ["--chip-ground"]),
    # everything drawn onto the pitch is measured on the pitch
    ("--pitch-", ["--pitch-fill"]),
    ("--plot-", ["--pitch-fill"]),
    ("--legend-", ["--legend-pill", "--pitch-fill"]),
    ("--peak-ring", ["--pitch-fill"]),
    ("--zone-", ["--pitch-fill"]),
    ("--shape-", ["--pitch-fill"]),
    ("--band-", ["--pitch-fill"]),
    ("--flow-", ["--pitch-fill"]),
    ("--marker-", ["--pitch-fill"]),
    ("--xt-", ["--pitch-fill"]),
    ("--shot-", ["--pitch-fill"]),
    ("--action-", ["--pitch-fill"]),
    ("--pos-line-", ["--pitch-fill"]),
    ("--pass-", ["--pitch-fill"]),
    ("--series-ok", ["--pitch-fill"]),
    ("--series-fail", ["--pitch-fill"]),
    ("--series-pass", ["--pitch-fill"]),
    ("--series-prog", ["--pitch-fill"]),
    ("--series-carry", ["--pitch-fill"]),
    ("--series-box", ["--pitch-fill"]),
    ("--series-alt", ["--pitch-fill"]),
    ("--series-cool", ["--pitch-fill"]),
    ("--series-warm", ["--pitch-fill"]),
    ("--series-mint", ["--pitch-fill"]),
    ("--series-neutral", ["--pitch-fill"]),
    # badge inks sit on their own tinted pill
    ("--pos-gk-ink", ["--pos-gk-fill"]),
    ("--pos-def-ink", ["--pos-def-fill"]),
    ("--pos-mid-ink", ["--pos-mid-fill"]),
    ("--pos-fwd-ink", ["--pos-fwd-fill"]),
    ("--banner-team-", ["--banner-team-fill"]),
    ("--banner-warn-", ["--banner-warn-fill"]),
    ("--error-", ["--error-veil"]),
    ("--tier-", ["--surface-raised"]),
]


def grounds_for(name):
    best = None
    for pre, gs in GROUND_FOR:
        if name.startswith(pre) and (best is None or len(pre) > len(best[0])):
            best = (pre, gs)
    return best[1] if best else None


# Values that are not colours and never will be: an RGB triplet handed to a
# canvas gradient, and the box-shadow tokens.
NOT_A_COLOUR = ("--heat-low", "--heat-mid", "--heat-high", "--elevation",
                "--gate-elevation", "--shadow",
                # an RGB triplet the canvas builds an rgba() from, like --heat-*
                "--dominance-them-rgb")


# ------------------------------------------------------------------ colour
HEX = re.compile(r"^#([0-9a-fA-F]{3,8})$")
RGB = re.compile(r"^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.%]+))?\s*\)$")
MIX = re.compile(r"^color-mix\(in srgb,\s*(.+?)\s+([\d.]+)%\s*,\s*(.+?)\s*\)$")


def parse(value: str):
    """-> (r, g, b, a) in 0..255 / 0..1, or None if this is not a colour."""
    v = " ".join(value.split())
    m = HEX.match(v)
    if m:
        h = m.group(1)
        if len(h) in (3, 4):
            h = "".join(c * 2 for c in h)
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
        return (r, g, b, a)
    m = RGB.match(v)
    if m:
        a = m.group(4)
        alpha = 1.0 if a is None else (float(a[:-1]) / 100 if a.endswith("%") else float(a))
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)), alpha)
    m = MIX.match(v)
    if m:
        c1, pct, c2 = parse(m.group(1)), float(m.group(2)) / 100, m.group(3).strip()
        if c1 is None:
            return None
        if c2 == "transparent":
            return (c1[0], c1[1], c1[2], c1[3] * pct)
        c2p = parse(c2)
        if c2p is None:
            return None
        return tuple(c1[i] * pct + c2p[i] * (1 - pct) for i in range(4))
    return None


def over(fg, bg):
    """Composite fg onto an opaque bg."""
    a = fg[3]
    return tuple(fg[i] * a + bg[i] * (1 - a) for i in range(3)) + (1.0,)


def _lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(c):
    return 0.2126 * _lin(c[0]) + 0.7152 * _lin(c[1]) + 0.0722 * _lin(c[2])


def ratio(fg, bg):
    f, b = luminance(fg), luminance(bg)
    hi, lo = max(f, b), min(f, b)
    return (hi + 0.05) / (lo + 0.05)


# ---------------------------------------------------------------- CIEDE2000
import math  # noqa: E402


def to_lab(c):
    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)
    r, g, b = _lin(c[0]), _lin(c[1]), _lin(c[2])
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 1.00000
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def ciede2000(c1, c2):
    L1, a1, b1 = to_lab(c1)
    L2, a2, b2 = to_lab(c2)
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7))) if Cb else 0.5
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if (a1p or b1) else 0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if (a2p or b2) else 0
    dLp, dCp = L2 - L1, C2p - C1p
    if C1p * C2p == 0:
        dhp = 0
    elif abs(h2p - h1p) <= 180:
        dhp = h2p - h1p
    else:
        dhp = h2p - h1p - 360 if h2p > h1p else h2p - h1p + 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dhp) / 2)
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hbp = (h1p + h2p + 360) / 2
    else:
        hbp = (h1p + h2p - 360) / 2
    T = (1 - 0.17 * math.cos(math.radians(hbp - 30)) + 0.24 * math.cos(math.radians(2 * hbp))
         + 0.32 * math.cos(math.radians(3 * hbp + 6)) - 0.20 * math.cos(math.radians(4 * hbp - 63)))
    dTh = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7)) if Cbp else 0
    Sl = 1 + (0.015 * (Lbp - 50) ** 2) / math.sqrt(20 + (Lbp - 50) ** 2)
    Sc, Sh = 1 + 0.045 * Cbp, 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dTh)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2
                     + Rt * (dCp / Sc) * (dHp / Sh))


# ------------------------------------------------------------ the palettes
# Categorical sets, by the role they encode. A set is only separable if every
# pair in it is, so these are the groups worth checking pairwise.
SERIES = {
    "match.html defensive actions": ["--action-tackle", "--action-interception",
        "--action-clearance", "--action-recovery", "--action-block",
        "--action-aerial", "--action-challenge", "--action-other"],
    "match.html position lines": ["--pos-line-gk", "--pos-line-def", "--pos-line-dm",
        "--pos-line-mid", "--pos-line-am", "--pos-line-fw", "--pos-line-sub"],
    "match.html shot outcomes": ["--shot-ok", "--shot-fail", "--shot-goal",
        "--shot-blocked", "--shot-post"],
    "match.html position badges": ["--pos-gk-ink", "--pos-def-ink", "--pos-mid-ink",
        "--pos-fwd-ink"],
    "players.html metric groups": ["--group-passing", "--group-creation",
        "--group-shooting", "--group-carrying", "--group-defending", "--group-aerial",
        "--group-discipline", "--group-tempo", "--group-halfspaces", "--group-holdup",
        "--group-setpieces", "--group-goalkeeping"],
    "players.html evidence layers": ["--layer-through", "--layer-receipt", "--layer-shot",
        "--layer-neutral", "--layer-quick", "--layer-blocked", "--layer-clearance",
        "--layer-challenge", "--layer-save"],
    "pitch layer series (PAL / TPAL)": ["--series-ok", "--series-fail", "--series-pass",
        "--series-prog", "--series-carry", "--series-box", "--series-alt",
        "--series-cool", "--series-warm", "--series-mint", "--series-neutral"],
    "percentile ramp": ["--rank-top", "--rank-high", "--rank-mid", "--rank-low",
        "--rank-bottom"],
    "W/D/L result inks": ["--positive-ink", "--caution-ink", "--negative-ink"],
    "lab series": ["--series-1", "--series-2", "--series-3", "--series-4", "--series-5"],
}
# Which family each series actually renders in, so it is measured in the scope
# that paints it rather than in one that merely resolves it.
SERIES_FAMILY = {
    "match.html defensive actions": "match", "match.html position lines": "match",
    "match.html shot outcomes": "match", "match.html position badges": "match",
    "players.html metric groups": "app", "players.html evidence layers": "app",
    "pitch layer series (PAL / TPAL)": "app", "percentile ramp": "app",
    "W/D/L result inks": "match", "lab series": "lab",
}


def aliases_and_usage(blocks):
    """(aliases to skip, family -> tokens that family's pages actually read).

    Two kinds of noise to remove. An ALIAS -- a :root declaration whose whole
    value is one var() -- has the same value as the role token it points at,
    so measuring both says everything twice. And a token declared in a scope
    a family inherits is not necessarily a token that family PAINTS:
    measuring match.html's action colours inside the writing-lab family is
    arithmetic about a combination that does not exist.
    """
    alias = set()
    for sel, decls in blocks:
        if sel != ":root":
            continue
        for n, v in decls.items():
            if re.fullmatch(r"var\(\s*--[\w-]+\s*\)", v.strip()):
                alias.add(n)

    declared = {}
    for _sel, decls in blocks:
        for n, v in decls.items():
            declared.setdefault(n, v)

    def expand(seed):
        """seed tokens plus everything they resolve through."""
        out, stack = set(), list(seed)
        while stack:
            n = stack.pop()
            if n in out:
                continue
            out.add(n)
            for ref in re.findall(r"var\(\s*(--[\w-]+)", declared.get(n, "")):
                stack.append(ref)
        return out

    use = {}
    for page, fam in A.FAMILY.items():
        if not page.endswith(".html"):
            continue
        src = (A.ROOT / page).read_text(encoding="utf-8")
        seen = set(re.findall(r"var\(\s*(--[\w-]+)", src))
        # match.html hands token NAMES to its canvas bridge as strings.
        seen |= set(re.findall(r"'(--[\w-]+)'", src))
        use.setdefault(fam, set()).update(expand(seen))
    # gate.js is loaded by pages in several families; its tokens belong to the
    # overlay, which is the same everywhere.
    gate = set(re.findall(r"var\(\s*(--[\w-]+)",
                          (A.ROOT / "dashboard" / "gate.js").read_text(encoding="utf-8")))
    for fam in use:
        use[fam] |= gate
    return alias, use


def main() -> int:
    blocks = A._blocks_from((A.ROOT / "dashboard" / "tokens.css").read_text(encoding="utf-8"))
    names = sorted({n for _, d in blocks for n in d})

    # ------------------------------------------------------------ contrast
    alias, use = aliases_and_usage(blocks)
    rows, unparsed, unclassified, skipped_unused = [], [], set(), 0
    for fam in FAMILIES:
        used = use.get(fam, set())
        for theme in ("light", "dark"):
            classes = A.STATE[(fam, theme)]
            light_app = A.STATE[("app", "light")]

            def val(tok, cls=None):
                raw = A.resolve(tok, cls if cls is not None else classes, blocks)
                return parse(raw) if raw else None

            default_grounds = [("--ground", val("--ground")),
                               ("--surface-raised", val("--surface-raised"))]
            if not all(g for _, g in default_grounds):
                continue
            for n in names:
                if n in alias or n.startswith(NOT_A_COLOUR):
                    continue
                if n not in used:
                    skipped_unused += 1
                    continue
                cat = category(n)
                if cat == "ground":
                    continue
                if cat == "?":
                    unclassified.add(n)
                    continue
                raw = A.resolve(n, classes, blocks)
                if raw is None:
                    continue
                fg = parse(raw)
                if fg is None:
                    unparsed.append((fam, theme, n, raw))
                    continue
                named = grounds_for(n)
                if named:
                    grounds = []
                    for gname in named:
                        if gname.endswith("@app-light"):
                            g = val(gname.split("@")[0], light_app)
                            grounds.append((gname.split("@")[0] + " (light)", g))
                        else:
                            grounds.append((gname, val(gname)))
                    grounds = [(gn, g) for gn, g in grounds if g]
                    if not grounds:
                        grounds = default_grounds
                else:
                    grounds = default_grounds
                need = 4.5 if cat == "text" else 3.0
                for gname, g in grounds:
                    r = ratio(over(fg, g), over(g, (255, 255, 255, 1.0)))
                    rows.append({"fam": fam, "theme": theme, "token": n, "cat": cat,
                                 "on": gname, "ratio": r, "need": need,
                                 "pass": r >= need, "value": raw})

    fails = [r for r in rows if not r["pass"]]
    fails.sort(key=lambda r: r["ratio"])

    def table(rs):
        out = ["| scope | token | category | on | value | ratio | needs |",
               "|---|---|---|---|---|---|---|"]
        for r in rs:
            out.append(f"| `{r['fam']}` {r['theme']} | `{r['token']}` | {r['cat']} | "
                       f"{r['on']} | `{r['value']}` | **{r['ratio']:.2f}** | {r['need']} |")
        return "\n".join(out)

    md = [
        "# Computed contrast",
        "",
        "Generated by `python restyle/palette_audit.py`. Every foreground token in",
        "`tokens.css`, resolved in every family scope and both themes, measured",
        "against that family's `--ground` and `--surface-raised`.",
        "",
        "WCAG 2.1 relative luminance. A token carrying alpha is composited over the",
        "ground before measuring, because that is what the eye gets. Text needs",
        "4.5:1 (1.4.3 AA); graphical objects, data marks and UI boundaries need 3:1",
        "(1.4.11).",
        "",
        "Each token is measured against the surface it is actually painted on,",
        "which the `on` column names. Most sit on the family's `--ground` and",
        "`--surface-raised`; a pitch colour is measured on the pitch, the gate's",
        "ink on the gate's card, `--ink-on-accent` on the accent, a badge ink on",
        "its own pill. A first pass that measured everything against the page",
        "ground reported 1,146 failures, almost all of them arithmetic about a",
        "surface the token never touches.",
        "",
        "Only tokens a family's own pages read are measured in that family, and",
        "compatibility aliases are skipped because they carry the same value as",
        "the role token they point at.",
        "",
        "**What this still cannot know.** Whether a token is really used as text",
        "rather than as a mark. The category comes from the name, and it is",
        "printed, so a wrong row can be spotted.",
        "",
        f"**{len(fails)} failures out of {len(rows)} measurements.**",
        "",
        "## Failures",
        "",
        "Ordered text first, then data marks, then boundaries, because that is the",
        "order in which they matter. A text failure is unreadable content. A mark",
        "failure is a data point the reader cannot find. A boundary failure is",
        "often fine: WCAG 1.4.11 applies to a boundary that is REQUIRED to identify",
        "a control or its state, and most of the hairlines below are decoration --",
        "a rule between two table rows that are already separated by position. They",
        "are listed because the line between decoration and affordance is a design",
        "judgement, and Phase 3 is where it gets made.",
        "",
    ]
    if fails:
        for cat in ("text", "mark", "boundary"):
            sub = [r for r in fails if r["cat"] == cat]
            if sub:
                md += [f"### {cat} — {len(sub)} failing", "", table(sub), ""]
    else:
        md.append("None.")
    md += ["", "## Everything, by scope", ""]
    for fam in FAMILIES:
        for theme in ("light", "dark"):
            sub = [r for r in rows if r["fam"] == fam and r["theme"] == theme]
            if not sub:
                continue
            nf = sum(1 for r in sub if not r["pass"])
            md += [f"### `{fam}` {theme} — {len(sub)} measurements, {nf} failing", "",
                   table(sorted(sub, key=lambda r: (r["pass"], r["ratio"]))), ""]
    if unparsed:
        md += ["## Not a colour, or not parseable", "",
               "Skipped rather than guessed at:", ""]
        seen = set()
        for fam, theme, n, raw in unparsed:
            if n in seen:
                continue
            seen.add(n)
            md.append(f"- `{n}` = `{raw}`")
        md.append("")
    if unclassified:
        md += ["## Unclassified", "",
               "The name matched no category, so these were measured as nothing. Each",
               "needs a category adding to `palette_audit.py` or a clearer name:", ""]
        md += [f"- `{n}`" for n in sorted(unclassified)] + [""]
    OUT_CONTRAST.write_text("\n".join(md), encoding="utf-8")

    # ------------------------------------------------------- separability
    sep_rows = []
    for label, toks in SERIES.items():
        fam = SERIES_FAMILY[label]
        for theme in ("light", "dark"):
            classes = A.STATE[(fam, theme)]
            got = {}
            for n in toks:
                raw = A.resolve(n, classes, blocks)
                c = parse(raw) if raw else None
                if c:
                    got[n] = (c, raw)
            keys = sorted(got)
            for i in range(len(keys)):
                for j in range(i + 1, len(keys)):
                    a, b = keys[i], keys[j]
                    d = ciede2000(got[a][0], got[b][0])
                    sep_rows.append({"set": label, "fam": fam, "theme": theme,
                                     "a": a, "b": b, "av": got[a][1], "bv": got[b][1],
                                     "d": d})
    flagged = sorted([r for r in sep_rows if r["d"] < 10], key=lambda r: r["d"])

    sm = [
        "# Series separability",
        "",
        "Generated by `python restyle/palette_audit.py`. CIEDE2000 between every",
        "pair within each categorical palette, in the family that paints it, in",
        "both themes.",
        "",
        "A categorical palette is only as good as its closest pair: a reader does",
        "not compare a mark with the legend, they compare it with the mark next to",
        "it. Flagged below **10**, which is roughly where two small marks stop",
        "being reliably told apart at a glance; **severe below 5**, which is near",
        "the threshold of noticing any difference at all.",
        "",
        "Some of these are deliberate. `tokens.css` says so for the evidence",
        "layers: a blocked shot, a clearance, a challenge and a save were given",
        "three hues between them, and were named separately so Phase 3 could",
        "diverge them on purpose. A zero here is that, showing up as arithmetic.",
        "",
        f"**{len(flagged)} flagged pairs out of {len(sep_rows)} compared.**",
        "",
        "| set | scope | pair | values | ΔE00 |",
        "|---|---|---|---|---|",
    ]
    for r in flagged:
        sev = " **severe**" if r["d"] < 5 else ""
        sm.append(f"| {r['set']} | `{r['fam']}` {r['theme']} | `{r['a']}` / `{r['b']}` | "
                  f"`{r['av']}` / `{r['bv']}` | **{r['d']:.1f}**{sev} |")
    sm += ["", "## Closest pair in every set", "",
           "| set | scope | closest pair | ΔE00 |", "|---|---|---|---|"]
    for label in SERIES:
        for theme in ("light", "dark"):
            sub = [r for r in sep_rows if r["set"] == label and r["theme"] == theme]
            if not sub:
                continue
            w = min(sub, key=lambda r: r["d"])
            sm.append(f"| {label} | `{w['fam']}` {theme} | `{w['a']}` / `{w['b']}` | "
                      f"{w['d']:.1f} |")
    OUT_SEPARABILITY.write_text("\n".join(sm) + "\n", encoding="utf-8")

    print(f"contrast.md: {len(rows)} measurements, {len(fails)} failures, "
          f"{len(unclassified)} unclassified tokens")
    print(f"separability.md: {len(sep_rows)} pairs, {len(flagged)} flagged "
          f"({sum(1 for r in flagged if r['d'] < 5)} severe)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
