"""Run bridge-probe.html and print its verdict.

The probe answers one question: can canvas code get its colours from
tokens.css? match.html has 118 canvas paint assignments, and a canvas
silently ignores a var() string rather than erroring, so the substitution
technique used on players.html and teams.html is invalid there. The
alternative is a bridge -- read the tokens through getComputedStyle and hand
canvas concrete strings -- and this establishes whether that works.

Exits non-zero on any UNEXPECTED failure. Test 3 is designed to fail and its
failures are counted separately; a run that reports eight expected failures
and zero unexpected ones is the passing result.

    python restyle/run_bridge_probe.py
"""
import pathlib
import re
import sys

from playwright.sync_api import sync_playwright

PROBE = pathlib.Path(__file__).with_name("bridge-probe.html")


def main() -> int:
    if not PROBE.exists():
        print(f"probe not found at {PROBE}")
        return 1

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(PROBE.as_uri())
        # The probe builds its report inside a setTimeout so the iframe in
        # test 4 has time to parse its stylesheet. Wait for the verdict to
        # actually be written rather than sleeping a guessed interval.
        page.wait_for_function(
            "() => document.getElementById('out')"
            "&& document.getElementById('out').innerText.includes('VERDICT')",
            timeout=10_000,
        )
        report = page.inner_text("#out")
        browser.close()

    print(report)

    m = re.search(r"unexpected failures\s*:\s*(\d+)", report)
    if not m:
        print("\nCOULD NOT READ A VERDICT FROM THE PROBE -- treating as failure")
        return 1

    unexpected = int(m.group(1))
    if unexpected:
        print(f"\n{unexpected} unexpected failure(s): the bridge is NOT proven")
        return 1

    print("\nbridge proven: 0 unexpected failures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
