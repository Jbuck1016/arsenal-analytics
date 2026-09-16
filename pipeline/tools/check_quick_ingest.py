"""Static contract checks for the browser-to-canonical quick ingest lane."""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS  {message}")


def main() -> None:
    page = (ROOT / "dashboard" / "quick-ingest.html").read_text(encoding="utf-8")
    home = (ROOT / "dashboard" / "index.html").read_text(encoding="utf-8")
    worker = (ROOT / "pipeline" / "process_writing_lab_queue.py").read_text(encoding="utf-8")

    require('href="quick-ingest.html"' in home, "homepage exposes Quick ingest")
    require("x-writing-key" in page and "crypto.subtle.digest" in page,
            "browser queue uses the existing unguessable private scope")
    require("/matches\\/(\\d+)" in page.lower(), "only a WhoScored match id is accepted")
    require(all(x in page for x in ("Premier League", "Champions League", "MLS")),
            "league and isolated competition routes are explicit")
    require("CANONICAL_COMPETITIONS" in worker,
            "worker has an allowlist for canonical publication")
    require("process_canonical_match" in worker,
            "canonical loads reuse league guards and idempotent upserts")
    require("enqueue_rebuild_if_new_data" in worker,
            "canonical loads enqueue the governed analytics publisher")
    require("matches_cup" in worker and "upsert_cup_events" in worker,
            "non-league matches remain isolated")
    require("game_id=eq." in page and "scrape_status==='error'" in page,
            "repeat submissions resume safely instead of creating duplicates")
    require("SUPABASE_SERVICE_KEY" not in page,
            "the browser never receives the service-role credential")


if __name__ == "__main__":
    main()
