"""Safety checks for evidence-bound model status transitions."""

from pathlib import Path


def main() -> None:
    source = (Path(__file__).resolve().parents[1] / "promote_model_candidate.py").read_text(encoding="utf-8")
    compile(source, "promote_model_candidate.py", "exec")
    assert 'TRANSITIONS = {"validated": "training", "shadow": "validated"}' in source
    assert '"active"' not in source
    assert "artifact_digest" in source and "report_digest" in source
    assert ".eq(\"status\", required_status)" in source
    assert "Dry run only" in source and "--execute" in source
    assert "no forecasts were generated or published" in source
    print("Model-candidate promotion safety checks passed")


if __name__ == "__main__":
    main()
