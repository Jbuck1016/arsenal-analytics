param([switch]$Execute, [switch]$Interactive)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "refresh_market_odds.ps1"
# Codex commands can run through a sandbox identity even though the durable
# desktop tasks belong to the signed-in profile. Mirror the existing FutScout
# tasks by binding to that interactive profile explicitly.
$identity = Split-Path -Leaf $env:USERPROFILE

$definitions = @(
    @{
        Name = "FutScout Thursday Market Snapshot"
        Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -SnapshotKind thursday -WindowHours 168 -Execute"
        Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Thursday -At "06:00"
        Description = "Captures immutable Thursday 1X2 odds alongside the frozen model slate."
    },
    @{
        Name = "FutScout Early Pre-Kickoff Market Snapshot"
        Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -SnapshotKind pre_kickoff -WindowHours 8 -Execute"
        Trigger = New-ScheduledTaskTrigger -Daily -At "03:00"
        Description = "Captures auditable pre-kickoff 1X2 odds for every European matchday, including midweek fixtures."
    },
    @{
        Name = "FutScout Late Pre-Kickoff Market Snapshot"
        Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -SnapshotKind pre_kickoff -WindowHours 8 -Execute"
        Trigger = New-ScheduledTaskTrigger -Daily -At "11:00"
        Description = "Captures a later auditable 1X2 snapshot; the report applies a strict closing-eligibility clock."
    }
)

foreach ($definition in $definitions) {
    Write-Host "$($definition.Name): $($definition.Trigger.StartBoundary)"
    if (-not $Execute) { continue }
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $definition.Arguments
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
    $logonType = if ($Interactive) { "Interactive" } else { "S4U" }
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType $logonType -RunLevel Limited
    Register-ScheduledTask -TaskName $definition.Name -Action $action -Trigger $definition.Trigger `
        -Settings $settings -Principal $principal -Description $definition.Description -Force | Out-Null
}

Write-Host "Execute mode: $($Execute.IsPresent)"
Write-Host "Requires ODDS_API_KEY in the backend .env; tasks do not invoke ChatGPT."
