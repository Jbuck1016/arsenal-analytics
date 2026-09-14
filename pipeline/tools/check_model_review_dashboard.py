#!/usr/bin/env python3
"""Static safety checks for the key-free private model review page."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
page = (ROOT / "dashboard" / "model-review.html").read_text(encoding="utf-8")
builder = (ROOT / "pipeline" / "build_model_review_dashboard.py").read_text(encoding="utf-8")
assert "SUPABASE_SERVICE_KEY" not in page
assert "SHADOW · PRIVATE" in page
assert "Password-gated review output" in page
assert "scoreline_distribution" not in builder
assert '"publication_allowed": False' in builder
assert '"review_ready": review_ready' in builder
assert "model-review-data.js" in page
assert 'ROOT / "artifacts" / "model-review"' in builder
assert "BLOCKED · STALE INPUT" in page
print("Model review dashboard safety checks passed")
