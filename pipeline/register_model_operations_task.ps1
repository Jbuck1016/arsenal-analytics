param([switch]$Execute)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$weeklyScript = Join-Path $PSScriptRoot "run_shadow_weekly.ps1"
$scoreScript = Join-Path $PSScriptRoot "refresh_shadow_scorecard.ps1"
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$today = [DateTime]::Today
$nextThursday = $today.AddDays((([int][DayOfWeek]::Thursday - [int]$today.DayOfWeek) + 7) % 7).AddHours(5)
if ($nextThursday -le [DateTime]::Now) { $nextThursday = $nextThursday.AddDays(7) }
$nextTuesday = $today.AddDays((([int][DayOfWeek]::Tuesday - [int]$today.DayOfWeek) + 7) % 7).AddHours(5)
if ($nextTuesday -le $nextThursday) { $nextTuesday = $nextTuesday.AddDays(7) }

$definitions = @(
    @{
        Name = "FutScout Thursday Shadow Forecast"
        Script = $weeklyScript
        Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$weeklyScript`" -Execute -PublishSite"
        Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Thursday -At $nextThursday
        Description = "Freezes, audits, persists, simulates, and publishes the private five-league shadow slate. Never activates a model."
    },
    @{
        Name = "FutScout Tuesday Shadow Scorecard"
        Script = $scoreScript
        Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scoreScript`" -PublishSite"
        Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Tuesday -At $nextTuesday
        Description = "Scores resolved frozen forecasts and refreshes the private model lab. Never activates a model."
    }
)

foreach ($definition in $definitions) {
    if (-not (Test-Path -LiteralPath $definition.Script)) { throw "Missing task script: $($definition.Script)" }
    Write-Host "$($definition.Name): $($definition.Trigger.StartBoundary)"
    if (-not $Execute) { continue }
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $definition.Arguments -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 3)
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $definition.Name -Action $action -Trigger $definition.Trigger -Settings $settings -Principal $principal -Description $definition.Description -Force | Out-Null
}

Write-Host "Execute mode: $($Execute.IsPresent)"
Write-Host "The tasks use local Python/Supabase credentials and Git/Vercel integration; they do not invoke ChatGPT."
