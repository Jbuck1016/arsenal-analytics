from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / "pipeline" / "import_transfermarkt_values.py").read_text(encoding="utf-8")
page = (ROOT / "dashboard" / "players.html").read_text(encoding="utf-8")
market_page = (ROOT / "dashboard" / "market-values.html").read_text(encoding="utf-8")
index_page = (ROOT / "dashboard" / "index.html").read_text(encoding="utf-8")
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
assert "11 · market intelligence" in index_page
assert "market-values.html" in index_page
assert 'src="gate.js' in market_page
assert "v_player_market_values_latest" in market_page
assert "mv_player_season" in market_page
assert "mv_player_role" in market_page
assert "The market," in market_page
assert "not a quality score" in market_page.lower()
assert "SUPABASE_SERVICE_KEY" not in market_page
assert "PARSE_API_KEY" not in market_page
print("transfermarkt market-value contract: PASS")
