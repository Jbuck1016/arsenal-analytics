#!/usr/bin/env python3
"""Benchmark the untouched 2025/26 model holdout against free closing odds.

Football-Data.co.uk publishes historical CSVs for league-match prediction.
Closing average 1X2 prices are converted to probabilities by proportional
overround removal. Matching uses date and normalized club names, never scores.
"""
from __future__ import annotations

import difflib
import io
import json
import re
import unicodedata
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import log_loss

import analyze_match_feature_families as families
import evaluate_model_philosophies as philosophies
import evaluate_multiseason_model as multi
import train_match_baselines as baseline


SEASON = "2526"
CODES = {
    "ENG-Premier League": "E0", "ESP-La Liga": "SP1", "ITA-Serie A": "I1",
    "GER-Bundesliga": "D1", "FRA-Ligue 1": "F1",
}
ALIASES = {
    "manchester united": "man united", "manchester city": "man city",
    "newcastle united": "newcastle", "tottenham hotspur": "tottenham",
    "west ham united": "west ham", "wolverhampton wanderers": "wolves",
    "nottingham forest": "nottm forest", "brighton and hove albion": "brighton",
    "paris saint germain": "paris sg", "olympique marseille": "marseille",
    "olympique lyonnais": "lyon", "internazionale": "inter", "ac milan": "milan",
    "hellas verona": "verona", "atletico de madrid": "ath madrid",
    "athletic club": "ath bilbao", "real betis balompie": "betis",
    "celta de vigo": "celta", "bayern munchen": "bayern munich",
    "borussia dortmund": "dortmund", "borussia monchengladbach": "mgladbach",
    "bayer 04 leverkusen": "leverkusen", "rasenballsport leipzig": "rb leipzig",
}


def normalized(value: str) -> str:
    value = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode().lower()
    value = re.sub(r"[^a-z0-9 ]+", "", value)
    value = re.sub(r"\b(fc|cf|ssc|as|ac|calcio|club|football)\b", "", value)
    value = re.sub(r"\s+", " ", value).strip()
    return ALIASES.get(value, value)


def download(league: str, code: str) -> pd.DataFrame:
    url = f"https://www.football-data.co.uk/mmz4281/{SEASON}/{code}.csv"
    request = urllib.request.Request(url, headers={"User-Agent": "FutScout research benchmark/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        frame = pd.read_csv(io.BytesIO(response.read()))
    frame["date"] = pd.to_datetime(frame["Date"], dayfirst=True, errors="coerce")
    frame["league"] = league
    frame["source_url"] = url
    return frame


def odds_columns(frame: pd.DataFrame) -> tuple[str, str, str, str]:
    for label, columns in (
        ("average_closing", ("AvgCH", "AvgCD", "AvgCA")),
        ("bet365_closing", ("B365CH", "B365CD", "B365CA")),
        ("average_available", ("AvgH", "AvgD", "AvgA")),
    ):
        if all(column in frame and frame[column].notna().any() for column in columns):
            return label, *columns
    raise RuntimeError("no usable 1X2 odds columns")


def best_match(model_row: pd.Series, candidates: pd.DataFrame) -> tuple[int | None, float]:
    home, away = normalized(model_row["home_team"]), normalized(model_row["away_team"])
    best_index, best_score = None, -1.0
    for index, row in candidates.iterrows():
        score = (difflib.SequenceMatcher(None, home, normalized(row["HomeTeam"])).ratio() +
                 difflib.SequenceMatcher(None, away, normalized(row["AwayTeam"])).ratio()) / 2
        if score > best_score:
            best_index, best_score = int(index), score
    return (best_index if best_score >= 0.72 else None), best_score


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    tournament = json.loads((root / "artifacts" / "model_reports" / "model_philosophy_tournament.json").read_text(encoding="utf-8"))
    final_models = tournament["folds"]["train_2324_2425_test_2526"]["models"]
    winner_name = tournament["winner"]
    winner = final_models[winner_name]
    shooting = final_models["shooting_led"]
    odds_frames = {league: download(league, code) for league, code in CODES.items()}
    matched = []
    for league, odds in odds_frames.items():
        label, hcol, dcol, acol = odds_columns(odds)
        for _, row in odds.iterrows():
            prices = np.asarray([row[hcol], row[dcol], row[acol]], dtype=float)
            result = str(row.get("FTR", ""))
            if result not in baseline.CLASS_ORDER or not np.isfinite(prices).all() or (prices <= 1).any():
                continue
            raw = 1.0 / prices; probabilities = raw / raw.sum()
            matched.append({
                "date": str(row["date"].date()), "league": league, "home_team": row["HomeTeam"], "away_team": row["AwayTeam"],
                "result": result, "odds_kind": label, "odds_probabilities": probabilities.tolist(), "overround": float(raw.sum() - 1.0),
            })
    labels = np.asarray([row["result"] for row in matched])
    odds_prob = np.asarray([row["odds_probabilities"] for row in matched])
    actual = np.asarray([baseline.CLASS_ORDER.index(value) for value in labels])
    odds_loss = float(log_loss(actual, odds_prob, labels=[0, 1, 2]))
    model_loss = float(winner["log_loss"])
    by_league = {}
    for league in CODES:
        indexes = [i for i, row in enumerate(matched) if row["league"] == league]
        if indexes:
            model_league = winner["by_league"][league]
            control_league = shooting["by_league"][league]
            by_league[league] = {"matches": len(indexes), "model_matches": model_league["matches"], "same_population_count": len(indexes) == model_league["matches"], "odds_log_loss": float(log_loss(actual[indexes], odds_prob[indexes], labels=[0, 1, 2])), "model_log_loss": float(model_league["log_loss"]), "shooting_control_log_loss": float(control_league["log_loss"])}
    comparable = len(matched) == winner["matches"] and all(row["same_population_count"] for row in by_league.values())
    report = {
        "report_schema_version": 2, "created_at": datetime.now(UTC).isoformat(), "season": SEASON,
        "source": "Football-Data.co.uk historical league CSVs", "source_page": "https://www.football-data.co.uk/downloadm.php",
        "method": "average closing 1X2 odds when available; proportional overround removal; exact season-and-league population count reconciliation",
        "model": f"{winner_name}_poisson_train_2324_2425_test_2526",
        "model_full_holdout_log_loss": model_loss, "matched": len(matched), "holdout_matches": winner["matches"],
        "coverage": len(matched) / winner["matches"], "population_counts_reconciled": comparable,
        "odds_log_loss": odds_loss, "model_log_loss_on_common_matches": model_loss,
        "model_delta_vs_odds": model_loss - odds_loss,
        "shooting_control_log_loss": float(shooting["log_loss"]),
        "winner_delta_vs_shooting_control": model_loss - float(shooting["log_loss"]),
        "by_league": by_league,
        "interpretation": "Markets are an external benchmark, not a training target. Positive model delta means the model trails closing odds.",
        "matches": matched,
    }
    output = root / "artifacts" / "model_reports" / "bookmaker_benchmark.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Matched {len(matched)}/{shooting['matches']} ({report['coverage']:.1%}); model={model_loss:.4f}; odds={odds_loss:.4f}")
    print(f"Report: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
