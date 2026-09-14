#!/usr/bin/env python3
"""Static and payload checks for the read-only model laboratory."""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
page = (ROOT / "dashboard" / "model-lab.html").read_text(encoding="utf-8")
builder = (ROOT / "pipeline" / "build_model_lab_dashboard.py").read_text(encoding="utf-8")
for label in ("overview", "validation", "features", "matches", "monitoring"):
    assert f'id="{label}"' in page
assert "gate.js" in page and "model-lab-data.js" in page
assert "can_promote\": False" in builder and "can_activate\": False" in builder
assert "SUPABASE_SERVICE_KEY" not in page
assert "Coefficient explorer" in page and "Forecast dissection" in page

payload_path = ROOT / "dashboard" / "model-lab-data.js"
if payload_path.is_file():
    text = payload_path.read_text(encoding="utf-8")
    payload = json.loads(text.removeprefix("window.MODEL_LAB_DATA=").removesuffix(";\n"))
    assert payload["model"]["feature_schema_version"] == 2
    assert payload["model"]["feature_count"] == 29
    assert payload["guardrails"] == {
        "can_activate": False,
        "can_promote": False,
        "note": "The lab visualizes immutable artifacts. Lifecycle changes remain separate reviewed commands.",
        "read_only": True,
    }
    assert payload["validation_folds"] and payload["candidate_ranking"]
print("Model lab dashboard checks passed")
