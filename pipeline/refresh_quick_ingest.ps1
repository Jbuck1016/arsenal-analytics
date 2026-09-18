param([string]$Python = "$env:USERPROFILE\anaconda3\python.exe")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ("quick_ingest_" + [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ") + ".log")
Start-Transcript -Path $log -Append | Out-Null
Push-Location $repoRoot
try {
    & (Resolve-Path -LiteralPath $Python).Path pipeline\process_writing_lab_queue.py
    if ($LASTEXITCODE -ne 0) { throw "quick match ingest failed" }
} finally {
    Pop-Location
    Stop-Transcript | Out-Null
}
