"""Find out what WhoScored calls Leagues Cup (and whether they cover it at all).

soccerdata's available_leagues() only lists what is already configured locally, so it
cannot tell us whether WhoScored publishes Leagues Cup. This asks WhoScored directly,
reusing the same browser session the scraper already uses to get past their bot checks.

It prints candidate "Region - Tournament" names. Whatever comes back is the exact string
that goes in pipeline/league_dict.json under "WhoScored".

Usage:
    python pipeline/find_cup_league.py
"""
from __future__ import annotations

import json
import re
import sys

from scrape_and_load import get_scraper

KEYWORDS = ("leagues cup", "concacaf", "champions cup", "liga mx", "mexico", "mx")


def page_source_via_driver(ws) -> str | None:
    """Try the selenium driver, whatever soccerdata calls it in this version."""
    for attr in ("_driver", "driver", "_browser", "browser"):
        drv = getattr(ws, attr, None)
        if drv is None:
            continue
        try:
            drv.get("https://www.whoscored.com/")
            return drv.page_source
        except Exception:  # noqa: BLE001
            continue
    return None


def page_source_via_reader(ws) -> str | None:
    """Fall back to the reader's own download helper."""
    for meth in ("_download_and_save", "_download"):
        fn = getattr(ws, meth, None)
        if fn is None:
            continue
        try:
            res = fn("https://www.whoscored.com/")
            if hasattr(res, "read"):
                data = res.read()
                return data.decode("utf-8", "ignore") if isinstance(data, bytes) else str(data)
            if isinstance(res, bytes):
                return res.decode("utf-8", "ignore")
            if isinstance(res, str):
                return res
        except Exception:  # noqa: BLE001
            continue
    return None


def extract_regions(html: str) -> list[dict]:
    """WhoScored embeds its region/tournament tree as a JS array."""
    for pat in (r"allRegions\s*=\s*(\[.*?\]);", r"var\s+allRegions\s*=\s*(\[.*?\]);"):
        m = re.search(pat, html, re.S)
        if not m:
            continue
        raw = m.group(1)
        # the blob is JS, not strict JSON: quote bare keys, swap single quotes
        fixed = re.sub(r"(\{|,)\s*([A-Za-z_][A-Za-z0-9_]*)\s*:", r'\1"\2":', raw)
        fixed = fixed.replace("'", '"')
        for candidate in (raw, fixed):
            try:
                return json.loads(candidate)
            except Exception:  # noqa: BLE001
                continue
    return []


def main() -> int:
    print("Opening WhoScored with the scraper's browser session...", flush=True)
    try:
        ws = get_scraper("USA-MLS", "2627", headless=False)
    except Exception as e:  # noqa: BLE001
        print(f"Could not start the scraper: {e}", file=sys.stderr)
        return 1

    html = page_source_via_driver(ws) or page_source_via_reader(ws)
    if not html:
        print("\nCould not read the WhoScored homepage automatically.", file=sys.stderr)
        print("Manual fallback: open whoscored.com, search 'Leagues Cup', and send me", file=sys.stderr)
        print("the page URL plus the breadcrumb text above the fixture list.", file=sys.stderr)
        return 1

    print(f"  got {len(html):,} chars of page source", flush=True)

    regions = extract_regions(html)
    hits: list[str] = []
    if regions:
        print(f"  parsed {len(regions)} regions\n", flush=True)
        for reg in regions:
            rname = reg.get("name") or reg.get("Name") or ""
            for t in (reg.get("tournaments") or reg.get("Tournaments") or []):
                tname = t.get("name") or t.get("Name") or ""
                full = f"{rname} - {tname}"
                if any(k in full.lower() for k in KEYWORDS):
                    hits.append(full)
    else:
        # regions blob not parseable: fall back to scanning raw text
        print("  could not parse the region tree, scanning raw text instead\n", flush=True)
        for m in re.finditer(r"[A-Za-z .&']{3,30}\s*-\s*[A-Za-z .&']*(?:Leagues Cup|Champions Cup)", html):
            hits.append(m.group(0).strip())

    if hits:
        print("Candidates found on WhoScored:\n", flush=True)
        for h in sorted(set(hits)):
            print(f'  "{h}"', flush=True)
        print(
            "\nAdd the right one to pipeline/league_dict.json, for example:\n"
            '  "USA-Leagues Cup": { "WhoScored": "<paste the exact string above>" }',
            flush=True,
        )
    else:
        print("No Leagues Cup / Concacaf competition found on the WhoScored homepage.", flush=True)
        print("That likely means they do not carry it, or it sits under a region name", flush=True)
        print("these keywords miss. Search whoscored.com manually and send me the URL.", flush=True)

    # always dump the region names, so we can see how they organise things
    if regions:
        names = sorted({(r.get("name") or r.get("Name") or "") for r in regions})
        print(f"\nAll {len(names)} WhoScored regions:", flush=True)
        print("  " + ", ".join(n for n in names if n), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
