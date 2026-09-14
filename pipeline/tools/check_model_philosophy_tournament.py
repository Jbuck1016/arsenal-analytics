#!/usr/bin/env python3
"""Contract checks for the isolated feature-philosophy experiment."""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / "pipeline" / "evaluate_model_philosophies.py").read_text(encoding="utf-8")
compile(source, "evaluate_model_philosophies.py", "exec")
assert "__all_without_shots__" in source
assert "promotion_decision\"] = \"research_only_no_lifecycle_change\"" in source

report = json.loads((ROOT / "artifacts" / "model_reports" / "model_philosophy_tournament.json").read_text(encoding="utf-8"))
assert report["promotion_decision"] == "research_only_no_lifecycle_change"
assert set(report["folds"]) == {"train_2324_test_2425", "train_2324_2425_test_2526"}
names = {row["name"] for row in report["summary"]}
assert {"shooting_led", "territory_led", "pressing_led", "territory_pressing", "all_without_shots"} <= names
for fold in report["folds"].values():
    shooting = set(fold["models"]["shooting_led"]["columns"])
    territory = set(fold["models"]["territory_led"]["columns"])
    assert any("shots" in name for name in shooting)
    assert not any("shots" in name for name in territory)
print("Model philosophy tournament checks passed")
