"""Scrape Leagues Cup into ISOLATED cup tables.

Why this is a separate script and separate tables
-------------------------------------------------
Every Leagues Cup Phase One fixture is MLS vs Liga MX. If those events landed in
`events`, all 40 MLS metric materialized views would silently absorb them, and Liga MX
clubs would appear in league leaderboards on three games against MLS sides on seventeen.
Materialized views bind to their source table by internal id, so a filtered view cannot
be swapped underneath them. Separate tables are the only structure that guarantees the
MLS analytics are untouched.

Cup data goes to: matches_cup, lineups_cup, events_cup (+ shared `players`).
The schema mirrors the MLS tables exactly, so the sequence and chain-role builders can
be pointed at them later without structural work.

Usage:
    python pipeline/scrape_cup.py --list-leagues     # find the WhoScored league id
    python pipeline/scrape_cup.py --list             # show the plan, scrape nothing
    python pipeline/scrape_cup.py                    # scrape all played cup matches
    python pipeline/scrape_cup.py --limit 3          # do the next 3 (good first test)
"""
from __future__ import annotations

import argparse
import json
import pathlib
import random
import shutil
import sys
import time

import pandas as pd

from scrape_and_load import (
    _int_or_none,
    build_event_row,
    cached_event_json_path,
    get_scraper,
    get_supabase,
)

DEFAULT_LEAGUE = "USA-Leagues Cup"
DEFAULT_SEASON = "2627"
NULL_CACHE_MAX_BYTES = 50


def install_league_dict() -> None:
    src = pathlib.Path(__file__).parent / "league_dict.json"
    dst = pathlib.Path.home() / "soccerdata" / "config" / "league_dict.json"
    if src.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, dst)


def list_leagues() -> None:
    """Print every league id soccerdata's WhoScored reader accepts."""
    import soccerdata as sd

    try:
        leagues = sd.WhoScored.available_leagues()
    except Exception as e:  # noqa: BLE001
        print(f"Could not list leagues: {e}", file=sys.stderr)
        return
    print(f"{len(leagues)} league id(s) available to WhoScored:\n", flush=True)
    for lg in sorted(leagues):
        mark = "  <-- cup candidate" if any(
            k in lg.lower() for k in ("cup", "leagues", "concacaf")
        ) else ""
        print(f"  {lg}{mark}", flush=True)
    print(
        "\nIf Leagues Cup is not listed, add it to pipeline/league_dict.json with its\n"
        'WhoScored name, e.g. {"USA-Leagues Cup": {"WhoScored": "<name on whoscored.com>"}}',
        flush=True,
    )


def read_full_schedule(ws) -> pd.DataFrame:
    sched = ws.read_schedule()
    if isinstance(sched.index, pd.MultiIndex):
        sched = sched.reset_index()
    return sched


def loaded_cup_games(sb) -> set[str]:
    """game_ids already in events_cup, so re-runs only fetch what is missing."""
    out: set[str] = set()
    page, off = 1000, 0
    while True:
        res = sb.table("matches_cup").select("game_id").range(off, off + page - 1).execute()
        rows = res.data or []
        for r in rows:
            out.add(str(r["game_id"]))
        if len(rows) < page:
            break
        off += page
    return out


def upsert_cup_match(sb, row: pd.Series, league: str, season: str) -> str:
    gid = str(_int_or_none(row.get("game_id")) or row.get("game_id"))
    payload = {
        "game_id": gid,
        "season": season,
        "competition": league,
        "date": str(row.get("date"))[:10] if row.get("date") is not None else None,
        "home_team": row.get("home_team"),
        "away_team": row.get("away_team"),
        "home_score": _int_or_none(row.get("home_score")),
        "away_score": _int_or_none(row.get("away_score")),
        "stage": row.get("stage") if "stage" in row else None,
    }
    payload = {k: v for k, v in payload.items() if v is not None or k in ("home_score", "away_score")}
    sb.table("matches_cup").upsert(payload, on_conflict="game_id").execute()
    return gid


