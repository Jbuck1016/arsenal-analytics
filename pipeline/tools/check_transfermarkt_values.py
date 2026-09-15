from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / "pipeline" / "import_transfermarkt_values.py").read_text(encoding="utf-8")
page = (ROOT / "dashboard" / "players.html").read_text(encoding="utf-8")
migration = (ROOT / "supabase" / "migrations" / "20260915040000_transfermarkt_market_values.sql").read_text(encoding="utf-8")

ast.parse(source)
assert "PARSE_API_KEY" in source
assert "SUPABASE_SERVICE_KEY" in source
assert "parse_market_value" in source
assert "fuzzy_name_in_team" in source
assert "unresolved" in source
assert "v_player_market_values_latest" in migration
assert "security_invoker = true" in migration
assert "enable row level security" in migration
assert "grant select on table public.v_player_market_values_latest to anon, authenticated" in migration
assert "SUPABASE_SERVICE_KEY" not in page
assert "PARSE_API_KEY" not in page
assert "v_player_market_values_latest" in page
assert "Market value" in page
print("transfermarkt market-value contract: PASS")
