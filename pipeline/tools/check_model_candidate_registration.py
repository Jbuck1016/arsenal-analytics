"""Safety checks for exact-artifact candidate registration."""

from pathlib import Path


def main() -> None:
    source = (Path(__file__).resolve().parents[1] / "register_model_candidate.py").read_text(encoding="utf-8")
    compile(source, "register_model_candidate.py", "exec")
    assert '"status": "training"' in source
    assert '"status": "shadow"' not in source and '"status": "active"' not in source
    assert "artifact digest does not match" in source
    assert "validation report digest does not match" in source
    assert "eligible_for_shadow_review" in source
    assert "Dry run only" in source
    assert "--execute" in source
    print("Exact model-candidate registration safety checks passed")


if __name__ == "__main__":
    main()
