# Arsenal Analytics — Claude Code Rules

Single-file HTML/Vanilla JS dashboard on Vercel, Supabase backend, WhoScored/soccerdata pipeline.

## Stack

- Frontend: `dashboard/index.html` — single-file HTML + Vanilla JS
- Backend: Supabase project `ptyffakhjbppzskvwggh`
- Data pipeline: `pipeline/scrape_and_load.py` (Python, soccerdata/WhoScored → Supabase)
- Hosting: Vercel, config in `vercel.json`

## Supabase schema

4 tables in `public` (verify live with supabase MCP before assuming):
- `matches` (game_id PK): season, competition, date, home/away_team, home/away_score, matchday, venue
- `players` (player_id PK): player_name, team
- `lineups` (id PK): game_id, player_id, team, is_starter, position, shirt_number
- `events` (id PK): game_id, minute, team, player, type, outcome_type, x, y, end_x, end_y, is_touch, is_shot, is_goal, qualifiers (jsonb)

RLS is disabled on all four tables. Flag if pushing toward public/recruiter-facing.

## Coordinate system (Opta / WhoScored)

- x: own goal (0) → opponent goal (100)
- y: right touchline (0) → left touchline (100)
- Never explain this from scratch. Use it.

## Data patterns

- Events are filtered by `type` text (e.g. `type = 'Pass'`). No is_pass boolean.
- Shot/goal flags: `is_shot`, `is_goal` booleans, default false.
- Qualifier richness (pass type, shot angle, set piece flags) lives in `qualifiers` jsonb.
- Pagination pattern: `sbAll()` in 1,000-row pages for any large query.

## Deployment

- Deploy script: `deploy.ps1` (PC). On Mac, ask before assuming a command exists.
- Vercel is connected — unresolved from last session whether via GitHub repo or CLI. Confirm before triggering deploy.
- Never ask me to manually edit files. Edit them directly.

## Tactical baseline

I have advanced soccer tactical knowledge. Don't explain pressing, half-spaces, third-man combinations, defensive line theory, or formation relationships from scratch. I hold three Barcelona FA certificates and read tactical material at professional level.

## Existing visualizations

Pass maps, heatmaps, passing networks, Zone 14 passes, progressive passes, defensive actions, multi-panel views, position-aware player stats, PDF export, Season Stats tab.

Before adding a new visualization, ask:
1. Data source — loaded or fresh fetch?
2. Match range / season?
3. Player, team, match, or season aggregate?
4. Where in the UI — new tab, panel, modal?
5. Replaces existing or adds?

## Portfolio lens

This dashboard is also a Sporting Director portfolio piece. When a build decision has portfolio implications — what to prioritize, what to document publicly, what a recruiter would see — flag that lens.
