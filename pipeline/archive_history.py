#!/usr/bin/env python3
"""Archive cached historical match JSON to private Supabase Storage.

The command is dry-run by default.  ``--execute`` uploads deterministic gzip
objects, downloads them again for digest verification, and only then upserts a
verified row in ``archive_match_manifest``.  It never deletes relational rows.

Examples:

    python pipeline/archive_history.py --season 2526
    python pipeline/archive_history.py --season 2526 --execute
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import quote

import httpx
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
BUCKET = "historical-match-archive"


@dataclass(frozen=True)
class ArchiveObject:
    game_id: str
    source_game_id: str
    season: str
    league: str
    source_path: Path
    object_path: str
    compressed: bytes
    digest: str
    raw_bytes: int
    event_count: int
    lineup_count: int

    @property
    def compressed_bytes(self) -> int:
        return len(self.compressed)


def cache_root() -> Path:
    override = os.environ.get("SOCCERDATA_DIR")
    if override:
        return Path(override).expanduser().resolve() / "data" / "WhoScored" / "events"
    return Path.home() / "soccerdata" / "data" / "WhoScored" / "events"


def iter_cache_files(root: Path, season: str, leagues: Iterable[str]) -> Iterable[tuple[str, Path]]:
    for league in leagues:
        folder = root / f"{league}_{season}"
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.json")):
            if path.is_file():
                yield league, path


def build_archive_object(
    path: Path,
    season: str,
    league: str,
    canonical_game_id: str | None = None,
) -> ArchiveObject:
    raw = path.read_bytes()
    payload = json.loads(raw.decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("top-level JSON value must be an object")
    if not isinstance(payload.get("events"), list):
        raise ValueError("events must be a JSON array")
    players_value = payload.get("playerIdNameDictionary")
    if players_value is not None and not isinstance(players_value, dict):
        raise ValueError("playerIdNameDictionary must be a JSON object")
    compressed = gzip.compress(raw, compresslevel=9, mtime=0)
    digest = hashlib.sha256(compressed).hexdigest()
    players = payload.get("playerIdNameDictionary") or {}
    events = payload.get("events") or []
    return ArchiveObject(
        game_id=canonical_game_id or path.stem,
        source_game_id=path.stem,
        season=season,
        league=league,
        source_path=path,
        object_path=f"{season}/{league}/{path.stem}.json.gz",
        compressed=compressed,
        digest=digest,
        raw_bytes=len(raw),
        event_count=len(events),
        lineup_count=len(players),
    )


def _payload_date(value: object) -> str:
    text = str(value or "").strip()
    if not text:
        raise ValueError("raw payload is missing startDate")
    iso_candidate = text.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(iso_candidate).date().isoformat()
    except ValueError:
        pass
    for fmt in ("%m/%d/%Y %I:%M:%S %p", "%m/%d/%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            continue
    raise ValueError(f"unsupported raw startDate: {text}")


def canonical_id_map(
    sb: Client,
    season: str,
    leagues: Iterable[str],
) -> tuple[set[str], dict[tuple[str, str, str, str], list[str]], dict[tuple[str, str], str]]:
    known_ids: set[str] = set()
    fixtures: dict[tuple[str, str, str, str], list[str]] = {}
    names: dict[tuple[str, str], str] = {}
    for league in leagues:
        rows = (
            sb.table("matches")
            .select("game_id,date,home_team,away_team")
            .eq("season", season)
            .eq("league", league)
            .execute()
            .data
            or []
        )
        for row in rows:
            game_id = str(row["game_id"])
            known_ids.add(game_id)
            key = (
                league,
                str(row["date"])[:10],
                str(row["home_team"]),
                str(row["away_team"]),
            )
            fixtures.setdefault(key, []).append(game_id)
        name_rows = (
            sb.table("team_names")
            .select("event_name,match_name")
            .eq("league", league)
            .execute()
            .data
            or []
        )
        for row in name_rows:
            names[(league, str(row["event_name"]))] = str(row["match_name"])
    return known_ids, fixtures, names


def resolve_canonical_game_id(
    path: Path,
    league: str,
    known_ids: set[str],
    fixtures: dict[tuple[str, str, str, str], list[str]],
    names: dict[tuple[str, str], str],
) -> str:
    if path.stem in known_ids:
        return path.stem
    payload = json.loads(path.read_text(encoding="utf-8"))
    home_raw = str((payload.get("home") or {}).get("name") or "").strip()
    away_raw = str((payload.get("away") or {}).get("name") or "").strip()
    home = names.get((league, home_raw), home_raw)
    away = names.get((league, away_raw), away_raw)
    key = (league, _payload_date(payload.get("startDate")), home, away)
    candidates = fixtures.get(key, [])
    if len(candidates) != 1:
        raise RuntimeError(
            "raw WhoScored id does not resolve to exactly one canonical match: "
            f"source={path.stem} fixture={key} candidates={candidates}"
        )
    return candidates[0]


def storage_url(base_url: str, object_path: str) -> str:
    encoded = quote(object_path, safe="/")
    return f"{base_url.rstrip('/')}/storage/v1/object/{BUCKET}/{encoded}"


def upload_and_verify(client: httpx.Client, base_url: str, item: ArchiveObject) -> None:
    url = storage_url(base_url, item.object_path)
    response = client.put(
        url,
        content=item.compressed,
        headers={"content-type": "application/gzip", "x-upsert": "true"},
    )
    response.raise_for_status()
    downloaded = client.get(url)
    downloaded.raise_for_status()
    remote_digest = hashlib.sha256(downloaded.content).hexdigest()
    if remote_digest != item.digest:
        raise RuntimeError(
            f"archive digest mismatch for {item.game_id}: "
            f"expected {item.digest}, got {remote_digest}"
        )


def manifest_payload(item: ArchiveObject) -> dict:
    return {
        "game_id": item.game_id,
        "season": item.season,
        "league": item.league,
        "source_provider": "WhoScored",
        "object_bucket": BUCKET,
        "object_path": item.object_path,
        "compression": "gzip",
        "content_sha256": item.digest,
        "raw_bytes": item.raw_bytes,
        "compressed_bytes": item.compressed_bytes,
        "event_count": item.event_count,
        "lineup_count": item.lineup_count,
        "archive_schema_version": 1,
        "verified_at": datetime.now(timezone.utc).isoformat(),
    }


def get_clients() -> tuple[Client, httpx.Client, str]:
    root = Path(__file__).resolve().parents[1]
    load_dotenv(root / ".env")
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY are required")
    sb = create_client(url, key)
    http = httpx.Client(
        headers={"apikey": key, "authorization": f"Bearer {key}"},
        timeout=60,
    )
    return sb, http, url


def existing_verified(sb: Client, item: ArchiveObject) -> bool:
    response = (
        sb.table("archive_match_manifest")
        .select("content_sha256,verified_at")
        .eq("game_id", item.game_id)
        .limit(1)
        .execute()
    )
    rows = response.data or []
    return bool(
        rows
        and rows[0].get("verified_at")
        and rows[0].get("content_sha256") == item.digest
    )


def archive_item(sb: Client, http: httpx.Client, url: str, item: ArchiveObject) -> str:
    if existing_verified(sb, item):
        return "already verified"
    upload_and_verify(http, url, item)
    sb.table("archive_match_manifest").upsert(
        manifest_payload(item), on_conflict="game_id"
    ).execute()
    return "uploaded and verified"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2526")
    parser.add_argument("--league", action="append", dest="leagues")
    parser.add_argument("--max-matches", type=int, default=0)
    parser.add_argument(
        "--source-game-id",
        action="append",
        dest="source_game_ids",
        help=(
            "Restrict the run to an exact cached WhoScored game id. Repeat the "
            "option to archive a bounded set of matches."
        ),
    )
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--cache-root", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    leagues = tuple(args.leagues or TOP_FIVE)
    root = (args.cache_root or cache_root()).expanduser().resolve()
    excluded = ids_for_season(args.season)
    files = [
        item for item in iter_cache_files(root, args.season, leagues)
        if item[1].stem not in excluded
    ]
    if args.source_game_ids:
        requested = {str(value) for value in args.source_game_ids}
        files = [item for item in files if item[1].stem in requested]
        found = {path.stem for _, path in files}
        missing = sorted(requested - found)
        if missing:
            raise RuntimeError(
                f"requested source game ids are not present in the cache: {missing}"
            )
    if args.max_matches > 0:
        files = files[: args.max_matches]
    print(
        f"Archive plan: season={args.season} files={len(files)} "
        f"source_exceptions={len(excluded)} execute={args.execute}"
    )
    if not files:
        print(f"No cached files found under {root}")
        return 1

    if not args.execute:
        total_raw = 0
        total_gzip = 0
        valid = 0
        invalid = 0
        for league, path in files:
            try:
                item = build_archive_object(path, args.season, league)
            except Exception as exc:
                invalid += 1
                print(f"INVALID {league} {path.stem}: {exc}")
                continue
            valid += 1
            total_raw += item.raw_bytes
            total_gzip += item.compressed_bytes
        print(
            "Dry run only: "
            f"valid={valid} invalid={invalid} raw={total_raw} gzip={total_gzip}; "
            "no uploads or writes"
        )
        return 1 if invalid else 0

    sb, http, url = get_clients()
    known_ids, fixtures, names = canonical_id_map(sb, args.season, leagues)
    uploaded = 0
    skipped = 0
    failed = 0
    try:
        for index, (league, path) in enumerate(files, 1):
            try:
                canonical_game_id = resolve_canonical_game_id(
                    path, league, known_ids, fixtures, names
                )
                item = build_archive_object(
                    path, args.season, league, canonical_game_id
                )
                result = archive_item(sb, http, url, item)
                if result == "already verified":
                    skipped += 1
                else:
                    uploaded += 1
                identity = item.game_id
                if item.source_game_id != item.game_id:
                    identity = f"{item.source_game_id}->{item.game_id}"
                print(f"[{index}/{len(files)}] {league} {identity}: {result}")
            except Exception as exc:  # continue to report the complete manifest gap
                failed += 1
                print(f"[{index}/{len(files)}] {league} {path.stem}: FAILED: {exc}")
    finally:
        http.close()

    print(
        "Archive summary: "
        f"uploaded={uploaded} already_verified={skipped} failed={failed}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
