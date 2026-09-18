param([switch]$Interactive)
$ErrorActionPreference = "Stop"

# =====================================================================
#  Register the scheduled scrape every night in the stable backend worktree.
#
#  Run this ONCE, in an ADMINISTRATOR PowerShell window.
#  (Right-click PowerShell -> Run as administrator)
#
#  WakeToRun     : brings the machine out of sleep to run. Needs the PC
#                  powered on and asleep, not shut down.
#  StartWhenAvailable : if the machine was off or the wake failed, run at
#                  the next opportunity rather than skipping the night.
#  The scraper only fetches matches it does not already have, so a late
#  or repeated run costs nothing.
# =====================================================================

$TaskName = "MLS-Euro Analytics Scrape"
$Script   = Join-Path $PSScriptRoot "weekly_scrape.bat"
$RunAt    = "11:30PM"        # late enough that Sunday evening games have finished

if (-not (Test-Path $Script)) {
  Write-Host "Could not find $Script" -ForegroundColor Red
  Write-Host "Place weekly_scrape.bat in the pipeline folder first." -ForegroundColor Red
  exit 1
}

# remove any previous registration so this script is safe to re-run
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$action  = New-ScheduledTaskAction -Execute $Script

$trigger = New-ScheduledTaskTrigger -Daily -At $RunAt

$settings = New-ScheduledTaskSettingsSet `
             -WakeToRun `
             -StartWhenAvailable `
             -AllowStartIfOnBatteries `
             -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
             -MultipleInstances IgnoreNew

$logonType = if ($Interactive) { "Interactive" } else { "S4U" }
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType $logonType -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName `
  -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
  -Description "Scrapes all active leagues and rebuilds the analytics layers." -Force | Out-Null

Write-Host ""
Write-Host "Registered '$TaskName'" -ForegroundColor Green
Write-Host "  Runs   : every day at $RunAt"
Write-Host "  Script : $Script"
Write-Host "  Logs   : $(Join-Path (Split-Path -Parent $PSScriptRoot) 'logs')\"
Write-Host ""
Write-Host "Test it now without waiting for the weekend:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "Check it ran:" -ForegroundColor Yellow
Write-Host "  Get-ScheduledTaskInfo -TaskName '$TaskName'"
Write-Host ""
Write-Host "IMPORTANT: wake timers must be enabled for the wake to work." -ForegroundColor Yellow
Write-Host "  Control Panel -> Power Options -> Change plan settings ->"
Write-Host "  Change advanced power settings -> Sleep -> Allow wake timers -> Enable"
Write-Host ""
