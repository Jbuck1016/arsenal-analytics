#!/usr/bin/env python3
"""Behavior checks for bounded PostgREST schema-cache retries."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import train_match_baselines as baseline


class Query:
    def __init__(self, failures: int, code: str = "PGRST002") -> None:
        self.failures = failures
        self.code = code
        self.calls = 0

    def execute(self):
        self.calls += 1
        if self.calls <= self.failures:
            raise baseline.APIError({"message": "transient", "code": self.code, "hint": None, "details": None})
        return "ok"


baseline.time.sleep = lambda _: None
transient = Query(2)
assert baseline.execute_with_retry(transient) == "ok"
assert transient.calls == 3

permanent = Query(1, "PGRST404")
try:
    baseline.execute_with_retry(permanent)
except baseline.APIError:
    pass
else:
    raise AssertionError("non-transient PostgREST error was retried or swallowed")
assert permanent.calls == 1
print("PostgREST retry checks passed")
