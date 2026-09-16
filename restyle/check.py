"""Run all three Phase 1 gates. Non-zero if any of them fails.

They answer three different questions and none of them subsumes another:

  assert_tokens.py        every literal I recorded replacing resolves back to
                          itself, and every page-local pin still beats the
                          family scope that would otherwise swallow it.
  assert_page_parity.py   every custom property every page READS resolves to
                          what it resolved at the branch point.
  assert_rule_parity.py   every ordinary CSS declaration, in the page and in
                          the stylesheets it links, expands to what it
                          expanded to at the branch point.

The first is a ledger and only sees what was written down. The second catches
a token whose value moved underneath a page. The third catches a rule whose
value moved, and is the only one that would notice a var() pointed at the
wrong token -- which is the actual work of this refactor.

    python restyle/check.py
"""
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
GATES = ["assert_tokens.py", "assert_page_parity.py", "assert_rule_parity.py"]


def main() -> int:
    bad = []
    for g in GATES:
        print(f"===== {g} " + "=" * (58 - len(g)))
        r = subprocess.run([sys.executable, str(HERE / g)], cwd=HERE.parent)
        if r.returncode:
            bad.append(g)
        print()
    if bad:
        print(f"FAILED: {', '.join(bad)}")
        return 1
    print("all three gates pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
