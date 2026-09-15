param(
    [string]$PrimaryPredictions = "artifacts\predictions\2627_latest_20260914T180029Z_v2.json",
    [string]$FixtureSnapshot = "artifacts\fixtures\2627_football_data.json",
    [int]$TableSimulations = 500
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

function Invoke-PythonStep {
    param([string[]]$Arguments)
    & python @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Python step failed ($LASTEXITCODE): python $($Arguments -join ' ')"
    }
}

Invoke-PythonStep @("pipeline\package_tactical_challenger.py")
$tacticalArtifact = Get-ChildItem "artifacts\models\territory-pressing-poisson-2324-2425-2526-*.pkl" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $tacticalArtifact) { throw "Tactical artifact was not produced" }

$primary = Get-Content -Raw $PrimaryPredictions | ConvertFrom-Json
$stamp = ([datetimeoffset]::Parse($primary.as_of)).UtcDateTime.ToString("yyyyMMddTHHmmssZ")
$tacticalPredictions = "artifacts\predictions\2627_latest_${stamp}_tactical.json"
Invoke-PythonStep @(
    "pipeline\generate_match_predictions.py",
    "--artifact", $tacticalArtifact.FullName,
    "--season", [string]$primary.season,
    "--as-of", [string]$primary.as_of,
    "--forecast-kind", [string]$primary.forecast_kind,
    "--fixtures-file", $FixtureSnapshot,
    "--output", $tacticalPredictions
)
Invoke-PythonStep @(
    "pipeline\compare_prediction_challengers.py",
    "--primary", $PrimaryPredictions,
    "--challenger", $tacticalPredictions,
    "--output", "artifacts\model_reports\live_challenger_comparison.json"
)
Invoke-PythonStep @("pipeline\audit_rich_feature_coverage_by_league.py")
Invoke-PythonStep @("pipeline\evaluate_nonlinear_challengers.py")
Invoke-PythonStep @(
    "pipeline\calibrate_table_simulation_uncertainty.py",
    "--simulations", [string]$TableSimulations
)
Invoke-PythonStep @(
    "pipeline\score_prediction_snapshot.py",
    "--predictions-file", "artifacts\predictions\2627_thursday_frozen_20260910T120000Z.json",
    "--matches-file", $FixtureSnapshot,
    "--output", "artifacts\model_reports\shadow_score_2627_thursday_frozen.json"
)
Invoke-PythonStep @("pipeline\audit_model_operations_freshness.py")
Invoke-PythonStep @(
    "pipeline\audit_local_prediction_output_integrity.py",
    "--predictions-file", $PrimaryPredictions,
    "--fixture-snapshot", $FixtureSnapshot
)
Invoke-PythonStep @(
    "pipeline\build_model_lab_dashboard.py",
    "--predictions-file", $PrimaryPredictions,
    "--challenger-predictions-file", $tacticalPredictions,
    "--shadow-report", "artifacts\model_reports\shadow_score_2627_thursday_frozen.json"
)
Invoke-PythonStep @("pipeline\tools\check_model_lab_dashboard.py")
Write-Output "Remaining research workstream completed without registration, promotion, activation, publication, or Supabase writes."
