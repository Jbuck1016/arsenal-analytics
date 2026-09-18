param([switch]$Execute, [switch]$Interactive)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "refresh_match_results.ps1"
$identity = Split-Path -Leaf $env:USERPROFILE
$start = (Get-Date).AddMinutes(2)
$trigger = New-ScheduledTaskTrigger -Once -At $start `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$name = "FutScout Hourly Match Result Watcher"

Write-Host "$name starts $($start.ToString('s')); network calls are internally limited to daily 03:00-15:59 local"
if ($Execute) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument (
        "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    )
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    $logonType = if ($Interactive) { "Interactive" } else { "S4U" }
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType $logonType -RunLevel Limited
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal `
        -Description "Updates known final scores hourly every day in European match windows, then scores prediction and market ledgers. Full event ingestion remains nightly." `
        -Force | Out-Null
}
Write-Host "Execute mode: $($Execute.IsPresent)"
