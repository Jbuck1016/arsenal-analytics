"""Backfill linked players' Transfermarkt transfers and value progression.

The job is deliberately bounded and cache-first because Parse charges per
successful player endpoint. Re-running it is safe: normalized rows are upserted
and successful provider responses are retained under artifacts/transfermarkt.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from dotenv import load_dotenv
from supabase import create_client

from import_transfermarkt_values import ParseClient, sb_all, upsert_batches

ROOT = Path(__file__).resolve().parent.parent
CACHE_ROOT = ROOT / "artifacts" / "transfermarkt"
REPORT_ROOT = ROOT / "artifacts" / "data_quality"


def key_name(value: Any) -> str:
    return re.sub(r"[^a-z0-9]", "", str(value or "").casefold())


def first_value(row: dict[str, Any], *names: str) -> Any:
    wanted = {key_name(name) for name in names}
    for key, value in row.items():
        if key_name(key) in wanted and value not in (None, ""):
            return value
    return None


def parse_date(value: Any) -> str | None:
    if value in (None, ""):
        return None
    text = str(value).strip()
    for fmt in ("%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y", "%b %d, %Y", "%d %b %Y"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            pass
    match = re.search(r"(20\d{2}|19\d{2})[-/.](\d{1,2})[-/.](\d{1,2})", text)
    if match:
        try:
            return date(int(match.group(1)), int(match.group(2)), int(match.group(3))).isoformat()
        except ValueError:
            return None
    return None


def amount_parts(value: Any) -> tuple[int | None, str | None]:
    if isinstance(value, dict):
        numeric = first_value(value, "eur", "value_eur", "amount_eur", "numeric", "amount", "value")
        display = first_value(value, "display", "formatted", "text", "label")
        if isinstance(numeric, (int, float)):
            return int(round(numeric)), str(display or numeric)
        value = display or numeric
    display = str(value).strip() if value not in (None, "") else None
    if not display:
        return None, None
    match = re.search(r"([0-9][0-9.,]*)", display)
    if not match:
        return None, display
    raw = match.group(1)
    if "," in raw and "." in raw:
        raw = raw.replace(".", "").replace(",", ".") if raw.rfind(",") > raw.rfind(".") else raw.replace(",", "")
    elif "," in raw:
        raw = raw.replace(",", ".") if len(raw.rsplit(",", 1)[1]) <= 2 else raw.replace(",", "")
    elif "." in raw and (raw.count(".") > 1 or len(raw.rsplit(".", 1)[1]) == 3):
        raw = raw.replace(".", "")
    number = float(raw)
    lower = display.casefold()
    if "mrd" in lower or "bn" in lower or "billion" in lower:
        multiplier = 1_000_000_000
    elif "mio" in lower or "million" in lower or re.search(r"(?:€|eur|\d)\s*[0-9.,]*\s*m\b", lower):
        multiplier = 1_000_000
    elif "tsd" in lower or re.search(r"(?:€|eur|\d)\s*[0-9.,]*\s*k\b", lower):
        multiplier = 1_000
    else:
        multiplier = 1
    return int(round(number * multiplier)), display


def number_or_none(value: Any) -> float | None:
    if value in (None, ""):
        return None
    match = re.search(r"\d+(?:[.,]\d+)?", str(value))
    return float(match.group(0).replace(",", ".")) if match else None


def club_parts(value: Any) -> tuple[str | None, str | None, str | None]:
    if isinstance(value, dict):
        return (
            str(first_value(value, "id", "club_id", "verein_id") or "") or None,
            str(first_value(value, "name", "club", "club_name", "verein") or "") or None,
            str(first_value(value, "competition", "competition_id", "league") or "") or None,
        )
    return None, str(value).strip() if value not in (None, "") else None, None


def walk_lists(node: Any, path: tuple[str, ...] = ()) -> Iterable[tuple[tuple[str, ...], list[Any]]]:
    if isinstance(node, dict):
        for key, value in node.items():
            yield from walk_lists(value, path + (str(key),))
    elif isinstance(node, list):
        yield path, node
        for index, value in enumerate(node):
            yield from walk_lists(value, path + (str(index),))


def value_history_rows(payload: dict[str, Any], tm_id: str, retrieved_at: str) -> list[dict[str, Any]]:
    data = payload.get("data") or payload
    candidates: list[list[Any]] = []
    for path, rows in walk_lists(data):
        joined = key_name(" ".join(path))
        if rows and all(isinstance(row, dict) for row in rows) and "market" in joined and ("history" in joined or "value" in joined):
            candidates.append(rows)
    output: dict[str, dict[str, Any]] = {}
    for rows in candidates:
        for row in rows:
            observed = parse_date(first_value(row, "date", "observed_on", "valuation_date", "datum"))
            numeric_value = first_value(row, "market_value_eur", "value_eur")
            display_value = first_value(row, "market_value", "marketValue", "value", "marktwert", "display")
            amount, inferred_display = amount_parts(numeric_value if numeric_value is not None else display_value)
            display = str(display_value or inferred_display) if (display_value or inferred_display) is not None else None
            if not observed or amount is None:
                continue
            output[observed] = {
                "transfermarkt_player_id": tm_id,
                "observed_on": observed,
                "season": str(first_value(row, "season", "saison") or "historical"),
                "market_value_eur": amount,
                "market_value_display": display,
                "currency": "EUR",
                "provider": "transfermarkt",
                "retrieved_at": retrieved_at,
            }
    return sorted(output.values(), key=lambda row: row["observed_on"])


def transfer_arrays(payload: dict[str, Any]) -> Iterable[tuple[str, list[dict[str, Any]]]]:
    data = payload.get("data") or payload
    for path, rows in walk_lists(data):
        joined = key_name(" ".join(path))
        if rows and all(isinstance(row, dict) for row in rows) and any(word in joined for word in ("terminated", "pending", "transfer", "history")):
            yield ("pending" if "pending" in joined else "completed"), rows


def transfer_rows(payload: dict[str, Any], tm_id: str, retrieved_at: str) -> list[dict[str, Any]]:
    output: dict[str, dict[str, Any]] = {}
    for status, rows in transfer_arrays(payload):
        for row in rows:
            from_value = first_value(row, "from", "from_club", "fromClub", "club_from", "abgebenderVerein")
            to_value = first_value(row, "to", "to_club", "toClub", "club_to", "aufnehmenderVerein")
            from_id, from_name, from_comp = club_parts(from_value)
            to_id, to_name, to_comp = club_parts(to_value)
            transfer_date = parse_date(first_value(row, "date", "transfer_date", "transferDate", "datum"))
            season = str(first_value(row, "season", "saison") or "") or None
            fee_raw = first_value(row, "fee", "transfer_fee", "transferFee", "abloese")
            fee_eur, fee_display = amount_parts(fee_raw)
            mv_raw = first_value(row, "market_value", "marketValue", "market_value_at_transfer", "marktwert")
            mv_eur, mv_display = amount_parts(mv_raw)
            transfer_type = str(first_value(row, "type", "transfer_type", "transferType", "status") or status)
            canonical = json.dumps(row, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
            key = str(first_value(row, "id", "transfer_id", "transferId") or hashlib.sha256(canonical.encode()).hexdigest()[:24])
            output[key] = {
                "transfermarkt_player_id": tm_id,
                "transfer_key": key,
                "transfer_date": transfer_date,
                "season": season,
                "from_club_id": from_id,
                "from_club_name": from_name,
                "from_competition": from_comp,
                "to_club_id": to_id,
                "to_club_name": to_name,
                "to_competition": to_comp,
                "fee_eur": fee_eur,
                "fee_display": fee_display,
                "market_value_eur": mv_eur,
                "market_value_display": mv_display,
                "transfer_type": transfer_type,
                "is_loan": "loan" in transfer_type.casefold() or "leihe" in transfer_type.casefold(),
                "player_age": number_or_none(first_value(row, "age", "player_age", "ageAtTransfer")),
                "contract_until": parse_date(first_value(row, "contract_until", "contractUntil")),
                "provider": "transfermarkt",
                "retrieved_at": retrieved_at,
                "source_payload": row,
            }
    return sorted(output.values(), key=lambda row: row["transfer_date"] or "", reverse=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player-id", action="append", default=[], help="Canonical player_id; repeat as needed")
    parser.add_argument("--transfermarkt-id", action="append", default=[], help="Provider player ID; repeat as needed")
    parser.add_argument("--limit", type=int, default=25, help="Maximum linked players when no explicit IDs are supplied")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--cache-only", action="store_true")
    parser.add_argument("--cache-dir", type=Path, default=CACHE_ROOT)
    args = parser.parse_args()

    load_dotenv(ROOT / ".env")
    required = ("PARSE_API_KEY", "SUPABASE_URL", "SUPABASE_SERVICE_KEY")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing environment variable(s): " + ", ".join(missing))
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])
    requested_player_ids, requested_tm_ids = set(args.player_id), set(args.transfermarkt_id)
    if requested_tm_ids and not requested_player_ids:
        links = [{"transfermarkt_player_id": tm_id} for tm_id in sorted(requested_tm_ids)]
    else:
        links = sb_all(sb, "transfermarkt_player_links", "transfermarkt_player_id,player_id,canonical_player_name,team,league")
        if requested_player_ids or requested_tm_ids:
            links = [row for row in links if str(row.get("player_id")) in requested_player_ids or str(row.get("transfermarkt_player_id")) in requested_tm_ids]
        else:
            links = [row for row in links if row.get("player_id")][: max(args.limit, 0)]

    parse = ParseClient(os.environ["PARSE_API_KEY"], args.cache_dir, args.refresh, args.cache_only)
    retrieved_at = datetime.now(timezone.utc).isoformat()
    all_values: list[dict[str, Any]] = []
    all_transfers: list[dict[str, Any]] = []
    players: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    for link in links:
        tm_id = str(link["transfermarkt_player_id"])
        try:
            profile = parse.get("get_player_profile", player_id=tm_id)
            transfers = parse.get("get_player_transfers", player_id=tm_id)
            values = value_history_rows(profile, tm_id, retrieved_at)
            moves = transfer_rows(transfers, tm_id, retrieved_at)
            all_values.extend(values)
            all_transfers.extend(moves)
            players.append({
                "player_id": link.get("player_id"), "name": link.get("canonical_player_name"),
                "transfermarkt_player_id": tm_id, "value_points": len(values), "transfers": len(moves),
            })
        except Exception as exc:  # keep a bounded batch resumable after one provider failure
            errors.append({"transfermarkt_player_id": tm_id, "player_id": str(link.get("player_id") or ""), "error": str(exc)})

    if args.execute:
        if all_values:
            upsert_batches(sb, "player_market_value_snapshots", all_values, "transfermarkt_player_id,observed_on")
        if all_transfers:
            upsert_batches(sb, "player_transfer_events", all_transfers, "transfermarkt_player_id,transfer_key")
    report = {
        "created_at": retrieved_at, "executed": bool(args.execute), "requested": len(links),
        "completed": len(players), "provider_calls": parse.calls, "cache_hits": parse.cache_hits,
        "market_value_points": len(all_values), "transfer_events": len(all_transfers),
        "players": players, "errors": errors,
    }
    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    report_path = REPORT_ROOT / "transfermarkt_player_history_latest.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in {"players", "errors"}}, indent=2))
    if errors:
        print(json.dumps({"errors": errors[:10]}, indent=2))
    print(f"report={report_path}")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
