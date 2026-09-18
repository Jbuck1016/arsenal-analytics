param(
    [string]$Season = "2627",
    [string]$Python = "$env:USERPROFILE\anaconda3\python.exe",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$now = Get-Date
$allowedDays = @([DayOfWeek]::Friday, [DayOfWeek]::Saturday, [DayOfWeek]::Sunday, [DayOfWeek]::Monday)
if (-not $Force -and ($allowedDays -notcontains $now.DayOfWeek -or $now.Hour -lt 3 -or $now.Hour -ge 16)) {
    Write-Host "Outside the European result-watch window; successful no-op"
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
$operationLog = Join-Path $logDir ("match_results_" + $stamp + ".log")
Start-Transcript -Path $operationLog -Append | Out-Null

Push-Location $repoRoot
try {
    $pythonExe = (Resolve-Path -LiteralPath $Python).Path
    & $pythonExe pipeline\sync_match_results.py --season $Season `
        --output "artifacts\model_reports\result_sync_${Season}.json" --execute
    if ($LASTEXITCODE -ne 0) { throw "result sync failed" }
    & $pythonExe pipeline\score_prediction_ledger.py --season $Season `
        --output "artifacts\model_reports\prediction_ledger_${Season}.json"
    if ($LASTEXITCODE -ne 0) { throw "prediction ledger refresh failed" }
    & $pythonExe pipeline\build_market_edge_report.py --season $Season `
        --output "artifacts\model_reports\market_edge_report_${Season}.json"
    if ($LASTEXITCODE -ne 0) { throw "market comparison refresh failed" }
    Write-Host "Match result refresh complete"
} catch {
    Write-Error ("Match result refresh failed: " + ($_ | Out-String))
    throw
} finally {
    Pop-Location
    Stop-Transcript | Out-Null
}
