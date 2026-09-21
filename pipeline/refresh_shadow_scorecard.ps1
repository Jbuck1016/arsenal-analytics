param(
    [string]$Season = "2627",
    [string]$Artifact = "artifacts\models\v2-field-tilt-box-entries-poisson-2324-2425-2526-20260914t205131z.pkl",
    [string]$Python = "$env:USERPROFILE\anaconda3\python.exe",
    [switch]$PublishSite
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$operationLog = Join-Path $logDir ("shadow_scorecard_" + [DateTimeOffset]::UtcNow.ToString("yyyyMMdd") + ".log")
Start-Transcript -Path $operationLog -Append | Out-Null
Push-Location $repoRoot
try {
    $pythonExe = (Resolve-Path -LiteralPath $Python).Path
    $artifactPath = (Resolve-Path -LiteralPath $Artifact).Path
    $artifactMeta = Get-Content -LiteralPath ([System.IO.Path]::ChangeExtension($artifactPath, ".json")) -Raw | ConvertFrom-Json
    $files = @(Get-ChildItem -LiteralPath "artifacts\predictions" -Filter "${Season}_thursday_frozen_*.json" -File |
        Where-Object {
            $snapshot = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            $snapshot.model_version -eq $artifactMeta.model_version
        } | Sort-Object Name)
    if ($files.Count -eq 0) { throw "No immutable Thursday snapshots exist for $Season" }
    $scorePath = "artifacts\model_reports\shadow_history_${Season}.json"
    $scoreArgs = @("pipeline\score_prediction_history.py")
    foreach ($file in $files) { $scoreArgs += @("--predictions-file", $file.FullName) }
    $scoreArgs += @("--output", $scorePath)
    & $pythonExe @scoreArgs
    if ($LASTEXITCODE -ne 0) { throw "shadow history scoring failed" }

    $latest = $files | Select-Object -Last 1
    $driftPath = "artifacts\data_quality\model_feature_drift_${Season}.json"
    & $pythonExe pipeline\audit_model_feature_drift.py --current-season $Season --artifact $artifactPath --output $driftPath
    if ($LASTEXITCODE -ne 0) { throw "artifact-specific feature drift audit failed" }
    & $pythonExe pipeline\build_model_lab_dashboard.py --artifact $artifactPath --predictions-file $latest.FullName --drift-report $driftPath --shadow-report $scorePath --output dashboard\model-lab-data.js
    if ($LASTEXITCODE -ne 0) { throw "model lab refresh failed" }

    if ($PublishSite) {
        & git add -- dashboard/model-lab-data.js
        if ($LASTEXITCODE -ne 0) { throw "scorecard staging failed" }
        $changed = @(& git diff --cached --name-only -- dashboard/model-lab-data.js)
        if ($changed.Count -gt 0) {
            $stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
            & git commit --only -m "Refresh shadow scorecard $stamp" -- dashboard/model-lab-data.js
            if ($LASTEXITCODE -ne 0) { throw "scorecard commit failed" }
            & git push origin HEAD:main
            if ($LASTEXITCODE -ne 0) { throw "scorecard push failed" }
        }
    }
    Write-Host "Shadow scorecard refresh complete: $scorePath"
} catch {
    Write-Error ("Shadow scorecard refresh failed: " + ($_ | Out-String))
    throw
} finally {
    Pop-Location
    Stop-Transcript | Out-Null
}
