param([string]$Python = "$env:USERPROFILE\anaconda3\python.exe")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$mapping = [ordered]@{
    "MLS-Euro Analytics Scrape" = "nightly_ingestion"
    "FutScout Hourly Match Result Watcher" = "match_result_watcher"
    "FutScout Early Pre-Kickoff Market Snapshot" = "market_odds_early"
    "FutScout Late Pre-Kickoff Market Snapshot" = "market_odds_late"
    "FutScout Thursday Market Snapshot" = "market_odds_thursday"
    "FutScout Daily Prediction Ledger" = "prediction_ledger"
    "FutScout Thursday Shadow Forecast" = "shadow_forecast"
    "FutScout Tuesday Shadow Scorecard" = "shadow_scorecard"
    "FutScout Quick Match Ingest" = "quick_ingest"
    "FutScout Pipeline Health Publisher" = "pipeline_health_publisher"
}

$records = @()
foreach ($taskName in $mapping.Keys) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        $records += [ordered]@{
            pipeline_name = $mapping[$taskName]
            status = "failed"
            observed_at = [DateTimeOffset]::UtcNow.ToString("o")
            next_run_at = $null
            host = $env:COMPUTERNAME
            detail = @{ task_name = $taskName; task_state = "missing" }
            error = "Windows scheduled task is missing"
        }
        continue
    }
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    if ($task.State -eq "Disabled") { $status = "disabled" }
    elseif ($task.State -eq "Running") { $status = "running" }
    elseif ($info.LastRunTime.Year -le 2000) { $status = "never_run" }
    elseif ($info.LastTaskResult -eq 0) { $status = "success" }
    else { $status = "failed" }
    $observed = if ($status -eq "running") { [DateTimeOffset]::UtcNow } else { [DateTimeOffset]$info.LastRunTime }
    $next = if ($info.NextRunTime.Year -gt 2000) { ([DateTimeOffset]$info.NextRunTime).ToUniversalTime().ToString("o") } else { $null }
    $records += [ordered]@{
        pipeline_name = $mapping[$taskName]
        status = $status
        observed_at = $observed.ToUniversalTime().ToString("o")
        next_run_at = $next
        host = $env:COMPUTERNAME
        detail = @{ task_name = $taskName; task_state = [string]$task.State; task_result = $info.LastTaskResult }
        error = if ($status -eq "failed") { "Windows Task Scheduler result $($info.LastTaskResult)" } else { $null }
    }
}

Push-Location $repoRoot
try {
    $json = $records | ConvertTo-Json -Depth 5 -Compress
    $inputPath = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($inputPath, $json, [System.Text.UTF8Encoding]::new($false))
        & (Resolve-Path -LiteralPath $Python).Path pipeline\record_pipeline_health.py --input $inputPath
        if ($LASTEXITCODE -ne 0) { throw "pipeline health publication failed" }
    } finally {
        Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
    }
} finally {
    Pop-Location
}
