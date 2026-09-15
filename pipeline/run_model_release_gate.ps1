param(
    [string]$PredictionsFile = "artifacts\predictions\2627_latest_20260914T180029Z_v2.json",
    [string]$FixtureSnapshot = "artifacts\fixtures\2627_football_data.json"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
    function Invoke-CheckedPython {
        param([string[]]$Arguments)
        & python @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Release gate failed: python $($Arguments -join ' ')"
        }
    }

    Invoke-CheckedPython @("pipeline\tools\check_model_artifact.py")
    Invoke-CheckedPython @("pipeline\tools\check_league_table_simulator.py")
    Invoke-CheckedPython @("pipeline\tools\check_prediction_challenger_comparison.py")
    Invoke-CheckedPython @("pipeline\tools\check_model_lab_dashboard.py")
    Invoke-CheckedPython @(
        "pipeline\audit_local_prediction_output_integrity.py",
        "--predictions-file", $PredictionsFile,
        "--fixture-snapshot", $FixtureSnapshot
    )

    Write-Output "MODEL RELEASE GATE: PASS"
    Write-Output "This gate validates local artifacts only; it does not register, promote, activate, publish, or write to Supabase."
} finally {
    Pop-Location
}
