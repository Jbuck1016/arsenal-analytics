"""Import current top-five-league Transfermarkt values through Parse.

Successful responses are cached before database writes. Player matching is
club-scoped, and ambiguous identities remain unresolved rather than guessed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import unicodedata
from dataclasses import asdict, dataclass
from datetime import date, datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv
from supabase import Client, create_client

ROOT = Path(__file__).resolve().parent.parent
CACHE_ROOT = ROOT / "artifacts" / "transfermarkt"
REPORT_ROOT = ROOT / "artifacts" / "data_quality"
PARSE_ROOT = "https://api.parse.bot/scraper/f9c987bb-681c-471d-a7f7-342ac6c0016b"

LEAGUES = {
    "ENG-Premier League": {"competition_id": "GB1", "name": "Premier League"},
    "ESP-La Liga": {"competition_id": "ES1", "name": "La Liga"},
    "GER-Bundesliga": {"competition_id": "L1", "name": "Bundesliga"},
    "ITA-Serie A": {"competition_id": "IT1", "name": "Serie A"},
    "FRA-Ligue 1": {"competition_id": "FR1", "name": "Ligue 1"},
}

TEAM_ALIASES = {
    "man city": "manchester city", "man utd": "manchester united",
    "brighton": "brighton hove albion", "tottenham": "tottenham hotspur",
    "newcastle": "newcastle united", "atletico": "atletico de madrid",
    "athletic club": "athletic bilbao", "rbl": "rb leipzig",
    "bayern": "bayern munich", "borussia m gladbach": "borussia monchengladbach",
    "fc koln": "1 fc koln", "leverkusen": "bayer 04 leverkusen",
    "mainz": "1 fsv mainz 05", "inter": "inter milan", "roma": "as roma",
    "psg": "paris saint germain", "lyon": "olympique lyon",
    "marseille": "olympique marseille",
    # Provider display names mapped to the shorter canonical WhoScored names.
    "hull city": "hull", "leeds united": "leeds",
    "deportivo a coruna": "deportivo", "espanyol barcelona": "espanyol",
    "real betis sevilla": "real betis", "real sociedad san sebastian": "real sociedad",
    "estac troyes": "troyes", "fc stade rennes": "rennes", "losc lille": "lille",
    "ogc nizza": "nice", "racing strassburg": "strasbourg", "stade brest 29": "brest",
    "fc schalke 04": "schalke", "tsg 1899 hoffenheim": "hoffenheim",
    "ac florenz": "fiorentina", "atalanta bergamo": "atalanta",
    "cagliari calcio": "cagliari", "como 1907": "como", "fc turin": "torino",
    "genua cfc": "genoa", "lazio rom": "lazio", "ssc neapel": "napoli",
    "udinese calcio": "udinese",
}


def normalize_name(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.casefold().replace("&", " and ")
    return " ".join(re.sub(r"[^a-z0-9]+", " ", text).split())


def normalize_team(value: Any) -> str:
    normalized = normalize_name(value).replace(" and ", " ")
    return TEAM_ALIASES.get(normalized, normalized)


def parse_market_value(value: Any) -> int | None:
    """Convert '1,43 Mrd. EUR', '100,00 Mio. EUR', or '750 Tsd. EUR' to euros."""
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in {"-", "—", "N/A"}:
        return None
    match = re.search(r"([0-9][0-9.]*(?:,[0-9]+)?)", text)
    if not match:
        return None
    number = float(match.group(1).replace(".", "").replace(",", "."))
    lower = text.casefold()
    if "mrd" in lower or "bn" in lower:
        multiplier = 1_000_000_000
    elif "mio" in lower or re.search(r"\bm\b", lower):
        multiplier = 1_000_000
    elif "tsd" in lower or re.search(r"\bk\b", lower):
        multiplier = 1_000
    else:
        multiplier = 1
    return int(round(number * multiplier))


class ParseClient:
    def __init__(self, api_key: str, cache_dir: Path, refresh: bool = False, cache_only: bool = False) -> None:
        self.cache_dir, self.refresh, self.cache_only = cache_dir, refresh, cache_only
        self.calls = self.cache_hits = 0
        cached = list(cache_dir.glob("*.json")) if cache_dir.exists() else []
        self.next_request_at = max((path.stat().st_mtime + 13.0 for path in cached), default=0.0)
        self.session = requests.Session()
        self.session.headers.update({"X-API-Key": api_key, "User-Agent": "FutScout/1.0"})

    def get(self, endpoint: str, **params: str) -> dict[str, Any]:
        key = json.dumps({"endpoint": endpoint, "params": params}, sort_keys=True, separators=(",", ":"))
        path = self.cache_dir / f"{endpoint}_{hashlib.sha256(key.encode()).hexdigest()[:16]}.json"
        if path.exists() and not self.refresh:
            self.cache_hits += 1
            return json.loads(path.read_text(encoding="utf-8"))
        if self.cache_only:
            raise RuntimeError(f"cache miss: {endpoint} {params}")
        # Parse's free plan permits five requests per minute. Pace against wall
        # time so separate resumable runs cannot burst across a process restart.
        response = None
        for attempt in range(5):
            wait_seconds = self.next_request_at - time.time()
            if wait_seconds > 0:
                time.sleep(wait_seconds)
            response = self.session.get(f"{PARSE_ROOT}/{endpoint}", params=params, timeout=90)
            self.next_request_at = time.time() + 13.0
            if response.status_code != 429:
                break
            retry_after = response.headers.get("Retry-After")
            try:
                cooldown = float(retry_after) if retry_after else 61.0
            except ValueError:
                cooldown = 61.0
            # Parse currently returns this header in milliseconds on this route.
            if cooldown > 300:
                cooldown /= 1000.0
            cooldown = min(max(cooldown, 13.0), 120.0)
            self.next_request_at = time.time() + max(cooldown, 13.0)
            print(f"Parse rate limit reached; retrying {endpoint} after {max(cooldown, 13.0):.0f}s", file=sys.stderr)
        assert response is not None
        response.raise_for_status()
        payload = response.json()
        if payload.get("status") != "success":
            raise RuntimeError(f"Parse {endpoint} failed: {payload}")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        self.calls += 1
        return payload


def sb_all(client: Client, table: str, columns: str) -> list[dict[str, Any]]:
    rows, start, page = [], 0, 1000
    while True:
        batch = client.table(table).select(columns).range(start, start + page - 1).execute().data or []
        rows.extend(batch)
        if len(batch) < page:
            return rows
        start += page


def best_unique_match(source: str, targets: list[str], threshold: float, margin: float) -> tuple[str | None, float]:
    scored = sorted(((SequenceMatcher(None, source, target).ratio(), target) for target in targets), reverse=True)
    if not scored or scored[0][0] < threshold:
        return None, scored[0][0] if scored else 0.0
    runner_up = scored[1][0] if len(scored) > 1 else 0.0
    if scored[0][0] - runner_up < margin:
        return None, scored[0][0]
    return scored[0][1], scored[0][0]


@dataclass
class ClubLink:
    league: str
    canonical_team: str | None
    tm_id: str
    tm_name: str
    method: str
    confidence: float


def link_clubs(league: str, canonical_teams: list[str], clubs: list[dict[str, Any]]) -> list[ClubLink]:
    target_map = {normalize_team(team): team for team in canonical_teams}
    links, used = [], set()
    for club in clubs:
        tm_name, tm_id = str(club.get("name") or ""), str(club.get("id") or "")
        source = normalize_team(tm_name)
        canonical, method, confidence = target_map.get(source), "normalized", 1.0
        if canonical is None:
            target, score = best_unique_match(source, list(target_map), 0.72, 0.06)
            canonical = target_map.get(target) if target else None
            method, confidence = ("fuzzy" if canonical else "unresolved"), round(score, 3)
        if canonical in used:
            canonical, method, confidence = None, "unresolved", 0.0
        if canonical:
            used.add(canonical)
        links.append(ClubLink(league, canonical, tm_id, tm_name, method, confidence))
    return links


def player_link(tm_player: dict[str, Any], candidates: list[dict[str, Any]], used: set[str]) -> dict[str, Any]:
    source = normalize_name(tm_player.get("name"))
    available = [p for p in candidates if str(p["player_id"]) not in used]
    exact = [p for p in available if normalize_name(p.get("player_name")) == source]
    if len(exact) == 1:
        chosen, method, confidence = exact[0], "normalized_name_in_team", 1.0
    else:
        by_name = {normalize_name(p.get("player_name")): p for p in available}
        target, score = best_unique_match(source, list(by_name), 0.88, 0.055)
        chosen = by_name.get(target) if target else None
        method, confidence = ("fuzzy_name_in_team" if chosen else "unresolved"), round(score, 3)
    if chosen:
        used.add(str(chosen["player_id"]))
    return {
        "player_id": str(chosen["player_id"]) if chosen else None,
        "canonical_player_name": chosen.get("player_name") if chosen else None,
        "match_method": method,
        "confidence": confidence,
    }


def upsert_batches(client: Client, table: str, rows: list[dict[str, Any]], conflict: str) -> None:
    for offset in range(0, len(rows), 300):
        client.table(table).upsert(rows[offset:offset + 300], on_conflict=conflict).execute()


def build_import(season: str, parse: ParseClient, sb: Client):
    directories = sb_all(sb, "v_team_directory", "team,league")
    players = sb_all(sb, "mv_player_season", "player_id,player_name,team,apps,minutes")
    teams_by_league = {league: sorted({str(r["team"]) for r in directories if r.get("league") == league}) for league in LEAGUES}
    players_by_team: dict[str, list[dict[str, Any]]] = {}
    for player in players:
        players_by_team.setdefault(str(player.get("team") or ""), []).append(player)

    observed_on, retrieved_at = date.today().isoformat(), datetime.now(timezone.utc).isoformat()
    links, snapshots, club_audit, provider_errors, used_players = [], [], [], [], set()
    for league, config in LEAGUES.items():
        payload = parse.get("get_competition_clubs", competition_id=config["competition_id"], season=season)
        clubs = (payload.get("data") or {}).get("clubs") or []
        for club in link_clubs(league, teams_by_league[league], clubs):
            club_audit.append(asdict(club))
            if not club.canonical_team:
                continue
            try:
                squad_payload = parse.get("get_club_squad", club_id=club.tm_id, season=season)
            except RuntimeError as exc:
                if not str(exc).startswith("cache miss:"):
                    raise
                provider_errors.append({
                    "endpoint": "get_club_squad", "club_id": club.tm_id,
                    "club": club.tm_name, "team": club.canonical_team,
                    "league": league, "error": str(exc),
                })
                continue
            squad = (squad_payload.get("data") or {}).get("players") or []
            canonical = players_by_team.get(club.canonical_team, [])
            for tm_player in squad:
                tm_id = str(tm_player.get("id") or "").strip()
                if not tm_id:
                    continue
                matched = player_link(tm_player, canonical, used_players)
                links.append({
                    "transfermarkt_player_id": tm_id,
                    "transfermarkt_player_name": str(tm_player.get("name") or "").strip(),
                    "transfermarkt_club_id": club.tm_id,
                    "transfermarkt_club_name": club.tm_name,
                    "player_id": matched["player_id"],
                    "canonical_player_name": matched["canonical_player_name"],
                    "team": club.canonical_team, "league": league,
                    "match_method": matched["match_method"], "confidence": matched["confidence"],
                    "verified_at": retrieved_at if matched["player_id"] else None,
                    "updated_at": retrieved_at,
                })
                display = tm_player.get("market_value")
                snapshots.append({
                    "transfermarkt_player_id": tm_id, "observed_on": observed_on,
                    "season": season, "market_value_eur": parse_market_value(display),
                    "market_value_display": str(display).strip() if display is not None else None,
                    "currency": "EUR", "provider": "transfermarkt", "retrieved_at": retrieved_at,
                })

    unresolved = [r for r in links if not r["player_id"]]
    fuzzy = [r for r in links if r["match_method"] == "fuzzy_name_in_team"]
    league_coverage = {}
    for league in LEAGUES:
        league_rows = [r for r in links if r["league"] == league]
        resolved_rows = [r for r in league_rows if r["player_id"]]
        league_coverage[league] = {
            "players": len(league_rows),
            "resolved_players": len(resolved_rows),
            "coverage": round(len(resolved_rows) / len(league_rows), 4) if league_rows else 0,
        }
    team_coverage = {}
    for team in sorted({str(r["team"]) for r in links}):
        team_rows = [r for r in links if r["team"] == team]
        resolved_rows = [r for r in team_rows if r["player_id"]]
        team_coverage[team] = {
            "league": team_rows[0]["league"],
            "players": len(team_rows),
            "resolved_players": len(resolved_rows),
            "coverage": round(len(resolved_rows) / len(team_rows), 4) if team_rows else 0,
        }
    report = {
        "created_at": retrieved_at, "season": season, "leagues": list(LEAGUES),
        "provider_calls": parse.calls, "cache_hits": parse.cache_hits,
        "provider_errors": provider_errors,
        "clubs": club_audit, "club_count": len(club_audit),
        "resolved_clubs": sum(bool(r["canonical_team"]) for r in club_audit),
        "players": len(links), "resolved_players": len(links) - len(unresolved),
        "unresolved_players": len(unresolved),
        "fuzzy_players": len(fuzzy),
        "players_with_value": sum(r["market_value_eur"] is not None for r in snapshots),
        "league_coverage": league_coverage,
        "team_coverage": team_coverage,
        "fuzzy_matches": [{k: r[k] for k in ("transfermarkt_player_id", "transfermarkt_player_name", "canonical_player_name", "team", "league", "confidence")} for r in fuzzy],
        "unresolved_sample": [{k: r[k] for k in ("transfermarkt_player_id", "transfermarkt_player_name", "team", "league", "confidence")} for r in unresolved[:100]],
    }
    return links, snapshots, report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--season", default="2026")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--cache-only", action="store_true", help="Use completed provider responses without making network calls")
    parser.add_argument("--cache-dir", type=Path, default=CACHE_ROOT)
    args = parser.parse_args()

    load_dotenv(ROOT / ".env")
    required = ("PARSE_API_KEY", "SUPABASE_URL", "SUPABASE_SERVICE_KEY")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        print("Missing environment variable(s): " + ", ".join(missing), file=sys.stderr)
        return 2
    parse = ParseClient(os.environ["PARSE_API_KEY"], args.cache_dir, args.refresh, args.cache_only)
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])
    links, snapshots, report = build_import(args.season, parse, sb)
    report["executed"] = bool(args.execute)
    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    report_path = REPORT_ROOT / "transfermarkt_import_latest.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.execute:
        upsert_batches(sb, "transfermarkt_player_links", links, "transfermarkt_player_id")
        upsert_batches(sb, "player_market_value_snapshots", snapshots, "transfermarkt_player_id,observed_on")
    print(json.dumps({k: v for k, v in report.items() if k not in {"clubs", "fuzzy_matches", "unresolved_sample", "team_coverage"}}, indent=2))
    print(f"report={report_path}")
    if not args.execute:
        print("dry-run only; pass --execute after reviewing the matching report")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
