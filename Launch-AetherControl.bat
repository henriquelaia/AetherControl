@echo off
title AetherControl // Next-Gen Hardware Monitor & Predictive Fan Controller
color 0B
echo ============================================================================
echo   AETHERCONTROL v3.0 // UNIVERSAL HARDWARE TELEMETRY ^& THERMAL STUDIO
echo ============================================================================
echo.

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0AetherControl-NativeDaemon.ps1"
pause
