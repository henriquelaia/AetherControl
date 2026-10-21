@echo off
title AetherControl // Hardware Auto-Scanner & Sensor PoC
color 0A
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0AetherControl-NativeDaemon.ps1" -PocOnly
pause
