param(
    [ValidateSet("thursday", "pre_kickoff", "ad_hoc")]
    [string]$SnapshotKind = "ad_hoc",
    [double]$WindowHours = 8,
    [string]$Season = "2627",
    [int]$ModelRunId = 4,
    [string]$Python = "$env:USERPROFILE\anaconda3\python.exe",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
$operationLog = Join-Path $logDir ("market_odds_" + $SnapshotKind + "_" + $stamp + ".log")
$artifact = "artifacts\market_odds\${Season}_${SnapshotKind}_${stamp}.json"

Start-Transcript -Path $operationLog -Append | Out-Null
Push-Location $repoRoot
try {
    $pythonExe = (Resolve-Path -LiteralPath $Python).Path
    $captureArgs = @(
        "pipeline\capture_market_odds.py",
        "--season", $Season,
        "--snapshot-kind", $SnapshotKind,
        "--window-hours", $WindowHours,
        "--output", $artifact
    )
    if ($Execute) { $captureArgs += "--execute" }
    & $pythonExe @captureArgs
    if ($LASTEXITCODE -ne 0) { throw "market odds capture failed" }

    if ($Execute) {
        & $pythonExe pipeline\build_market_edge_report.py `
            --season $Season --model-run-id $ModelRunId `
            --output "artifacts\model_reports\market_edge_report_${Season}.json"
        if ($LASTEXITCODE -ne 0) { throw "market edge report failed" }
    }
    Write-Host "Market odds refresh complete: $artifact"
} catch {
    Write-Error ("Market odds refresh failed: " + ($_ | Out-String))
    throw
} finally {
    Pop-Location
    Stop-Transcript | Out-Null
}
