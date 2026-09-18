param([switch]$Execute, [switch]$Interactive)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$identity = Split-Path -Leaf $env:USERPROFILE
$definitions = @(
    @{
        Name = "FutScout Quick Match Ingest"
        Script = Join-Path $PSScriptRoot "refresh_quick_ingest.ps1"
        Interval = New-TimeSpan -Minutes 5
        Limit = New-TimeSpan -Minutes 45
        Description = "Drains browser-submitted WhoScored match URLs into governed canonical or isolated cup storage."
    },
    @{
        Name = "FutScout Pipeline Health Publisher"
        Script = Join-Path $PSScriptRoot "publish_task_health.ps1"
        Interval = New-TimeSpan -Minutes 15
        Limit = New-TimeSpan -Minutes 5
        Description = "Publishes bounded Windows task heartbeats to private Supabase health state."
    }
)

foreach ($definition in $definitions) {
    $start = (Get-Date).AddMinutes(2)
    $trigger = New-ScheduledTaskTrigger -Once -At $start -RepetitionInterval $definition.Interval -RepetitionDuration (New-TimeSpan -Days 3650)
    Write-Host "$($definition.Name): starts $($start.ToString('s'))"
    if (-not $Execute) { continue }
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -WorkingDirectory $repoRoot -Argument (
        "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($definition.Script)`""
    )
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit $definition.Limit
    $logonType = if ($Interactive) { "Interactive" } else { "S4U" }
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType $logonType -RunLevel Limited
    Register-ScheduledTask -TaskName $definition.Name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $definition.Description -Force | Out-Null
}
Write-Host "Execute mode: $($Execute.IsPresent)"
