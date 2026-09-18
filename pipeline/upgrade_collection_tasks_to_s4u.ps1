param([switch]$IncludeNightlyScraper)

$ErrorActionPreference = "Stop"
$scripts = @(
    "register_match_result_task.ps1",
    "register_market_odds_tasks.ps1",
    "register_model_operations_task.ps1",
    "register_collection_support_tasks.ps1"
)

foreach ($script in $scripts) {
    $path = Join-Path $PSScriptRoot $script
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path -Execute
    if ($LASTEXITCODE -ne 0) { throw "S4U registration failed: $script" }
}

if ($IncludeNightlyScraper) {
    $path = Join-Path $PSScriptRoot "register_scrape_task.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path -Execute -Force
    if ($LASTEXITCODE -ne 0) { throw "S4U registration failed: register_scrape_task.ps1" }
}

Write-Host "Collection tasks registered for background S4U execution."
Write-Host "Run this script from an elevated Windows PowerShell session."
