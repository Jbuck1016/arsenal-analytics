#!/usr/bin/env python3
"""Build deterministic provider-to-fixture team mappings for ML backfills.

The command is dry-run by default. With ``--execute`` it writes only the
service-only ``ml_match_team_map`` table. Historical observations and rolling
features are built in PostgreSQL from this deterministic side mapping.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from dotenv import load_dotenv
from supabase import Client, create_client

from historical_source_exceptions import ids_for_season


TOP_FIVE = (
    "ENG-Premier League",
    "ESP-La Liga",
    "ITA-Serie A",
    "GER-Bundesliga",
    "FRA-Ligue 1",
)


def cache_root() -> Path:
    override = os.environ.get("SOCCERDATA_DIR")
    if override:
        return Path(override).expanduser().resolve() / "data" / "WhoScored" / "events"
    return Path.home() / "soccerdata" / "data" / "WhoScored" / "events"


def client() -> Client:
    repo_root = Path(__file__).resolve().parents[1]
    load_dotenv(repo_root / ".env")
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY are required")
    return create_client(url, key)


def fetch_pages(query, page_size: int = 1000) -> list[dict]:
    rows: list[dict] = []
    offset = 0
    while True:
        page = query.range(offset, offset + page_size - 1).execute().data or []
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += page_size


def fetch_matches(db: Client, season: str) -> dict[str, dict]:
    rows = fetch_pages(
        db.table("matches")
        .select("game_id,season,league,home_team,away_team,home_score,away_score")
        .eq("season", season)
        .in_("league", list(TOP_FIVE))
        .order("game_id")
    )
    return {
        str(row["game_id"]): row
        for row in rows
        if row.get("home_score") is not None and row.get("away_score") is not None
    }


def fetch_verified_games(db: Client, season: str) -> dict[str, str]:
    rows = fetch_pages(
        db.table("archive_match_manifest")
        .select("game_id,object_path")
        .eq("season", season)
        .not_.is_("verified_at", "null")
        .order("game_id")
    )
    return {str(row["game_id"]): str(row["object_path"]) for row in rows}


def build_rows(
    root: Path,
    season: str,
    matches: dict[str, dict],
    verified: dict[str, str],
) -> list[dict]:
    rows: list[dict] = []
    for game_id in sorted(set(matches) & set(verified)):
        match = matches[game_id]
        object_path = verified[game_id]
        expected_prefix = f"{season}/{match['league']}/"
        if not object_path.startswith(expected_prefix) or not object_path.endswith(".json.gz"):
            raise ValueError(f"{game_id}: invalid verified archive object path {object_path}")
        source_game_id = Path(object_path).name.removesuffix(".json.gz")
        path = root / f"{match['league']}_{season}" / f"{source_game_id}.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError(f"{game_id}: top-level JSON value must be an object")
        home = payload.get("home") or {}
        away = payload.get("away") or {}
        sides = (
            (home, match["home_team"], match["away_team"], True),
            (away, match["away_team"], match["home_team"], False),
        )
        for source, team, opponent, is_home in sides:
            team_id = source.get("teamId")
            source_team = source.get("name")
            if team_id is None or not source_team:
                raise ValueError(f"{game_id}: missing raw {'home' if is_home else 'away'} identity")
            rows.append(
                {
                    "game_id": game_id,
                    "team_id": str(team_id),
                    "team": team,
                    "opponent": opponent,
                    "source_team": source_team,
                    "is_home": is_home,
                    "season": season,
                    "league": match["league"],
                    "source_provider": "WhoScored",
                }
            )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2526")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--cache-root", type=Path)
    parser.add_argument("--batch-size", type=int, default=500)
    parser.add_argument("--game-batch-size", type=int, default=75)
    parser.add_argument("--observation-schema-version", type=int, default=1)
    parser.add_argument("--feature-schema-version", type=int, default=1)
    parser.add_argument(
        "--features-only",
        action="store_true",
        help="Resume a schema-v2 run after all typed observation rows are complete.",
    )
    args = parser.parse_args()
    if args.observation_schema_version not in {1, 2}:
        raise ValueError("--observation-schema-version must be 1 or 2")
    if args.feature_schema_version not in {1, 2}:
        raise ValueError("--feature-schema-version must be 1 or 2")
    if args.observation_schema_version != args.feature_schema_version:
        raise ValueError("observation and feature schema versions must advance together")

    db = client()
    matches = fetch_matches(db, args.season)
    excluded = ids_for_season(args.season)
    unknown_exclusions = excluded - set(matches)
    if unknown_exclusions:
        raise RuntimeError(f"source exceptions do not match canonical matches: {sorted(unknown_exclusions)}")
    model_matches = {game_id: row for game_id, row in matches.items() if game_id not in excluded}
    verified = fetch_verified_games(db, args.season)
    root = (args.cache_root or cache_root()).expanduser().resolve()
    rows = build_rows(root, args.season, model_matches, verified)

    expected = len(model_matches) * 2
    if len(rows) != expected:
        raise RuntimeError(f"expected {expected} side mappings, built {len(rows)}")
    if len({(row['game_id'], row['team_id']) for row in rows}) != len(rows):
        raise RuntimeError("duplicate provider team mapping detected")

    print(
        f"ML team-map plan: season={args.season} matches={len(model_matches)} "
        f"source_exceptions={len(excluded)} rows={len(rows)} execute={args.execute}"
    )
    if not args.execute:
        print("Dry run only; no writes")
        return 0

    if args.features_only:
        if args.feature_schema_version != 2:
            raise ValueError("--features-only is supported only for feature schema version 2")
        all_game_ids = sorted(model_matches)
        feature_rows = 0
        for offset in range(0, len(all_game_ids), args.game_batch_size):
            game_batch = all_game_ids[offset : offset + args.game_batch_size]
            feature_result = db.rpc(
                "ml_backfill_team_match_features_v2_batch",
                {"p_season": args.season, "p_game_ids": game_batch},
            ).execute()
            feature_rows += int(feature_result.data or 0)
            print(
                "Feature rows upserted: "
                f"{min(offset + len(game_batch), len(all_game_ids))}/{len(all_game_ids)} matches"
            )
        if feature_rows != 2 * len(all_game_ids):
            raise RuntimeError(
                f"Expected {2 * len(all_game_ids)} feature rows, got {feature_rows}"
            )
        print(f"Feature rows upserted total: {feature_rows}")
        return 0

    for offset in range(0, len(rows), args.batch_size):
        batch = rows[offset : offset + args.batch_size]
        db.table("ml_match_team_map").upsert(batch, on_conflict="game_id,team_id").execute()
        print(f"Mapped {min(offset + len(batch), len(rows))}/{len(rows)} team sides")
    observation_rows = 0
    for league in TOP_FIVE:
        game_ids = sorted(
            game_id for game_id, match in model_matches.items() if match["league"] == league
        )
        league_rows = 0
        for offset in range(0, len(game_ids), args.game_batch_size):
            game_batch = game_ids[offset : offset + args.game_batch_size]
            if args.observation_schema_version == 1:
                observation_rpc = "ml_backfill_team_match_observations"
                observation_args = {
                    "p_season": args.season,
                    "p_observation_schema_version": 1,
                    "p_league": league,
                    "p_game_ids": game_batch,
                }
            else:
                # V2 deliberately copies the stable V1 observation fields and
                # augments them. Only rebuild base rows when the batch is not
                # already complete; historical reruns otherwise waste most of
                # their statement budget re-aggregating stable data.
                existing_v1 = (
                    db.table("ml_team_match_observations")
                    .select("game_id,team")
                    .eq("season", args.season)
                    .eq("league", league)
                    .eq("observation_schema_version", 1)
                    .in_("game_id", game_batch)
                    .execute()
                )
                existing_pairs = {
                    (str(row["game_id"]), str(row["team"]))
                    for row in (existing_v1.data or [])
                }
                if len(existing_pairs) != 2 * len(game_batch):
                    db.rpc(
                        "ml_backfill_team_match_observations",
                        {
                            "p_season": args.season,
                            "p_observation_schema_version": 1,
                            "p_league": league,
                            "p_game_ids": game_batch,
                        },
                    ).execute()
                observation_rpc = "ml_backfill_team_match_observations_v2"
                observation_args = {
                    "p_season": args.season,
                    "p_league": league,
                    "p_game_ids": game_batch,
                }
            observation_result = db.rpc(observation_rpc, observation_args).execute()
            batch_rows = int(observation_result.data or 0)
            league_rows += batch_rows
            print(
                f"Observation rows upserted for {league}: "
                f"{min(offset + len(game_batch), len(game_ids))}/{len(game_ids)} matches"
            )
        observation_rows += league_rows
        if league_rows != 2 * len(game_ids):
            raise RuntimeError(
                f"{league}: expected {2 * len(game_ids)} observation rows, got {league_rows}"
            )
    print(f"Observation rows upserted total: {observation_rows}")
    if args.feature_schema_version == 1:
        feature_rpc = "ml_backfill_team_match_features"
        feature_args = {
            "p_season": args.season,
            "p_feature_schema_version": 1,
            "p_observation_schema_version": 1,
        }
        feature_result = db.rpc(feature_rpc, feature_args).execute()
        print(f"Feature rows upserted: {feature_result.data}")
    else:
        all_game_ids = sorted(model_matches)
        feature_rows = 0
        for offset in range(0, len(all_game_ids), args.game_batch_size):
            game_batch = all_game_ids[offset : offset + args.game_batch_size]
            feature_result = db.rpc(
                "ml_backfill_team_match_features_v2_batch",
                {"p_season": args.season, "p_game_ids": game_batch},
            ).execute()
            feature_rows += int(feature_result.data or 0)
            print(
                "Feature rows upserted: "
                f"{min(offset + len(game_batch), len(all_game_ids))}/{len(all_game_ids)} matches"
            )
        if feature_rows != 2 * len(all_game_ids):
            raise RuntimeError(
                f"Expected {2 * len(all_game_ids)} feature rows, got {feature_rows}"
            )
        print(f"Feature rows upserted total: {feature_rows}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
