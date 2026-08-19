@echo off
REM ===================================================================
REM  Scheduled scrape - all active leagues, then one full rebuild.
REM
REM  Runs unattended: scrape_league.py detects there is no terminal and
REM  skips the interactive menu, so --all is passed explicitly here.
REM  It only fetches matches it does not already have, so a missed night
REM  self-corrects on the next run with no duplicated work.
REM
REM  VERIFY the conda path below matches the output of: conda info --base
REM ===================================================================

setlocal
set "REPO=%USERPROFILE%\arsenal-analytics"
set "LOGDIR=%REPO%\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

REM one log per run, dated, so a bad run can be diagnosed after the fact.
REM PowerShell rather than wmic: wmic has been removed from recent Windows 11 builds.
set "STAMP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HHmm'"`) do set "STAMP=%%I"
if not defined STAMP set "STAMP=run"
set "LOG=%LOGDIR%\scrape_%STAMP%.log"

echo ================================================= >> "%LOG%"
echo  Scheduled scrape started %DATE% %TIME%           >> "%LOG%"
echo ================================================= >> "%LOG%"

call "%USERPROFILE%\anaconda3\Scripts\activate.bat" base
if errorlevel 1 (
  echo ERROR: could not activate conda base >> "%LOG%"
  echo Check that %USERPROFILE%\anaconda3 is the right path. >> "%LOG%"
  exit /b 1
)

cd /d "%REPO%"
if errorlevel 1 (
  echo ERROR: repo not found at %REPO% >> "%LOG%"
  exit /b 1
)

REM --all   : every league marked active in the leagues registry
REM --headless: no browser window steals focus on a scheduled run
python pipeline\scrape_league.py --all --headless >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"

echo. >> "%LOG%"
echo Finished %DATE% %TIME% with exit code %RC% >> "%LOG%"

REM keep the 30 most recent logs, delete the rest
for /f "skip=30 delims=" %%F in ('dir /b /o-d "%LOGDIR%\scrape_*.log" 2^>nul') do (
  del "%LOGDIR%\%%F" 2>nul
)

exit /b %RC%
