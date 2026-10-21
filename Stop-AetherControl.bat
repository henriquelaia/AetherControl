@echo off
title AetherControl // Stopping Service
color 0C
echo ============================================================================
echo   AETHERCONTROL // STOPPING DAEMON ^& RETURNING FAN CONTROL TO BIOS
echo ============================================================================

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:5175/api/daemon/shutdown' -Method Post -TimeoutSec 2 | Out-Null } catch {}; $lines = netstat -ano | Select-String ':5175\s+.*LISTENING\s+(\d+)'; foreach ($l in $lines) { $pidKill = [int]$l.Matches.Groups[1].Value; if ($pidKill -gt 4) { Stop-Process -Id $pidKill -Force -ErrorAction SilentlyContinue } }; Write-Host '  [+] AetherControl Service Stopped Cleanly.' -ForegroundColor Green"
timeout /t 2 >nul
