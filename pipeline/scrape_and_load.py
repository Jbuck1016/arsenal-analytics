"""Scrape WhoScored match events for a team and load into Supabase.

Usage:
    python pipeline/scrape_and_load.py                                          # all Arsenal PL 25/26
    python pipeline/scrape_and_load.py --league "INT-Champions League"          # Champions League
    python pipeline/scrape_and_load.py --league USA-MLS --season 2526 --team "Los Angeles FC"
    python pipeline/scrape_and_load.py --match-id 1821342                       # single match
    python pipeline/scrape_and_load.py --list                                   # list schedule only
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
from pathlib import Path
from typing import Any

import pandas as pd
import soccerdata as sd
from dotenv import load_dotenv
from supabase import Client, create_client

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
DEFAULT_LEAGUE = "ENG-Premier League"
DEFAULT_SEASON = "2526"
SLEEP_BETWEEN_MATCHES = 8


def get_supabase() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def get_scraper(league: str, season: str) -> sd.WhoScored:
    return sd.WhoScored(leagues=league, seasons=[season], headless=True)


def _int_or_none(v: Any) -> int | None:
    if v is None:
        return None
    try:
        if isinstance(v, float) and math.isnan(v):
            return None
        return int(v)
    except (ValueError, TypeError):
        return None


def _str_or_none(v: Any) -> str | None:
    if v is None:
        return None
    try:
        if isinstance(v, float) and math.isnan(v):
            return None
    except TypeError:
        pass
    s = str(v)
    return s if s else None


def _float_or_none(v: Any) -> float | None:
    if v is None:
        return None
    try:
        f = float(v)
        if math.isnan(f):
            return None
        return f
    except (ValueError, TypeError):
        return None


def get_team_schedule(ws: sd.WhoScored, team: str) -> pd.DataFrame:
    schedule = ws.read_schedule()
    if schedule.index.names and any(n for n in schedule.index.names):
        schedule = schedule.reset_index()
    mask = schedule["home_team"].str.contains(team, na=False) | schedule[
        "away_team"
    ].str.contains(team, na=False)
    return schedule[mask].copy()


def upsert_match(sb: Client, sched_row: pd.Series, league: str, season: str) -> str:
    game_id = str(sched_row["game_id"])
    date_val = sched_row.get("date")
    try:
        date_str = pd.to_datetime(date_val).date().isoformat() if date_val is not None else None
    except Exception:
        date_str = str(date_val) if date_val is not None else None
    payload = {
        "game_id": game_id,
        "season": season,
        "competition": league,
        "date": date_str,
        "home_team": _str_or_none(sched_row.get("home_team")),
        "away_team": _str_or_none(sched_row.get("away_team")),
        "home_score": _int_or_none(sched_row.get("home_score")),
        "away_score": _int_or_none(sched_row.get("away_score")),
        "matchday": _int_or_none(
            sched_row.get("week")
            if "week" in sched_row.index
            else sched_row.get("matchday")
        ),
        "venue": _str_or_none(sched_row.get("venue")),
    }
    sb.table("matches").upsert(payload, on_conflict="game_id").execute()
    return game_id


def cached_event_json_path(ws: sd.WhoScored, game_id: str, league: str, season: str) -> Path:
    return ws.data_dir / "events" / f"{league}_{season}" / f"{game_id}.json"


def ensure_event_json(ws: sd.WhoScored, game_id: str, league: str, season: str) -> dict:
    path = cached_event_json_path(ws, game_id, league, season)
    if not path.is_file():
        # populate cache
        ws.read_events(match_id=int(game_id), output_fmt="raw")
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def _display_name(v: Any) -> str | None:
    if isinstance(v, dict):
        return v.get("displayName")
    return _str_or_none(v)


def upsert_players_and_lineups(
    sb: Client,
    game_data: dict,
    game_id: str,
) -> None:
    team_names = {
        int(game_data["home"]["teamId"]): game_data["home"]["name"],
        int(game_data["away"]["teamId"]): game_data["away"]["name"],
    }
    player_names: dict[int, str] = {
        int(pid): name for pid, name in game_data.get("playerIdNameDictionary", {}).items()
    }

    # Assign each player to a team based on the first event we see them touch
    player_team: dict[int, int] = {}
    for ev in game_data.get("events", []):
        pid = ev.get("playerId")
        tid = ev.get("teamId")
        if pid is None or tid is None:
            continue
        if pid not in player_team:
            player_team[int(pid)] = int(tid)

    # If home/away include player lists with starter info, use them
    starters: dict[int, bool] = {}
    positions: dict[int, str | None] = {}
    shirts: dict[int, int | None] = {}
    for side in ("home", "away"):
        side_data = game_data.get(side, {})
        for p in side_data.get("players", []) or []:
            pid = p.get("playerId")
            if pid is None:
                continue
            pid = int(pid)
            starters[pid] = not bool(p.get("isFirstEleven") is False)
            if "isFirstEleven" in p:
                starters[pid] = bool(p["isFirstEleven"])
            positions[pid] = p.get("position")
            shirts[pid] = _int_or_none(p.get("shirtNo"))

    players_payload: list[dict] = []
    lineups_payload: list[dict] = []
    seen_players: set[str] = set()

    for pid_int, name in player_names.items():
        tid = player_team.get(pid_int)
        team = team_names.get(tid) if tid is not None else None
        pid_str = str(pid_int)
        if pid_str not in seen_players:
            players_payload.append(
                {"player_id": pid_str, "player_name": name, "team": team}
            )
            seen_players.add(pid_str)
        lineups_payload.append(
            {
                "game_id": game_id,
                "player_id": pid_str,
                "team": team or "unknown",
                "is_starter": starters.get(pid_int, True),
                "position": positions.get(pid_int),
                "shirt_number": shirts.get(pid_int),
            }
        )

    if players_payload:
        sb.table("players").upsert(players_payload, on_conflict="player_id").execute()
    # lineups has no unique constraint; clear + reinsert for idempotency
    sb.table("lineups").delete().eq("game_id", game_id).execute()
    for i in range(0, len(lineups_payload), 500):
        sb.table("lineups").insert(lineups_payload[i : i + 500]).execute()


def build_event_row(
    game_id: str,
    ev: dict,
    team_names: dict[int, str],
    player_names: dict[int, str],
) -> dict:
    pid = ev.get("playerId")
    tid = ev.get("teamId")
    return {
        "game_id": game_id,
        "ws_id": _int_or_none(ev.get("id")),
        "event_id": _int_or_none(ev.get("eventId")),
        "period": _int_or_none(
            ev["period"].get("value") if isinstance(ev.get("period"), dict) else ev.get("period")
        ),
        "minute": _int_or_none(ev.get("minute")),
        "second": _int_or_none(ev.get("second")),
        "expanded_minute": _int_or_none(ev.get("expandedMinute")),
        "team_id": str(tid) if tid is not None else None,
        "team": team_names.get(int(tid)) if tid is not None else None,
        "player_id": str(pid) if pid is not None else None,
        "player": player_names.get(int(pid)) if pid is not None else None,
        "type": _display_name(ev.get("type")),
        "outcome_type": _display_name(ev.get("outcomeType")),
        "x": _float_or_none(ev.get("x")),
        "y": _float_or_none(ev.get("y")),
        "end_x": _float_or_none(ev.get("endX")),
        "end_y": _float_or_none(ev.get("endY")),
        "is_touch": bool(ev.get("isTouch", False)),
        "is_shot": bool(ev.get("isShot", False)),
        "is_goal": bool(ev.get("isGoal", False)),
        "card_type": _display_name(ev.get("cardType")),
        "qualifiers": ev.get("qualifiers") or [],
    }


def upsert_events(sb: Client, game_data: dict, game_id: str) -> int:
    team_names = {
        int(game_data["home"]["teamId"]): game_data["home"]["name"],
        int(game_data["away"]["teamId"]): game_data["away"]["name"],
    }
    player_names = {
        int(pid): name
        for pid, name in game_data.get("playerIdNameDictionary", {}).items()
    }
    rows_by_wsid: dict[int, dict] = {}
    for ev in game_data.get("events", []):
        if ev.get("id") is None:
            continue
        row = build_event_row(game_id, ev, team_names, player_names)
        rows_by_wsid[row["ws_id"]] = row  # last-write wins for duplicates
    rows = list(rows_by_wsid.values())
    if not rows:
        return 0
    for i in range(0, len(rows), 500):
        chunk = rows[i : i + 500]
        sb.table("events").upsert(chunk, on_conflict="game_id,ws_id").execute()
    return len(rows)


def process_match(
    sb: Client, ws: sd.WhoScored, sched_row: pd.Series, league: str, season: str
) -> tuple[str, int]:
    game_id = upsert_match(sb, sched_row, league, season)
    print(f"  -> match row upserted (game_id={game_id})")
    game_data = ensure_event_json(ws, game_id, league, season)
    print(f"  -> loaded raw json ({len(game_data.get('events', []))} events)")
    upsert_players_and_lineups(sb, game_data, game_id)
    n = upsert_events(sb, game_data, game_id)
    print(f"  -> upserted {n} events")
    return game_id, n


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--league", type=str, default=DEFAULT_LEAGUE, help="league id (default: ENG-Premier League)")
    p.add_argument("--season", type=str, default=DEFAULT_SEASON, help="season code (default: 2526)")
    p.add_argument("--team", type=str, default="Arsenal", help="team name to filter (default: Arsenal)")
    p.add_argument("--match-id", type=str, help="scrape a single WhoScored match id")
    p.add_argument("--list", action="store_true", help="list team schedule and exit")
    args = p.parse_args()

    league = args.league
    season = args.season
    team = args.team

    sb = get_supabase()
    ws = get_scraper(league, season)

    print(f"Reading schedule for {league} {season}...")
    team_sched = get_team_schedule(ws, team)
    print(f"Found {len(team_sched)} {team} matches in schedule")

    if args.list:
        cols = [
            c
            for c in ("date", "home_team", "away_team", "home_score", "away_score", "game_id")
            if c in team_sched.columns
        ]
        print(team_sched[cols].to_string(index=False))
        return 0

    if args.match_id:
        match = team_sched[team_sched["game_id"].astype(str) == str(args.match_id)]
        if match.empty:
            print(f"match_id {args.match_id} not in {team} schedule", file=sys.stderr)
            return 1
        row = match.iloc[0]
        print(
            f"Scraping single match: {row.get('home_team')} vs {row.get('away_team')}"
        )
        process_match(sb, ws, row, league, season)
        return 0

    for idx, (_, row) in enumerate(team_sched.iterrows()):
        print(
            f"[{idx + 1}/{len(team_sched)}] {row.get('date')} {row.get('home_team')} vs {row.get('away_team')}"
        )
        try:
            process_match(sb, ws, row, league, season)
        except Exception as e:
            print(f"  !! failed: {e}", file=sys.stderr)
        if idx < len(team_sched) - 1:
            time.sleep(SLEEP_BETWEEN_MATCHES)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
