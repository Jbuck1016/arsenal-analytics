"""Static contract checks for the private Writing Lab workflow."""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS  {message}")


def main() -> None:
    page = (ROOT / "dashboard" / "writing-lab.html").read_text(encoding="utf-8")
    home = (ROOT / "dashboard" / "index.html").read_text(encoding="utf-8")
    worker = (ROOT / "pipeline" / "process_writing_lab_queue.py").read_text(encoding="utf-8")
    migration = (
        ROOT / "supabase" / "migrations" / "20260915224025_writing_lab_projects.sql"
    ).read_text(encoding="utf-8")

    require('href="writing-lab.html"' in home, "homepage exposes the Writing Lab")
    require("x-writing-key" in page and "crypto.subtle.digest" in page,
            "browser workspaces use an unguessable scoped key")
    require(all(term in page for term in ("Article leads", "Team evidence", "Plot desk")),
            "evidence pack has an editorial hierarchy")
    require(all(term in page for term in ("Article draft", "Workspace notes", "Published article URL")),
            "notes, full draft and publication record persist together")
    require(all(term in page for term in ("passes", "touches", "heat", "shots")),
            "article-ready team and player plot families are available")
    require("events_cup" in page and "matches_cup" in worker,
            "cup writing evidence stays outside league-only analytics")
    require("--watch" in worker and "scrape_status" in worker,
            "the local worker can process the browser queue continuously")
    require("enable row level security" in migration.lower(),
            "workspace storage enables row-level security")
    require("anon_delete" not in migration and "grant select, insert, update" in migration.lower(),
            "browser workspaces cannot delete the research archive")
    require(migration.lower().count("create policy") == 3,
            "read, create and update each have an explicit ownership policy")


if __name__ == "__main__":
    main()
