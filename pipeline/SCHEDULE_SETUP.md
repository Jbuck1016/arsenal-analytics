# Setting up Auto-Scrape on Windows

## Add to Windows Task Scheduler:
1. Open Task Scheduler (search in Start menu)
2. Click "Create Basic Task"
3. Name: "Arsenal Analytics Scrape"
4. Trigger: Weekly, every 3 days
5. Action: Start a program
6. Program: C:\Users\jbuck\arsenal-analytics\pipeline\scrape_all.bat
7. Click Finish

## To run manually:
Double-click scrape_all.bat or run it from PowerShell