def upsert_cup_players_and_lineups(sb, game_data: dict, game_id: str) -> None:
    team_names = {
        int(game_data["home"]["teamId"]): game_data["home"]["name"],
        int(game_data["away"]["teamId"]): game_data["away"]["name"],
    }
    player_names = {
        int(pid): name for pid, name in game_data.get("playerIdNameDictionary", {}).items()
    }
    player_team: dict[int, int] = {}
    for ev in game_data.get("events", []):
        pid, tid = ev.get("playerId"), ev.get("teamId")
        if pid is None or tid is None:
            continue
        if int(pid) not in player_team:
            player_team[int(pid)] = int(tid)

    starters: dict[int, bool] = {}
    positions: dict[int, str | None] = {}
    shirts: dict[int, int | None] = {}
    for side in ("home", "away"):
        for p in (game_data.get(side, {}) or {}).get("players", []) or []:
            pid = p.get("playerId")
            if pid is None:
                continue
            pid = int(pid)
            starters[pid] = bool(p["isFirstEleven"]) if "isFirstEleven" in p else True
            positions[pid] = p.get("position")
            shirts[pid] = _int_or_none(p.get("shirtNo"))

    players_payload, lineups_payload, seen = [], [], set()
    for pid_int, name in player_names.items():
        tid = player_team.get(pid_int)
        team = team_names.get(tid) if tid is not None else None
        pid_str = str(pid_int)
        if pid_str not in seen:
            players_payload.append({"player_id": pid_str, "player_name": name, "team": team})
            seen.add(pid_str)
        lineups_payload.append({
            "game_id": game_id, "player_id": pid_str, "team": team or "unknown",
            "is_starter": starters.get(pid_int, True),
            "position": positions.get(pid_int), "shirt_number": shirts.get(pid_int),
        })

    if players_payload:
        sb.table("players").upsert(players_payload, on_conflict="player_id").execute()
    sb.table("lineups_cup").delete().eq("game_id", game_id).execute()
    for i in range(0, len(lineups_payload), 500):
        sb.table("lineups_cup").insert(lineups_payload[i : i + 500]).execute()


def upsert_cup_events(sb, game_data: dict, game_id: str) -> int:
    team_names = {
        int(game_data["home"]["teamId"]): game_data["home"]["name"],
        int(game_data["away"]["teamId"]): game_data["away"]["name"],
    }
    player_names = {
        int(pid): name for pid, name in game_data.get("playerIdNameDictionary", {}).items()
    }
    rows_by_wsid: dict[int, dict] = {}
    for ev in game_data.get("events", []):
        if ev.get("id") is None:
            continue
        row = build_event_row(game_id, ev, team_names, player_names)
        rows_by_wsid[row["ws_id"]] = row
    rows = list(rows_by_wsid.values())
    if not rows:
        return 0
    for i in range(0, len(rows), 500):
        sb.table("events_cup").upsert(rows[i : i + 500], on_conflict="game_id,ws_id").execute()
    return len(rows)


def record_cup_clubs(sb, game_data: dict, sched_row: pd.Series) -> None:
    """Build the cup club whitelist from what actually appears, for later reconciliation."""
    rows = []
    for side, sched_key in (("home", "home_team"), ("away", "away_team")):
        ev_name = (game_data.get(side, {}) or {}).get("name")
        if not ev_name:
            continue
        rows.append({
            "event_name": ev_name,
            "match_name": sched_row.get(sched_key),
            "display_name": ev_name,
            "league": None,
        })
    for r in rows:
        try:
            existing = sb.table("team_names_cup").select("event_name") \
                .eq("event_name", r["event_name"]).limit(1).execute()
            if not (existing.data or []):
                sb.table("team_names_cup").insert(r).execute()
        except Exception:  # noqa: BLE001 - whitelist is metadata, never block a load
            pass


