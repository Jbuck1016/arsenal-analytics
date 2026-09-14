"""Synthetic checks for frozen prediction scoring and its sample gate."""

from pathlib import Path
import sys


PIPELINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PIPELINE))

import score_prediction_snapshot as scoring  # noqa: E402


def prediction(game_id: str, league: str = "ENG-Premier League") -> dict:
    return {
        "game_id": game_id, "league": league,
        "date": "2026-09-12T12:00:00+00:00",
        "home_win_probability": 0.6, "draw_probability": 0.25, "away_win_probability": 0.15,
        "home_expected_goals": 1.8, "away_expected_goals": 0.8,
    }


def main() -> None:
    predictions = [prediction("1"), prediction("2")]
    matches = [
        {"game_id": "1", "home_score": 2, "away_score": 0},
        {"game_id": "2", "home_score": None, "away_score": None},
    ]
    report = scoring.evaluate(predictions, matches)
    assert report["resolved"] == 1 and report["pending"] == 1
    assert report["overall"]["matches"] == 1
    assert report["by_league"]["ENG-Premier League"]["matches"] == 1
    assert report["sample_gate"]["decision"] == "collect_more_results"
    eligible, through = scoring.evaluation_predictions({
        "as_of": "2026-09-10T12:00:00+00:00",
        "predictions": predictions + [prediction("3") | {"date": "2026-10-01T12:00:00+00:00"}],
    })
    assert [row["game_id"] for row in eligible] == ["1", "2"]
    assert through == "2026-09-17T12:00:00+00:00"
    try:
        scoring.evaluate([prediction("1"), prediction("1")], matches)
    except RuntimeError as exc:
        assert "duplicate" in str(exc)
    else:
        raise AssertionError("duplicate predictions were accepted")
    source = (PIPELINE / "score_prediction_snapshot.py").read_text(encoding="utf-8")
    assert ".insert(" not in source and ".upsert(" not in source and ".update(" not in source
    print("Prediction snapshot scoring checks passed")


if __name__ == "__main__":
    main()
