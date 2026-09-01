param(
    [ValidateSet("2526", "2425", "2324")]
    [string]$Season = "2526",
    [int]$MaxMatches = 0,
    [switch]$Headless,
    [switch]$Execute
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logDir "history_${Season}_$stamp.log"

$arguments = @(
    (Join-Path $PSScriptRoot "scrape_history.py"),
    "--season", $Season,
    "--max-matches", $MaxMatches
)
if ($Headless) { $arguments += "--headless" }
if ($Execute) { $arguments += "--execute" }

Push-Location $repoRoot
try {
    & python @arguments 2>&1 | Tee-Object -FilePath $log
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
Write-Host "Log: $log"
exit $exitCode