def purge_null_cache(ws, game_id: str, league: str, season: str) -> None:
    path = cached_event_json_path(ws, game_id, league, season)
    try:
        if path.is_file() and path.stat().st_size <= NULL_CACHE_MAX_BYTES:
            path.unlink()
    except OSError:
        pass


def main() -> int:
    install_league_dict()
    p = argparse.ArgumentParser()
    p.add_argument("--league", default=DEFAULT_LEAGUE)
    p.add_argument("--season", default=DEFAULT_SEASON)
    p.add_argument("--list", action="store_true", help="show the plan, scrape nothing")
    p.add_argument("--list-leagues", action="store_true", help="print available league ids")
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--min-gap", type=int, default=60)
    p.add_argument("--max-gap", type=int, default=120)
    p.add_argument("--headless", action="store_true")
    args = p.parse_args()

    if args.list_leagues:
        list_leagues()
        return 0

    league, season = args.league, args.season
    sb = get_supabase()

    print(f"Reading schedule for {league} {season}...", flush=True)
    try:
        ws = get_scraper(league, season, headless=args.headless)
        sched = read_full_schedule(ws)
    except Exception as e:  # noqa: BLE001
        print(f"\nCould not read the schedule for '{league}': {e}\n", file=sys.stderr)
        print("Run this to see which league ids WhoScored accepts:", file=sys.stderr)
        print("  python pipeline/scrape_cup.py --list-leagues", file=sys.stderr)
        return 1

    if "home_score" in sched.columns:
        played = sched[sched["home_score"].notna()].copy()
    else:
        played = sched.copy()
    already = loaded_cup_games(sb)
    todo = [r for _, r in played.iterrows()
            if str(_int_or_none(r.get("game_id")) or r.get("game_id")) not in already]

    print(f"  fixtures in schedule : {len(sched)}", flush=True)
    print(f"  played               : {len(played)}", flush=True)
    print(f"  already loaded       : {len(already)}", flush=True)
    print(f"  to scrape            : {len(todo)}", flush=True)

    if args.limit:
        todo = todo[: args.limit]
        print(f"  limited to           : {len(todo)}", flush=True)
    if args.list:
        for r in todo[:20]:
            print(f"    {r.get('date')}  {r.get('home_team')} vs {r.get('away_team')}", flush=True)
        return 0
    if not todo:
        print("\nNothing new to scrape.", flush=True)
        return 0

    ok = fail = 0
    for i, row in enumerate(todo, 1):
        gid = str(_int_or_none(row.get("game_id")) or row.get("game_id"))
        print(f"\n[{i}/{len(todo)}] {row.get('home_team')} vs {row.get('away_team')} ({gid})", flush=True)
        purge_null_cache(ws, gid, league, season)
        try:
            path = cached_event_json_path(ws, gid, league, season)
            if not path.is_file():
                ws.read_events(match_id=int(gid), output_fmt="raw")
            with path.open(encoding="utf-8") as fh:
                game_data = json.load(fh)

            upsert_cup_match(sb, row, league, season)
            upsert_cup_players_and_lineups(sb, game_data, gid)
            n = upsert_cup_events(sb, game_data, gid)
            record_cup_clubs(sb, game_data, row)
            print(f"  -> upserted {n} events", flush=True)
            print("  -> success", flush=True)
            ok += 1
        except Exception as e:  # noqa: BLE001
            print(f"  !! failed: {e}", file=sys.stderr, flush=True)
            fail += 1
        if i < len(todo):
            gap = random.randint(args.min_gap, args.max_gap)
            print(f"  ... waiting {gap}s", flush=True)
            time.sleep(gap)

    print("\n=== Summary ===", flush=True)
    print(f"  succeeded: {ok}", flush=True)
    print(f"  failed:    {fail}", flush=True)
    print("\nCup data is isolated in matches_cup / lineups_cup / events_cup.", flush=True)
    print("MLS analytics are untouched. Cup analytics are a separate build.", flush=True)
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
